# Beginner Guide: Deploy Flutter + Node.js Backend on Render

This guide walks you through deploying your Digital Kissan app's backend on Render and building the Flutter Android app to connect to it.

## Prerequisites

1. **GitHub Account**: Push your code to a GitHub repository
2. **Render Account**: Sign up at https://render.com
3. **Firebase Project**: With Firestore enabled and service account key
4. **API Keys**: Mapbox, Grok AI, Cloudinary credentials
5. **Android Development**: Android Studio, Flutter SDK installed

## Step 1: Prepare Your Code

### 1.1 Push to GitHub
```bash
git add .
git commit -m "Ready for deployment"
git push origin main
```

### 1.2 Verify Backend Configuration
- Ensure `backend/.env.example` is updated (no MONGO_URI needed)
- Confirm `render.yaml` exists in root directory
- Check that `backend/package.json` has correct scripts

## Step 2: Deploy Backend on Render

### 2.1 Create Render Web Service
1. Go to https://dashboard.render.com
2. Click "New" → "Web Service"
3. Connect your GitHub repository
4. Configure service:
   - **Name**: `digital-kissan-backend`
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Root Directory**: `backend`

### 2.2 Set Environment Variables
In Render dashboard, add these environment variables:

**Required:**
- `FIREBASE_PROJECT_ID`: Your Firebase project ID
- `FIREBASE_SERVICE_ACCOUNT_JSON`: The entire JSON content of your Firebase service account key
- `MAPBOX_ACCESS_TOKEN`: Your Mapbox access token
- `GROK_API_KEY`: Your Grok AI API key
- `CLOUDINARY_CLOUD_NAME`: Your Cloudinary cloud name
- `CLOUDINARY_API_KEY`: Your Cloudinary API key
- `CLOUDINARY_API_SECRET`: Your Cloudinary API secret

**Optional:**
- `OPENWEATHER_KEY`: For weather features
- `OPENAI_API_KEY`: Fallback AI provider

### 2.3 Deploy
1. Click "Create Web Service"
2. Wait for deployment (usually 5-10 minutes)
3. Note the service URL (e.g., `https://digital-kissan-backend.onrender.com`)

## Step 3: Test Deployed Backend

### 3.1 Health Check
Open browser and visit: `https://your-service-url.onrender.com/api/health`

You should see a JSON response like:
```json
{
  "message": "Digital Kissan Backend API",
  "version": "1.0.0",
  "status": "running"
}
```

### 3.2 Test with Flutter (Local Development)
Update your Flutter app to use the deployed backend:

```bash
flutter run --dart-define=API_BASE_URL=https://your-service-url.onrender.com
```

## Step 4: Build Flutter Android APK

### 4.1 Prepare Android Build
1. Ensure Android SDK is installed
2. Check Flutter doctor:
   ```bash
   flutter doctor
   ```

### 4.2 Configure Android Secrets
1. Copy `android/local.properties.example` to `android/local.properties`
2. Add your Mapbox downloads token:
   ```
   MAPBOX_DOWNLOADS_TOKEN=pk.your_mapbox_downloads_token_here
   ```

### 4.3 Build APK
```bash
# For debug APK
flutter build apk --dart-define=API_BASE_URL=https://your-service-url.onrender.com

# For release APK
flutter build apk --release --dart-define=API_BASE_URL=https://your-service-url.onrender.com
```

### 4.4 Find APK
- Debug: `build/app/outputs/flutter-apk/app-debug.apk`
- Release: `build/app/outputs/flutter-apk/app-release.apk`

## Step 5: Install and Test

### 5.1 Install APK on Android Device
1. Transfer APK to your Android device
2. Enable "Install from unknown sources" in settings
3. Install the APK

### 5.2 Test the App
1. Open the app
2. Try logging in (Firebase Auth)
3. Check if data loads from deployed backend
4. Test features like listings, chat, etc.

## Troubleshooting

### Backend Issues
- **Service won't start**: Check environment variables in Render logs
- **Firebase errors**: Verify `FIREBASE_SERVICE_ACCOUNT_JSON` is valid JSON
- **Port issues**: Render handles PORT automatically

### Flutter Issues
- **Build fails**: Run `flutter clean` then rebuild
- **Network errors**: Ensure API_BASE_URL is correct
- **Mapbox issues**: Check downloads token in `android/local.properties`

### Common Render Tips
- Free tier has 750 hours/month, then sleeps after inactivity
- Logs are available in Render dashboard
- Environment variables are encrypted and secure

## Next Steps

1. **Domain**: Add custom domain in Render
2. **SSL**: Render provides free SSL certificates
3. **Monitoring**: Set up uptime monitoring
4. **Scaling**: Upgrade plan for more resources
5. **CI/CD**: Push updates automatically deploy

## Cost Estimate

- **Render Free Tier**: $0 (750 hours/month)
- **Firebase**: Free tier covers most usage
- **Mapbox**: Free tier available
- **Grok AI**: Check x.ai pricing
- **Cloudinary**: Free tier available

Your app is now deployed and ready for users!