import { Router } from 'express';

import { requireAuth, requireRole } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { col, docToJson, queryToJson, serverTimestamp } from '../utils/firestoreHelpers.js';
import { fetchOfficialRates } from '../services/ratesIngestion.service.js';
import { admin } from '../config/firebaseAdmin.js';
import { asyncHandler } from '../utils/errors.js';

export const ratesRouter = Router();

ratesRouter.get('/latest', asyncHandler(async (req, res) => {
  const { crop, district, limit = 100 } = req.query;

  let query = col('crop_rates');

  if (typeof crop === 'string' && crop.trim()) {
    query = query.where('cropName', '==', crop.trim());
  }
  if (typeof district === 'string' && district.trim()) {
    query = query.where('district', '==', district.trim());
  }

  query = query.orderBy('rateDate', 'desc').limit(Math.min(Number(limit) || 100, 300));
  const snapshot = await query.get();
  res.json(queryToJson(snapshot));
}));

ratesRouter.post('/', requireAuth, attachDbUser, requireRole('admin'), asyncHandler(async (req, res) => {
  const payload = req.body || {};
  const data = {
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
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const ref = await col('crop_rates').add(data);
  const snap = await ref.get();
  res.status(201).json(docToJson(snap));
}));

ratesRouter.post('/ingest/official', requireAuth, attachDbUser, requireRole('admin'), asyncHandler(async (_req, res) => {
  const rows = await fetchOfficialRates();
  if (!rows.length) {
    res.json({ message: 'No rows ingested. Add official source adapters in ratesIngestion.service.js' });
    return;
  }

  const batch = admin.firestore().batch();
  for (const row of rows) {
    const ref = col('crop_rates').doc();
    batch.set(ref, {
      ...row,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }
  await batch.commit();
  res.json({ message: 'Ingestion complete', inserted: rows.length });
}));
