import { Router } from 'express';

import { CropRateModel } from '../models/cropRate.model.js';
import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { requireRole } from '../middlewares/auth.js';
import { fetchOfficialRates } from '../services/ratesIngestion.service.js';

export const ratesRouter = Router();

ratesRouter.get('/latest', async (req, res) => {
  const { crop, district, limit = 100 } = req.query;
  const query = {};

  if (typeof crop === 'string' && crop.trim()) query.cropName = crop.trim();
  if (typeof district === 'string' && district.trim()) {
    query.district = district.trim();
  }

  const rows = await CropRateModel.find(query)
    .sort({ rateDate: -1, createdAt: -1 })
    .limit(Math.min(Number(limit) || 100, 300));

  res.json(rows);
});

ratesRouter.post('/', requireAuth, attachDbUser, requireRole('admin'), async (req, res) => {
  const payload = req.body || {};
  const doc = await CropRateModel.create({
    cropName: payload.cropName,
    marketName: payload.marketName,
    district: payload.district,
    minPrice: Number(payload.minPrice),
    maxPrice: Number(payload.maxPrice),
    unit: payload.unit || '40kg',
    sourceName: payload.sourceName,
    sourceUrl: payload.sourceUrl,
    isOfficialSource: payload.isOfficialSource !== false,
    rateDate: payload.rateDate ? new Date(payload.rateDate) : new Date(),
  });
  res.status(201).json(doc);
});

ratesRouter.post('/ingest/official', requireAuth, attachDbUser, requireRole('admin'), async (_req, res) => {
  const rows = await fetchOfficialRates();
  if (!rows.length) {
    res.json({ message: 'No rows ingested. Add official source adapters in ratesIngestion.service.js' });
    return;
  }

  const inserted = await CropRateModel.insertMany(rows, { ordered: false });
  res.json({ message: 'Ingestion complete', inserted: inserted.length });
});
