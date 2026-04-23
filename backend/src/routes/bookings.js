import { Router } from 'express';
import { z } from 'zod';
import {
  requireAuth,
  requirePartnerSubscriptionAccess,
  requireRole,
} from '../middleware/auth.js';
import { Booking } from '../models/Booking.js';
import { PartnerWithdrawal } from '../models/PartnerWithdrawal.js';
import { ReservationPayment } from '../models/ReservationPayment.js';
import { Venue } from '../models/Venue.js';
import { env } from '../config/env.js';
import { emitCalendarUpdate } from '../utils/emitCalendarUpdate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import {
  checkCinetpayTransferBalance,
  checkCinetpayTransferStatus,
  checkCinetpayPaymentStatus,
  initiateCinetpayTransfer,
  isCinetpayPayoutConfigured,
  initiateCinetpayPayment,
  isCinetpayConfigured,
} from '../utils/cinetpay.js';
import {
  applyPayoutProfileToReservationPayment,
  computeReservationSettlement,
  createReservationPaymentHoldExpiry,
  createReservationPaymentIdentifier,
  hasReservationPaymentHoldConflict,
} from '../utils/reservationPayments.js';
import { isPartnerVisiblePublicly } from '../utils/subscriptionVisibility.js';
import {
  ensureBookingFitsBusinessHours,
  isValidDateString,
  normalizeTimeRange,
  rangesOverlap,
} from '../utils/timeSlots.js';

const router = Router();

const bookingCheckoutSchema = z.object({
  venueId: z.string().min(1),
  providerId: z.string().optional().or(z.literal('')),
  eventType: z.string().min(2),
  eventDate: z.string().min(8),
  startTime: z.string().optional().or(z.literal('')),
  endTime: z.string().optional().or(z.literal('')),
  guestCount: z.coerce.number().int().positive(),
  budget: z.coerce.number().nonnegative().optional(),
  notes: z.string().optional().or(z.literal('')),
  network: z.enum(['MOOV', 'TOGOCEL']),
  phoneNumber: z.string().min(6),
});

const bookingVerifySchema = z.object({
  identifier: z.string().optional().or(z.literal('')),
});

const manualBookingSchema = z.object({
  venueId: z.string().min(1),
  providerId: z.string().optional().or(z.literal('')),
  customerName: z.string().min(2),
  customerPhone: z.string().optional().or(z.literal('')),
  eventType: z.string().min(2),
  eventDate: z.string().min(8),
  startTime: z.string().min(5),
  endTime: z.string().min(5),
  guestCount: z.coerce.number().int().positive(),
  budget: z.coerce.number().nonnegative().optional(),
  totalAmount: z.coerce.number().nonnegative().optional(),
  depositAmount: z.coerce.number().nonnegative().optional(),
  status: z.enum(['pending', 'confirmed']).optional().default('confirmed'),
  notes: z.string().optional().or(z.literal('')),
});

const bookingStatusSchema = z.object({
  status: z.enum(['pending', 'confirmed', 'rejected', 'cancelled']),
  totalAmount: z.coerce.number().nonnegative().optional(),
  depositAmount: z.coerce.number().nonnegative().optional(),
});

const payoutUpdateSchema = z.object({
  payoutReference: z.string().optional().or(z.literal('')),
  payoutNotes: z.string().optional().or(z.literal('')),
});

const partnerWithdrawalCreateSchema = z.object({
  amount: z.coerce.number().positive(),
  network: z.enum(['MOOV', 'TOGOCEL']).optional(),
  phoneNumber: z.string().optional().or(z.literal('')),
  accountName: z.string().optional().or(z.literal('')),
});

const adminWithdrawalUpdateSchema = z.object({
  status: z.enum(['processing', 'paid', 'rejected', 'failed']),
  adminNotes: z.string().optional().or(z.literal('')),
});

function createBookingPayload(booking) {
  return {
    ...booking.toPublicJSON(),
    venue: booking.venue?.toPublicJSON?.() ?? booking.venue,
    provider: booking.provider?.toPublicJSON?.() ?? booking.provider,
  };
}

function buildDateFilters(yearRaw, monthRaw) {
  const year = Number.parseInt(String(yearRaw || ''), 10);
  const month = Number.parseInt(String(monthRaw || ''), 10);

  if (!Number.isFinite(year) || year < 2020 || year > 2100) {
    return null;
  }

  const safeMonth =
    Number.isFinite(month) && month >= 1 && month <= 12 ? month : null;
  const start = safeMonth
    ? new Date(year, safeMonth - 1, 1)
    : new Date(year, 0, 1);
  const end = safeMonth ? new Date(year, safeMonth, 1) : new Date(year + 1, 0, 1);

  return {
    $gte: start,
    $lt: end,
  };
}

function buildFinanceRangeFilter(rangeRaw, yearRaw, monthRaw) {
  const range = String(rangeRaw || '')
    .trim()
    .toLowerCase();

  const now = new Date();

  if (range === 'week') {
    const start = new Date(now);
    start.setDate(start.getDate() - 7);
    start.setHours(0, 0, 0, 0);
    return { $gte: start, $lte: now };
  }

  if (range === 'month') {
    const start = new Date(now.getFullYear(), now.getMonth(), 1);
    const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);
    return { $gte: start, $lt: end };
  }

  if (range === '6m') {
    const start = new Date(now.getFullYear(), now.getMonth() - 5, 1);
    const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);
    return { $gte: start, $lt: end };
  }

  if (range === 'year') {
    const start = new Date(now.getFullYear(), 0, 1);
    const end = new Date(now.getFullYear() + 1, 0, 1);
    return { $gte: start, $lt: end };
  }

  if (range === 'all') {
    return null;
  }

  return buildDateFilters(yearRaw, monthRaw);
}

function buildReservationPaymentRecord(payment) {
  const customer =
    payment.customer?.toPublicJSON?.() ??
    (payment.customer?._id
      ? {
          id: payment.customer._id.toString(),
          fullName: payment.customer.fullName,
          email: payment.customer.email,
          phone: payment.customer.phone,
        }
      : null);
  const partner =
    payment.partner?.toPublicJSON?.() ??
    (payment.partner?._id
      ? {
          id: payment.partner._id.toString(),
          fullName: payment.partner.fullName,
          email: payment.partner.email,
          phone: payment.partner.phone,
          partnerProfile: payment.partner.partnerProfile,
        }
      : null);

  return {
    payment: payment.toPublicJSON(),
    venue: payment.venue?.toPublicJSON?.() ?? payment.venue,
    booking: payment.booking?.toPublicJSON?.() ?? payment.booking,
    customer,
    partner,
  };
}

function buildReservationFinanceSummary(records) {
  const paid = records.filter((item) => item.payment.status === 'success');
  const ready = paid.filter((item) => item.payment.payoutStatus === 'ready');
  const pendingProfile = paid.filter(
    (item) => item.payment.payoutStatus === 'pending_profile',
  );
  const settled = paid.filter((item) => item.payment.payoutStatus === 'paid');
  const now = new Date();
  const monthGross = paid.reduce((sum, item) => {
    const effectiveDate = new Date(item.payment.paidAt || item.payment.createdAt || now);
    if (
      effectiveDate.getFullYear() === now.getFullYear() &&
      effectiveDate.getMonth() === now.getMonth()
    ) {
      return sum + item.payment.grossAmount;
    }
    return sum;
  }, 0);

  return {
    successfulReservations: paid.length,
    totalGrossAmount: paid.reduce((sum, item) => sum + item.payment.grossAmount, 0),
    totalPlatformFee: paid.reduce(
      (sum, item) => sum + item.payment.platformFeeAmount,
      0,
    ),
    totalPartnerNet: paid.reduce(
      (sum, item) => sum + item.payment.partnerNetAmount,
      0,
    ),
    readyPayoutAmount: ready.reduce(
      (sum, item) => sum + item.payment.partnerNetAmount,
      0,
    ),
    pendingProfileAmount: pendingProfile.reduce(
      (sum, item) => sum + item.payment.partnerNetAmount,
      0,
    ),
    settledPayoutAmount: settled.reduce(
      (sum, item) => sum + item.payment.partnerNetAmount,
      0,
    ),
    currentMonthGrossAmount: monthGross,
  };
}

function createWithdrawalIdentifier(partnerId) {
  const stamp = Date.now();
  const suffix = Math.random().toString(36).slice(2, 8).toUpperCase();
  return `MEEVO-WD-${partnerId.toString().slice(-4).toUpperCase()}-${stamp}-${suffix}`;
}

function buildWithdrawalRecord(withdrawal) {
  const partner =
    withdrawal.partner?.toPublicJSON?.() ??
    (withdrawal.partner?._id
      ? {
          id: withdrawal.partner._id.toString(),
          fullName: withdrawal.partner.fullName,
          email: withdrawal.partner.email,
          phone: withdrawal.partner.phone,
          partnerProfile: withdrawal.partner.partnerProfile,
        }
      : null);

  return {
    withdrawal: withdrawal.toPublicJSON(),
    partner,
  };
}

function summarizeWithdrawals(withdrawals) {
  const items = withdrawals.map((entry) => entry.withdrawal ?? entry);
  return {
    totalRequestedAmount: items.reduce((sum, item) => sum + (item.amount || 0), 0),
    pendingAmount: items
      .filter((item) => item.status === 'pending' || item.status === 'processing')
      .reduce((sum, item) => sum + (item.amount || 0), 0),
    paidAmount: items
      .filter((item) => item.status === 'paid')
      .reduce((sum, item) => sum + (item.amount || 0), 0),
  };
}

async function computePartnerWallet(partnerId) {
  const [payments, withdrawals] = await Promise.all([
    ReservationPayment.find({
      partner: partnerId,
      status: 'success',
    }).select('partnerNetAmount payoutStatus'),
    PartnerWithdrawal.find({
      partner: partnerId,
      status: { $in: ['pending', 'processing', 'paid'] },
    }).select('amount status'),
  ]);

  const totalNetRevenue = payments.reduce(
    (sum, item) => sum + (Number(item.partnerNetAmount) || 0),
    0,
  );
  const readyBalance = payments
    .filter((item) => item.payoutStatus === 'ready')
    .reduce((sum, item) => sum + (Number(item.partnerNetAmount) || 0), 0);
  const lockedPendingProfile = payments
    .filter((item) => item.payoutStatus === 'pending_profile')
    .reduce((sum, item) => sum + (Number(item.partnerNetAmount) || 0), 0);
  const reservedWithdrawals = withdrawals
    .filter((item) => item.status === 'pending' || item.status === 'processing')
    .reduce((sum, item) => sum + (Number(item.amount) || 0), 0);
  const paidWithdrawals = withdrawals
    .filter((item) => item.status === 'paid')
    .reduce((sum, item) => sum + (Number(item.amount) || 0), 0);
  const availableBalance = Math.max(0, readyBalance - reservedWithdrawals);

  return {
    totalNetRevenue,
    readyBalance,
    lockedPendingProfile,
    reservedWithdrawals,
    paidWithdrawals,
    availableBalance,
  };
}

function resolveWithdrawalPaymentMethod(network) {
  return network === 'TOGOCEL' ? '' : '';
}

async function syncWithdrawalFromProvider(withdrawal) {
  if (!withdrawal.cinetpayTransferId && !withdrawal.clientTransferId && !withdrawal.lot) {
    return withdrawal;
  }

  const providerStatus = await checkCinetpayTransferStatus({
    transactionId: withdrawal.cinetpayTransferId,
    clientTransferId: withdrawal.clientTransferId,
    lot: withdrawal.lot,
  });
  const item = Array.isArray(providerStatus?.data)
    ? providerStatus.data[0]
    : providerStatus?.data;

  withdrawal.lastProviderPayload = providerStatus;
  withdrawal.transferStatus = item?.treatment_status || withdrawal.transferStatus;
  withdrawal.sendingStatus = item?.sending_status || withdrawal.sendingStatus;
  withdrawal.comment = item?.comment || withdrawal.comment;

  if (providerStatus.internalStatus === 'paid') {
    withdrawal.status = 'paid';
    withdrawal.paidAt = item?.validated_at
      ? new Date(item.validated_at)
      : withdrawal.paidAt || new Date();
    withdrawal.processedAt = withdrawal.processedAt || new Date();
  } else if (providerStatus.internalStatus === 'failed') {
    withdrawal.status = 'failed';
    withdrawal.processedAt = new Date();
  } else if (providerStatus.internalStatus === 'rejected') {
    withdrawal.status = 'rejected';
    withdrawal.processedAt = new Date();
  } else if (withdrawal.status === 'pending') {
    withdrawal.status = 'processing';
    withdrawal.processedAt = withdrawal.processedAt || new Date();
  }

  await withdrawal.save();
  return withdrawal;
}

async function validateScheduleAvailability({
  venue,
  eventDate,
  startTime,
  endTime,
  ignoreReservationPaymentId,
}) {
  if (!isValidDateString(eventDate)) {
    throw new Error('La date doit respecter le format YYYY-MM-DD.');
  }

  normalizeTimeRange(startTime, endTime);
  ensureBookingFitsBusinessHours(
    startTime,
    endTime,
    venue.businessHours?.opensAt || '08:00',
    venue.businessHours?.closesAt || '23:00',
  );

  const isBlockedDate = venue.blockedDates.includes(eventDate);
  const overlappingManualBlock = (venue.manualBlocks ?? []).find(
    (entry) =>
      entry.date === eventDate &&
      rangesOverlap(startTime, endTime, entry.startTime, entry.endTime),
  );

  const existingBookings = await Booking.find({
    venue: venue._id,
    eventDate,
    status: { $in: ['pending', 'confirmed'] },
  });

  const overlappingBooking = existingBookings.find((entry) =>
    rangesOverlap(startTime, endTime, entry.startTime, entry.endTime),
  );

  const pendingPaymentConflict = await hasReservationPaymentHoldConflict({
    venueId: venue._id,
    eventDate,
    startTime,
    endTime,
    ignorePaymentId: ignoreReservationPaymentId,
  });

  if (
    isBlockedDate ||
    overlappingManualBlock ||
    overlappingBooking ||
    pendingPaymentConflict
  ) {
    throw new Error(
      'Ce creneau n est plus disponible pour cette salle. Verifiez le planning en temps reel.',
    );
  }
}

async function applySuccessfulReservationPayment({
  payment,
  statusPayload,
  app,
}) {
  if (payment.booking) {
    const existing = await Booking.findById(payment.booking)
      .populate('venue')
      .populate('provider');
    if (existing) {
      payment.status = 'success';
      payment.txReference = statusPayload?.tx_reference || payment.txReference;
      payment.paymentReference =
        statusPayload?.payment_reference || payment.paymentReference;
      payment.paymentMethod =
        statusPayload?.payment_method || payment.paymentMethod;
      payment.paidAt = statusPayload?.datetime
        ? new Date(statusPayload.datetime)
        : payment.paidAt || new Date();
      payment.lastStatusPayload = statusPayload || payment.lastStatusPayload;
      payment.bookingCreatedAt = payment.bookingCreatedAt || new Date();
      await payment.save();
      return existing;
    }
  }

  const venue = await Venue.findById(payment.venue).populate('partner');
  if (!venue || venue.status !== 'published' || !isPartnerVisiblePublicly(venue.partner)) {
    throw new Error('Le lieu de cette reservation n est plus disponible.');
  }

  await validateScheduleAvailability({
    venue,
    eventDate: payment.eventDate,
    startTime: payment.startTime,
    endTime: payment.endTime,
    ignoreReservationPaymentId: payment._id,
  });

  const booking = await Booking.create({
    customer: payment.customer,
    customerName: payment.customerName,
    customerPhone: payment.phoneNumber,
    venue: venue._id,
    provider: payment.provider || undefined,
    source: 'platform',
    eventType: payment.eventType,
    eventDate: payment.eventDate,
    startTime: payment.startTime,
    endTime: payment.endTime,
    guestCount: payment.guestCount,
    budget: payment.budget,
    depositAmount: payment.grossAmount,
    totalAmount: payment.grossAmount,
    status: 'confirmed',
    notes: payment.notes || '',
  });

  payment.status = 'success';
  payment.txReference = statusPayload?.tx_reference || payment.txReference;
  payment.paymentReference =
    statusPayload?.payment_reference || payment.paymentReference;
  payment.paymentMethod = statusPayload?.payment_method || payment.paymentMethod;
  payment.paidAt = statusPayload?.datetime
    ? new Date(statusPayload.datetime)
    : payment.paidAt || new Date();
  payment.lastStatusPayload = statusPayload || payment.lastStatusPayload;
  payment.booking = booking._id;
  payment.bookingCreatedAt = new Date();
  if (!payment.payoutPhoneNumber || !payment.payoutNetwork) {
    applyPayoutProfileToReservationPayment(payment, {
      phoneNumber: venue.partner?.partnerProfile?.payoutPhoneNumber,
      network: venue.partner?.partnerProfile?.payoutNetwork,
      accountName: venue.partner?.partnerProfile?.payoutAccountName,
    });
  }
  await payment.save();

  const populatedBooking = await Booking.findById(booking._id)
    .populate('venue')
    .populate('provider');
  const payload = createBookingPayload(populatedBooking);
  app.get('io').emit('booking:created', payload);
  await emitCalendarUpdate(app, venue, payment.eventDate);

  return populatedBooking;
}

router.get(
  '/',
  requireAuth,
  asyncHandler(async (request, response) => {
    const filters = {};
    const canUsePartnerScope = request.user.hasOperationalPartnerAccess?.();

    if (request.user.role === 'customer' || !canUsePartnerScope) {
      filters.customer = request.user._id;
      filters.customerArchivedAt = null;
    }

    if (request.user.role === 'partner' && canUsePartnerScope) {
      const venues = await Venue.find({ partner: request.user._id }).select('_id');
      filters.venue = { $in: venues.map((venue) => venue._id) };
    }

    // Les reservations payees sont creees en "confirmed". On ne remonte pas les
    // anciennes reservations "pending" dans l UI (success-only).
    filters.status = { $ne: 'pending' };

    const items = await Booking.find(filters)
      .populate('venue')
      .populate('provider')
      .sort({ createdAt: -1 })
      .limit(80);

    response.json({
      items: items.map(createBookingPayload),
    });
  }),
);

router.post(
  '/checkout',
  requireAuth,
  asyncHandler(async (request, response) => {
    const body = bookingCheckoutSchema.parse(request.body);

    if (!isCinetpayConfigured()) {
      return response.status(503).json({
        message:
          'CinetPay n est pas configure sur le serveur. Ajoutez CINETPAY_APIKEY et CINETPAY_SITE_ID dans le backend.',
      });
    }

    const venue = await Venue.findById(body.venueId).populate('partner');

    if (
      !venue ||
      venue.status !== 'published' ||
      !isPartnerVisiblePublicly(venue.partner)
    ) {
      return response.status(404).json({
        message: 'Salle introuvable.',
      });
    }

    const startTime = body.startTime || venue.businessHours?.opensAt || '08:00';
    const endTime = body.endTime || venue.businessHours?.closesAt || '23:00';

    try {
      await validateScheduleAvailability({
        venue,
        eventDate: body.eventDate,
        startTime,
        endTime,
      });
    } catch (error) {
      return response.status(409).json({
        message: error.message,
      });
    }

    const quote = computeReservationSettlement(venue.startingPrice);
    const identifier = createReservationPaymentIdentifier(
      request.user._id,
      venue._id,
    );
    const businessName =
      venue.partner?.partnerProfile?.businessName || venue.name;
    const description = `Reservation Meevo ${businessName} - ${body.eventType} - ${body.eventDate}`;

    let paymentInit;
    try {
      paymentInit = await initiateCinetpayPayment({
        transactionId: identifier,
        amount: quote.grossAmount,
        description,
        customerName: request.user.fullName,
        customerEmail: request.user.email,
        customerPhoneNumber: body.phoneNumber,
        metadata: JSON.stringify({
          kind: 'booking',
          network: body.network,
          venueId: body.venueId,
        }),
      });
    } catch (error) {
      return response.status(502).json({
        message: error.message,
      });
    }

    const paymentUrl = paymentInit.paymentUrl;

    const payment = new ReservationPayment({
      customer: request.user._id,
      partner: venue.partner?._id || venue.partner,
      venue: venue._id,
      provider: body.providerId || undefined,
      identifier,
      description,
      customerName: request.user.fullName,
      customerEmail: request.user.email,
      eventType: body.eventType,
      eventDate: body.eventDate,
      startTime,
      endTime,
      guestCount: body.guestCount,
      budget: body.budget,
      notes: body.notes || '',
      grossAmount: quote.grossAmount,
      platformFeeRate: quote.platformFeeRate,
      platformFeeAmount: quote.platformFeeAmount,
      partnerNetAmount: quote.partnerNetAmount,
      network: body.network,
      phoneNumber: body.phoneNumber,
      paymentUrl,
      txReference: paymentInit.paymentToken,
      status: 'pending',
      holdExpiresAt: createReservationPaymentHoldExpiry(),
    });
    applyPayoutProfileToReservationPayment(payment, {
      phoneNumber: venue.partner?.partnerProfile?.payoutPhoneNumber,
      network: venue.partner?.partnerProfile?.payoutNetwork,
      accountName: venue.partner?.partnerProfile?.payoutAccountName,
    });
    await payment.save();
    await emitCalendarUpdate(request.app, venue, body.eventDate);

    response.status(201).json({
      item: buildReservationPaymentRecord(payment),
      paymentUrl,
    });
  }),
);

router.post(
  '/verify-payment',
  requireAuth,
  asyncHandler(async (request, response) => {
    const body = bookingVerifySchema.parse(request.body);
    const payment = body.identifier
      ? await ReservationPayment.findOne({
          customer: request.user._id,
          identifier: body.identifier,
        })
      : await ReservationPayment.findOne({ customer: request.user._id }).sort({
          createdAt: -1,
        });

    if (!payment) {
      return response.status(404).json({
        message: 'Aucun paiement de reservation a verifier.',
      });
    }

    const statusPayload = await checkCinetpayPaymentStatus(payment.identifier);
    const data = statusPayload?.data ?? {};
    payment.status = statusPayload.internalStatus || payment.status;
    payment.paymentReference = data.operator_id || payment.paymentReference;
    payment.paymentMethod = data.payment_method || payment.paymentMethod;
    payment.phoneNumber = data.customer_phone_number || payment.phoneNumber;
    payment.paidAt = data.payment_date
      ? new Date(data.payment_date)
      : payment.paidAt || new Date();
    payment.lastStatusPayload = statusPayload;

    let booking = null;
    if (payment.status === 'success') {
      booking = await applySuccessfulReservationPayment({
        payment,
        statusPayload,
        app: request.app,
      });
    } else {
      await payment.save();
      if (['expired', 'cancelled', 'failed'].includes(payment.status)) {
        await emitCalendarUpdate(
          request.app,
          payment.venue,
          payment.eventDate,
        );
      }
    }

    const populatedPayment = await ReservationPayment.findById(payment._id)
      .populate('customer')
      .populate('partner')
      .populate('venue')
      .populate('booking');

    response.json({
      item: buildReservationPaymentRecord(populatedPayment),
      booking: booking ? createBookingPayload(booking) : null,
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

    const payment = await ReservationPayment.findOne({ identifier });

    if (!payment) {
      return response.status(404).json({
        message: 'Paiement de reservation introuvable.',
      });
    }

    const statusPayload = await checkCinetpayPaymentStatus(payment.identifier);
    payment.lastStatusPayload = statusPayload;

    if (statusPayload.internalStatus === 'success') {
      await applySuccessfulReservationPayment({
        payment,
        statusPayload,
        app: request.app,
      });
    } else {
      payment.status = statusPayload.internalStatus || payment.status;
      await payment.save();
      if (['failed', 'cancelled', 'expired'].includes(payment.status)) {
        await emitCalendarUpdate(
          request.app,
          payment.venue,
          payment.eventDate,
        );
      }
    }

    response.json({ success: true });
  }),
);

router.get(
  '/finance/partner',
  requireAuth,
  asyncHandler(async (request, response) => {
    if (request.user.role !== 'partner' && request.user.role !== 'admin') {
      return response.status(403).json({ message: 'Permission refusee.' });
    }

    const {
      q = '',
      payoutStatus,
      withdrawalStatus,
      network,
      year,
      month,
      range,
    } = request.query;
    const filters = {
      partner: request.user._id,
      status: 'success',
    };
    const withdrawalFilters = {
      partner: request.user._id,
    };

    if (payoutStatus && payoutStatus !== 'Tous') {
      filters.payoutStatus = String(payoutStatus);
    }

    if (network && network !== 'Tous') {
      filters.network = String(network);
      withdrawalFilters.network = String(network);
    }

    if (withdrawalStatus && withdrawalStatus !== 'Tous') {
      withdrawalFilters.status = String(withdrawalStatus);
    }

    const paidAt = buildFinanceRangeFilter(range, year, month);
    if (paidAt) {
      filters.paidAt = paidAt;
      withdrawalFilters.requestedAt = paidAt;
    }

    const [payments, rawWithdrawals, payoutBalance] = await Promise.all([
      ReservationPayment.find(filters)
        .populate('customer')
        .populate('partner')
        .populate('venue')
        .populate('booking')
        .sort({ paidAt: -1, createdAt: -1 })
        .limit(2000),
      PartnerWithdrawal.find(withdrawalFilters)
        .populate('partner')
        .sort({ requestedAt: -1, createdAt: -1 })
        .limit(500),
      isCinetpayPayoutConfigured()
        ? checkCinetpayTransferBalance().catch(() => null)
        : Promise.resolve(null),
    ]);

    const query = String(q).trim().toLowerCase();
    const records = payments
      .map(buildReservationPaymentRecord)
      .filter((record) => {
        if (!query) return true;
        const haystack = [
          record.payment.identifier,
          record.payment.paymentReference,
          record.payment.txReference,
          record.payment.phoneNumber,
          record.payment.payoutPhoneNumber,
          record.customer?.fullName,
          record.customer?.email,
          record.venue?.name,
          record.venue?.city,
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        return haystack.includes(query);
      });

    const withdrawals = await Promise.all(
      rawWithdrawals.map(async (withdrawal) => {
        if (
          isCinetpayPayoutConfigured() &&
          (withdrawal.status === 'pending' || withdrawal.status === 'processing')
        ) {
          return buildWithdrawalRecord(await syncWithdrawalFromProvider(withdrawal));
        }
        return buildWithdrawalRecord(withdrawal);
      }),
    ).then((items) =>
      items.filter((record) => {
        if (!query) return true;
        const haystack = [
          record.withdrawal.clientTransferId,
          record.withdrawal.cinetpayTransferId,
          record.withdrawal.phoneNumber,
          record.withdrawal.accountName,
          record.withdrawal.network,
          record.partner?.fullName,
          record.partner?.email,
          record.partner?.partnerProfile?.businessName,
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        return haystack.includes(query);
      }),
    );
    const wallet = await computePartnerWallet(request.user._id);

    response.json({
      item: {
        summary: buildReservationFinanceSummary(records),
        items: records,
        wallet: {
          ...wallet,
          payoutProviderAvailableBalance:
            payoutBalance?.available != null ? Number(payoutBalance.available) : null,
          payoutProviderRawBalance:
            payoutBalance?.amount != null ? Number(payoutBalance.amount) : null,
        },
        withdrawalsSummary: summarizeWithdrawals(withdrawals),
        withdrawals,
      },
    });
  }),
);

router.post(
  '/finance/partner/withdrawals',
  requireAuth,
  asyncHandler(async (request, response) => {
    if (request.user.role !== 'partner' && request.user.role !== 'admin') {
      return response.status(403).json({ message: 'Permission refusee.' });
    }

    const body = partnerWithdrawalCreateSchema.parse(request.body);
    const payoutProfile = request.user.partnerProfile ?? {};
    const network = body.network || payoutProfile.payoutNetwork || 'MOOV';
    const phoneNumber = (body.phoneNumber || payoutProfile.payoutPhoneNumber || '').trim();
    const accountName = (body.accountName || payoutProfile.payoutAccountName || '').trim();

    if (!phoneNumber) {
      return response.status(409).json({
        message: 'Configurez d abord votre numero de retrait.',
      });
    }

    const wallet = await computePartnerWallet(request.user._id);
    const roundedAmount = Math.floor(Math.max(0, Number(body.amount) || 0) / 5) * 5;

    if (roundedAmount < 100) {
      return response.status(409).json({
        message: 'Le retrait minimum est fixe a 100 FCFA.',
      });
    }

    if (roundedAmount > wallet.availableBalance) {
      return response.status(409).json({
        message: 'Le montant depasse votre solde disponible.',
      });
    }

    const withdrawal = await PartnerWithdrawal.create({
      partner: request.user._id,
      amount: roundedAmount,
      network,
      phoneNumber,
      accountName,
      clientTransferId: createWithdrawalIdentifier(request.user._id),
      status: isCinetpayPayoutConfigured() ? 'processing' : 'pending',
    });

    if (isCinetpayPayoutConfigured()) {
      try {
        const transfer = await initiateCinetpayTransfer({
          clientTransferId: withdrawal.clientTransferId,
          amount: roundedAmount,
          phoneNumber,
          paymentMethod: resolveWithdrawalPaymentMethod(network),
        });
        const item = transfer.item ?? {};
        withdrawal.cinetpayTransferId = item.transaction_id || '';
        withdrawal.lot = item.lot || '';
        withdrawal.transferStatus = item.treatment_status || '';
        withdrawal.sendingStatus = item.sending_status || '';
        withdrawal.comment = item.comment || '';
        withdrawal.lastProviderPayload = transfer.raw;
        withdrawal.processedAt = new Date();
        if (transfer.internalStatus === 'paid') {
          withdrawal.status = 'paid';
          withdrawal.paidAt = item.validated_at
            ? new Date(item.validated_at)
            : new Date();
        } else if (transfer.internalStatus === 'failed') {
          withdrawal.status = 'failed';
        } else if (transfer.internalStatus === 'rejected') {
          withdrawal.status = 'rejected';
        } else {
          withdrawal.status = 'processing';
        }
        await withdrawal.save();
      } catch (error) {
        withdrawal.status = 'pending';
        withdrawal.adminNotes = error.message || 'Retrait cree sans envoi automatique.';
        await withdrawal.save();
      }
    }

    await withdrawal.populate('partner');

    response.status(201).json({
      item: buildWithdrawalRecord(withdrawal),
    });
  }),
);

router.get(
  '/finance/admin',
  requireAuth,
  requireRole('admin'),
  asyncHandler(async (request, response) => {
    const {
      q = '',
      payoutStatus,
      withdrawalStatus,
      network,
      year,
      month,
      range,
    } = request.query;
    const filters = {
      status: 'success',
    };
    const withdrawalFilters = {};

    if (payoutStatus && payoutStatus !== 'Tous') {
      filters.payoutStatus = String(payoutStatus);
    }

    if (network && network !== 'Tous') {
      filters.network = String(network);
      withdrawalFilters.network = String(network);
    }

    if (withdrawalStatus && withdrawalStatus !== 'Tous') {
      withdrawalFilters.status = String(withdrawalStatus);
    }

    const paidAt = buildFinanceRangeFilter(range, year, month);
    if (paidAt) {
      filters.paidAt = paidAt;
      withdrawalFilters.requestedAt = paidAt;
    }

    const [payments, rawWithdrawals, payoutBalance] = await Promise.all([
      ReservationPayment.find(filters)
        .populate('customer')
        .populate('partner')
        .populate('venue')
        .populate('booking')
        .sort({ paidAt: -1, createdAt: -1 })
        .limit(4000),
      PartnerWithdrawal.find(withdrawalFilters)
        .populate('partner')
        .sort({ requestedAt: -1, createdAt: -1 })
        .limit(3000),
      isCinetpayPayoutConfigured()
        ? checkCinetpayTransferBalance().catch(() => null)
        : Promise.resolve(null),
    ]);

    const query = String(q).trim().toLowerCase();
    const records = payments
      .map(buildReservationPaymentRecord)
      .filter((record) => {
        if (!query) return true;
        const haystack = [
          record.payment.identifier,
          record.payment.paymentReference,
          record.payment.txReference,
          record.payment.phoneNumber,
          record.payment.payoutPhoneNumber,
          record.payment.payoutReference,
          record.customer?.fullName,
          record.customer?.email,
          record.partner?.fullName,
          record.partner?.email,
          record.partner?.partnerProfile?.businessName,
          record.venue?.name,
          record.venue?.city,
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        return haystack.includes(query);
      });

    const partnerTotalsMap = new Map();
    for (const record of records) {
      const partnerId = record.partner?.id || 'unknown';
      const existing = partnerTotalsMap.get(partnerId) || {
        partner: record.partner,
        reservations: 0,
        grossAmount: 0,
        platformFeeAmount: 0,
        partnerNetAmount: 0,
      };
      existing.reservations += 1;
      existing.grossAmount += record.payment.grossAmount || 0;
      existing.platformFeeAmount += record.payment.platformFeeAmount || 0;
      existing.partnerNetAmount += record.payment.partnerNetAmount || 0;
      partnerTotalsMap.set(partnerId, existing);
    }

    const withdrawals = await Promise.all(
      rawWithdrawals.map(async (withdrawal) => {
        if (
          isCinetpayPayoutConfigured() &&
          (withdrawal.status === 'pending' || withdrawal.status === 'processing')
        ) {
          return buildWithdrawalRecord(await syncWithdrawalFromProvider(withdrawal));
        }
        return buildWithdrawalRecord(withdrawal);
      }),
    ).then((items) =>
      items.filter((record) => {
        if (!query) return true;
        const haystack = [
          record.withdrawal.clientTransferId,
          record.withdrawal.cinetpayTransferId,
          record.withdrawal.phoneNumber,
          record.withdrawal.accountName,
          record.withdrawal.network,
          record.withdrawal.status,
          record.partner?.fullName,
          record.partner?.email,
          record.partner?.partnerProfile?.businessName,
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        return haystack.includes(query);
      }),
    );

    response.json({
      item: {
        summary: buildReservationFinanceSummary(records),
        items: records,
        partnerTotals: Array.from(partnerTotalsMap.values()).sort(
          (left, right) => right.partnerNetAmount - left.partnerNetAmount,
        ),
        withdrawalsSummary: summarizeWithdrawals(withdrawals),
        withdrawals,
        payoutProviderAvailableBalance:
          payoutBalance?.available != null ? Number(payoutBalance.available) : null,
      },
    });
  }),
);

router.patch(
  '/finance/admin/:id/payout',
  requireAuth,
  requireRole('admin'),
  asyncHandler(async (request, response) => {
    const body = payoutUpdateSchema.parse(request.body);
    const payment = await ReservationPayment.findById(request.params.id)
      .populate('customer')
      .populate('partner')
      .populate('venue')
      .populate('booking');

    if (!payment) {
      return response.status(404).json({
        message: 'Paiement de reservation introuvable.',
      });
    }

    if (payment.status !== 'success') {
      return response.status(409).json({
        message: 'Seuls les paiements confirmes peuvent etre reverses.',
      });
    }

    payment.payoutStatus = 'paid';
    payment.payoutPaidAt = new Date();
    payment.payoutReference = body.payoutReference || payment.payoutReference;
    payment.payoutNotes = body.payoutNotes || payment.payoutNotes;
    await payment.save();

    response.json({
      item: buildReservationPaymentRecord(payment),
    });
  }),
);

router.patch(
  '/finance/admin/withdrawals/:id',
  requireAuth,
  requireRole('admin'),
  asyncHandler(async (request, response) => {
    const body = adminWithdrawalUpdateSchema.parse(request.body);
    const withdrawal = await PartnerWithdrawal.findById(request.params.id).populate(
      'partner',
    );

    if (!withdrawal) {
      return response.status(404).json({
        message: 'Retrait introuvable.',
      });
    }

    withdrawal.adminNotes = body.adminNotes || withdrawal.adminNotes;
    withdrawal.status = body.status;
    withdrawal.processedAt = new Date();
    if (body.status === 'paid') {
      withdrawal.paidAt = new Date();
    }
    await withdrawal.save();

    response.json({
      item: buildWithdrawalRecord(withdrawal),
    });
  }),
);

router.all(
  '/finance/payout/notify',
  asyncHandler(async (request, response) => {
    const clientTransferId =
      request.body?.client_transaction_id ||
      request.query?.client_transaction_id ||
      '';
    const transactionId =
      request.body?.transaction_id || request.query?.transaction_id || '';
    const lot = request.body?.lot || request.query?.lot || '';

    if (!clientTransferId && !transactionId && !lot) {
      response.json({ success: true });
      return;
    }

    const withdrawal = await PartnerWithdrawal.findOne({
      $or: [
        ...(clientTransferId ? [{ clientTransferId }] : []),
        ...(transactionId ? [{ cinetpayTransferId: transactionId }] : []),
        ...(lot ? [{ lot }] : []),
      ],
    });

    if (!withdrawal) {
      response.json({ success: true });
      return;
    }

    if (isCinetpayPayoutConfigured()) {
      await syncWithdrawalFromProvider(withdrawal).catch(() => null);
    }

    response.json({ success: true });
  }),
);

router.post(
  '/manual',
  requireAuth,
  requirePartnerSubscriptionAccess,
  asyncHandler(async (request, response) => {
    const body = manualBookingSchema.parse(request.body);
    const venue = await Venue.findById(body.venueId);

    if (!venue) {
      return response.status(404).json({
        message: 'Salle introuvable.',
      });
    }

    if (
      request.user.role !== 'admin' &&
      String(venue.partner) !== String(request.user._id)
    ) {
      return response.status(403).json({
        message: 'Vous ne pouvez pas ajouter une reservation sur cette salle.',
      });
    }

    try {
      await validateScheduleAvailability({
        venue,
        eventDate: body.eventDate,
        startTime: body.startTime,
        endTime: body.endTime,
      });
    } catch (error) {
      return response.status(409).json({
        message: error.message,
      });
    }

    const booking = await Booking.create({
      venue: venue._id,
      provider: body.providerId || undefined,
      customerName: body.customerName,
      customerPhone: body.customerPhone || '',
      source: 'manual',
      eventType: body.eventType,
      eventDate: body.eventDate,
      startTime: body.startTime,
      endTime: body.endTime,
      guestCount: body.guestCount,
      budget: body.budget,
      depositAmount: body.depositAmount ?? 0,
      totalAmount: body.totalAmount ?? venue.startingPrice,
      status: body.status,
      notes: body.notes || '',
    });

    const populatedBooking = await Booking.findById(booking._id)
      .populate('venue')
      .populate('provider');
    const payload = createBookingPayload(populatedBooking);

    request.app.get('io').emit('booking:created', payload);
    await emitCalendarUpdate(request.app, venue, body.eventDate);

    response.status(201).json({
      item: payload,
    });
  }),
);

router.patch(
  '/:id/status',
  requireAuth,
  requirePartnerSubscriptionAccess,
  asyncHandler(async (request, response) => {
    const body = bookingStatusSchema.parse(request.body);
    const booking = await Booking.findById(request.params.id)
      .populate('venue')
      .populate('provider');

    if (!booking) {
      return response.status(404).json({
        message: 'Reservation introuvable.',
      });
    }

    if (
      request.user.role === 'partner' &&
      String(booking.venue?.partner ?? '') !== String(request.user._id)
    ) {
      return response.status(403).json({
        message: 'Vous ne pouvez pas gerer cette reservation.',
      });
    }

    booking.status = body.status;

    if (body.totalAmount !== undefined) {
      booking.totalAmount = body.totalAmount;
    }

    if (body.depositAmount !== undefined) {
      booking.depositAmount = body.depositAmount;
    }

    await booking.save();

    const payload = createBookingPayload(booking);

    request.app.get('io').emit('booking:updated', payload);
    await emitCalendarUpdate(request.app, booking.venue, booking.eventDate);

    response.json({
      item: payload,
    });
  }),
);

router.delete(
  '/:id',
  requireAuth,
  asyncHandler(async (request, response) => {
    const booking = await Booking.findById(request.params.id)
      .populate('venue')
      .populate('provider');

    if (!booking) {
      return response.status(404).json({
        message: 'Reservation introuvable.',
      });
    }

    if (
      request.user.role === 'customer' ||
      !request.user.hasOperationalPartnerAccess?.()
    ) {
      if (String(booking.customer) !== String(request.user._id)) {
        return response.status(403).json({
          message: 'Vous ne pouvez pas supprimer cette reservation.',
        });
      }

      booking.customerArchivedAt = new Date();
      await booking.save();

      response.json({
        success: true,
      });
      return;
    }

    if (
      request.user.role === 'partner' &&
      request.user.hasOperationalPartnerAccess?.()
    ) {
      if (String(booking.venue?.partner ?? '') !== String(request.user._id)) {
        return response.status(403).json({
          message: 'Vous ne pouvez pas supprimer cette reservation.',
        });
      }
      if (booking.source !== 'manual') {
        return response.status(403).json({
          message: 'Seules les reservations manuelles peuvent etre supprimees.',
        });
      }
    }

    await Booking.deleteOne({ _id: booking._id });

    const payload = createBookingPayload(booking);
    request.app.get('io').emit('booking:deleted', payload);
    if (booking.venue) {
      await emitCalendarUpdate(request.app, booking.venue, booking.eventDate);
    }

    response.json({
      success: true,
    });
  }),
);

export const bookingsRouter = router;
