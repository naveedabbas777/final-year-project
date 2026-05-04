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
3. Ensure MongoDB is running locally:
   - `mongodb://127.0.0.1:27017/digital_kissan`

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
- `POST /api/rates` (auth + admin)
- `POST /api/rates/ingest/official` (auth + admin, placeholder)
- `GET /api/listings`
- `POST /api/listings` (auth)
- `PATCH /api/listings/:id/status` (auth)
- `POST /api/offers` (auth)
- `POST /api/offers/:id/accept` (auth)
- `GET /api/orders/me` (auth)
- `PATCH /api/orders/:id/status` (auth)

## 5) Flutter connection

Run Flutter with backend URL:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.X.X:5000
```

Use LAN IP for physical devices.
Use `10.0.2.2` for Android emulator.

For this machine currently, your detected LAN IP is `10.192.10.221`, so for a physical phone use:

```bash
flutter run --dart-define=API_BASE_URL=http://10.192.10.221:5000
```
