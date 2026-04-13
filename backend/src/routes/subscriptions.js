import { Router } from 'express';
import { z } from 'zod';
import { env } from '../config/env.js';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { SubscriptionPayment } from '../models/SubscriptionPayment.js';
import { User } from '../models/User.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import {
  checkCinetpayPaymentStatus,
  initiateCinetpayPayment,
  isCinetpayConfigured,
} from '../utils/cinetpay.js';
import { getPartnerSubscriptionVisibility } from '../utils/subscriptionVisibility.js';
import {
  addMonths,
  buildPartnerModules,
  buildSubscriptionPresets,
  computeSubscriptionQuote,
  createSubscriptionIdentifier,
  paymentNetworkOptions,
} from '../utils/subscriptions.js';

const router = Router();

const checkoutSchema = z.object({
  months: z.coerce.number().int().min(1).max(env.PARTNER_MAX_SUBSCRIPTION_MONTHS),
  network: z.enum(['MOOV', 'TOGOCEL']),
  phoneNumber: z.string().min(6),
});

const verifySchema = z.object({
  identifier: z.string().optional().or(z.literal('')),
});

const callbackSchema = z.object({
  tx_reference: z.string().optional().or(z.literal('')),
  identifier: z.string().min(1),
  payment_reference: z.string().optional().or(z.literal('')),
  amount: z.union([z.string(), z.number()]).optional(),
  datetime: z.string().optional().or(z.literal('')),
  payment_method: z.string().optional().or(z.literal('')),
  phone_number: z.string().optional().or(z.literal('')),
});

function monthLabel(date) {
  return new Intl.DateTimeFormat('fr-FR', {
    month: 'short',
    year: 'numeric',
  }).format(date);
}

function buildAdminDateFilters(yearRaw, monthRaw) {
  const year = Number.parseInt(String(yearRaw || ''), 10);
  const month = Number.parseInt(String(monthRaw || ''), 10);

  if (!Number.isFinite(year) || year < 2020 || year > 2100) {
    return null;
  }

  const safeMonth = Number.isFinite(month) && month >= 1 && month <= 12
    ? month
    : null;
  const start = safeMonth
    ? new Date(year, safeMonth - 1, 1)
    : new Date(year, 0, 1);
  const end = safeMonth
    ? new Date(year, safeMonth, 1)
    : new Date(year + 1, 0, 1);

  return {
    $gte: start,
    $lt: end,
  };
}

function buildAdminSubscriptionRecord(payment) {
  const user = payment.user;
  const visibility = getPartnerSubscriptionVisibility(user);

  return {
    payment: payment.toPublicJSON(),
    user: user.toPublicJSON(),
    subscriptionState: visibility.state,
    isVisiblePublicly: visibility.isVisiblePublicly,
    inGracePeriod: visibility.inGracePeriod,
    daysUntilExpiry: visibility.daysUntilExpiry,
    daysUntilGraceEnd: visibility.daysUntilGraceEnd,
    expiresAt: visibility.expiresAt,
    graceEndsAt: visibility.graceEndsAt,
  };
}

function buildAdminSubscriptionSummary(records) {
  const successful = records.filter((item) => item.payment.status === 'success');
  const pending = records.filter((item) =>
    ['pending', 'processing'].includes(item.payment.status),
  );
  const failed = records.filter((item) =>
    ['failed', 'cancelled', 'expired'].includes(item.payment.status),
  );
  const now = new Date();
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth();

  const currentMonthRevenue = successful.reduce((sum, item) => {
    const effectiveDate = new Date(item.payment.paidAt || item.payment.createdAt || now);
    if (
      effectiveDate.getFullYear() === currentYear &&
      effectiveDate.getMonth() === currentMonth
    ) {
      return sum + item.payment.totalAmount;
    }
    return sum;
  }, 0);

  const latestByUser = new Map();
  for (const item of records) {
    if (!latestByUser.has(item.user.id)) {
      latestByUser.set(item.user.id, item);
    }
  }

  const uniqueUsers = Array.from(latestByUser.values());

  return {
    totalPayments: records.length,
    successfulPayments: successful.length,
    pendingPayments: pending.length,
    failedPayments: failed.length,
    activePartners: uniqueUsers.filter((item) => item.subscriptionState === 'active').length,
    expiringSoonPartners: uniqueUsers.filter((item) => item.subscriptionState === 'expiring_soon').length,
    gracePartners: uniqueUsers.filter((item) => item.subscriptionState === 'grace').length,
    hiddenPartners: uniqueUsers.filter((item) => item.subscriptionState === 'expired').length,
    totalRevenue: successful.reduce((sum, item) => sum + item.payment.totalAmount, 0),
    currentMonthRevenue,
  };
}

function buildAdminSubscriptionTimeline(records) {
  const now = new Date();
  const points = [];
  const indexByKey = new Map();

  for (let offset = 11; offset >= 0; offset -= 1) {
    const date = new Date(now.getFullYear(), now.getMonth() - offset, 1);
    const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
    const point = {
      key,
      label: monthLabel(date),
      count: 0,
      revenue: 0,
    };
    indexByKey.set(key, point);
    points.push(point);
  }

  for (const item of records) {
    const effectiveDate = new Date(item.payment.paidAt || item.payment.createdAt || now);
    const key = `${effectiveDate.getFullYear()}-${String(effectiveDate.getMonth() + 1).padStart(2, '0')}`;
    const point = indexByKey.get(key);
    if (!point) continue;
    point.count += 1;
    if (item.payment.status === 'success') {
      point.revenue += item.payment.totalAmount;
    }
  }

  return points;
}

function buildOverview(user, payments = []) {
  return {
    paymentConfigured: isCinetpayConfigured(),
    monthlyPrice: env.PARTNER_MONTHLY_PRICE,
    maxMonths: env.PARTNER_MAX_SUBSCRIPTION_MONTHS,
    presets: buildSubscriptionPresets(),
    networks: paymentNetworkOptions.map((item) => ({
      code: item.code,
      label: item.label,
      paymentMethodLabel: item.paymentMethodLabel,
    })),
    subscription: user.toPublicJSON().subscription,
    canAccessDashboard: user.hasOperationalPartnerAccess(),
    payments: payments.map((item) => item.toPublicJSON()),
  };
}

async function applySuccessfulPayment({ user, payment, statusPayload }) {
  const paidAt = statusPayload?.datetime
    ? new Date(statusPayload.datetime)
    : payment.paidAt || new Date();
  const hasActiveCurrent =
    user.subscription?.status === 'active' &&
    user.subscription?.endsAt &&
    new Date(user.subscription.endsAt).getTime() >= Date.now();

  if (!payment.appliedAt) {
    const startAt = hasActiveCurrent && user.subscription?.endsAt
      ? new Date(user.subscription.endsAt)
      : new Date();
    const endsAt = addMonths(startAt, payment.months);

    user.role = user.role === 'admin' ? 'admin' : 'partner';
    user.subscription = {
      status: 'active',
      cycle: payment.cycle,
      months: payment.months,
      monthlyPrice: payment.monthlyPrice,
      grossAmount: payment.grossAmount,
      discountAmount: payment.discountAmount,
      totalAmount: payment.totalAmount,
      paygateNetwork: payment.network,
      paymentMethod:
        statusPayload?.payment_method || payment.paymentMethod || '',
      currentPaymentIdentifier: payment.identifier,
      startedAt:
        hasActiveCurrent && user.subscription?.startedAt
          ? user.subscription.startedAt
          : startAt,
      endsAt,
      lastPaymentAt: paidAt,
    };
    payment.appliedAt = new Date();
  }

  payment.status = 'success';
  payment.paymentMethod =
    statusPayload?.payment_method || payment.paymentMethod || '';
  payment.txReference = statusPayload?.tx_reference || payment.txReference;
  payment.paymentReference =
    statusPayload?.payment_reference || payment.paymentReference;
  payment.phoneNumber = statusPayload?.phone_number || payment.phoneNumber;
  payment.paidAt = paidAt;
  payment.lastStatusPayload = statusPayload || payment.lastStatusPayload;

  await Promise.all([payment.save(), user.save()]);
  return user;
}

router.get(
  '/me',
  requireAuth,
  asyncHandler(async (request, response) => {
    const payments = await SubscriptionPayment.find({ user: request.user._id })
      .sort({ createdAt: -1 })
      .limit(12);

    response.json({
      item: buildOverview(request.user, payments),
    });
  }),
);

router.get(
  '/admin',
  requireAuth,
  requireRole('admin'),
  asyncHandler(async (request, response) => {
    const {
      q = '',
      status,
      network,
      year,
      month,
      subscriptionState,
    } = request.query;
    const filters = {};

    if (status && status !== 'Tous') {
      filters.status = String(status);
    }

    if (network && network !== 'Tous') {
      filters.network = String(network);
    }

    const createdAt = buildAdminDateFilters(year, month);
    if (createdAt) {
      filters.createdAt = createdAt;
    }

    const payments = await SubscriptionPayment.find(filters)
      .populate('user')
      .sort({ createdAt: -1 })
      .limit(2000);

    const search = String(q).trim().toLowerCase();
    const records = payments
      .filter((payment) => payment.user)
      .map(buildAdminSubscriptionRecord)
      .filter((record) => {
        if (
          subscriptionState &&
          subscriptionState !== 'Tous' &&
          record.subscriptionState !== String(subscriptionState)
        ) {
          return false;
        }

        if (!search) return true;

        const haystack = [
          record.payment.identifier,
          record.payment.phoneNumber,
          record.payment.paymentReference,
          record.payment.txReference,
          record.user.fullName,
          record.user.email,
          record.user.phone,
          record.user.city,
          record.user.partnerProfile?.businessName,
          record.user.partnerProfile?.partnerType,
          record.user.partnerProfile?.whatsapp,
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();

        return haystack.includes(search);
      });

    response.json({
      item: {
        summary: buildAdminSubscriptionSummary(records),
        timeline: buildAdminSubscriptionTimeline(records),
        items: records,
      },
    });
  }),
);

router.post(
  '/checkout',
  requireAuth,
  asyncHandler(async (request, response) => {
    const body = checkoutSchema.parse(request.body);

    if (!request.user.partnerProfile?.partnerType) {
      return response.status(409).json({
        message:
          'Remplissez d abord votre dossier partenaire avant de payer l abonnement.',
      });
    }

    if (!isCinetpayConfigured()) {
      return response.status(503).json({
        message:
          'CinetPay n est pas configure sur le serveur. Ajoutez CINETPAY_APIKEY et CINETPAY_SITE_ID dans le backend.',
      });
    }

    const quote = computeSubscriptionQuote(body.months);
    const identifier = createSubscriptionIdentifier(request.user._id);
    const businessName =
      request.user.partnerProfile?.businessName || request.user.fullName;
    const description = `Abonnement Meevo ${quote.months} mois - ${businessName}`;

    let paymentInit;
    try {
      paymentInit = await initiateCinetpayPayment({
        transactionId: identifier,
        amount: quote.totalAmount,
        description,
        customerName: request.user.fullName,
        customerEmail: request.user.email,
        customerPhoneNumber: body.phoneNumber,
        metadata: JSON.stringify({
          kind: 'subscription',
          months: quote.months,
          network: body.network,
        }),
      });
    } catch (error) {
      return response.status(502).json({
        message: error.message,
      });
    }

    const paymentUrl = paymentInit.paymentUrl;

    const payment = await SubscriptionPayment.create({
      user: request.user._id,
      identifier,
      months: quote.months,
      cycle: quote.cycle,
      monthlyPrice: quote.monthlyPrice,
      grossAmount: quote.grossAmount,
      discountAmount: quote.discountAmount,
      totalAmount: quote.totalAmount,
      network: body.network,
      phoneNumber: body.phoneNumber,
      partnerType: request.user.partnerProfile?.partnerType || '',
      modules: buildPartnerModules(request.user.partnerProfile?.partnerType),
      description,
      paymentUrl,
      txReference: paymentInit.paymentToken,
      status: 'pending',
    });

    request.user.role = request.user.role === 'admin' ? 'admin' : 'partner';
    request.user.subscription = {
      status: 'pending',
      cycle: quote.cycle,
      months: quote.months,
      monthlyPrice: quote.monthlyPrice,
      grossAmount: quote.grossAmount,
      discountAmount: quote.discountAmount,
      totalAmount: quote.totalAmount,
      paygateNetwork: body.network,
      paymentMethod: '',
      currentPaymentIdentifier: identifier,
      startedAt: request.user.subscription?.startedAt,
      endsAt: request.user.subscription?.endsAt,
      lastPaymentAt: request.user.subscription?.lastPaymentAt,
    };
    await request.user.save();

    response.status(201).json({
      item: payment.toPublicJSON(),
      paymentUrl,
      overview: buildOverview(request.user, [payment]),
      user: request.user.toPublicJSON(),
    });
  }),
);

router.post(
  '/verify',
  requireAuth,
  asyncHandler(async (request, response) => {
    const body = verifySchema.parse(request.body);
    const payment = body.identifier
      ? await SubscriptionPayment.findOne({
          user: request.user._id,
          identifier: body.identifier,
        })
      : await SubscriptionPayment.findOne({ user: request.user._id }).sort({
          createdAt: -1,
        });

    if (!payment) {
      return response.status(404).json({
        message: 'Aucun paiement d abonnement a verifier.',
      });
    }

    const statusPayload = await checkCinetpayPaymentStatus(payment.identifier);
    const data = statusPayload?.data ?? {};
    payment.status = statusPayload.internalStatus || payment.status;
    payment.paymentMethod = data.payment_method || payment.paymentMethod || '';
    payment.paymentReference = data.operator_id || payment.paymentReference;
    payment.phoneNumber = data.customer_phone_number || payment.phoneNumber;
    payment.lastStatusPayload = statusPayload;

    if (payment.status === 'success') {
      await applySuccessfulPayment({
        user: request.user,
        payment,
        statusPayload,
      });
    } else {
      await payment.save();
      if (
        request.user.subscription?.currentPaymentIdentifier === payment.identifier &&
        request.user.subscription?.status !== 'active'
      ) {
        request.user.subscription.status =
          payment.status === 'processing' ? 'pending' : payment.status;
        await request.user.save();
      }
    }

    const payments = await SubscriptionPayment.find({ user: request.user._id })
      .sort({ createdAt: -1 })
      .limit(12);

    response.json({
      item: payment.toPublicJSON(),
      overview: buildOverview(request.user, payments),
      user: request.user.toPublicJSON(),
      paymentStatus: statusPayload,
    });
  }),
);

router.post(
  '/cinetpay/notify',
  asyncHandler(async (request, response) => {
    const raw = request.body ?? {};
    const identifier =
      raw.cpm_trans_id?.toString?.() ||
      raw.transaction_id?.toString?.() ||
      raw.identifier?.toString?.() ||
      '';

    if (!identifier) {
      return response.status(400).json({
        message: 'Transaction id manquant.',
      });
    }

    const payment = await SubscriptionPayment.findOne({ identifier });

    if (!payment) {
      return response.status(404).json({
        message: 'Paiement introuvable.',
      });
    }

    const user = await User.findById(payment.user);
    if (!user) {
      return response.status(404).json({
        message: 'Utilisateur introuvable.',
      });
    }

    const statusPayload = await checkCinetpayPaymentStatus(payment.identifier);
    const data = statusPayload?.data ?? {};
    payment.status = statusPayload.internalStatus || payment.status;
    payment.paymentMethod = data.payment_method || payment.paymentMethod || '';
    payment.paymentReference = data.operator_id || payment.paymentReference;
    payment.phoneNumber = data.customer_phone_number || payment.phoneNumber;
    payment.lastStatusPayload = statusPayload;

    if (payment.status === 'success') {
      await applySuccessfulPayment({
        user,
        payment,
        statusPayload,
      });
    } else {
      await payment.save();
    }

    response.json({ success: true });
  }),
);

export const subscriptionsRouter = router;
