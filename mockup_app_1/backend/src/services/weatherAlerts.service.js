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
  if (userData?.notificationsEnabled === false) return;
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

    const resp = await admin.messaging().sendEachForMulticast({ tokens, ...payload });
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

function buildLocationLabel(userDoc) {
  return userDoc?.address || userDoc?.locationSummary || userDoc?.district || userDoc?.name || 'your location';
}

function getRainNext3hThreshold() {
  const raw = Number(env.weatherRainNext3hThreshold);
  if (!Number.isFinite(raw)) return 0.6;
  return Math.min(1, Math.max(0, raw));
}

function pad2(value) {
  return String(value).padStart(2, '0');
}

function getThreeHourWindowKey(date = new Date()) {
  const startHour = Math.floor(date.getHours() / 3) * 3;
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}-${pad2(startHour)}`;
}

function isThreeHourSummaryWindow(date = new Date()) {
  return date.getMinutes() <= 20;
}

function isMorningSummaryWindow(sunriseEpochSeconds) {
  if (typeof sunriseEpochSeconds !== 'number') return false;
  const now = Date.now();
  const morningStart = (sunriseEpochSeconds + 3600) * 1000;
  const morningEnd = (sunriseEpochSeconds + (6 * 3600)) * 1000;
  return now >= morningStart && now <= morningEnd;
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
    visibility: current?.visibility ?? null,
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

function buildAlertDefinitions(userDoc, current, todayForecast) {
  const alerts = [];

  // `current` is the output of toOneCallCurrent() which uses `temp` and `wind_speed`.
  // Precipitation is extracted from the raw rain/snow sub-objects on `current`.
  const temp = typeof current?.temp === 'number' ? current.temp : null;
  const windSpeed = typeof current?.wind_speed === 'number' ? current.wind_speed : 0;
  const sunrise = typeof current?.sunrise === 'number' ? current.sunrise : null;
  const visibility = typeof current?.visibility === 'number' ? current.visibility : null;
  const precip = extractPrecip(current); // reads rain['1h'] or snow['1h']
  const rainChance = typeof todayForecast?.pop === 'number' ? todayForecast.pop : 0;
  const weatherMain = Array.isArray(current?.weather) && current.weather.length > 0
    ? String(current.weather[0]?.main || '').toLowerCase()
    : '';
  const locationLabel = buildLocationLabel(userDoc);

  if (isThreeHourSummaryWindow()) {
    const slotKey = getThreeHourWindowKey();
    const rainAlertThreshold = getRainNext3hThreshold();
    const hourlyItems = Array.isArray(todayForecast?.hourly) ? todayForecast.hourly : [];
    const slotStart = new Date();
    slotStart.setMinutes(0, 0, 0);
    slotStart.setHours(Math.floor(slotStart.getHours() / 3) * 3);
    const slotEnd = new Date(slotStart.getTime() + (3 * 60 * 60 * 1000));

    const windowItems = hourlyItems.filter((item) => {
      const dt = typeof item?.dt === 'number' ? item.dt * 1000 : null;
      return dt != null && dt >= slotStart.getTime() && dt < slotEnd.getTime();
    });

    const temps = windowItems
      .map((item) => item?.main?.temp)
      .filter((value) => typeof value === 'number');
    const windValues = windowItems
      .map((item) => item?.wind?.speed)
      .filter((value) => typeof value === 'number');
    const rainValues = windowItems
      .map((item) => extractPrecip({ rain: item?.rain, snow: item?.snow }))
      .filter((value) => typeof value === 'number');
    const visibilityValues = windowItems
      .map((item) => item?.visibility)
      .filter((value) => typeof value === 'number');
    const humidityValues = windowItems
      .map((item) => item?.main?.humidity)
      .filter((value) => typeof value === 'number');
    const cloudValues = windowItems
      .map((item) => item?.clouds?.all)
      .filter((value) => typeof value === 'number');
    const popValues = windowItems
      .map((item) => item?.pop)
      .filter((value) => typeof value === 'number');

    const summaryTempMin = temps.length > 0 ? Math.min(...temps) : temp;
    const summaryTempMax = temps.length > 0 ? Math.max(...temps) : temp;
    const summaryWindMax = windValues.length > 0 ? Math.max(...windValues) : windSpeed;
    const summaryRainMax = rainValues.length > 0 ? Math.max(...rainValues) : precip;
    const summaryVisibilityMin = visibilityValues.length > 0 ? Math.min(...visibilityValues) : visibility;
    const summaryHumidity = humidityValues.length > 0
      ? humidityValues.reduce((a, b) => a + b, 0) / humidityValues.length
      : (typeof current?.humidity === 'number' ? current.humidity : null);
    const summaryCloudCover = cloudValues.length > 0
      ? cloudValues.reduce((a, b) => a + b, 0) / cloudValues.length
      : (typeof current?.clouds === 'number' ? current.clouds : null);
    const slotRainChance = popValues.length > 0 ? Math.max(...popValues) : rainChance;
    const sunriseLabel = formatTime(current?.sunrise);
    const sunsetLabel = formatTime(current?.sunset);

    alerts.push({
      type: 'forecast_summary_3h',
      slotKey,
      title: `🌤 ${locationLabel} next 3-hour forecast`,
      body: `Summary for ${locationLabel}: temperature ${summaryTempMin != null && summaryTempMax != null ? `${summaryTempMin.toFixed(1)}°C to ${summaryTempMax.toFixed(1)}°C` : 'unavailable'}, rain chance ${Math.round(slotRainChance * 100)}%, precipitation ${summaryRainMax.toFixed(1)} mm, humidity ${summaryHumidity != null ? `${Math.round(summaryHumidity)}%` : 'unavailable'}, cloud cover ${summaryCloudCover != null ? `${Math.round(summaryCloudCover)}%` : 'unavailable'}, wind up to ${summaryWindMax.toFixed(1)} m/s${summaryVisibilityMin != null ? `, visibility around ${Math.round(summaryVisibilityMin)} m` : ''}${sunriseLabel ? `, sunrise ${sunriseLabel}` : ''}${sunsetLabel ? `, sunset ${sunsetLabel}` : ''}.`,
    });

    if (slotRainChance >= rainAlertThreshold) {
      alerts.push({
        type: 'rain_next_3h',
        slotKey,
        title: `🌧 Rain likely in next 3 hours (${locationLabel})`,
        body: `Rain probability for the next 3 hours is ${Math.round(slotRainChance * 100)}% with expected precipitation up to ${summaryRainMax.toFixed(1)} mm. Plan field work accordingly.`,
      });
    }
  }

  if (isMorningSummaryWindow(sunrise)) {
    alerts.push({
      type: 'morning_weather',
      title: `🌅 Morning weather for ${locationLabel}`,
      body: `At ${locationLabel}, rain chance is ${Math.round(rainChance * 100)}% with expected precipitation of ${precip.toFixed(1)} mm. Current temperature is ${temp !== null ? `${temp.toFixed(1)}°C` : 'unavailable'}.`,
    });
  }

  const rainLikely = rainChance >= 0.5 || precip > 0.1 || weatherMain === 'rain' || weatherMain === 'drizzle';
  const stormy = weatherMain === 'thunderstorm' || weatherMain === 'tornado';
  const snowy = weatherMain === 'snow' || Boolean(current?.snow);
  const lowVisibility = visibility !== null && visibility <= 5000;
  const hot = temp !== null && temp >= 35;
  const cold = temp !== null && temp <= 5;
  const windy = windSpeed >= 10;
  const harshNow =
    stormy ||
    snowy ||
    lowVisibility ||
    weatherMain === 'rain' ||
    precip >= 5 ||
    windSpeed >= 15 ||
    temp !== null && (temp >= 42 || temp <= 2);

  if (harshNow) {
    const parts = [];
    if (stormy) parts.push('storm');
    if (snowy) parts.push('snow');
    if (lowVisibility) parts.push(`visibility ${Math.round(visibility / 1000)} km`);
    if (weatherMain && !stormy && !snowy) parts.push(weatherMain);
    if (precip >= 5) parts.push(`precipitation ${precip.toFixed(1)} mm`);
    if (windSpeed >= 15) parts.push(`wind ${windSpeed.toFixed(1)} m/s`);
    if (temp !== null && temp >= 42) parts.push(`heat ${temp.toFixed(1)}°C`);
    if (temp !== null && temp <= 2) parts.push(`cold ${temp.toFixed(1)}°C`);

    alerts.push({
      type: 'severe_weather',
      title: '⛈ Harsh weather alert',
      body: `Harsh weather conditions are active right now: ${parts.join(', ')}. Protect crops, workers, and equipment immediately.`,
    });
  }

  if (stormy) {
    alerts.push({
      type: 'storm',
      title: '⛈ Storm alert',
      body: 'Storm conditions are active right now. Move equipment under cover and avoid field work until it clears.',
    });
  }

  if (lowVisibility) {
    alerts.push({
      type: 'visibility',
      title: '🌫 Low visibility alert',
      body: `Visibility is low${visibility != null ? ` (${Math.round(visibility)} m)` : ''}. Limit travel and field movement until conditions improve.`,
    });
  }

  if (snowy) {
    alerts.push({
      type: 'snow',
      title: '❄ Snow alert',
      body: 'Snow or freezing precipitation is active now. Protect seedlings, irrigation lines, and exposed crops.',
    });
  }

  if (rainLikely) {
    alerts.push({
      type: 'rain',
      title: '🌧 Rain expected near your fields',
      body: `Chance of rain around ${Math.round(rainChance * 100)}%. Secure equipment and delay spraying.`,
    });
  }

  if (hot) {
    alerts.push({
      type: 'heat',
      title: '🌡 High heat alert',
      body: `Temperatures above ${temp.toFixed(1)}°C expected. Increase irrigation if needed.`,
    });
  }

  if (cold) {
    alerts.push({
      type: 'cold',
      title: '❄ Low temperature alert',
      body: `Temps near ${temp.toFixed(1)}°C. Protect sensitive crops from frost.`,
    });
  }

  if (windy) {
    alerts.push({
      type: 'wind',
      title: '💨 Windy conditions',
      body: `Wind at ${windSpeed.toFixed(1)} m/s. Avoid spraying pesticides or fertilisers.`,
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

function hasSameSlotAlertToday(alerts, type, slotKey) {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return alerts.some((alert) => {
    if (alert.type !== type || alert.slotKey !== slotKey) return false;
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

  const alertDefinitions = buildAlertDefinitions(userDoc, current, todayForecast);
  const existingAlerts = await readExistingAlerts(userDoc.firebaseUid, 100);
  const alertsToCreate = alertDefinitions.filter((alert) => {
    if (alert.slotKey) {
      return !hasSameSlotAlertToday(existingAlerts, alert.type, alert.slotKey);
    }
    return !hasSameDayAlertToday(existingAlerts, alert.type);
  });

  for (const alert of alertsToCreate) {
    await firestore.collection('weather_alerts').add({
      userId: userDoc.firebaseUid,
      userName: userDoc.displayName || userDoc.name || '',
      address: userDoc.address || '',
      lat: userDoc.lat,
      lon: userDoc.lon,
      type: alert.type,
      slotKey: alert.slotKey || null,
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

  const eligibleUsers = snapshot.docs
    .map((doc) => ({ id: doc.id, firebaseUid: doc.id, ...doc.data() }))
    .filter((data) => typeof data.lat === 'number' && typeof data.lon === 'number');

  const results = [];
  const BATCH_SIZE = 5;

  for (let i = 0; i < eligibleUsers.length; i += BATCH_SIZE) {
    const batch = eligibleUsers.slice(i, i + BATCH_SIZE);
    const settled = await Promise.allSettled(
      batch.map((user) => refreshWeatherForUser(user))
    );

    for (const result of settled) {
      if (result.status === 'fulfilled' && result.value) {
        results.push(result.value);
      } else if (result.status === 'rejected') {
        // eslint-disable-next-line no-console
        console.error(`[WeatherJob] Batch refresh failed:`, result.reason?.message);
      }
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