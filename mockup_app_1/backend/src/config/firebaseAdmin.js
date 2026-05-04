import admin from 'firebase-admin';
import { env } from './env.js';
import fs from 'fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

let initialized = false;

export function initFirebaseAdmin() {
  if (initialized) return;

  try {
    const backendDir = path.resolve(__dirname, '../../');
    const localKeyPath = path.resolve(backendDir, 'serviceAccountKey.json');
    const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || localKeyPath;

    if (fs.existsSync(credentialsPath)) {
      const serviceAccount = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: env.firebaseProjectId || serviceAccount.project_id,
      });
    } else {
      throw new Error(
        'Firebase credentials are missing. Provide serviceAccountKey.json or set GOOGLE_APPLICATION_CREDENTIALS.',
      );
    }
    console.log('Firebase Admin initialized successfully');
  } catch (error) {
    console.error('Firebase Admin initialization failed:', error.message);
    throw error;
  }

  initialized = true;
}

export { admin };
