# Backend Setup Guide

## Status
- ✅ Node.js Backend: Running on `http://localhost:5000`  
- ✅ App Connected: Updated to use `http://10.224.247.221:5000`
- ❌ MongoDB: **NOT installed** - Database connection will fail

## MongoDB Setup Options

### Option 1: MongoDB Atlas (Cloud) - RECOMMENDED ⭐
Fastest for testing without local installation.

1. Go to https://www.mongodb.com/cloud/atlas
2. Create a free account and cluster
3. Get your connection string (looks like: `mongodb+srv://username:password@cluster.mongodb.net/digital_kissan?retryWrites=true&w=majority`)
4. Update `.env`:
   ```
   MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/digital_kissan?retryWrites=true&w=majority
   ```
5. Restart backend: `npm start`

### Option 2: Install MongoDB Locally

#### Windows - Direct Installation
1. Download from https://www.mongodb.com/try/download/community
2. Install MongoDB Community Edition
3. Start MongoDB:
   ```powershell
   mongod
   ```
4. Backend will auto-connect to `mongodb://127.0.0.1:27017/digital_kissan`

#### Windows - Docker
If you have Docker installed:
```powershell
docker run -d -p 27017:27017 --name mongodb mongo:latest
```

### Option 3: Test Without Database (Mock Data)
For quick testing without setting up MongoDB:

Edit `backend/src/config/db.js` to add mock data support (advanced)

## Current Backend Endpoints

Once MongoDB is set up, these endpoints will work:

- `GET /api/rates/latest` - Fetch crop rates
- `GET /api/listings` - Fetch marketplace listings  
- `GET /api/users/me` - Get user profile (requires Firebase auth token)
- `POST /api/listings` - Create listing
- `POST /api/offers` - Make offer
- etc.

## Verify Backend Connection

From your Flutter app, check the debug console for:
```
[ApiClient] GET http://10.224.247.221:5000/api/rates/latest (auth=false)
```

If you see connection errors, it's likely MongoDB not responding.

## Application Status

**App Configuration:**
- Backend URL: `http://10.224.247.221:5000`
- Device: Connected (RZCWA12SKKV)
- Auth: Working (registration/login functional)
- Marketplace: Will work once MongoDB is set up

## Next Steps

1. ⭐ **Quick Start**: Use MongoDB Atlas cloud option
2. Build and test marketplace features
3. The app will show marketplace data once database is connected

## Help

If marketplace tab still shows errors after MongoDB setup:
- Check `[ApiClient]` and `[MarketApi]` debug logs in Flutter console
- Verify backend is still running: `http://10.224.247.221:5000`
- Check `.env` file has correct MONGO_URI
