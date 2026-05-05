import fs from 'node:fs';
import path from 'node:path';

import { Router } from 'express';
import multer from 'multer';

import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { env } from '../config/env.js';
import crypto from 'node:crypto';

export const uploadsRouter = Router();

const uploadsDir = path.resolve(process.cwd(), 'uploads', 'listings');
fs.mkdirSync(uploadsDir, { recursive: true });

const storage = multer.diskStorage({
  destination(_req, _file, cb) {
    cb(null, uploadsDir);
  },
  filename(_req, file, cb) {
    const safeBase = path
      .basename(file.originalname)
      .replace(/[^a-zA-Z0-9._-]/g, '_');
    cb(null, `${Date.now()}-${safeBase}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter(_req, file, cb) {
    if (!file.mimetype.startsWith('image/')) {
      cb(new Error('Only image uploads are allowed'));
      return;
    }
    cb(null, true);
  },
});

uploadsRouter.post(
  '/listing-image',
  requireAuth,
  attachDbUser,
  upload.single('image'),
  async (req, res) => {
    if (!req.file) {
      res.status(400).json({ message: 'Image file is required' });
      return;
    }

    const relativeUrl = `/uploads/listings/${req.file.filename}`;
    const baseUrl = `${req.protocol}://${req.get('host')}`;

    res.status(201).json({
      message: 'Image uploaded',
      imageUrl: `${baseUrl}${relativeUrl}`,
      relativeUrl,
      filename: req.file.filename,
      size: req.file.size,
      mimeType: req.file.mimetype,
    });
  },
);

// Cloudinary signing endpoint for client-side signed uploads
uploadsRouter.post('/cloudinary/sign', requireAuth, attachDbUser, (req, res) => {
  try {
    const { folder, public_id } = req.body || {};
    const timestamp = Math.floor(Date.now() / 1000);

    // Build params string in alphabetical order of keys
    const parts = [];
    if (folder) parts.push(`folder=${folder}`);
    if (public_id) parts.push(`public_id=${public_id}`);
    parts.push(`timestamp=${timestamp}`);
    const paramsToSign = parts.join('&');

    const apiSecret = env.cloudinary.apiSecret || '';
    if (!apiSecret) {
      return res.status(500).json({ message: 'Cloudinary not configured on server' });
    }

    const signature = crypto.createHash('sha1').update(paramsToSign + apiSecret).digest('hex');

    res.json({
      apiKey: env.cloudinary.apiKey || '',
      cloudName: env.cloudinary.cloudName || '',
      timestamp,
      signature,
    });
  } catch (err) {
    res.status(500).json({ message: 'Failed to compute signature' });
  }
});
