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
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

    let serviceAccount;
    if (serviceAccountJson) {
      try {
        serviceAccount = JSON.parse(serviceAccountJson);
      } catch (parseError) {
        throw new Error(
          `Invalid FIREBASE_SERVICE_ACCOUNT_JSON: ${parseError.message}`,
        );
      }
    } else if (fs.existsSync(credentialsPath)) {
      serviceAccount = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
    }

    if (!serviceAccount) {
      throw new Error(
        'Firebase credentials are missing. Provide serviceAccountKey.json, set GOOGLE_APPLICATION_CREDENTIALS, or set FIREBASE_SERVICE_ACCOUNT_JSON.',
      );
    }

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: env.firebaseProjectId || serviceAccount.project_id,
    });
    console.log('Firebase Admin initialized successfully');
  } catch (error) {
    console.error('Firebase Admin initialization failed:', error.message);
    throw error;
  }

  initialized = true;
}

export { admin };
