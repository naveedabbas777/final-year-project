import dotenv from 'dotenv';

dotenv.config();

export const env = {
  port: Number(process.env.PORT || 5000),
  host: process.env.HOST || '0.0.0.0',

  allowedOrigins: (process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((v) => v.trim())
    .filter(Boolean),
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || '',
  openWeatherKey: process.env.OPENWEATHER_KEY || '',
  weatherRainNext3hThreshold: Number(process.env.WEATHER_RAIN_NEXT_3H_THRESHOLD || 0.6),
  mapboxAccessToken: process.env.MAPBOX_ACCESS_TOKEN || '',
  grokApiKey: process.env.GROK_API_KEY || '',
  grokModel: process.env.GROK_MODEL || 'grok-4.3',
  grokMaxTokens: Number(process.env.GROK_MAX_TOKENS || 65536),
  // Optional OpenAI fallback (set OPENAI_API_KEY in .env to enable)
  openaiApiKey: process.env.OPENAI_API_KEY || '',
  openaiModel: process.env.OPENAI_MODEL || 'gpt-3.5-turbo',
  openaiMaxTokens: Number(process.env.OPENAI_MAX_TOKENS || 1024),
  cloudinary: {
    cloudName: process.env.CLOUDINARY_CLOUD_NAME || '',
    apiKey: process.env.CLOUDINARY_API_KEY || '',
    apiSecret: process.env.CLOUDINARY_API_SECRET || '',
  },
};
