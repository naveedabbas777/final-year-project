import { createApp } from './app.js';
import { env } from './config/env.js';
import { initFirebaseAdmin } from './config/firebaseAdmin.js';
import { startWeatherRefreshJob } from './services/weatherAlerts.service.js';

async function start() {
  initFirebaseAdmin();
  // Log whether OpenWeather key is configured (do not print full key)
  if (env.openWeatherKey && env.openWeatherKey.length > 0) {
    const visible = env.openWeatherKey.slice(0, 4);
    // eslint-disable-next-line no-console
    console.log(`[Startup] OpenWeather key present (prefix: ${visible}****)`);
  } else {
    // eslint-disable-next-line no-console
    console.warn('[Startup] OpenWeather key not set; weather refresh disabled');
  }
  startWeatherRefreshJob({ intervalMinutes: 15 });

  const app = createApp();
  app.listen(env.port, env.host, () => {
    // eslint-disable-next-line no-console
    console.log(
      `API running on http://localhost:${env.port} and http://${env.host}:${env.port}`,
    );
  });
}

start().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Failed to start server', err);
  process.exit(1);
});
