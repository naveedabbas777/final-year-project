import dotenv from 'dotenv';

dotenv.config();

export const env = {
  port: Number(process.env.PORT || 5000),
  mongoUri: process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/digital_kissan',
  allowedOrigins: (process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((v) => v.trim())
    .filter(Boolean),
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || '',
  openWeatherKey: process.env.OPENWEATHER_KEY || '',
  mapboxAccessToken: process.env.MAPBOX_ACCESS_TOKEN || '',
};
