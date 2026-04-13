import { Router } from 'express';
import { z } from 'zod';
import { requireAuth, requirePartnerSubscriptionAccess } from '../middleware/auth.js';
import { Provider } from '../models/Provider.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { isPartnerVisiblePublicly } from '../utils/subscriptionVisibility.js';

const router = Router();

const providerMutationSchema = z.object({
  name: z.string().min(2),
  category: z.string().min(2),
  description: z.string().optional().or(z.literal('')),
  city: z.string().min(2),
  startingPrice: z.coerce.number().nonnegative(),
  photoUrl: z.string().optional().or(z.literal('')),
  phone: z.string().optional().or(z.literal('')),
  whatsapp: z.string().optional().or(z.literal('')),
  email: z.string().optional().or(z.literal('')),
  isFeatured: z.boolean().optional(),
});

const providerUpdateSchema = providerMutationSchema.partial();

router.get(
  '/mine',
  requireAuth,
  requirePartnerSubscriptionAccess,
  asyncHandler(async (request, response) => {
    const filters = { partner: request.user._id };

    const items = await Provider.find(filters).sort({ createdAt: -1 }).limit(100);

    response.json({
      items: items.map((provider) => provider.toPublicJSON()),
    });
  }),
);

router.get(
  '/',
  asyncHandler(async (request, response) => {
    const {
      category,
      city,
      featured,
      q,
      page = '1',
      limit = '24',
    } = request.query;
    const filters = {};

    if (q) {
      const escapedQuery = String(q).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const queryRegex = new RegExp(escapedQuery, 'i');
      filters.$or = [
        { name: queryRegex },
        { category: queryRegex },
        { city: queryRegex },
        { description: queryRegex },
      ];
    }

    if (category) {
      filters.category = new RegExp(String(category), 'i');
    }

    if (city) {
      filters.city = new RegExp(String(city), 'i');
    }

    if (featured === 'true') {
      filters.isFeatured = true;
    }

    const safeLimit = Math.min(Number(limit) || 24, 60);
    const safePage = Math.max(Number(page) || 1, 1);
    const skip = (safePage - 1) * safeLimit;

    const items = await Provider.find(filters)
      .populate('partner', 'role subscription')
      .sort({ isFeatured: -1, createdAt: -1 });
    const visibleItems = items.filter((provider) =>
      isPartnerVisiblePublicly(provider.partner),
    );
    const paginatedItems = visibleItems.slice(skip, skip + safeLimit);

    response.json({
      items: paginatedItems.map((provider) => provider.toPublicJSON()),
      pagination: {
        page: safePage,
        limit: safeLimit,
        total: visibleItems.length,
        totalPages: Math.max(Math.ceil(visibleItems.length / safeLimit), 1),
      },
    });
  }),
);

router.post(
  '/',
  requireAuth,
  requirePartnerSubscriptionAccess,
  asyncHandler(async (request, response) => {
    const body = providerMutationSchema.parse(request.body);

    const provider = await Provider.create({
      ...body,
      photoUrl: body.photoUrl || '',
      phone: body.phone || '',
      whatsapp: body.whatsapp || '',
      email: body.email || '',
      isFeatured: body.isFeatured ?? false,
      partner: request.user._id,
    });

    request.app.get('io').emit('provider:created', provider.toPublicJSON());

    response.status(201).json({
      item: provider.toPublicJSON(),
    });
  }),
);

router.patch(
  '/:id',
  requireAuth,
  requirePartnerSubscriptionAccess,
  asyncHandler(async (request, response) => {
    const body = providerUpdateSchema.parse(request.body);
    const provider = await Provider.findById(request.params.id);

    if (!provider) {
      return response.status(404).json({
        message: 'Prestataire introuvable.',
      });
    }

    if (
      request.user.role !== 'admin' &&
      String(provider.partner) !== String(request.user._id)
    ) {
      return response.status(403).json({
        message: 'Vous ne pouvez pas modifier ce prestataire.',
      });
    }

    if (body.name) provider.name = body.name;
    if (body.category) provider.category = body.category;
    if (body.description !== undefined) provider.description = body.description;
    if (body.city) provider.city = body.city;
    if (body.startingPrice !== undefined) provider.startingPrice = body.startingPrice;
    if (body.photoUrl !== undefined) provider.photoUrl = body.photoUrl;
    if (body.phone !== undefined) provider.phone = body.phone;
    if (body.whatsapp !== undefined) provider.whatsapp = body.whatsapp;
    if (body.email !== undefined) provider.email = body.email;
    if (body.isFeatured !== undefined) provider.isFeatured = body.isFeatured;

    await provider.save();

    request.app.get('io').emit('provider:updated', provider.toPublicJSON());

    response.json({
      item: provider.toPublicJSON(),
    });
  }),
);

export const providersRouter = router;
