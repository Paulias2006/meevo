import { Router } from 'express';
import { z } from 'zod';
import { requireAuth, requirePartnerSubscriptionAccess } from '../middleware/auth.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { uploadBase64ToCloudinary } from '../utils/cloudinary.js';

const router = Router();

const uploadSchema = z.object({
  fileBase64: z.string().min(20),
  fileName: z.string().optional().or(z.literal('')),
  mimeType: z.string().optional().or(z.literal('')),
  resourceType: z.enum(['image', 'video', 'auto']).optional().default('image'),
  folder: z.string().optional().or(z.literal('')),
});

router.post(
  '/cloudinary',
  requireAuth,
  requirePartnerSubscriptionAccess,
  asyncHandler(async (request, response) => {
    const body = uploadSchema.parse(request.body);

    const upload = await uploadBase64ToCloudinary({
      fileBase64: body.fileBase64,
      fileName: body.fileName || 'media',
      mimeType: body.mimeType || 'application/octet-stream',
      resourceType: body.resourceType,
      folder: body.folder || 'meevo/uploads',
    });

    response.status(201).json({
      item: upload,
    });
  }),
);

export const uploadsRouter = router;
