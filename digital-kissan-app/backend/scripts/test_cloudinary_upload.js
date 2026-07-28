import path from 'node:path';
import process from 'node:process';
import dotenv from 'dotenv';
import { v2 as cloudinary } from 'cloudinary';

const envPath = path.resolve(process.cwd(), '.env');
dotenv.config({ path: envPath });

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME || '',
  api_key: process.env.CLOUDINARY_API_KEY || '',
  api_secret: process.env.CLOUDINARY_API_SECRET || '',
});

const filePath = path.resolve(process.cwd(), '../assets/placeholder.png');
const folder = 'smoke-tests';

async function main() {
  if (!process.env.CLOUDINARY_CLOUD_NAME || !process.env.CLOUDINARY_API_KEY || !process.env.CLOUDINARY_API_SECRET) {
    throw new Error('Cloudinary credentials missing from backend/.env');
  }

  const upload = await cloudinary.uploader.upload(filePath, {
    folder,
    resource_type: 'image',
    use_filename: true,
    unique_filename: false,
  });

  console.log(JSON.stringify({
    uploaded: true,
    secure_url: upload.secure_url,
    public_id: upload.public_id,
    width: upload.width,
    height: upload.height,
  }, null, 2));

  try {
    await cloudinary.uploader.destroy(upload.public_id, { resource_type: 'image' });
    console.log(JSON.stringify({ cleanedUp: true, public_id: upload.public_id }, null, 2));
  } catch (cleanupError) {
    console.error(`Cleanup failed: ${cleanupError.message}`);
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
