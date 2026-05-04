import express from 'express';
import cors from 'cors';
import path from 'node:path';

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
import { alertsRouter } from './routes/alerts.routes.js';

export function createApp() {
  const app = express();

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
  app.use('/api/alerts', alertsRouter);

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
        rates: '/api/rates',
        listings: '/api/listings',
      },
    });
  });

  app.use((err, _req, res, _next) => {
    // eslint-disable-next-line no-console
    console.error(err);
    res.status(err.statusCode || 500).json({
      message: err.message || 'Internal server error',
    });
  });

  return app;
}
