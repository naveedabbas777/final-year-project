# Digital Kissan - Complete Project Overview

## 📋 Project Summary

**Digital Kissan** is a comprehensive agriculture-focused mobile application built with **Flutter** (frontend) and **Node.js Express** (backend). The app serves as a digital marketplace for farmers and agricultural buyers in Pakistan, with bilingual support (English/Urdu).

**Key Purpose**: Digitalize agriculture trade, provide weather forecasting, crop rate monitoring, plant disease detection, and facilitate communication between buyers and sellers.

---

## 🏗️ Architecture Overview

### High-Level Stack
```
┌─────────────────────────────────────────┐
│   Flutter Mobile App (Android/iOS)      │
│   - 27 Screens                          │
│   - Bilingual UI (EN/UR)                │
│   - Firebase Auth, Firestore            │
│   - Mapbox, Geolocator, Image Picker    │
└──────────────┬──────────────────────────┘
               │ HTTP REST (Port 5000)
               │ Firebase Bearer Token
               │
┌──────────────▼──────────────────────────┐
│   Node.js Express REST API              │
│   - 14 Route Modules                    │
│   - Firebase Admin SDK Auth             │
│   - MongoDB Database                    │
│   - Cloudinary Image Storage            │
│   - Rate Limiting & CORS                │
└──────────────┬──────────────────────────┘
               │
       ┌───────┴─────────┬─────────────────┐
       ▼                 ▼                 ▼
   MongoDB          Firebase Admin      Cloudinary
   Database         SDK (Auth Verify)    (Images)
```

---

## 📱 Frontend - Flutter Application

### Technology Stack
- **Framework**: Flutter (Dart ^3.7.2)
- **State Management**: Provider package
- **Authentication**: Firebase Auth
- **Database**: Firebase Firestore (real-time)
- **Maps**: Mapbox Maps Flutter
- **Location**: Geolocator, Geocoding
- **Notifications**: Firebase Cloud Messaging (FCM)
- **Image Handling**: Image Picker, image package
- **Localization**: intl package (English/Urdu)
- **UI**: Material Design, Google Fonts

### Project Structure

#### **Screens (27 files)**
1. **Authentication**
   - `splash_screen.dart` - App initialization
   - `login_screen.dart` - Email/password login
   - `registration_screen.dart` - User registration
   - `email_verification_screen.dart` - Email verification
   - `forgot_password_screen.dart` - Password reset

2. **Dashboard & Core**
   - `dashboard_screen.dart` - Main home screen
   - `location_screen.dart` - Location selection & weather
   - `forecast_screen.dart` - Weather forecast details
   - `detailed_forecast_screen.dart` - Extended forecast

3. **Marketplace**
   - `market_screen.dart` - Browse listings
   - `listing_detail_screen.dart` - View listing details
   - `create_listing_screen.dart` - Create new product listing
   - `my_listings_screen.dart` - Seller's product listings
   - `seller_profile_screen.dart` - View seller profile

4. **Transactions**
   - `offers_screen.dart` - Buy/sell offers
   - `orders_screen.dart` - Order tracking
   - `chat_screen.dart` - Direct messaging
   - `conversations_screen.dart` - Message list

5. **Features**
   - `plant_disease_screen.dart` - Plant disease classifier
   - `alerts_screen.dart` - Weather alerts
   - `assistant_screen.dart` - AI-powered guidance

6. **User Settings**
   - `profile_screen.dart` - User profile management
   - `settings_screen.dart` - App settings
   - `admin_dashboard_screen.dart` - Admin console

7. **Admin**
   - `admin/admin_console_shell.dart` - Admin interface

#### **Services (12 files)**
- `auth_service.dart` - Firebase authentication logic
- `api_client.dart` - HTTP client for REST API calls
- `market_api_service.dart` - Marketplace endpoints (listings, offers, orders)
- `firebase_service.dart` - Firestore operations
- `weather_service.dart` - OpenWeather API integration
- `notification_service.dart` - Local notifications
- `push_service.dart` - Push notifications (FCM)
- `alert_service.dart` - Weather alerts management
- `plant_disease_classifier.dart` - TensorFlow Lite model (commented out - requires Git)
- `assistant_service.dart` - AI assistant chat
- `admin_api_service.dart` - Admin operations
- `connectivity_service.dart` - Network connectivity checks

#### **Providers (3 files)** - State Management
- `auth_provider.dart` - Authentication state
- `language_provider.dart` - Language/localization state
- `plant_disease_provider.dart` - Plant disease classification state

#### **Models & Utils**
- `lib/models/` - Data models (DTOs, entities)
- `lib/utils/` - Utilities (validators, error handling, helpers)
- `lib/config/` - Configuration (themes, routing)
- `lib/widgets/` - Reusable UI components
- `lib/l10n/` - Localization files (EN/UR)

### Key Features

| Feature | Technology | Status |
|---------|-----------|--------|
| User Authentication | Firebase Auth | ✅ Complete |
| Email Verification | Firebase Email | ✅ Complete |
| Bilingual UI | intl + SharedPreferences | ✅ Complete |
| Marketplace (CRUD) | Express API + Firestore | ✅ Complete |
| Real-time Chat | Firestore Collections | ✅ Complete |
| Weather Forecast | OpenWeather API | ✅ Complete |
| Weather Alerts | Local Notifications | ✅ Complete |
| Location Picking | Mapbox + Geolocator | ✅ Complete |
| Image Upload | Cloudinary API | ✅ Complete |
| Plant Disease Detection | TFLite Model | ⚠️ Disabled (Git dependency) |
| Push Notifications | FCM | ✅ Complete |
| AI Assistant | Gemini API | ✅ Complete |

---

## 🔌 Backend - Node.js Express API

### Technology Stack
- **Framework**: Express.js (Node.js)
- **Authentication**: Firebase Admin SDK
- **Database**: MongoDB
- **Image Storage**: Cloudinary
- **Rate Limiting**: express-rate-limit
- **Security**: Helmet, CORS
- **AI Model**: Google Gemini API

### Project Structure

#### **Routes (14 modules)**
```
/api/
├── /health ................. Server health check
├── /config/public .......... Public config (Mapbox token)
├── /users .................. Profile management
│   ├── GET /api/users/me
│   └── PATCH /api/users/me
├── /listings ............... Marketplace listings
│   ├── GET / (search, filter)
│   ├── POST / (create)
│   └── PATCH /:id/status
├── /offers ................. Buy/Sell offers
│   ├── POST / (create)
│   └── POST /:id/accept
├── /orders ................. Order management
│   ├── GET /me
│   └── PATCH /:id/status
├── /rates .................. Crop prices
│   ├── GET /latest
│   └── POST / (admin)
├── /uploads ................ Image uploads
│   └── POST / (Cloudinary)
├── /weather ................ Weather data (external API)
├── /messages ............... Messaging system
├── /ratings ................ User ratings/reviews
├── /alerts ................. Weather alerts
├── /assistant .............. AI chat assistant
└── /admin .................. Admin operations
```

#### **Database Models (MongoDB)**
- `users` - User profiles, auth status
- `listings` - Product listings with seller info
- `offers` - Buy/sell offers between users
- `orders` - Purchase orders
- `cropRates` - Historical crop prices
- `ratings` - User ratings/reviews

#### **Key Middleware**
1. **CORS** - Origin validation for cross-origin requests
2. **Helmet** - Security headers
3. **Rate Limiting** - 120 requests/minute per IP
4. **JSON Parser** - 2MB body limit
5. **requireAuth** - Firebase token verification
6. **attachDbUser** - MongoDB user lookup
7. **Error Handler** - Structured error responses

#### **External Integrations**
- **Firebase Admin SDK** - Token verification & user lookup
- **Cloudinary** - Image upload & CDN
- **Google Gemini API** - AI assistant chat
- **OpenWeather API** - Weather data

---

## 🔐 Authentication Flow

### Registration
```
User Input (name, email, password)
    ↓
Firebase Auth (create user)
    ↓
Send verification email
    ↓
User verifies email
    ↓
Create Firestore profile doc
    ↓
Store FCM token in Firestore
```

### Login
```
User Input (email, password)
    ↓
Firebase Auth (sign in)
    ↓
Get Firebase ID token
    ↓
Backend verifies token with Firebase Admin SDK
    ↓
Return user profile from MongoDB
    ↓
App stores token locally for API calls
```

### API Authentication
```
All API requests include:
Authorization: Bearer <firebase_id_token>

Backend:
1. Verifies signature with Firebase public keys
2. Extracts uid from token
3. Looks up user in MongoDB
4. Proceeds with request or rejects
```

---

## 📊 Data Models

### User Profile
```dart
{
  uid: string (Firebase)
  name: string
  email: string
  phone?: string
  district: string
  profileImageUrl?: string
  fcmToken: string
  role: "farmer" | "buyer" | "admin"
  createdAt: timestamp
  updatedAt: timestamp
}
```

### Listing (Product)
```dart
{
  listingId: string
  sellerUid: string (Firebase)
  cropName: string
  district: string
  quantity: double
  unit: string (e.g., "40kg")
  askingPrice: double
  qualityGrade: string ("A", "B", "C")
  description: string
  imageUrls: [string] (Cloudinary)
  latitude?: double
  longitude?: double
  status: "active" | "sold" | "inactive"
  createdAt: timestamp
}
```

### Offer
```dart
{
  offerId: string
  buyerUid: string
  sellerUid: string
  listingId: string
  offeredPrice: double
  quantity: double
  status: "pending" | "accepted" | "rejected"
  createdAt: timestamp
}
```

### Order
```dart
{
  orderId: string
  buyerUid: string
  sellerUid: string
  listingId: string
  quantity: double
  totalPrice: double
  status: "pending" | "confirmed" | "shipped" | "delivered"
  createdAt: timestamp
}
```

---

## 🌍 External APIs & Integrations

| Service | Purpose | Configuration |
|---------|---------|----------------|
| **Firebase Auth** | User authentication | `google-services.json` |
| **Firebase Firestore** | Real-time user/location data | Auto-managed by Firebase |
| **Firebase Cloud Messaging** | Push notifications | Auto-configured in app |
| **OpenWeather API** | Weather forecasting | API key in backend `.env` |
| **Mapbox** | Maps, geocoding, directions | Token in `local.properties` + backend `.env` |
| **Cloudinary** | Image storage & CDN | Credentials in backend `.env` |
| **Google Gemini API** | AI assistant chat | API key in backend `.env` |

---

## ⚙️ Setup & Configuration

### Frontend Setup
```bash
# 1. Install dependencies
flutter pub get

# 2. Generate localization files
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Set Mapbox token
# Create android/local.properties:
MAPBOX_DOWNLOADS_TOKEN=pk.YOUR_TOKEN

# 4. Run on device
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:5000
```

### Backend Setup
```bash
cd backend

# 1. Install dependencies
npm install

# 2. Create .env file with:
# - GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json
# - FIREBASE_PROJECT_ID=your_project_id
# - MAPBOX_ACCESS_TOKEN=your_token
# - GEMINI_API_KEY=your_key
# - CLOUDINARY_CLOUD_NAME=your_cloud
# - CLOUDINARY_API_KEY=your_key
# - CLOUDINARY_API_SECRET=your_secret

# 3. Seed demo data
npm run seed

# 4. Start server
npm run dev
```

### Environment Variables
```env
# Backend (.env)
NODE_ENV=development
PORT=5000
MONGODB_URI=mongodb://127.0.0.1:27017/digital_kissan
FIREBASE_PROJECT_ID=your_project_id
GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json
MAPBOX_ACCESS_TOKEN=your_mapbox_token
GEMINI_API_KEY=your_gemini_key
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

---

## 🔄 Data Flow Examples

### Creating a Listing
```
1. User fills form in CreateListingScreen
2. Selects images via ImagePicker
3. Pins location using Mapbox
4. Submits form
5. Frontend uploads images to Cloudinary
6. Frontend calls POST /api/listings with image URLs
7. Backend validates & stores in MongoDB
8. Backend triggers refresh for other users
9. Listing appears in MarketScreen
```

### Sending an Offer
```
1. User views listing detail
2. Enters offer price & quantity
3. Submits offer
4. Frontend calls POST /api/offers
5. Backend stores offer in MongoDB
6. Backend sends FCM push to seller
7. Seller sees offer notification
8. Seller accepts/rejects offer
9. System creates Order or cancels Offer
```

### Weather Alerts
```
1. User sets location & alert preferences
2. Backend runs scheduled task (every hour)
3. Queries OpenWeather API for location
4. Checks if alert conditions met
5. Sends FCM push if alert triggered
6. Frontend shows AlertsScreen with notification
```

---

## 📈 Current Status & Completion

### ✅ Completed Features
- User authentication (Firebase)
- Email verification
- Bilingual UI (English/Urdu)
- Marketplace (browse, create, edit listings)
- Image upload (Cloudinary)
- Offer system (buy/sell)
- Order tracking
- Real-time chat (Firestore)
- Weather forecasting
- Weather alerts
- Location selection & mapping
- User profiles
- Admin dashboard
- AI assistant (Gemini)
- Push notifications (FCM)

### ⚠️ Partially Complete
- Plant disease classifier (TensorFlow Lite disabled - requires Git)
- User ratings/reviews system

### 🔄 In Development
- Dedicated listing creation screen with image upload
- Multi-thread messaging system
- Admin controls refinement

---

## 🚀 Running the Application

### Quick Start
```bash
# Terminal 1: Backend
cd backend
npm run dev
# Backend starts on localhost:5000

# Terminal 2: adb reverse (for USB device)
adb reverse tcp:5000 tcp:5000

# Terminal 3: Flutter
flutter run --dart-define=API_BASE_URL=http://10.192.10.221:5000
```

### Device Connection
- **USB Device**: Use `adb reverse tcp:5000 tcp:5000`
- **Android Emulator**: Use `10.0.2.2:5000`
- **Physical Device**: Use your PC's LAN IP (e.g., `192.168.x.x:5000`)

---

## 📁 Key File Locations

| Component | Location |
|-----------|----------|
| App Entry | `lib/main.dart` |
| Screens | `lib/screens/` |
| Services | `lib/services/` |
| Models | `lib/models/` |
| Localization | `lib/l10n/` |
| Backend App | `backend/src/app.js` |
| Routes | `backend/src/routes/` |
| Models | `backend/src/models/` |
| Utilities | `backend/src/utils/` |
| Config | `backend/src/config/` |

---

## 🔒 Security Notes

1. **Secrets Management**
   - ✅ Mapbox token: Secured in `android/local.properties` (gitignored)
   - ✅ Firebase credentials: In `google-services.json` and backend `.env`
   - ✅ Cloudinary/Gemini keys: In backend `.env` only

2. **Token Security**
   - Firebase ID tokens used for all API requests
   - Backend verifies tokens with Firebase Admin SDK
   - Tokens expire (refreshed automatically by Firebase)

3. **CORS & Rate Limiting**
   - ✅ CORS enabled for allowed origins only
   - ✅ Rate limiting: 120 requests/minute per IP
   - ✅ Helmet security headers enabled

4. **Database Security**
   - Firebase Firestore rules restrict access by user
   - MongoDB accessed only via Express API (not publicly exposed)

---

## 📚 Documentation Files

- `README.md` - Project setup guide
- `ARCHITECTURE_DIAGRAMS.md` - System architecture diagrams
- `PROJECT_ANALYSIS.md` - Code analysis
- `SECURITY_AND_QUALITY_IMPROVEMENTS.md` - Security checklist
- `IN_APP_GUIDANCE_SYSTEM.md` - Floating assistant documentation
- `backend/README.md` - Backend setup guide

---

## 🎯 Next Steps / Future Enhancements

1. **Enable Plant Disease Classifier** - Install Git to re-enable TensorFlow Lite
2. **Improve Ratings System** - Add user ratings and reviews with filters
3. **Advanced Search** - Add category, price range, rating filters
4. **Payment Integration** - Add payment gateway (Stripe/JazzCash)
5. **Inventory Management** - Track stock levels per listing
6. **Analytics Dashboard** - Track sales, trends, popular crops
7. **Notifications Refinement** - More granular notification preferences
8. **Performance Optimization** - Image caching, lazy loading
9. **Offline Mode** - Cache listings and data locally
10. **Mobile App Store** - Publish to Google Play and Apple App Store

---

## 👥 User Roles

| Role | Capabilities |
|------|--------------|
| **Farmer/Seller** | Create listings, receive offers, manage orders, chat with buyers |
| **Buyer** | Browse listings, send offers, place orders, track purchases |
| **Admin** | View analytics, manage rates, moderate content, system settings |

---

## 📞 Support & Debugging

### Common Issues
1. **API Connection Fails**: Check backend is running and `API_BASE_URL` is correct
2. **Images Don't Upload**: Verify Cloudinary credentials in backend `.env`
3. **Push Notifications Don't Work**: Ensure FCM token is registered
4. **Location Permission Denied**: Grant location permission in app settings
5. **Map Doesn't Load**: Verify Mapbox token in `local.properties`

### Debug Commands
```bash
# Check backend health
curl http://localhost:5000/api/health

# Check Flutter device connection
flutter devices

# View app logs
flutter logs

# View backend logs
npm run dev (already shows logs)
```

---

Generated: May 11, 2026
Project Name: Digital Kissan
Version: 1.0.0
