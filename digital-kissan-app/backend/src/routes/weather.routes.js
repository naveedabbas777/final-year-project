import { Router } from 'express';
import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { asyncHandler } from '../utils/errors.js';
import { env } from '../config/env.js';
import { refreshWeatherForUser } from '../services/weatherAlerts.service.js';

export const weatherRouter = Router();

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
    rain: current?.rain,
    snow: current?.snow,
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

// Proxy endpoint: /api/weather?lat=...&lon=...
weatherRouter.get('/', asyncHandler(async (req, res) => {
    const { lat, lon } = req.query;
    if (!lat || !lon) {
      res.status(400).json({ message: 'Missing lat or lon query parameters' });
      return;
    }

    const key = env.openWeatherKey;
    if (!key) {
      res.status(500).json({ message: 'OpenWeather API key not configured on server' });
      return;
    }

    const base = 'https://api.openweathermap.org/data/2.5';
    const currentUrl = `${base}/weather?lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lon)}&units=metric&appid=${encodeURIComponent(key)}`;
    const forecastUrl = `${base}/forecast?lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lon)}&units=metric&appid=${encodeURIComponent(key)}`;

    const [currentResp, forecastResp] = await Promise.all([fetch(currentUrl), fetch(forecastUrl)]);

    if (!currentResp.ok) {
      const text = await currentResp.text();
      res.status(currentResp.status).json({ message: 'OpenWeather current failed', detail: text });
      return;
    }
    if (!forecastResp.ok) {
      const text = await forecastResp.text();
      res.status(forecastResp.status).json({ message: 'OpenWeather forecast failed', detail: text });
      return;
    }

    const currentJson = await currentResp.json();
    const forecastJson = await forecastResp.json();

    const current = toOneCallCurrent(currentJson);
    const forecast = { daily: toDailyFromForecast(forecastJson) };

    res.json({
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
    });
}));

weatherRouter.get('/me', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
    if (!req.dbUser || typeof req.dbUser.lat !== 'number' || typeof req.dbUser.lon !== 'number') {
      res.status(400).json({ message: 'Saved location not found for user' });
      return;
    }

    const snapshot = await refreshWeatherForUser(req.dbUser, { force: true });
    if (!snapshot) {
      res.status(404).json({ message: 'Weather snapshot could not be generated' });
      return;
    }

    res.json(snapshot);
}));
