import { Router } from 'express';
import { Booking } from '../models/Booking.js';
import { Provider } from '../models/Provider.js';
import { Venue } from '../models/Venue.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { isPartnerVisiblePublicly } from '../utils/subscriptionVisibility.js';

const router = Router();

router.get(
  '/home',
  asyncHandler(async (_request, response) => {
    const [allPublishedVenues, allProviders, bookingsCount] = await Promise.all([
      Venue.find({ status: 'published' })
        .populate('partner', 'role subscription')
        .sort({ isFeatured: -1, isPopular: -1, createdAt: -1 }),
      Provider.find({})
        .populate('partner', 'role subscription')
        .sort({ isFeatured: -1, createdAt: -1 }),
      Booking.countDocuments(),
    ]);

    const visibleVenues = allPublishedVenues.filter((venue) =>
      isPartnerVisiblePublicly(venue.partner),
    );
    const visibleProviders = allProviders.filter((provider) =>
      isPartnerVisiblePublicly(provider.partner),
    );

    const venuesCount = visibleVenues.length;
    const cities = Array.from(new Set(visibleVenues.map((item) => item.city)));
    const providersCount = visibleProviders.length;
    const featuredVenuesSource =
      visibleVenues.filter((item) => item.isFeatured).length > 0
        ? visibleVenues.filter((item) => item.isFeatured)
        : visibleVenues.filter((item) => item.isPopular).length > 0
            ? visibleVenues.filter((item) => item.isPopular)
            : visibleVenues;
    const featuredProvidersSource =
      visibleProviders.filter((item) => item.isFeatured).length > 0
        ? visibleProviders.filter((item) => item.isFeatured)
        : visibleProviders;

    const featuredVenues = featuredVenuesSource.slice(0, 10);
    const featuredProviders = featuredProvidersSource.slice(0, 4);

    response.json({
      stats: {
        venuesCount,
        citiesCount: cities.length,
        providersCount,
        bookingsCount,
      },
      featuredVenues: featuredVenues.map((item) => item.toPublicJSON()),
      featuredProviders: featuredProviders.map((item) => item.toPublicJSON()),
    });
  }),
);

export const dashboardRouter = router;
