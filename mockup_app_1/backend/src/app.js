import express from 'express';
import cors from 'cors';
import path from 'node:path';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { formatErrorResponse } from './utils/errors.js';

import { env } from './config/env.js';
import { healthRouter } from './routes/health.routes.js';
import { usersRouter } from './routes/users.routes.js';
import { ratesRouter } from './routes/rates.routes.js';
import { listingsRouter } from './routes/listings.routes.js';
import { offersRouter } from './routes/offers.routes.js';
import { ordersRouter } from './routes/orders.routes.js';
import { uploadsRouter } from './routes/uploads.routes.js';
import { weatherRouter } from './routes/weather.routes.js';
import { messagesRouter } from './routes/messages.routes.js';
import { ratingsRouter } from './routes/ratings.routes.js';
import { alertsRouter } from './routes/alerts.routes.js';
import { configRouter } from './routes/config.routes.js';

export function createApp() {
  const app = express();

  // Security headers
  app.use(helmet());

  // Basic rate limiter for all API endpoints
  const limiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 120, // limit each IP to 120 requests per windowMs
    standardHeaders: true,
    legacyHeaders: false,
  });
  app.use(limiter);

  app.use(
    cors({
      origin(origin, callback) {
        if (!origin || env.allowedOrigins.length === 0) {
          callback(null, true);
          return;
        }
        callback(null, env.allowedOrigins.includes(origin));
      },
      credentials: true,
    }),
  );

  app.use(express.json({ limit: '2mb' }));
  app.use('/uploads', express.static(path.resolve(process.cwd(), 'uploads')));

  app.use('/api/health', healthRouter);
  app.use('/api/users', usersRouter);
  app.use('/api/rates', ratesRouter);
  app.use('/api/listings', listingsRouter);
  app.use('/api/offers', offersRouter);
  app.use('/api/orders', ordersRouter);
  app.use('/api/uploads', uploadsRouter);
  app.use('/api/weather', weatherRouter);
  app.use('/api/messages', messagesRouter);
  app.use('/api/ratings', ratingsRouter);
  app.use('/api/alerts', alertsRouter);
  app.use('/api/config', configRouter);

  // Root route
  app.get('/', (_req, res) => {
    res.json({
      message: 'Digital Kissan Backend API',
      version: '1.0.0',
      status: 'running',
      endpoints: {
        health: '/api/health',
        users: '/api/users',
        weather: '/api/weather',
        messages: '/api/messages',
        alerts: '/api/alerts',
        config: '/api/config',
        rates: '/api/rates',
        listings: '/api/listings',
      },
    });
  });

  app.use((err, _req, res, _next) => {
    // eslint-disable-next-line no-console
    console.error(err);
    const statusCode = err.statusCode || 500;
    const response = formatErrorResponse(err);
    res.status(statusCode).json(response);
  });

  return app;
}
