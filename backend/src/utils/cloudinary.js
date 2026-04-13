import crypto from 'crypto';
import { env } from '../config/env.js';

// Cloudinary credentials are loaded from environment variables at server start.
function ensureCloudinaryConfig() {
  if (
    !env.CLOUDINARY_CLOUD_NAME ||
    !env.CLOUDINARY_API_KEY ||
    !env.CLOUDINARY_API_SECRET
  ) {
    throw new Error(
      'Cloudinary n est pas configure. Renseignez CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY et CLOUDINARY_API_SECRET.',
    );
  }
}

function signUploadParameters(parameters) {
  const serialized = Object.entries(parameters)
    .filter(([, value]) => value !== undefined && value !== null && value !== '')
    .sort(([leftKey], [rightKey]) => leftKey.localeCompare(rightKey))
    .map(([key, value]) => `${key}=${value}`)
    .join('&');

  return crypto
    .createHash('sha1')
    .update(`${serialized}${env.CLOUDINARY_API_SECRET}`)
    .digest('hex');
}

export async function uploadBase64ToCloudinary({
  fileBase64,
  fileName,
  mimeType,
  resourceType = 'image',
  folder = 'meevo/uploads',
}) {
  ensureCloudinaryConfig();

  const timestamp = Math.floor(Date.now() / 1000);
  const publicId = `${Date.now()}-${String(fileName || 'media')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80)}`;

  const signature = signUploadParameters({
    folder,
    public_id: publicId,
    timestamp,
  });

  const normalizedFile =
    fileBase64.startsWith('data:')
      ? fileBase64
      : `data:${mimeType || 'application/octet-stream'};base64,${fileBase64}`;

  const formData = new FormData();
  formData.append('file', normalizedFile);
  formData.append('api_key', env.CLOUDINARY_API_KEY);
  formData.append('timestamp', String(timestamp));
  formData.append('signature', signature);
  formData.append('folder', folder);
  formData.append('public_id', publicId);

  const response = await fetch(
    `https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD_NAME}/${resourceType}/upload`,
    {
      method: 'POST',
      body: formData,
    },
  );

  const payload = await response.json();

  if (!response.ok) {
    throw new Error(
      payload?.error?.message ||
        'Echec du televersement Cloudinary.',
    );
  }

  return {
    publicId: payload.public_id,
    secureUrl: payload.secure_url,
    resourceType: payload.resource_type,
    bytes: payload.bytes,
    format: payload.format,
    duration: payload.duration,
  };
}
