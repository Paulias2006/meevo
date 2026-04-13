import 'dotenv/config';
import { z } from 'zod';

const isProduction = process.env.NODE_ENV === 'production';
const defaultMongoUri = 'mongodb://127.0.0.1:27017/meevo';
const defaultJwtSecret = 'meevo_dev_secret_change_me_2026';

const envSchema = z.object({
  PORT: z.coerce.number().default(4000),
  HOST: z.string().optional().default('0.0.0.0'),
  MONGODB_URI: z.string().min(1).default(defaultMongoUri),
  JWT_SECRET: z.string().min(10).default(defaultJwtSecret),
  CLIENT_ORIGIN: z.string().default('*'),
  PUBLIC_BASE_URL: z.string().optional().default(''),
  PARTNER_MONTHLY_PRICE: z.coerce.number().default(50000),
  PARTNER_MAX_SUBSCRIPTION_MONTHS: z.coerce.number().default(24),
  BOOKING_PLATFORM_COMMISSION_RATE: z.coerce.number().default(0.05),
  BOOKING_PAYMENT_HOLD_MINUTES: z.coerce.number().default(15),
  CINETPAY_APIKEY: z.string().optional().default(''),
  CINETPAY_SITE_ID: z.string().optional().default(''),
  CINETPAY_NOTIFY_URL: z.string().optional().default(''),
  CINETPAY_RETURN_URL: z.string().optional().default(''),
  CINETPAY_CURRENCY: z.string().optional().default('XOF'),
  CINETPAY_LANG: z.string().optional().default('fr'),
  CINETPAY_CHANNELS: z.string().optional().default('MOBILE_MONEY'),
  CINETPAY_PAYOUT_PASSWORD: z.string().optional().default(''),
  CINETPAY_PAYOUT_NOTIFY_URL: z.string().optional().default(''),
  CINETPAY_PAYOUT_PREFIX: z.string().optional().default('228'),
  CLOUDINARY_CLOUD_NAME: z.string().optional().default(''),
  CLOUDINARY_API_KEY: z.string().optional().default(''),
  CLOUDINARY_API_SECRET: z.string().optional().default(''),
});

export const env = envSchema.parse(process.env);

if (isProduction) {
  if (env.MONGODB_URI === defaultMongoUri) {
    throw new Error(
      'MONGODB_URI doit etre configure en production. Mettez une vraie base MongoDB.',
    );
  }

  if (env.JWT_SECRET === defaultJwtSecret) {
    throw new Error(
      'JWT_SECRET doit etre personnalise en production pour securiser les sessions.',
    );
  }
}
