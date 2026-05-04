import { createApp } from './app.js';
import { env } from './config/env.js';
import { connectDb } from './config/db.js';
import { initFirebaseAdmin } from './config/firebaseAdmin.js';
import { startWeatherRefreshJob } from './services/weatherAlerts.service.js';

async function start() {
  await connectDb(env.mongoUri);
  initFirebaseAdmin();
  startWeatherRefreshJob({ intervalMinutes: 15 });

  const app = createApp();
  app.listen(env.port, () => {
    // eslint-disable-next-line no-console
    console.log(`API running on http://localhost:${env.port}`);
  });
}

start().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Failed to start server', err);
  process.exit(1);
});
