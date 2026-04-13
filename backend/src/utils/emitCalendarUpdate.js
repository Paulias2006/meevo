import { Booking } from '../models/Booking.js';
import { buildAvailabilityPayload } from './timeSlots.js';

export async function emitCalendarUpdate(app, venue, date) {
  const io = app.get('io');

  if (!io || !venue) {
    return;
  }

  const bookings = await Booking.find({
    venue: venue._id,
    status: { $in: ['pending', 'confirmed'] },
    ...(date ? { eventDate: date } : {}),
  }).select('customer eventDate startTime endTime status eventType');

  const availability = buildAvailabilityPayload({
    venue,
    bookings,
    date: date ?? null,
  });

  io.emit('calendar:updated', {
    venueId: venue._id.toString(),
    date: date ?? null,
    ...availability,
  });
}
