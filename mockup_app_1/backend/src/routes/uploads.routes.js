import fs from 'node:fs';
import path from 'node:path';

import { Router } from 'express';
import multer from 'multer';

import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';

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
