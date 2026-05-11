# Digital Kissan Backend (REST + MongoDB)

This backend uses:
- Firebase Auth token verification (authentication only)
- Express REST API
- MongoDB for all app domain data (rates, listings, offers, orders)

## 1) Setup

1. Copy environment file:
   - `cp .env.example .env` (or create `.env` manually on Windows)
2. Add Firebase service account credentials path in `.env`:
   - `GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json`
   - Or for hosted deployments, set `FIREBASE_SERVICE_ACCOUNT_JSON` to the service account JSON object.
3. Ensure MongoDB is running locally:
   - `mongodb://127.0.0.1:27017/digital_kissan`
4. Add the Mapbox access token in `.env` so the Flutter app can load it from the backend:
   - `MAPBOX_ACCESS_TOKEN=your_mapbox_access_token`
5. Add a Grok API key for the AI assistant:
   - Get your key from https://console.x.ai
   - `GROK_API_KEY=sk_your_grok_api_key`
   - `GROK_MODEL=grok-4.3` (optional override)
   - `GROK_MAX_TOKENS=2048` (optional, default: 2048)
6. Add Cloudinary credentials to `.env` for server-side image uploads:
   - `CLOUDINARY_CLOUD_NAME=your_cloud_name`
   - `CLOUDINARY_API_KEY=your_api_key`
   - `CLOUDINARY_API_SECRET=your_api_secret`

## 2) Run

```bash
npm install
npm run dev
```

If you are not using git workflows, these are the practical next commands:

```bash
# 1) install deps once
npm install

# 2) seed demo data so rates/listings show in app immediately
npm run seed

# 3) run API
npm run start
```

### Hosted deployment guidance

When deploying on Render or any secret-managed host, avoid committing `serviceAccountKey.json`.
Use the `FIREBASE_SERVICE_ACCOUNT_JSON` environment variable to provide the Firebase service account JSON directly.

Required runtime environment variables for hosting:
- `PORT` (Render provides this automatically; the app already reads `process.env.PORT`)
- `MONGO_URI`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_SERVICE_ACCOUNT_JSON` or `GOOGLE_APPLICATION_CREDENTIALS`
- `MAPBOX_ACCESS_TOKEN`
- `GROK_API_KEY`
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

Optional variables:
- `OPENWEATHER_KEY`
- `OPENAI_API_KEY`
- `OPENAI_MODEL`
- `OPENAI_MAX_TOKENS`

API base URL:
- `http://localhost:5000`

Health check:
- `GET /api/health`

## 3) Auth model

Client sends Firebase ID token in Authorization header:
- `Authorization: Bearer <firebase_id_token>`

Backend verifies token using Firebase Admin SDK.

## 4) Routes

- `GET /api/health`
- `GET /api/users/me` (auth)
- `PATCH /api/users/me` (auth)
- `GET /api/rates/latest`
- `GET /api/config/public`
- `POST /api/rates` (auth + admin)
- `POST /api/rates/ingest/official` (auth + admin, placeholder)
- `GET /api/listings`
- `POST /api/listings` (auth)
- `PATCH /api/listings/:id/status` (auth)
- `POST /api/offers` (auth)
- `POST /api/offers/:id/accept` (auth)
- `GET /api/orders/me` (auth)
- `PATCH /api/orders/:id/status` (auth)
- `POST /api/assistant/chat` (auth)

## 5) Flutter connection

Run Flutter with backend URL:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.X.X:5000
```

Use LAN IP for physical devices.
Use `10.0.2.2` for Android emulator.

The app loads the Mapbox access token from `GET /api/config/public` at startup, so keep `MAPBOX_ACCESS_TOKEN` in the backend environment instead of Flutter source.

For this machine currently, your detected LAN IP is `10.192.10.221`, so for a physical phone use:

```bash
flutter run --dart-define=API_BASE_URL=http://10.192.10.221:5000
```
