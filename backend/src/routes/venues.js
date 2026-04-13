import { Router } from 'express';
import slugify from 'slugify';
import { z } from 'zod';
import { requireAuth, requirePartnerSubscriptionAccess } from '../middleware/auth.js';
import { Booking } from '../models/Booking.js';
import { ReservationPayment } from '../models/ReservationPayment.js';
import { Venue } from '../models/Venue.js';
import { emitCalendarUpdate } from '../utils/emitCalendarUpdate.js';
import { normalizeCityLabel } from '../utils/cities.js';
import { reservationPaymentHoldStatuses } from '../utils/reservationPayments.js';
import {
  buildAvailabilityPayload,
  isValidDateString,
  normalizeTimeRange,
  rangesOverlap,
} from '../utils/timeSlots.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { isPartnerVisiblePublicly } from '../utils/subscriptionVisibility.js';

const router = Router();
const MONTH_PATTERN = /^\d{4}-\d{2}$/;

function isValidMonthString(value) {
  return MONTH_PATTERN.test(value);
}

function toMonthRange(month) {
  const [yearRaw, monthRaw] = month.split('-');
  const year = Number(yearRaw);
  const monthIndex = Number(monthRaw) - 1;
  const start = `${yearRaw}-${monthRaw}-01`;
  const endDate = new Date(year, monthIndex + 1, 0);
  const endMonth = String(endDate.getMonth() + 1).padStart(2, '0');
  const endDay = String(endDate.getDate()).padStart(2, '0');
  const end = `${year}-${endMonth}-${endDay}`;
  return { start, end };
}

const manualBlockSchema = z.object({
  date: z.string().min(8),
  startTime: z.string().min(5),
  endTime: z.string().min(5),
  reason: z.string().optional().or(z.literal('')),
});

const venueMutationSchema = z.object({
  name: z.string().min(2),
  venueType: z.string().optional().or(z.literal('')),
  shortDescription: z.string().optional().or(z.literal('')),
  description: z.string().optional().or(z.literal('')),
  city: z.string().min(2),
  district: z.string().optional().or(z.literal('')),
  address: z.string().optional().or(z.literal('')),
  googleMapsUrl: z.string().optional().or(z.literal('')),
  country: z.string().optional().or(z.literal('')),
  latitude: z.coerce.number().optional(),
  longitude: z.coerce.number().optional(),
  capacity: z.coerce.number().int().positive(),
  startingPrice: z.coerce.number().nonnegative(),
  eventTypes: z.array(z.string()).optional(),
  amenities: z.array(z.string()).optional(),
  photos: z.array(z.string()).optional(),
  videoUrl: z.string().optional().or(z.literal('')),
  coverPhoto: z.string().optional().or(z.literal('')),
  businessHours: z
    .object({
      opensAt: z.string().min(5),
      closesAt: z.string().min(5),
    })
    .optional(),
  isPopular: z.boolean().optional(),
  isFeatured: z.boolean().optional(),
  blockedDates: z.array(z.string()).optional(),
  manualBlocks: z.array(manualBlockSchema).optional(),
});

function validateVenueSchedule(body) {
  if (body.businessHours) {
    normalizeTimeRange(body.businessHours.opensAt, body.businessHours.closesAt);
  }

  for (const entry of body.manualBlocks ?? []) {
    if (!isValidDateString(entry.date)) {
      throw new Error(`Date de blocage invalide: ${entry.date}`);
    }

    normalizeTimeRange(entry.startTime, entry.endTime);
  }
}

function hasBlockingConflict(manualBlocks, date, startTime, endTime) {
  return manualBlocks.find(
    (entry) =>
      entry.date === date &&
      rangesOverlap(startTime, endTime, entry.startTime, entry.endTime),
  );
}

router.get(
  '/mine',
  requireAuth,
  requirePartnerSubscriptionAccess,
  asyncHandler(async (request, response) => {
    const filters = { partner: request.user._id };

    const items = await Venue.find(filters).sort({ createdAt: -1 }).limit(100);

    response.json({
      items: items.map((venue) => venue.toPublicJSON()),
    });
  }),
);

router.get(
  '/',
  asyncHandler(async (request, response) => {
    const {
      q,
      city,
      eventType,
      minCapacity,
      maxPrice,
      date,
      startTime,
      endTime,
      featured,
      popular,
      page = '1',
      limit = '12',
    } = request.query;

    const filters = {
      status: 'published',
    };

    if (q) {
      const escapedQuery = String(q).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const queryRegex = new RegExp(escapedQuery, 'i');
      filters.$or = [
        { name: queryRegex },
        { city: queryRegex },
        { district: queryRegex },
        { venueType: queryRegex },
        { shortDescription: queryRegex },
        { description: queryRegex },
        { address: queryRegex },
      ];
    }

    if (city) {
      filters.city = new RegExp(String(city), 'i');
    }

    if (eventType) {
      filters.eventTypes = { $in: [String(eventType)] };
    }

    if (minCapacity) {
      filters.capacity = {
        ...(filters.capacity ?? {}),
        $gte: Number(minCapacity),
      };
    }

    if (maxPrice) {
      filters.startingPrice = {
        $lte: Number(maxPrice),
      };
    }

    if (featured === 'true') {
      filters.isFeatured = true;
    }

    if (popular === 'true') {
      filters.isPopular = true;
    }

    const safeLimit = Math.min(Number(limit) || 12, 60);
    const safePage = Math.max(Number(page) || 1, 1);
    const skip = (safePage - 1) * safeLimit;

    if (date) {
      if (!isValidDateString(String(date))) {
        return response.status(400).json({
          message: 'La date doit respecter le format YYYY-MM-DD.',
        });
      }

      const [bookedEntries, paymentHolds] = await Promise.all([
        Booking.find({
          eventDate: String(date),
          status: { $in: ['pending', 'confirmed'] },
        }).select('venue startTime endTime'),
        ReservationPayment.find({
          eventDate: String(date),
          status: { $in: reservationPaymentHoldStatuses },
          booking: { $exists: false },
          holdExpiresAt: { $gte: new Date() },
        }).select('venue startTime endTime'),
      ]);

      const requestedStartTime = startTime ? String(startTime) : null;
      const requestedEndTime = endTime ? String(endTime) : null;

      if ((requestedStartTime && !requestedEndTime) || (!requestedStartTime && requestedEndTime)) {
        return response.status(400).json({
          message: 'Les heures de debut et de fin doivent etre envoyees ensemble.',
        });
      }

      if (requestedStartTime && requestedEndTime) {
        try {
          normalizeTimeRange(requestedStartTime, requestedEndTime);
        } catch (error) {
          return response.status(400).json({
            message: error.message,
          });
        }
      }

      const venues = await Venue.find(filters)
        .populate('partner', 'role subscription')
        .sort({
        isFeatured: -1,
        isPopular: -1,
        createdAt: -1,
      });

      const filteredItems = venues.filter((venue) => {
        if (!isPartnerVisiblePublicly(venue.partner)) {
          return false;
        }

        if (venue.blockedDates.includes(String(date))) {
          return false;
        }

        if (!requestedStartTime || !requestedEndTime) {
          return true;
        }

        const manualConflict = hasBlockingConflict(
          venue.manualBlocks ?? [],
          String(date),
          requestedStartTime,
          requestedEndTime,
        );

        if (manualConflict) {
          return false;
        }

        const bookingConflict = bookedEntries.find(
          (entry) =>
            String(entry.venue) === venue._id.toString() &&
            rangesOverlap(
              requestedStartTime,
              requestedEndTime,
              entry.startTime,
              entry.endTime,
            ),
        );

        const paymentHoldConflict = paymentHolds.find(
          (entry) =>
            String(entry.venue) === venue._id.toString() &&
            rangesOverlap(
              requestedStartTime,
              requestedEndTime,
              entry.startTime,
              entry.endTime,
            ),
        );

        return !bookingConflict && !paymentHoldConflict;
      });

      const paginatedItems = filteredItems.slice(skip, skip + safeLimit);

      return response.json({
        items: paginatedItems.map((venue) => venue.toPublicJSON()),
        pagination: {
          page: safePage,
          limit: safeLimit,
          total: filteredItems.length,
          totalPages: Math.max(Math.ceil(filteredItems.length / safeLimit), 1),
        },
      });
    }

    const items = await Venue.find(filters)
      .populate('partner', 'role subscription')
      .sort({ isFeatured: -1, isPopular: -1, createdAt: -1 });
    const visibleItems = items.filter((venue) =>
      isPartnerVisiblePublicly(venue.partner),
    );
    const paginatedItems = visibleItems.slice(skip, skip + safeLimit);

    response.json({
      items: paginatedItems.map((venue) => venue.toPublicJSON()),
      pagination: {
        page: safePage,
        limit: safeLimit,
        total: visibleItems.length,
        totalPages: Math.max(Math.ceil(visibleItems.length / safeLimit), 1),
      },
    });
  }),
);

router.get(
  '/:id',
  asyncHandler(async (request, response) => {
    const venue = await Venue.findById(request.params.id).populate(
      'partner',
      'role subscription',
    );

    if (
      !venue ||
      venue.status !== 'published' ||
      !isPartnerVisiblePublicly(venue.partner)
    ) {
      return response.status(404).json({
        message: 'Salle introuvable.',
      });
    }

    return response.json({
      item: venue.toPublicJSON(),
    });
  }),
);

router.get(
  '/:id/availability',
  asyncHandler(async (request, response) => {
    const venue = await Venue.findById(request.params.id).populate(
      'partner',
      'role subscription',
    );
    const date = request.query.date ? String(request.query.date) : null;

    if (!venue || !isPartnerVisiblePublicly(venue.partner)) {
      return response.status(404).json({
        message: 'Salle introuvable.',
      });
    }

    if (date && !isValidDateString(date)) {
      return response.status(400).json({
        message: 'La date doit respecter le format YYYY-MM-DD.',
      });
    }

    const [bookings, paymentHolds] = await Promise.all([
      Booking.find({
        venue: venue._id,
        status: { $in: ['pending', 'confirmed'] },
        ...(date ? { eventDate: date } : {}),
      }).select('customer eventDate startTime endTime status eventType'),
      ReservationPayment.find({
        venue: venue._id,
        status: { $in: reservationPaymentHoldStatuses },
        booking: { $exists: false },
        holdExpiresAt: { $gte: new Date() },
        ...(date ? { eventDate: date } : {}),
      }).select('eventDate startTime endTime status eventType'),
    ]);

    const mergedBookings = [
      ...bookings,
      ...paymentHolds.map((entry) => ({
        _id: entry._id,
        eventDate: entry.eventDate,
        startTime: entry.startTime,
        endTime: entry.endTime,
        status: 'pending',
        eventType: entry.eventType || 'Paiement en cours',
      })),
    ];

    const availability = buildAvailabilityPayload({
      venue,
      bookings: mergedBookings,
      date,
    });

    return response.json({
      date,
      ...availability,
    });
  }),
);

router.get(
  '/:id/availability/month',
  asyncHandler(async (request, response) => {
    const venue = await Venue.findById(request.params.id).populate(
      'partner',
      'role subscription',
    );
    const month = request.query.month ? String(request.query.month) : null;

    if (!venue || !isPartnerVisiblePublicly(venue.partner)) {
      return response.status(404).json({
        message: 'Salle introuvable.',
      });
    }

    if (!month || !isValidMonthString(month)) {
      return response.status(400).json({
        message: 'Le mois doit respecter le format YYYY-MM.',
      });
    }

    const { start, end } = toMonthRange(month);

    const [bookings, paymentHolds] = await Promise.all([
      Booking.find({
        venue: venue._id,
        status: { $in: ['pending', 'confirmed'] },
        eventDate: { $gte: start, $lte: end },
      }).select('eventDate'),
      ReservationPayment.find({
        venue: venue._id,
        status: { $in: reservationPaymentHoldStatuses },
        booking: { $exists: false },
        holdExpiresAt: { $gte: new Date() },
        eventDate: { $gte: start, $lte: end },
      }).select('eventDate'),
    ]);

    const bookedDates = new Set([
      ...bookings.map((entry) => entry.eventDate),
      ...paymentHolds.map((entry) => entry.eventDate),
    ]);
    const manualDates = new Set(
      (venue.manualBlocks ?? [])
        .filter((entry) => entry.date >= start && entry.date <= end)
        .map((entry) => entry.date),
    );
    const blockedDates = new Set(
      (venue.blockedDates ?? []).filter(
        (entry) => entry >= start && entry <= end,
      ),
    );
    const busyDates = new Set([
      ...bookedDates,
      ...manualDates,
      ...blockedDates,
    ]);

    return response.json({
      month,
      start,
      end,
      busyDates: Array.from(busyDates).sort(),
      bookedDates: Array.from(bookedDates).sort(),
      manualDates: Array.from(manualDates).sort(),
      blockedDates: Array.from(blockedDates).sort(),
      totalBusy: busyDates.size,
    });
  }),
);

router.post(
  '/',
  requireAuth,
  requirePartnerSubscriptionAccess,
  asyncHandler(async (request, response) => {
    const body = venueMutationSchema.parse(request.body);
    validateVenueSchedule(body);
    const baseSlug = slugify(body.name, { lower: true, strict: true });
    const slug = `${baseSlug}-${Date.now().toString().slice(-6)}`;

    const venue = await Venue.create({
      name: body.name,
      venueType: body.venueType || 'salle',
      slug,
      shortDescription: body.shortDescription || '',
      description: body.description || '',
      city: normalizeCityLabel(body.city),
      district: body.district || '',
      address: body.address || '',
      googleMapsUrl: body.googleMapsUrl || '',
      country: body.country || 'Togo',
      coordinates: {
        latitude: body.latitude,
        longitude: body.longitude,
      },
      capacity: body.capacity,
      startingPrice: body.startingPrice,
      eventTypes: body.eventTypes || [],
      amenities: body.amenities || [],
      photos: body.photos || [],
      videoUrl: body.videoUrl || '',
      coverPhoto: body.coverPhoto || '',
      businessHours: body.businessHours || { opensAt: '08:00', closesAt: '23:00' },
      isPopular: body.isPopular ?? false,
      isFeatured: body.isFeatured ?? false,
      blockedDates: body.blockedDates || [],
      manualBlocks: body.manualBlocks || [],
      partner: request.user._id,
    });

    request.app.get('io').emit('venue:created', venue.toPublicJSON());
    await emitCalendarUpdate(request.app, venue);

    response.status(201).json({
      item: venue.toPublicJSON(),
    });
  }),
);

router.patch(
  '/:id',
  requireAuth,
  requirePartnerSubscriptionAccess,
  asyncHandler(async (request, response) => {
    const body = venueMutationSchema.partial().parse(request.body);
    validateVenueSchedule(body);
    const venue = await Venue.findById(request.params.id);

    if (!venue) {
      return response.status(404).json({
        message: 'Salle introuvable.',
      });
    }

    if (request.user.role !== 'admin' && String(venue.partner) !== String(request.user._id)) {
      return response.status(403).json({
        message: 'Vous ne pouvez pas modifier cette salle.',
      });
    }

    if (body.name) venue.name = body.name;
    if (body.venueType !== undefined) venue.venueType = body.venueType || venue.venueType;
    if (body.shortDescription !== undefined) venue.shortDescription = body.shortDescription;
    if (body.description !== undefined) venue.description = body.description;
    if (body.city) venue.city = normalizeCityLabel(body.city);
    if (body.district !== undefined) venue.district = body.district;
    if (body.address !== undefined) venue.address = body.address;
    if (body.googleMapsUrl !== undefined) venue.googleMapsUrl = body.googleMapsUrl;
    if (body.country !== undefined) venue.country = body.country;
    if (body.latitude !== undefined || body.longitude !== undefined) {
      venue.coordinates = {
        latitude: body.latitude ?? venue.coordinates?.latitude,
        longitude: body.longitude ?? venue.coordinates?.longitude,
      };
    }
    if (body.capacity) venue.capacity = body.capacity;
    if (body.startingPrice !== undefined) venue.startingPrice = body.startingPrice;
    if (body.eventTypes) venue.eventTypes = body.eventTypes;
    if (body.amenities) venue.amenities = body.amenities;
    if (body.photos) venue.photos = body.photos;
    if (body.videoUrl !== undefined) venue.videoUrl = body.videoUrl;
    if (body.coverPhoto !== undefined) venue.coverPhoto = body.coverPhoto;
    if (body.businessHours) venue.businessHours = body.businessHours;
    if (body.isPopular !== undefined) venue.isPopular = body.isPopular;
    if (body.isFeatured !== undefined) venue.isFeatured = body.isFeatured;
    if (body.blockedDates) venue.blockedDates = body.blockedDates;
    if (body.manualBlocks) venue.manualBlocks = body.manualBlocks;

    await venue.save();

    request.app.get('io').emit('venue:updated', venue.toPublicJSON());
    await emitCalendarUpdate(request.app, venue);

    response.json({
      item: venue.toPublicJSON(),
    });
  }),
);

export const venuesRouter = router;
