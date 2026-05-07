import fs from 'node:fs';
import path from 'node:path';

import { Router } from 'express';
import multer from 'multer';
import { v2 as cloudinary } from 'cloudinary';

import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { env } from '../config/env.js';
import crypto from 'node:crypto';
import { asyncHandler, ServiceError, ValidationError } from '../utils/errors.js';

export const uploadsRouter = Router();

// configure cloudinary
cloudinary.config({
  cloud_name: env.cloudinary.cloudName || '',
  api_key: env.cloudinary.apiKey || '',
  api_secret: env.cloudinary.apiSecret || '',
});

const uploadsDir = path.resolve(process.cwd(), 'uploads', 'listings');
fs.mkdirSync(uploadsDir, { recursive: true });
const profilesDir = path.resolve(process.cwd(), 'uploads', 'profiles');
fs.mkdirSync(profilesDir, { recursive: true });

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

const allowedImageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter(_req, file, cb) {
    // Check MIME type first
    if (file.mimetype && file.mimetype.startsWith('image/')) {
      cb(null, true);
      return;
    }
    
    // Fallback: check file extension
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowedImageExts.includes(ext)) {
      cb(null, true);
      return;
    }
    
    // If neither MIME type nor extension matches, reject
    cb(new Error('Only image uploads are allowed (jpg, jpeg, png, gif, webp, bmp)'));
  },
});

function publicFileUrl(req, folder, filename) {
  return `${req.protocol}://${req.get('host')}/uploads/${folder}/${filename}`;
}

async function uploadFileToCloudinary(localPath, folder) {
  const result = await cloudinary.uploader.upload(localPath, {
    folder,
    resource_type: 'image',
    use_filename: true,
    unique_filename: false,
  });

  try {
    fs.unlinkSync(localPath);
  } catch (_error) {
    /* ignore cleanup failure */
  }

  return result;
}

// Server-side upload to Cloudinary for listings
uploadsRouter.post(
  '/listing-image',
  requireAuth,
  attachDbUser,
  upload.single('image'),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      throw new ValidationError('Image file is required');
    }

    const localPath = req.file.path;
    const folder = 'listings';
    const cloudConfigured =
      env.cloudinary.cloudName && env.cloudinary.apiKey && env.cloudinary.apiSecret;

    if (!cloudConfigured) {
      return res.status(201).json({
        message: 'Image uploaded locally',
        imageUrl: publicFileUrl(req, folder, req.file.filename),
        localPath: `/uploads/${folder}/${req.file.filename}`,
      });
    }

    try {
      const result = await uploadFileToCloudinary(localPath, folder);

      res.status(201).json({
        message: 'Image uploaded',
        imageUrl: result.secure_url,
        publicId: result.public_id,
        width: result.width,
        height: result.height,
      });
    } catch (err) {
      // Clean up local file on error
      try {
        fs.unlinkSync(localPath);
      } catch (e) {
        /* ignore */
      }
      throw new ServiceError(`Image upload failed: ${err.message}`, 'UPLOAD_FAILED');
    }
  }),
);

uploadsRouter.post(
  '/profile-image',
  requireAuth,
  attachDbUser,
  upload.single('image'),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      throw new ValidationError('Image file is required');
    }

    const localPath = req.file.path;
    const folder = 'profiles';
    const cloudConfigured =
      env.cloudinary.cloudName && env.cloudinary.apiKey && env.cloudinary.apiSecret;

    if (!cloudConfigured) {
      // Move from listings temp dir to profiles dir for local profile images.
      const targetPath = path.join(profilesDir, req.file.filename);
      fs.renameSync(localPath, targetPath);

      res.status(201).json({
        message: 'Profile image uploaded locally',
        imageUrl: publicFileUrl(req, folder, req.file.filename),
        localPath: `/uploads/${folder}/${req.file.filename}`,
      });
      return;
    }

    try {
      const result = await uploadFileToCloudinary(localPath, folder);

      res.status(201).json({
        message: 'Profile image uploaded',
        imageUrl: result.secure_url,
        publicId: result.public_id,
        width: result.width,
        height: result.height,
      });
    } catch (err) {
      try {
        fs.unlinkSync(localPath);
      } catch (_error) {
        /* ignore cleanup failure */
      }
      throw new ServiceError(`Profile image upload failed: ${err.message}`, 'UPLOAD_FAILED');
    }
  }),
);

// Cloudinary signing endpoint for client-side signed uploads
uploadsRouter.post(
  '/cloudinary/sign',
  requireAuth,
  attachDbUser,
  asyncHandler((req, res) => {
    const { folder, public_id } = req.body || {};
    const timestamp = Math.floor(Date.now() / 1000);

    if (!env.cloudinary.cloudName || !env.cloudinary.apiKey || !env.cloudinary.apiSecret) {
      return res.status(200).json({
        cloudinaryEnabled: false,
        message: 'Cloudinary not configured on server',
      });
    }

    // Build params string in alphabetical order of keys
    const parts = [];
    if (folder) parts.push(`folder=${folder}`);
    if (public_id) parts.push(`public_id=${public_id}`);
    parts.push(`timestamp=${timestamp}`);
    const paramsToSign = parts.join('&');

    const signature = crypto
      .createHash('sha1')
      .update(paramsToSign + env.cloudinary.apiSecret)
      .digest('hex');

    res.json({
      apiKey: env.cloudinary.apiKey || '',
      cloudName: env.cloudinary.cloudName || '',
      timestamp,
      signature,
    });
  }),
);
