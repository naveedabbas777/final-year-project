import { Router } from 'express';

import { requireAuth, requireRole } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { col, docToJson, queryToJson, serverTimestamp } from '../utils/firestoreHelpers.js';
import { fetchOfficialRates } from '../services/ratesIngestion.service.js';
import { admin } from '../config/firebaseAdmin.js';
import multer from 'multer';
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

// Update an existing rate (admin only)
ratesRouter.patch('/:id', requireAuth, attachDbUser, requireRole('admin'), asyncHandler(async (req, res) => {
  const id = String(req.params.id || '').trim();
  if (!id) return res.status(400).json({ message: 'rate id required' });
  const payload = req.body || {};
  const update = {};
  if (typeof payload.cropName === 'string') update.cropName = payload.cropName;
  if (typeof payload.marketName === 'string') update.marketName = payload.marketName;
  if (typeof payload.district === 'string') update.district = payload.district;
  if (payload.minPrice !== undefined) update.minPrice = Number(payload.minPrice);
  if (payload.maxPrice !== undefined) update.maxPrice = Number(payload.maxPrice);
  if (typeof payload.unit === 'string') update.unit = payload.unit;
  if (typeof payload.sourceName === 'string') update.sourceName = payload.sourceName;
  if (typeof payload.sourceUrl === 'string') update.sourceUrl = payload.sourceUrl;
  if (payload.rateDate) update.rateDate = new Date(payload.rateDate);
  update.updatedAt = serverTimestamp();

  const ref = col('crop_rates').doc(id);
  await ref.set(update, { merge: true });
  const snap = await ref.get();
  res.json(docToJson(snap));
}));

// CSV bulk upload (admin only) - accepts multipart/form-data with file field 'file'
const upload = multer({ storage: multer.memoryStorage() });

ratesRouter.post('/bulk', requireAuth, attachDbUser, requireRole('admin'), upload.single('file'), asyncHandler(async (req, res) => {
  const file = req.file;
  if (!file) return res.status(400).json({ message: 'CSV file required (field name: file)' });
  const text = file.buffer.toString('utf8');
  // simple CSV parse: assume header row with cropName,marketName,district,minPrice,maxPrice,unit,sourceName,sourceUrl,rateDate
  const lines = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  if (lines.length < 1) return res.status(400).json({ message: 'CSV is empty' });
  const header = lines[0].split(',').map(h => h.trim());
  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    const parts = lines[i].split(',');
    if (parts.length < 5) continue;
    const obj = {};
    for (let j = 0; j < Math.min(parts.length, header.length); j++) {
      obj[header[j]] = parts[j].trim();
    }
    rows.push(obj);
  }
  if (!rows.length) return res.json({ message: 'No valid rows found', inserted: 0 });

  const batch = admin.firestore().batch();
  for (const r of rows) {
    const ref = col('crop_rates').doc();
    const data = {
      cropName: r.cropName || r.crop || '',
      marketName: r.marketName || '',
      district: r.district || '',
      minPrice: Number(r.minPrice) || 0,
      maxPrice: Number(r.maxPrice) || 0,
      unit: r.unit || '40kg',
      sourceName: r.sourceName || 'csv',
      sourceUrl: r.sourceUrl || '',
      isOfficialSource: false,
      rateDate: r.rateDate ? new Date(r.rateDate) : new Date(),
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };
    batch.set(ref, data);
  }
  await batch.commit();
  res.json({ message: 'Bulk upload complete', inserted: rows.length });
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
