import express from 'express';

import { env } from '../config/env.js';

export const configRouter = express.Router();

configRouter.get('/public', (_req, res) => {
  res.json({
    mapboxAccessToken: env.mapboxAccessToken,
    openWeatherConfigured: Boolean(env.openWeatherKey && env.openWeatherKey.length > 0),
  });
});