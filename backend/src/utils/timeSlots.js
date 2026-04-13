const TIME_PATTERN = /^([01]\d|2[0-3]):([0-5]\d)$/;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

export function isValidDateString(value) {
  return DATE_PATTERN.test(value);
}

export function isValidTimeString(value) {
  return TIME_PATTERN.test(value);
}

export function timeToMinutes(value) {
  const match = TIME_PATTERN.exec(value);

  if (!match) {
    throw new Error(`Heure invalide: ${value}`);
  }

  return Number(match[1]) * 60 + Number(match[2]);
}

export function normalizeTimeRange(startTime, endTime) {
  if (!isValidTimeString(startTime) || !isValidTimeString(endTime)) {
    throw new Error('Le format horaire attendu est HH:MM.');
  }

  if (timeToMinutes(endTime) <= timeToMinutes(startTime)) {
    throw new Error('L heure de fin doit etre apres l heure de debut.');
  }

  return { startTime, endTime };
}

export function rangesOverlap(firstStart, firstEnd, secondStart, secondEnd) {
  const firstStartMinutes = timeToMinutes(firstStart);
  const firstEndMinutes = timeToMinutes(firstEnd);
  const secondStartMinutes = timeToMinutes(secondStart);
  const secondEndMinutes = timeToMinutes(secondEnd);

  return firstStartMinutes < secondEndMinutes && secondStartMinutes < firstEndMinutes;
}

export function ensureBookingFitsBusinessHours(startTime, endTime, opensAt, closesAt) {
  const startMinutes = timeToMinutes(startTime);
  const endMinutes = timeToMinutes(endTime);
  const openMinutes = timeToMinutes(opensAt);
  const closeMinutes = timeToMinutes(closesAt);

  if (startMinutes < openMinutes || endMinutes > closeMinutes) {
    throw new Error(
      `Le creneau doit rester dans les horaires d ouverture ${opensAt}-${closesAt}.`,
    );
  }
}

export function buildAvailabilityPayload({ venue, bookings, date }) {
  const manualBlocks = (venue.manualBlocks ?? []).filter(
    (entry) => !date || entry.date === date,
  );
  const bookingSlots = bookings
    .filter((entry) => !date || entry.eventDate === date)
    .map((entry) => ({
      source: 'booking',
      bookingId: entry._id.toString(),
      date: entry.eventDate,
      startTime: entry.startTime,
      endTime: entry.endTime,
      status: entry.status,
      eventType: entry.eventType,
      customer: entry.customer,
    }));

  const manualSlots = manualBlocks.map((entry, index) => ({
    source: 'manual',
    slotId: `${entry.date}-${entry.startTime}-${entry.endTime}-${index}`,
    date: entry.date,
    startTime: entry.startTime,
    endTime: entry.endTime,
    reason: entry.reason ?? '',
  }));

  const slots = [...manualSlots, ...bookingSlots].sort((left, right) => {
    const startDifference = timeToMinutes(left.startTime) - timeToMinutes(right.startTime);
    if (startDifference !== 0) return startDifference;
    return timeToMinutes(left.endTime) - timeToMinutes(right.endTime);
  });

  return {
    businessHours: venue.businessHours ?? { opensAt: '08:00', closesAt: '23:00' },
    blockedDates: venue.blockedDates ?? [],
    slots,
  };
}
