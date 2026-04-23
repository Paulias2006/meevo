import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import { adminRouter } from './routes/admin.js';
import { env } from './config/env.js';
import { authRouter } from './routes/auth.js';
import { bookingsRouter } from './routes/bookings.js';
import { dashboardRouter } from './routes/dashboard.js';
import { locationRouter } from './routes/location.js';
import { providersRouter } from './routes/providers.js';
import { subscriptionsRouter } from './routes/subscriptions.js';
import { uploadsRouter } from './routes/uploads.js';
import { venuesRouter } from './routes/venues.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';

export function createApp(io) {
  const app = express();

  app.set('io', io);
  app.use(
    cors({
      origin: env.CLIENT_ORIGIN === '*' ? true : env.CLIENT_ORIGIN,
      credentials: true,
    }),
  );
  app.use(helmet());
  app.use(morgan('dev'));

  app.get('/health', (_request, response) => {
    response.json({
      status: 'ok',
    });
  });

  app.use('/api/uploads', express.json({ limit: '100mb' }), uploadsRouter);
  app.use(express.json({ limit: '4mb' }));
  app.use(express.urlencoded({ extended: true, limit: '4mb' }));

  app.use('/api/auth', authRouter);
  app.use('/api/admin', adminRouter);
  app.use('/api/dashboard', dashboardRouter);
  app.use('/api/location', locationRouter);
  app.use('/api/subscriptions', subscriptionsRouter);
  app.use('/api/venues', venuesRouter);
  app.use('/api/providers', providersRouter);
  app.use('/api/bookings', bookingsRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
