import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { ReservationPayment } from '../models/ReservationPayment.js';
import { User } from '../models/User.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { comparePassword, hashPassword, signToken } from '../utils/auth.js';
import { normalizeCityLabel } from '../utils/cities.js';
import { env } from '../config/env.js';
import { applyPayoutProfileToReservationPayment } from '../utils/reservationPayments.js';

const registerSchema = z.object({
  fullName: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(8),
  phone: z.string().min(6).optional().or(z.literal('')),
  city: z.string().optional().or(z.literal('')),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

const partnerOnboardingSchema = z.object({
  businessName: z.string().min(2),
  partnerType: z.enum([
    'Salle',
    'Hotel',
    'Prestataire',
    'Lieu hybride',
    'Salle + Prestataire',
  ]),
  city: z.string().min(2),
  district: z.string().optional().or(z.literal('')),
  whatsapp: z.string().min(6),
  description: z.string().min(12),
});

const payoutProfileSchema = z.object({
  phoneNumber: z.string().min(6),
  network: z.enum(['MOOV', 'TOGOCEL']),
  accountName: z.string().min(2),
});

const router = Router();

router.post(
  '/register',
  asyncHandler(async (request, response) => {
    const body = registerSchema.parse(request.body);
    const existingUser = await User.findOne({ email: body.email.toLowerCase() });

    if (existingUser) {
      return response.status(409).json({
        message: 'Un compte existe deja avec cet email.',
      });
    }

    const user = await User.create({
      fullName: body.fullName,
      email: body.email.toLowerCase(),
      phone: body.phone || '',
      city: normalizeCityLabel(body.city || ''),
      role: 'customer',
      passwordHash: await hashPassword(body.password),
    });

    const token = signToken({ sub: user._id.toString(), role: user.role }, env.JWT_SECRET);

    return response.status(201).json({
      token,
      user: user.toPublicJSON(),
    });
  }),
);

router.post(
  '/login',
  asyncHandler(async (request, response) => {
    const body = loginSchema.parse(request.body);
    const user = await User.findOne({ email: body.email.toLowerCase() });

    if (!user) {
      return response.status(401).json({
        message: 'Email ou mot de passe incorrect.',
      });
    }

    const isValidPassword = await comparePassword(body.password, user.passwordHash);

    if (!isValidPassword) {
      return response.status(401).json({
        message: 'Email ou mot de passe incorrect.',
      });
    }

    const token = signToken({ sub: user._id.toString(), role: user.role }, env.JWT_SECRET);

    return response.json({
      token,
      user: user.toPublicJSON(),
    });
  }),
);

router.get(
  '/me',
  requireAuth,
  asyncHandler(async (request, response) => {
    response.json({
      user: request.user.toPublicJSON(),
    });
  }),
);

router.post(
  '/become-partner',
  requireAuth,
  asyncHandler(async (request, response) => {
    const body = partnerOnboardingSchema.parse(request.body);

    request.user.role =
      request.user.role === 'admin' ? 'admin' : 'partner';
    request.user.city = normalizeCityLabel(body.city);
    request.user.partnerProfile = {
      businessName: body.businessName,
      partnerType: body.partnerType,
      whatsapp: body.whatsapp,
      district: body.district || '',
      description: body.description,
      payoutPhoneNumber: request.user.partnerProfile?.payoutPhoneNumber || '',
      payoutNetwork: request.user.partnerProfile?.payoutNetwork || '',
      payoutAccountName: request.user.partnerProfile?.payoutAccountName || '',
      payoutUpdatedAt: request.user.partnerProfile?.payoutUpdatedAt,
      submittedAt: new Date(),
    };
    request.user.subscription = {
      status:
        request.user.subscription?.status === 'active'
          ? 'active'
          : 'inactive',
      cycle: request.user.subscription?.cycle || 'monthly',
      months: request.user.subscription?.months || 0,
      monthlyPrice: request.user.subscription?.monthlyPrice || 0,
      grossAmount: request.user.subscription?.grossAmount || 0,
      discountAmount: request.user.subscription?.discountAmount || 0,
      totalAmount: request.user.subscription?.totalAmount || 0,
      paygateNetwork: request.user.subscription?.paygateNetwork || '',
      paymentMethod: request.user.subscription?.paymentMethod || '',
      currentPaymentIdentifier:
        request.user.subscription?.currentPaymentIdentifier || '',
      startedAt: request.user.subscription?.startedAt,
      endsAt: request.user.subscription?.endsAt,
      lastPaymentAt: request.user.subscription?.lastPaymentAt,
    };
    await request.user.save();

    const token = signToken(
      { sub: request.user._id.toString(), role: request.user.role },
      env.JWT_SECRET,
    );

    return response.json({
      token,
      user: request.user.toPublicJSON(),
    });
  }),
);

router.patch(
  '/payout-profile',
  requireAuth,
  asyncHandler(async (request, response) => {
    if (
      request.user.role !== 'partner' &&
      request.user.role !== 'admin' &&
      !request.user.partnerProfile?.partnerType
    ) {
      return response.status(409).json({
        message: 'Configurez d abord votre dossier partenaire.',
      });
    }

    const body = payoutProfileSchema.parse(request.body);

    request.user.partnerProfile = {
      businessName: request.user.partnerProfile?.businessName || '',
      partnerType: request.user.partnerProfile?.partnerType || '',
      whatsapp: request.user.partnerProfile?.whatsapp || '',
      district: request.user.partnerProfile?.district || '',
      description: request.user.partnerProfile?.description || '',
      submittedAt: request.user.partnerProfile?.submittedAt,
      payoutPhoneNumber: body.phoneNumber,
      payoutNetwork: body.network,
      payoutAccountName: body.accountName,
      payoutUpdatedAt: new Date(),
    };
    await request.user.save();

    const pendingPayouts = await ReservationPayment.find({
      partner: request.user._id,
      status: 'success',
      payoutStatus: 'pending_profile',
    });

    if (pendingPayouts.length > 0) {
      await Promise.all(
        pendingPayouts.map((payment) => {
          applyPayoutProfileToReservationPayment(payment, {
            phoneNumber: body.phoneNumber,
            network: body.network,
            accountName: body.accountName,
          });
          return payment.save();
        }),
      );
    }

    response.json({
      user: request.user.toPublicJSON(),
    });
  }),
);

export const authRouter = router;
