import { admin } from '../config/firebaseAdmin.js';
import { env } from '../config/env.js';

function collectFcmTokens(userData) {
  const tokens = [];
  if (Array.isArray(userData?.fcmTokens)) {
    tokens.push(...userData.fcmTokens.filter(Boolean));
  }
  if (typeof userData?.fcmToken === 'string' && userData.fcmToken.trim()) {
    tokens.push(userData.fcmToken.trim());
  }
  return [...new Set(tokens)];
}

async function removeInvalidTokens(userId, invalidTokens) {
  if (!userId || invalidTokens.length === 0) return;
  await admin.firestore().collection('users').doc(userId).set(
    { fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens) },
    { merge: true },
  );
}

async function sendWeatherAlertPushes(userDoc, alerts) {
  if (!userDoc?.firebaseUid || !Array.isArray(alerts) || alerts.length === 0) return;

  const userSnap = await admin.firestore().collection('users').doc(userDoc.firebaseUid).get();
  const userData = userSnap.exists ? userSnap.data() : null;
  const tokens = collectFcmTokens(userData);
  if (tokens.length === 0) return;

  for (const alert of alerts) {
    const payload = {
      notification: {
        title: alert.title,
        body: alert.body,
      },
      data: {
        type: 'weather_alert',
        alertType: alert.type,
        userId: userDoc.firebaseUid,
      },
    };

    const resp = await admin.messaging().sendMulticast({ tokens, ...payload });
    if (resp.failureCount > 0) {
      const invalidTokens = [];
      resp.responses.forEach((r, i) => {
        if (!r.success) invalidTokens.push(tokens[i]);
      });
      await removeInvalidTokens(userDoc.firebaseUid, invalidTokens);
    }
  }
}

function degToCompass(deg) {
  if (deg == null) return '';
  const dirs = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
  const idx = Math.floor(((deg / 22.5) + 0.5)) % 16;
  return dirs[idx];
}

function formatTime(epochSeconds) {
  if (epochSeconds == null) return '';
  return new Date(epochSeconds * 1000).toLocaleTimeString([], {
    hour: 'numeric',
    minute: '2-digit',
  });
}

function extractPrecip(current) {
  const rain = current?.rain;
  if (rain && typeof rain === 'object' && typeof rain['1h'] === 'number') return rain['1h'];
  const snow = current?.snow;
  if (snow && typeof snow === 'object' && typeof snow['1h'] === 'number') return snow['1h'];
  return 0;
}

function toOneCallCurrent(current) {
  const weather = Array.isArray(current?.weather) && current.weather.length > 0 ? current.weather[0] : null;
  return {
    temp: current?.main?.temp ?? null,
    weather: weather ? [weather] : [],
    wind_speed: current?.wind?.speed ?? null,
    wind_deg: current?.wind?.deg ?? null,
    humidity: current?.main?.humidity ?? null,
    clouds: current?.clouds?.all ?? null,
    rain: current?.rain ?? null,
    snow: current?.snow ?? null,
    sunrise: current?.sys?.sunrise ?? null,
    sunset: current?.sys?.sunset ?? null,
  };
}

function toDailyFromForecast(forecast) {
  const list = Array.isArray(forecast?.list) ? forecast.list : [];
  const byDate = new Map();

  for (const item of list) {
    if (!item || typeof item !== 'object' || typeof item.dt !== 'number') continue;
    const dateKey = new Date(item.dt * 1000).toISOString().slice(0, 10);
    if (!byDate.has(dateKey)) byDate.set(dateKey, []);
    byDate.get(dateKey).push(item);
  }

  const daily = [];
  for (const [dateKey, items] of byDate.entries()) {
    if (items.length === 0) continue;

    let tempMin = null;
    let tempMax = null;
    let tempSum = 0;
    let tempCount = 0;
    let popAny = 0;
    const pops = [];
    let humiditySum = 0;
    let humidityCount = 0;
    let cloudsSum = 0;
    let cloudsCount = 0;
    let visibilitySum = 0;
    let visibilityCount = 0;
    let windSpeedMax = 0;
    let windDeg = null;
    let firstWeather = null;

    for (const item of items) {
      const main = item.main || {};
      const temp = typeof main.temp === 'number' ? main.temp : null;
      const tMin = typeof main.temp_min === 'number' ? main.temp_min : null;
      const tMax = typeof main.temp_max === 'number' ? main.temp_max : null;

      if (tMin != null) tempMin = tempMin == null ? tMin : Math.min(tempMin, tMin);
      if (tMax != null) tempMax = tempMax == null ? tMax : Math.max(tempMax, tMax);
      if (temp != null) {
        tempSum += temp;
        tempCount += 1;
      }

      if (typeof item.pop === 'number') {
        pops.push(item.pop);
        popAny = Math.max(popAny, item.pop);
      }

      if (typeof main.humidity === 'number') {
        humiditySum += main.humidity;
        humidityCount += 1;
      }

      if (typeof item.visibility === 'number') {
        visibilitySum += item.visibility;
        visibilityCount += 1;
      }

      if (typeof item.clouds?.all === 'number') {
        cloudsSum += item.clouds.all;
        cloudsCount += 1;
      }

      if (typeof item.wind?.speed === 'number' && item.wind.speed > windSpeedMax) {
        windSpeedMax = item.wind.speed;
      }
      if (windDeg == null && typeof item.wind?.deg === 'number') {
        windDeg = item.wind.deg;
      }

      if (!firstWeather && Array.isArray(item.weather) && item.weather.length > 0 && item.weather[0] && typeof item.weather[0] === 'object') {
        firstWeather = item.weather[0];
      }
    }

    if (pops.length > 0) {
      let product = 1;
      for (const p of pops) {
        const pc = Math.min(1, Math.max(0, p));
        product *= (1 - pc);
      }
      popAny = Math.max(popAny, 1 - product);
    }

    const avgTemp = tempCount > 0 ? tempSum / tempCount : null;
    const avgHumidity = humidityCount > 0 ? humiditySum / humidityCount : null;
    const avgClouds = cloudsCount > 0 ? cloudsSum / cloudsCount : null;
    const avgVisibility = visibilityCount > 0 ? visibilitySum / visibilityCount : null;

    const firstDt = items[0].dt;
    daily.push({
      dt: firstDt,
      temp: { min: tempMin, max: tempMax, day: avgTemp },
      pop: popAny,
      uvi: 0,
      humidity: avgHumidity,
      visibility: avgVisibility,
      sunrise: null,
      sunset: null,
      moon_phase: null,
      wind_speed: windSpeedMax,
      wind_deg: windDeg,
      clouds: avgClouds,
      weather: firstWeather ? [firstWeather] : [],
      hourly: items,
      date_key: dateKey,
    });
  }

  daily.sort((a, b) => (a.dt ?? 0) - (b.dt ?? 0));
  return daily;
}

function toWeatherPayload(currentJson, forecastJson) {
  const current = toOneCallCurrent(currentJson);
  const forecast = { daily: toDailyFromForecast(forecastJson) };

  return {
    raw: {
      current: currentJson,
      forecast: forecastJson,
    },
    current,
    forecast,
    derived: {
      sunrise: formatTime(current.sunrise),
      sunset: formatTime(current.sunset),
      windDirection: degToCompass(current.wind_deg),
      precipitation: extractPrecip(current),
    },
  };
}

async function fetchOpenWeather(lat, lon) {
  const key = env.openWeatherKey;
  if (!key) {
    throw new Error('OpenWeather API key not configured on server');
  }

  const base = 'https://api.openweathermap.org/data/2.5';
  const currentUrl = `${base}/weather?lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lon)}&units=metric&appid=${encodeURIComponent(key)}`;
  const forecastUrl = `${base}/forecast?lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lon)}&units=metric&appid=${encodeURIComponent(key)}`;

  const [currentResp, forecastResp] = await Promise.all([fetch(currentUrl), fetch(forecastUrl)]);

  if (!currentResp.ok) {
    const text = await currentResp.text();
    throw new Error(`OpenWeather current failed: ${text}`);
  }
  if (!forecastResp.ok) {
    const text = await forecastResp.text();
    throw new Error(`OpenWeather forecast failed: ${text}`);
  }

  const currentJson = await currentResp.json();
  const forecastJson = await forecastResp.json();
  return toWeatherPayload(currentJson, forecastJson);
}

function buildAlertDefinitions(current, todayForecast) {
  const alerts = [];
  const rainLikely = (todayForecast?.pop ?? 0) >= 0.5 || (current.precipitation > 0.1);
  const hot = current.temperature >= 35;
  const cold = current.temperature <= 5;
  const windy = current.windSpeed >= 10;

  if (rainLikely) {
    alerts.push({
      type: 'rain',
      title: 'Rain expected near your fields',
      body: `Chance of rain around ${Math.round((todayForecast?.pop ?? 0) * 100)}%. Secure equipment and delay spraying.`,
    });
  }

  if (hot) {
    alerts.push({
      type: 'heat',
      title: 'High heat alert',
      body: 'Temperatures above 35°C expected. Increase irrigation if needed.',
    });
  }

  if (cold) {
    alerts.push({
      type: 'cold',
      title: 'Low temperature alert',
      body: `Temps near ${Math.round(current.temperature)}°C. Protect sensitive crops.`,
    });
  }

  if (windy) {
    alerts.push({
      type: 'wind',
      title: 'Windy conditions',
      body: `Wind above ${current.windSpeed.toFixed(1)} m/s. Avoid spraying.`,
    });
  }

  return alerts;
}

function toJsDate(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function toIsoString(value) {
  const dt = toJsDate(value);
  return dt ? dt.toISOString() : null;
}

function normalizeWeatherCache(data) {
  if (!data) return null;
  return {
    ...data,
    refreshedAt: toIsoString(data.refreshedAt),
  };
}

function removeUndefinedValues(obj) {
  if (obj === null || obj === undefined) return null;
  if (typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) {
    return obj.map((item) => removeUndefinedValues(item)).filter((item) => item !== undefined);
  }
  return Object.entries(obj).reduce((acc, [key, value]) => {
    const cleaned = removeUndefinedValues(value);
    if (cleaned !== undefined) {
      acc[key] = cleaned;
    }
    return acc;
  }, {});
}

function hasSameDayAlertToday(alerts, type) {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return alerts.some((alert) => {
    if (alert.type !== type) return false;
    const createdAt = toJsDate(alert.createdAt);
    return createdAt != null && createdAt >= start;
  });
}

async function readExistingAlerts(userId, limit = 50) {
  const snapshot = await admin
    .firestore()
    .collection('weather_alerts')
    .where('userId', '==', userId)
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get();

  return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

export async function fetchWeatherSnapshot(lat, lon) {
  return fetchOpenWeather(lat, lon);
}

export async function getCachedWeatherForUser(userId) {
  const doc = await admin.firestore().collection('weather_cache').doc(userId).get();
  if (!doc.exists) return null;
  return normalizeWeatherCache({ id: doc.id, ...doc.data() });
}

export async function refreshWeatherForUser(userDoc, { force = false } = {}) {
  if (!userDoc?.firebaseUid || typeof userDoc.lat !== 'number' || typeof userDoc.lon !== 'number') {
    return null;
  }

  const firestore = admin.firestore();
  const cacheRef = firestore.collection('weather_cache').doc(userDoc.firebaseUid);
  const existing = force ? null : await cacheRef.get();
  const cached = existing?.exists ? existing.data() : null;
  const refreshedAt = cached?.refreshedAt?.toDate ? cached.refreshedAt.toDate() : null;
  const cacheFreshForMinutes = 15;

  if (!force && refreshedAt && ((Date.now() - refreshedAt.getTime()) / 60000) < cacheFreshForMinutes) {
    return { id: cacheRef.id, ...cached };
  }

  const payload = await fetchOpenWeather(userDoc.lat, userDoc.lon);
  const current = payload.current;
  const todayForecast = Array.isArray(payload.forecast?.daily) ? payload.forecast.daily[0] : null;

  const alertDefinitions = buildAlertDefinitions(current, todayForecast);
  const existingAlerts = await readExistingAlerts(userDoc.firebaseUid, 100);
  const alertsToCreate = alertDefinitions.filter((alert) => !hasSameDayAlertToday(existingAlerts, alert.type));

  for (const alert of alertsToCreate) {
    await firestore.collection('weather_alerts').add({
      userId: userDoc.firebaseUid,
      userName: userDoc.displayName || userDoc.name || '',
      address: userDoc.address || '',
      lat: userDoc.lat,
      lon: userDoc.lon,
      type: alert.type,
      title: alert.title,
      body: alert.body,
      source: 'weather-refresh-job',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      weatherUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  try {
    await sendWeatherAlertPushes(userDoc, alertsToCreate);
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(`[WeatherJob] Push notify failed for ${userDoc.firebaseUid}:`, error.message);
  }

  const cacheData = {
    userId: userDoc.firebaseUid,
    address: userDoc.address || '',
    lat: userDoc.lat,
    lon: userDoc.lon,
    refreshedAt: admin.firestore.FieldValue.serverTimestamp(),
    current: payload.current,
    forecast: payload.forecast,
    derived: payload.derived,
  };

  await cacheRef.set(removeUndefinedValues(cacheData), { merge: true });
  return normalizeWeatherCache({
    id: cacheRef.id,
    userId: userDoc.firebaseUid,
    address: userDoc.address || '',
    lat: userDoc.lat,
    lon: userDoc.lon,
    refreshedAt: new Date().toISOString(),
    current: payload.current,
    forecast: payload.forecast,
    derived: payload.derived,
  });
}

export async function refreshAllWeatherCaches() {
  const snapshot = await admin
    .firestore()
    .collection('users')
    .get();

  const results = [];
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (typeof data.lat !== 'number' || typeof data.lon !== 'number') continue;
    try {
      const refreshed = await refreshWeatherForUser({ id: doc.id, firebaseUid: doc.id, ...data });
      if (refreshed) results.push(refreshed);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(`[WeatherJob] Failed for ${doc.id}:`, error.message);
    }
  }
  return results;
}

export async function listUserAlerts(userId, limit = 50) {
  const snapshot = await admin
    .firestore()
    .collection('weather_alerts')
    .where('userId', '==', userId)
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get();

  return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

export function startWeatherRefreshJob({ intervalMinutes = 15 } = {}) {
  if (!env.openWeatherKey) {
    // eslint-disable-next-line no-console
    console.warn('[WeatherJob] OpenWeather key missing; background refresh disabled');
    return null;
  }

  const intervalMs = Math.max(5, intervalMinutes) * 60 * 1000;

  const run = async () => {
    try {
      await refreshAllWeatherCaches();
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('[WeatherJob] Refresh cycle failed:', error.message);
    }
  };

  run();
  const timer = setInterval(run, intervalMs);
  return timer;
}