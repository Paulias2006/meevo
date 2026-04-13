import { env } from '../config/env.js';
import { ReservationPayment } from '../models/ReservationPayment.js';
import { rangesOverlap } from './timeSlots.js';

export const reservationPaymentHoldStatuses = ['pending', 'processing'];

export function createReservationPaymentIdentifier(userId, venueId) {
  const stamp = Date.now();
  const suffix = Math.random().toString(36).slice(2, 8).toUpperCase();
  return `MEEVO-BOOK-${userId.toString().slice(-4).toUpperCase()}-${venueId
    .toString()
    .slice(-4)
    .toUpperCase()}-${stamp}-${suffix}`;
}

export function computeReservationSettlement(rawGrossAmount) {
  const grossAmount = Math.max(0, Math.round(Number(rawGrossAmount) || 0));
  const platformFeeRate = Math.max(
    0,
    Math.min(1, Number(env.BOOKING_PLATFORM_COMMISSION_RATE) || 0.05),
  );
  const platformFeeAmount = Math.round(grossAmount * platformFeeRate);
  const partnerNetAmount = Math.max(0, grossAmount - platformFeeAmount);

  return {
    grossAmount,
    platformFeeRate,
    platformFeeAmount,
    partnerNetAmount,
  };
}

export function createReservationPaymentHoldExpiry() {
  return new Date(
    Date.now() + Math.max(5, Number(env.BOOKING_PAYMENT_HOLD_MINUTES) || 15) * 60 * 1000,
  );
}

export async function findActiveReservationPaymentHolds({
  eventDate,
  venueId,
}) {
  return ReservationPayment.find({
    ...(venueId ? { venue: venueId } : {}),
    ...(eventDate ? { eventDate } : {}),
    booking: { $exists: false },
    status: { $in: reservationPaymentHoldStatuses },
    holdExpiresAt: { $gte: new Date() },
  }).select(
    'venue eventDate startTime endTime status eventType holdExpiresAt identifier',
  );
}

export async function hasReservationPaymentHoldConflict({
  venueId,
  eventDate,
  startTime,
  endTime,
  ignorePaymentId,
}) {
  const holds = await findActiveReservationPaymentHolds({ venueId, eventDate });

  return holds.find((entry) => {
    if (ignorePaymentId && String(entry._id) === String(ignorePaymentId)) {
      return false;
    }

    return rangesOverlap(startTime, endTime, entry.startTime, entry.endTime);
  });
}

export function applyPayoutProfileToReservationPayment(payment, payoutProfile) {
  const payoutPhoneNumber = payoutProfile?.phoneNumber?.trim?.() || '';
  const payoutNetwork = payoutProfile?.network?.trim?.() || '';
  const payoutAccountName = payoutProfile?.accountName?.trim?.() || '';

  payment.payoutPhoneNumber = payoutPhoneNumber;
  payment.payoutNetwork = payoutNetwork;
  payment.payoutAccountName = payoutAccountName;
  payment.payoutStatus =
    payoutPhoneNumber && payoutNetwork ? 'ready' : 'pending_profile';
}
