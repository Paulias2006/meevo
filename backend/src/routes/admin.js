import { Router } from 'express';
import { z } from 'zod';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { Booking } from '../models/Booking.js';
import { PartnerWithdrawal } from '../models/PartnerWithdrawal.js';
import { Provider } from '../models/Provider.js';
import { ReservationPayment } from '../models/ReservationPayment.js';
import { SubscriptionPayment } from '../models/SubscriptionPayment.js';
import { User } from '../models/User.js';
import { Venue } from '../models/Venue.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { hashPassword } from '../utils/auth.js';
import { normalizeCityLabel } from '../utils/cities.js';

const listUsersQuerySchema = z.object({
  q: z.string().optional().default(''),
  role: z
    .enum(['Tous', 'customer', 'partner', 'admin'])
    .optional()
    .default('Tous'),
  subscriptionStatus: z
    .enum(['Tous', 'inactive', 'pending', 'active', 'expired', 'cancelled'])
    .optional()
    .default('Tous'),
  city: z.string().optional().default(''),
  from: z.string().optional().default(''),
  to: z.string().optional().default(''),
});

const createAdminSchema = z.object({
  fullName: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(8),
  phone: z.string().optional().or(z.literal('')),
  city: z.string().optional().or(z.literal('')),
});

const updateAdminStatusSchema = z.object({
  isAdmin: z.boolean(),
});

const router = Router();

router.use(requireAuth, requireRole('admin'));

function resolveSubscriptionState(user) {
  const subscription = user.subscription;

  if (!subscription) {
    return 'inactive';
  }

  if (subscription.status === 'active' && subscription.endsAt) {
    const expiresAt = new Date(subscription.endsAt).getTime();
    if (!Number.isNaN(expiresAt) && expiresAt < Date.now()) {
      return 'expired';
    }
  }

  return subscription.status || 'inactive';
}

function toAdminUserRecord(user) {
  return {
    user: user.toPublicJSON(),
    businessName: user.partnerProfile?.businessName || '',
    partnerType: user.partnerProfile?.partnerType || '',
    whatsapp: user.partnerProfile?.whatsapp || '',
    subscriptionState: resolveSubscriptionState(user),
    hasPartnerProfile: Boolean(user.partnerProfile?.partnerType),
  };
}

function endOfDay(dateString) {
  const value = new Date(`${dateString}T23:59:59.999Z`);
  return Number.isNaN(value.getTime()) ? null : value;
}

function startOfDay(dateString) {
  const value = new Date(`${dateString}T00:00:00.000Z`);
  return Number.isNaN(value.getTime()) ? null : value;
}

async function ensureDeletionAllowed(currentUser, targetUser) {
  if (currentUser._id.toString() === targetUser._id.toString()) {
    return 'Vous ne pouvez pas supprimer votre propre compte admin.';
  }

  if (targetUser.role === 'admin') {
    const adminCount = await User.countDocuments({ role: 'admin' });
    if (adminCount <= 1) {
      return 'Le dernier compte admin ne peut pas etre supprime.';
    }
  }

  return '';
}

router.get(
  '/users',
  asyncHandler(async (request, response) => {
    const query = listUsersQuerySchema.parse(request.query);
    const mongoFilter = {};
    const createdAtFilter = {};

    if (query.role !== 'Tous') {
      mongoFilter.role = query.role;
    }

    const fromDate = query.from ? startOfDay(query.from) : null;
    if (fromDate) {
      createdAtFilter.$gte = fromDate;
    }

    const toDate = query.to ? endOfDay(query.to) : null;
    if (toDate) {
      createdAtFilter.$lte = toDate;
    }

    if (Object.keys(createdAtFilter).length > 0) {
      mongoFilter.createdAt = createdAtFilter;
    }

    const users = await User.find(mongoFilter).sort({ createdAt: -1 });
    const q = query.q.trim().toLowerCase();
    const cityQuery = query.city.trim().toLowerCase();

    const items = users
      .filter((user) => {
        const subscriptionState = resolveSubscriptionState(user);
        if (
          query.subscriptionStatus !== 'Tous' &&
          subscriptionState !== query.subscriptionStatus
        ) {
          return false;
        }

        if (cityQuery) {
          const cityHaystack = (user.city || '').toLowerCase();
          if (!cityHaystack.includes(cityQuery)) {
            return false;
          }
        }

        if (!q) {
          return true;
        }

        const haystack = [
          user.fullName,
          user.email,
          user.phone,
          user.city,
          user.partnerProfile?.businessName,
          user.partnerProfile?.partnerType,
          user.partnerProfile?.whatsapp,
          subscriptionState,
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();

        return haystack.includes(q);
      })
      .map(toAdminUserRecord);

    const summary = {
      totalUsers: items.length,
      admins: items.filter((item) => item.user.role == 'admin').length,
      partners: items.filter((item) => item.user.role == 'partner').length,
      customers: items.filter((item) => item.user.role == 'customer').length,
      activeSubscriptions: items.filter(
        (item) => item.subscriptionState == 'active',
      ).length,
    };

    response.json({
      item: {
        summary,
        items,
      },
    });
  }),
);

router.post(
  '/users/admin',
  asyncHandler(async (request, response) => {
    const body = createAdminSchema.parse(request.body);
    const email = body.email.toLowerCase().trim();
    const normalizedCity = normalizeCityLabel(body.city || '');
    const passwordHash = await hashPassword(body.password);
    const existing = await User.findOne({ email });

    if (existing) {
      existing.fullName = body.fullName.trim();
      existing.phone = (body.phone || '').trim();
      existing.city = normalizedCity;
      existing.role = 'admin';
      existing.passwordHash = passwordHash;
      await existing.save();

      return response.status(201).json({
        item: toAdminUserRecord(existing),
      });
    }

    const created = await User.create({
      fullName: body.fullName.trim(),
      email,
      phone: (body.phone || '').trim(),
      city: normalizedCity,
      passwordHash,
      role: 'admin',
    });

    response.status(201).json({
      item: toAdminUserRecord(created),
    });
  }),
);

router.patch(
  '/users/:userId/admin',
  asyncHandler(async (request, response) => {
    const body = updateAdminStatusSchema.parse(request.body);
    const target = await User.findById(request.params.userId);

    if (!target) {
      return response.status(404).json({
        message: 'Utilisateur introuvable.',
      });
    }

    if (!body.isAdmin && request.user._id.toString() === target._id.toString()) {
      return response.status(409).json({
        message: 'Vous ne pouvez pas retirer vos propres droits admin ici.',
      });
    }

    if (body.isAdmin) {
      target.role = 'admin';
    } else {
      const adminCount = await User.countDocuments({ role: 'admin' });
      if (target.role === 'admin' && adminCount <= 1) {
        return response.status(409).json({
          message: 'Le dernier compte admin ne peut pas perdre ses droits.',
        });
      }

      target.role = target.partnerProfile?.partnerType ? 'partner' : 'customer';
    }

    await target.save();

    response.json({
      item: toAdminUserRecord(target),
    });
  }),
);

router.delete(
  '/users/:userId',
  asyncHandler(async (request, response) => {
    const target = await User.findById(request.params.userId);

    if (!target) {
      return response.status(404).json({
        message: 'Utilisateur introuvable.',
      });
    }

    const blockMessage = await ensureDeletionAllowed(request.user, target);
    if (blockMessage) {
      return response.status(409).json({
        message: blockMessage,
      });
    }

    const venueIds = (
      await Venue.find({ partner: target._id }).select('_id')
    ).map((item) => item._id);
    const providerIds = (
      await Provider.find({ partner: target._id }).select('_id')
    ).map((item) => item._id);

    const bookingOr = [{ customer: target._id }];
    if (venueIds.length > 0) {
      bookingOr.push({ venue: { $in: venueIds } });
    }
    if (providerIds.length > 0) {
      bookingOr.push({ provider: { $in: providerIds } });
    }

    const bookingIds = (await Booking.find({ $or: bookingOr }).select('_id')).map(
      (item) => item._id,
    );

    const paymentOr = [{ customer: target._id }, { partner: target._id }];
    if (venueIds.length > 0) {
      paymentOr.push({ venue: { $in: venueIds } });
    }
    if (providerIds.length > 0) {
      paymentOr.push({ provider: { $in: providerIds } });
    }
    if (bookingIds.length > 0) {
      paymentOr.push({ booking: { $in: bookingIds } });
    }

    await ReservationPayment.deleteMany({ $or: paymentOr });
    await Booking.deleteMany({ $or: bookingOr });
    await SubscriptionPayment.deleteMany({ user: target._id });
    await PartnerWithdrawal.deleteMany({ partner: target._id });

    if (providerIds.length > 0) {
      await Provider.deleteMany({ _id: { $in: providerIds } });
    }
    if (venueIds.length > 0) {
      await Venue.deleteMany({ _id: { $in: venueIds } });
    }

    await User.deleteOne({ _id: target._id });

    response.json({
      message: 'Utilisateur supprime.',
    });
  }),
);

export const adminRouter = router;
