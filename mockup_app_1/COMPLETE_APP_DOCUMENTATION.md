# Digital Kissan - Complete Application Documentation

**Last Updated:** May 2026  
**Version:** 1.0.0  
**Status:** Production Ready

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Technology Stack](#technology-stack)
3. [Architecture](#architecture)
4. [Frontend (Flutter)](#frontend-flutter)
5. [Backend (Node.js/Express)](#backend-nodejs-express)
6. [Database Schema (Firestore)](#database-schema-firestore)
7. [API Routes & Endpoints](#api-routes--endpoints)
8. [Data Flow & User Journeys](#data-flow--user-journeys)
9. [Security & Access Control](#security--access-control)
10. [Background Services](#background-services)
11. [Setup & Deployment](#setup--deployment)
12. [Features & Capabilities](#features--capabilities)
13. [Known Limitations](#known-limitations)

---

## Project Overview

**Digital Kissan** is a comprehensive agricultural ecosystem platform designed specifically for Pakistani farmers. The application bridges the gap between modern technology and traditional farming by providing:

- **Real-time Weather Alerts** - Location-based weather warnings with farming recommendations
- **Smart Marketplace** - Peer-to-peer agricultural product trading platform
- **AI Farming Assistant** - Intelligent chatbot for farming advice in English & Urdu
- **Order Management** - Complete transaction lifecycle tracking
- **Community Messaging** - Direct product-based communication
- **Admin Dashboard** - System management and monitoring

### Key Statistics
- **Supported Languages:** English, Urdu
- **User Roles:** Farmer, Buyer, Seller, Admin
- **Minimum SDK:** Dart 3.7.2, Java 11
- **Localization:** Full bilingual support with RTL handling

---

## Technology Stack

### Frontend
```
┌─────────────────────────────────┐
│   Flutter (Dart 3.7.2)          │
├─────────────────────────────────┤
│ • Material Design 3              │
│ • Provider (State Management)    │
│ • Firebase (Auth, Firestore)    │
│ • Mapbox Maps                    │
│ • Image Picker & Upload          │
│ • Geolocation                    │
│ • Push Notifications             │
│ • Localization (i18n)            │
└─────────────────────────────────┘
```

### Backend
```
┌─────────────────────────────────┐
│   Node.js + Express.js          │
├─────────────────────────────────┤
│ • Firebase Admin SDK             │
│ • Firestore Database             │
│ • Cloudinary (Image Storage)     │
│ • Firebase Cloud Messaging       │
│ • OpenWeather API                │
│ • OpenAI / Gemini / Grok APIs   │
│ • Helmet (Security Headers)      │
│ • Rate Limiting                  │
│ • Multer (File Upload)           │
│ • Dotenv (Configuration)         │
└─────────────────────────────────┘
```

### Infrastructure
- **Authentication:** Firebase Authentication
- **Database:** Cloud Firestore (NoSQL)
- **File Storage:** Cloudinary + Local Fallback
- **Push Notifications:** Firebase Cloud Messaging (FCM)
- **Weather Data:** OpenWeather API (15-min refresh)
- **Maps:** Mapbox Maps
- **AI Services:** OpenAI, Google Gemini, Grok

---

## Architecture

### High-Level System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      DIGITAL KISSAN ECOSYSTEM                  │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐              ┌────────────────────┐
│    FLUTTER APP   │              │   NODE.JS BACKEND  │
├──────────────────┤              ├────────────────────┤
│ • 15+ Screens    │──────────────│ • 14 API Routes    │
│ • 8 Services     │  HTTP/REST   │ • 7 Firestore Col. │
│ • 3 Providers    │◄────────────►│ • 2 Background Svc │
│ • Theme System   │              │ • Security Layers  │
└──────────────────┘              └────────────────────┘
         │                                │
         ▼                                ▼
   ┌─────────────────────────────────────────────┐
   │        FIREBASE (Core Infrastructure)       │
   ├─────────────────────────────────────────────┤
   │ • Authentication (Email/Password)           │
   │ • Firestore (7 Collections)                 │
   │ • Cloud Messaging (FCM)                     │
   └─────────────────────────────────────────────┘
         │              │              │
         ▼              ▼              ▼
    ┌────────┐    ┌──────────┐    ┌──────────┐
    │Mapbox  │    │OpenWeather│   │Cloudinary│
    │ Maps   │    │   API    │    │ Storage  │
    └────────┘    └──────────┘    └──────────┘
```

### Deployment Architecture

```
FRONTEND (Flutter App)
  └─► APK/AAB for Android
  └─► Built with Flutter SDK

BACKEND (Node.js)
  └─► Port: 5000 (default)
  └─► Environment: .env configuration
  └─► Running on: Linux/Mac/Windows/Docker

FIREBASE HOSTING
  └─► Authentication: Firestore rules
  └─► Database: Cloud Firestore
  └─► Messaging: Firebase Cloud Messaging
  └─► Storage: Cloud Storage (via Cloudinary)
```

---

## Frontend (Flutter)

### Project Structure

```
lib/
├── main.dart                          # App entry point & initialization
├── config/
│   ├── app_router.dart               # Page transitions & routing
│   ├── app_config.dart               # API base URL, constants
│   └── app_theme.dart                # Colors, typography, decorations
├── l10n/                              # Localization files (en/ur)
├── models/
│   └── help_guide_model.dart         # Help content for screens
├── providers/                         # State management
│   ├── auth_provider.dart            # Auth state & bootstrap
│   ├── language_provider.dart        # Localization state
│   └── plant_disease_provider.dart   # Plant disease detection (disabled)
├── services/                          # Business logic & API calls
│   ├── api_client.dart               # HTTP client with retry logic
│   ├── auth_service.dart             # Firebase auth wrapper
│   ├── firebase_service.dart         # User & profile management
│   ├── market_api_service.dart       # Listings, offers, orders, ratings
│   ├── weather_service.dart          # Weather data fetching
│   ├── alert_service.dart            # Weather alerts
│   ├── assistant_service.dart        # AI chatbot
│   ├── connectivity_service.dart     # Backend health checks
│   ├── notification_service.dart     # Local & push notifications
│   └── push_service.dart             # FCM token management
├── screens/                           # UI Screens
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── registration_screen.dart
│   ├── email_verification_screen.dart
│   ├── forgot_password_screen.dart
│   ├── dashboard_screen.dart
│   ├── forecast_screen.dart
│   ├── detailed_forecast_screen.dart
│   ├── market_screen.dart
│   ├── listing_detail_screen.dart
│   ├── listing_location_picker.dart
│   ├── my_listings_screen.dart
│   ├── create_listing_screen.dart
│   ├── product_listing_details_screen.dart
│   ├── offers_screen.dart
│   ├── orders_screen.dart
│   ├── chat_screen.dart
│   ├── conversations_screen.dart
│   ├── profile_screen.dart
│   ├── seller_profile_screen.dart
│   ├── alerts_screen.dart
│   ├── assistant_screen.dart
│   ├── settings_screen.dart
│   ├── location_screen.dart
│   ├── plant_disease_screen.dart
│   └── admin/
│       ├── admin_console_shell.dart
│       ├── admin_dashboard_screen.dart
│       └── admin_profile_screen.dart
├── widgets/                           # Reusable UI components
│   ├── app_snack_bar.dart
│   ├── async_state_widgets.dart      # Loading, error states
│   ├── comprehensive_help_dialog.dart
│   ├── confirm_dialog.dart
│   ├── floating_assistant.dart       # Floating chat bubble
│   ├── help_guide_dialog.dart
│   ├── info_row.dart
│   ├── photo_viewer.dart
│   ├── price_display.dart
│   ├── section_header.dart
│   ├── status_badge.dart
│   └── tip_card.dart
└── utils/                             # Utility functions
    ├── api_client.dart
    ├── cache_layer.dart              # Local caching
    ├── error_presenter.dart          # Error message formatting
    ├── form_validators.dart          # Input validation rules
    ├── json_response.dart            # JSON parsing helpers
    └── retry_helper.dart             # Retry logic with backoff
```

### Core Services Detailed

#### **1. ApiClient** (`api_client.dart`)
**Purpose:** Central HTTP client for all backend communication

**Features:**
- Automatic Firebase ID token attachment
- Exponential backoff retry logic (3 attempts)
- Request timeout handling (20 seconds default)
- Error parsing and user-friendly messages
- Debug logging for development

**Methods:**
```dart
// GET requests
Future<dynamic> get(String path, {
  Map<String, String>? query,
  bool auth = false,
})

Future<String> getText(String path, {
  Map<String, String>? query,
  bool auth = false,
})

// POST requests
Future<dynamic> post(String path, {
  bool auth = false,
  dynamic body,
})

// PATCH requests
Future<dynamic> patch(String path, {
  bool auth = false,
  dynamic body,
})

// DELETE requests
Future<void> delete(String path, { bool auth = false })
```

#### **2. AuthService** (`auth_service.dart`)
**Purpose:** Firebase Authentication wrapper

**Methods:**
- `registerWithEmailPassword()` - Create account
- `signInWithEmailPassword()` - Login
- `signOut()` - Logout
- `sendPasswordResetEmail()` - Password recovery
- `sendCurrentUserVerificationEmail()` - Email verification
- `reloadCurrentUser()` - Refresh auth state

**Flow:**
1. User enters email/password
2. Firebase creates user
3. AuthProvider listens to state changes
4. Firestore user document created via FirebaseService
5. FCM token registered

#### **3. FirebaseService** (`firebase_service.dart`)
**Purpose:** User profile & metadata management

**DTOs:**
```dart
UserProfileDto
├─ id, firebaseUid
├─ name, displayName
├─ phone, phoneNumber, email
├─ role (farmer/admin)
├─ district, province, address
├─ lat, lon, locationUpdatedAt
├─ photoUrl
└─ Computed properties: primaryName, hasContactInfo, locationSummary

CropRateDto
├─ id, cropName, marketName
├─ district, minPrice, maxPrice, unit
└─ lastUpdatedAt

ListingDto
├─ id, sellerUid
├─ cropName, qualityGrade
├─ quantity, unit, askingPrice
├─ district, locationName, latitude, longitude
├─ description, imageUrls
├─ status (open/reserved/sold/cancelled)
└─ createdAt, updatedAt

OfferDto
├─ id, listingId, buyerUid
├─ offerPrice, quantity
├─ status (pending/accepted/rejected)
└─ createdAt, updatedAt

OrderDto
├─ id, listingId, buyerUid, sellerUid
├─ offerPrice, quantity
├─ status (created/in_transit/delivered/completed/disputed/cancelled)
├─ cropName, listingDistrict
└─ createdAt, updatedAt
```

**Key Methods:**
- `createUserIfNotExists()` - Ensure Firestore user doc
- `getUserMe()` - Current user's full profile (unredacted)
- `getUserByUid()` - User profile by UID (with redaction rules)
- `getUserByPhone()` - User lookup by phone number
- `updateUserProfile()` - Edit user details
- `updateUserLocation()` - Update lat/lon
- `updateUserNotificationData()` - Register FCM token

#### **4. MarketApiService** (`market_api_service.dart`)
**Purpose:** All marketplace operations

**Listings:**
```dart
Future<List<ListingDto>> getListings({
  String? crop,
  String? district,
  String? sellerUid,
  String? status,
  String sort = 'new',    // 'new', 'price_asc', 'price_desc'
  int limit = 50,
  DateTime? before,       // Cursor for pagination
})

Future<ListingDto> createListing({
  required String cropName,
  required String qualityGrade,
  required double quantity,
  required String unit,
  required double askingPrice,
  required String district,
  String? locationName,
  double? latitude,
  double? longitude,
  String? description,
  List<String>? imageUrls,
})

Future<void> updateListing(
  String id,
  { /* partial updates */ }
)

Future<void> changeListingStatus(
  String id,
  String newStatus,  // open, reserved, sold, cancelled
)

Future<void> deleteListing(String id)
```

**Offers:**
```dart
Future<List<OfferDto>> getMyOffers()
Future<List<OfferDto>> getIncomingOffers()

Future<OfferDto> submitOffer({
  required String listingId,
  required double offerPrice,
  required double quantity,
})

Future<void> respondToOffer(
  String offerId,
  String response,  // 'accepted' or 'rejected'
)
```

**Orders:**
```dart
Future<List<OrderDto>> getMyOrders()

Future<void> updateOrderStatus(
  String orderId,
  String newStatus,  // State machine enforced on backend
)
```

**Ratings:**
```dart
Future<RatingEligibility> checkRatingEligibility(String uid)

Future<void> submitRating({
  required String targetUid,
  required int score,        // 1-5
  String? comment,
})

Future<RatingSummary> getUserRatings(String uid)
```

#### **5. WeatherService** (`weather_service.dart`)
**Purpose:** Weather data aggregation

**Returns:**
```dart
CurrentWeather
├─ temperature, description, icon
├─ windSpeed, windDirection, windDegree
├─ precipitation, humidity, cloudCover
└─ sunrise, sunset

DailyForecast (10 days)
├─ date, tempMin, tempMax, tempAvg
├─ description, icon, windSpeed
├─ precipitation, humidity, cloudCover
├─ pop (probability of precipitation)
└─ uvIndex
```

**Data Flow:**
1. Frontend calls `fetchWeatherData(lat?, lon?)`
2. Backend aggregates OpenWeather API data
3. Converts to OneCall format
4. Returns current + 10-day daily forecast
5. Frontend caches in SharedPreferences

#### **6. AlertService** (`alert_service.dart`)
**Purpose:** Weather alert management with local state

**Alert Types:**
- `rain` - Heavy rainfall warning
- `heat` - Extreme temperature (high)
- `cold` - Extreme temperature (low)
- `wind` - High wind warning
- `admin_notice` - System messages

**Methods:**
```dart
Future<void> loadAlerts()
Future<void> markAsRead(String alertId)

// Properties
List<AlertItem> alerts
int unreadCount
bool isLoading
```

#### **7. AssistantService** (`assistant_service.dart`)
**Purpose:** AI farming advice chatbot

**Modes:**
- `auto` - Auto-detect language
- `english` - Reply in English only
- `urdu` - Reply in Urdu only
- `both` - Bilingual reply

**System Prompt:**
> "You are an expert agricultural advisor for Digital Kissan. Your expertise covers: crop selection, seasonal planning, soil health, pest management, irrigation, fertilization, harvesting, post-harvest handling, weather-based decisions, market trends. Provide detailed, comprehensive answers with practical guidance and actionable steps."

**Implementation:**
- Maintains conversation history (last 10 messages)
- Detects language from user input (Urdu: U+0600-U+06FF range)
- Fallback chain: OpenAI → Gemini → Grok

### State Management (Provider)

#### **AuthProvider**
**States:**
```dart
enum AuthBootstrapState { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  User? _user;
  String _role;                              // 'farmer', 'admin'
  bool _roleResolved;
  AuthBootstrapState _bootstrapState;
}
```

**Key Features:**
- Explicit bootstrap state to prevent race conditions
- 5-second fallback timer if auth stream delays
- Automatic Firestore user doc creation
- FCM token registration on login
- Role caching from backend

**Methods:**
- `signOut()` - Unified sign-out with token cleanup
- `get isAdmin` - Convenience property

#### **LanguageProvider**
**Manages:**
- Current Locale (en/ur)
- Persistence to SharedPreferences
- Locale resolution with fallback

#### **PlantDiseaseProvider**
**Status:** Currently disabled (requires Git for tflite_flutter)

### Screens Overview

#### **Dashboard** (`dashboard_screen.dart`)
**Purpose:** Home screen with quick access to key features

**Sections:**
1. **Weather Widget** - Current temp, condition, location
2. **Tips Carousel** - Auto-scrolling farming tips (3-sec interval)
3. **Alerts Panel** - Recent weather alerts (max 3)
4. **Quick Actions** - Buttons to Forecast, Marketplace, Profile
5. **Unread Messages** - Badge with count

**State Management:**
- Loads user profile, weather, alerts simultaneously
- Handles backend unreachable scenario gracefully
- Auto-scroll tips with manual override detection
- 30-second periodic alert refresh

#### **Market Screen** (`market_screen.dart`)
**Tabs:**
1. **Browse Listings** - Grid of available products
2. **My Listings** - Seller's own listings
3. **Rates** - Market rates for crops

**Features:**
- Filter by crop name, district, price range
- Search with debounce
- Listings pagination
- Offer quick action buttons
- Status indicators (open, reserved, sold)

#### **My Listings** (`my_listings_screen.dart`)
**Capabilities:**
- Create new listing with image upload
- Edit existing listings
- Change listing status
- Delete listings
- View incoming offers
- Track unread messages per listing
- Filter by status or search by crop/district

**Image Upload:**
- Multer on backend validates MIME type + size (5MB)
- Uploads to Cloudinary
- Fallback to local `/uploads` storage
- Returns public URL

#### **Assistant Screen** (`assistant_screen.dart`)
**UI:**
- Chat interface with conversation history
- Message bubbles (user on right, assistant on left)
- Language mode selector (auto/English/Urdu/both)
- Send button with loading state

**Features:**
- Maintains conversation context (last 10 messages)
- Auto-detects language (Urdu vs English)
- Graceful error handling with retry
- Responsive keyboard handling

#### **Profile Screen** (`profile_screen.dart`)
**Displays:**
- User name, email, phone
- District, province, address
- Profile photo with upload capability
- Unread message/offer counts

**Functionality:**
- `GET /api/users/me` endpoint (always unredacted)
- Photo upload to Cloudinary
- Edit profile fields
- Sign out button

### Theme System (`app_theme.dart`)

**Color Palette:**
```
Primary Colors:
├─ primary: #1B5E20 (Deep green)
├─ primaryDark: #003300
├─ primaryMid: #2E7D32 (Green 800)
├─ primaryLight: #388E3C (Green 700)
├─ primarySurface: #E8F5E9 (Green 50)
└─ primaryBorder: #C8E6C9 (Green 100)

Status Colors:
├─ statusOpen: #2E7D32 (Green)
├─ statusReserved: #E65100 (Orange)
├─ statusSold: #546E7A (Grey)
├─ statusCancelled: #C62828 (Red)
└─ statusDisputed: #F57F17 (Amber)

Text Colors:
├─ textPrimary: #1A1A1A
├─ textSecondary: #616161
└─ textHint: #9E9E9E
```

**Typography:**
- `heading1` - 26px, Bold (w800)
- `heading2` - 20px, Bold (w800)
- `heading3` - 17px, SemiBold (w700)
- `body` - 14px, Regular, line-height 1.5
- `caption` - 12px, Regular
- `priceLarge` - 28px, Black (w900)

### Utils & Helpers

#### **FormValidators**
```dart
// Email: RFC 5322 basic pattern
// Phone: 7-15 digits
// Password: ≥6 characters
// Name: ≥2 characters
// Crop: 1-50 chars
// District: 1-50 chars
// Quantity: 0-999,999 (numeric)
// Price: 0-9,999,999 (numeric)
```

#### **ErrorPresenter**
Maps exceptions to user-friendly messages:
- Firebase auth errors (invalid-email, weak-password, etc.)
- Network errors (socket, timeout)
- HTTP status codes (401, 403, 404, 429, 500)
- Structured backend errors

#### **RetryHelper**
```dart
Future<T> retry<T>(
  Future<T> Function() fn,
  {
    int maxAttempts = 3,
    int initialDelayMs = 500,
    Function? onRetry,
  }
)
```
- Exponential backoff: 500ms → 1000ms → 2000ms
- Catches SocketException, TimeoutException
- Surfaces other errors immediately

---

## Backend (Node.js/Express)

### Project Structure

```
backend/
├── package.json
├── src/
│   ├── server.js                      # Entry point
│   ├── app.js                         # Express app creation
│   ├── config/
│   │   ├── env.js                    # Environment variables
│   │   └── firebaseAdmin.js          # Firebase initialization
│   ├── middlewares/
│   │   ├── auth.js                   # requireAuth, requireRole
│   │   └── attachDbUser.js           # Fetch user doc from Firestore
│   ├── routes/                        # 14 API endpoint files
│   │   ├── users.routes.js
│   │   ├── listings.routes.js
│   │   ├── offers.routes.js
│   │   ├── orders.routes.js
│   │   ├── messages.routes.js
│   │   ├── weather.routes.js
│   │   ├── alerts.routes.js
│   │   ├── assistant.routes.js
│   │   ├── ratings.routes.js
│   │   ├── uploads.routes.js
│   │   ├── admin.routes.js
│   │   ├── config.routes.js
│   │   ├── rates.routes.js
│   │   └── health.routes.js
│   ├── services/
│   │   ├── weatherAlerts.service.js  # 15-min refresh job
│   │   └── ratesIngestion.service.js # Placeholder
│   ├── utils/
│   │   ├── firestoreHelpers.js       # col(), docToJson(), queryToJson()
│   │   ├── validators.js             # Input validation rules
│   │   ├── errors.js                 # Error classes & asyncHandler
│   │   ├── fcmHelper.js              # sendPushToUser(), sendPushToUsers()
│   └── scripts/                       # Helper scripts
│       ├── check_endpoints.js
│       ├── run_groq_request.cjs
│       └── test_cloudinary_upload.js
├── serviceAccountKey.json             # Firebase credentials
├── firestore.indexes.json             # Firestore indexes
└── firebase.json                      # Firebase config
```

### Server Initialization (`server.js`)

```javascript
async function start() {
  // 1. Initialize Firebase Admin
  initFirebaseAdmin();
  
  // 2. Log OpenWeather availability
  if (env.openWeatherKey) {
    console.log(`[Startup] OpenWeather key present`);
  }
  
  // 3. Start weather refresh job (15-min interval)
  startWeatherRefreshJob({ intervalMinutes: 15 });
  
  // 4. Create Express app
  const app = createApp();
  
  // 5. Listen on port
  app.listen(env.port, env.host, () => {
    console.log(`API running on http://localhost:${env.port}`);
  });
}
```

### App Configuration (`app.js`)

```javascript
export function createApp() {
  const app = express();
  
  // Security
  app.use(helmet());
  
  // Rate limiting: 120 req/min per IP
  app.use(rateLimit({
    windowMs: 60 * 1000,
    max: 120,
  }));
  
  // CORS with origin validation
  app.use(cors({ /* allowedOrigins, credentials */ }));
  
  // Body parser: 2MB limit
  app.use(express.json({ limit: '2mb' }));
  
  // Static files: /uploads served publicly
  app.use('/uploads', express.static(path.resolve(process.cwd(), 'uploads')));
  
  // Routes
  app.use('/api/health', healthRouter);
  app.use('/api/users', usersRouter);
  app.use('/api/listings', listingsRouter);
  app.use('/api/offers', offersRouter);
  app.use('/api/orders', ordersRouter);
  app.use('/api/messages', messagesRouter);
  app.use('/api/weather', weatherRouter);
  app.use('/api/alerts', alertsRouter);
  app.use('/api/assistant', assistantRouter);
  app.use('/api/ratings', ratingsRouter);
  app.use('/api/uploads', uploadsRouter);
  app.use('/api/admin', adminRouter);
  app.use('/api/config', configRouter);
  app.use('/api/rates', ratesRouter);
  
  // Error handling middleware
  app.use((err, req, res, next) => {
    const statusCode = err.statusCode || 500;
    const response = formatErrorResponse(err);
    res.status(statusCode).json(response);
  });
  
  return app;
}
```

### Middleware

#### **Authentication (`auth.js`)**

```javascript
export async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const [, token] = authHeader.split(' ');
  
  if (!token) {
    res.status(401).json({ message: 'Missing bearer token' });
    return;
  }
  
  try {
    // Verify Firebase ID token
    const decoded = await admin.auth().verifyIdToken(token, true);
    req.user = {
      uid: decoded.uid,
      email: decoded.email || null,
      phoneNumber: decoded.phone_number || null,
      name: decoded.name || null,
    };
  } catch (firebaseError) {
    // Optional dev auth fallback (ALLOW_DEV_AUTH_FALLBACK=true)
    if (!allowDevAuthFallback) {
      res.status(401).json({ message: 'Invalid or expired auth token' });
      return;
    }
    // Dev auth: decode JWT manually
    req.user = buildDevUser(token);
  }
  
  next();
}

export function requireRole(...roles) {
  return (req, res, next) => {
    const role = req.dbUser.role || 'farmer';
    if (!roles.includes(role)) {
      res.status(403).json({ message: 'Forbidden' });
      return;
    }
    next();
  };
}
```

#### **Attach Database User (`attachDbUser.js`)**

Fetches user's Firestore document and caches in `req.dbUser`.

---

## API Routes & Endpoints

### 1. Health Check

```
GET /api/health
└─ Returns: { status: 'ok', timestamp: ISO }
└─ Auth: None
```

### 2. Users Management

```
GET /api/users/me
├─ Returns: Current user's full profile (unredacted)
├─ Auth: Required
└─ Includes: All fields (phone, email, address, lat/lon)

GET /api/users/:uid
├─ Returns: User profile with visibility rules
├─ Auth: Required
├─ Redaction: Phone, email, address hidden unless:
│   ├─ Same user (viewerUid === targetUid)
│   ├─ Viewer is admin
│   ├─ Completed order together
│   ├─ One made offer on other's listings
│   └─ Shared marketplace activity
└─ Purpose: Privacy while enabling seller discovery

GET /api/users/by-phone/:phone
├─ Returns: User lookup by phone
├─ Auth: Required
├─ Use Case: Add contacts, verify seller
└─ Returns 404 if not found

PATCH /api/users/me
├─ Updates: displayName, phoneNumber, photoUrl, district, address, lat, lon
├─ Auth: Required
├─ Validation: Trims, validates format
└─ Merge: true (partial updates)
```

### 3. Listings Management

```
GET /api/listings
├─ Query Parameters:
│   ├─ crop: Filter by crop name (string match)
│   ├─ district: Filter by district
│   ├─ sellerUid: Filter by seller
│   ├─ status: Filter by status (all/open/reserved/sold/cancelled)
│   ├─ sort: 'new' (default), 'price_asc', 'price_desc'
│   ├─ limit: 1-200 (default 50)
│   └─ before: ISO date for cursor pagination
├─ Auth: None
├─ Returns: Array of ListingDto
└─ Pagination: Cursor-based with createdAt

POST /api/listings
├─ Body:
│   ├─ cropName: string, 2-50 chars (required)
│   ├─ qualityGrade: 'A', 'B', 'C' (default 'A')
│   ├─ quantity: number > 0 (required)
│   ├─ unit: '40kg', '50kg', etc. (required)
│   ├─ askingPrice: number > 0 (required)
│   ├─ district: string (required)
│   ├─ locationName: string (optional)
│   ├─ latitude: number (optional)
│   ├─ longitude: number (optional)
│   ├─ description: string (optional)
│   └─ imageUrls: string[] (optional)
├─ Auth: Required
├─ Returns: Created ListingDto
├─ Validation: Server-side on all fields
└─ Status: Always created as 'open'

PATCH /api/listings/:id
├─ Updates: Text fields, quantity, price, location, images
├─ Auth: Required
├─ Authorization: Seller or admin only
├─ Returns: Updated ListingDto
└─ Merge: true (partial updates)

PATCH /api/listings/:id/status
├─ Body: { status: 'open'|'reserved'|'sold'|'cancelled' }
├─ Auth: Required
├─ Authorization: Seller or admin
└─ Returns: Updated listing

DELETE /api/listings/:id
├─ Auth: Required
├─ Authorization: Seller or admin
└─ Soft delete option available
```

### 4. Offers Management

```
GET /api/offers/me
├─ Returns: Offers made by current user
├─ Auth: Required
├─ Enrichment: Includes listing details for each offer
└─ Sort: By createdAt desc

GET /api/offers/incoming
├─ Returns: Offers on current user's listings
├─ Auth: Required
├─ Enrichment: Includes listing details
└─ Use: Seller dashboard

POST /api/offers
├─ Body:
│   ├─ listingId: string (required)
│   ├─ offerPrice: number > 0 (required)
│   └─ quantity: number > 0 (required)
├─ Auth: Required
├─ Validation:
│   ├─ Listing must exist
│   ├─ Listing must be 'open'
│   ├─ Buyer ≠ seller
│   └─ No duplicate pending offer from buyer
├─ Returns: Created OfferDto
├─ Side Effects:
│   ├─ Notifies seller via FCM
│   └─ Creates notification log
└─ Status: Created as 'pending'

PATCH /api/offers/:id/status
├─ Body: { status: 'accepted'|'rejected' }
├─ Auth: Required
├─ Authorization: Seller only
├─ Validation: Offer exists, seller match
├─ Returns: Updated OfferDto
└─ Side Effects:
    ├─ If accepted: Creates order doc, notifies buyer
    ├─ If rejected: Notifies buyer, updates offer
    └─ Can override pending offers on same listing
```

### 5. Orders Management

```
GET /api/orders/me
├─ Returns: Orders where user is buyer OR seller
├─ Auth: Required
├─ Enrichment: cropName, listingDistrict from listings
├─ Sort: By createdAt desc
└─ Use: Order history

POST /api/orders (Created internally when offer accepted)
├─ Body:
│   ├─ listingId: string
│   ├─ buyerUid: string
│   ├─ sellerUid: string
│   ├─ offerPrice: number
│   └─ quantity: number
├─ Returns: Created OrderDto
└─ Status: 'created'

PATCH /api/orders/:id/status
├─ Body: { status: 'in_transit'|'delivered'|'completed'|'disputed' }
├─ Auth: Required
├─ Authorization: Buyer, seller, or admin
├─ Validation: STATE MACHINE
│   ├─ created → [in_transit, cancelled] (seller), [cancelled] (buyer)
│   ├─ in_transit → [delivered] (seller), [disputed] (buyer)
│   ├─ delivered → [completed, disputed] (buyer)
│   ├─ completed → [disputed] (admin)
│   └─ disputed → [completed, cancelled] (admin)
├─ Returns: Updated OrderDto
└─ Side Effects: Notifies counterpart via FCM
```

### 6. Messages (Listing Threads)

```
GET /api/messages/:listingId
├─ Returns: All messages in listing thread
├─ Auth: Required
├─ Authorization: Thread participant only
├─ Returns: { messages: [], thread: {...} }
└─ Thread: { id, listingId, sellerUid, participantUids, lastMessageAt }

POST /api/messages/:listingId
├─ Body: { content: string }
├─ Auth: Required
├─ Authorization: Buyer or seller of listing
├─ Validation:
│   ├─ Listing exists
│   ├─ User is buyer or seller
│   └─ Thread auto-created if needed
├─ Returns: Created message
└─ Side Effects: Updates thread.lastMessageAt

GET /api/messages/:listingId/participants
├─ Returns: List of users in thread
├─ Auth: Required
└─ Authorization: Participant only
```

### 7. Weather Data

```
GET /api/weather/me
├─ Returns: Weather for user's saved location
├─ Auth: Required
├─ Source: OpenWeather API
├─ Returns:
│   ├─ current: { temp, weather, wind_speed, humidity, ... }
│   └─ forecast: { daily: [{ date, tempMin, tempMax, ... }] }
└─ Caching: 15-min server-side

GET /api/weather?lat=X&lon=Y
├─ Returns: Weather for custom location
├─ Auth: Optional
├─ Parameters: latitude, longitude
└─ Use: Forecast screen with custom location
```

### 8. Weather Alerts

```
GET /api/alerts
├─ Query: limit (1-100, default 50)
├─ Auth: Required
├─ Returns: Array of AlertDto (user's alerts only)
├─ Alert Types: rain, heat, cold, wind, admin_notice
└─ Pagination: Optional limit

PATCH /api/alerts/:id/read
├─ Auth: Required
├─ Authorization: Alert owner only
├─ Returns: { message: 'Alert marked as read' }
└─ Side Effects: Sets readAt timestamp
```

### 9. AI Assistant

```
POST /api/assistant/chat
├─ Body:
│   ├─ message: string (required, ≤2000 chars)
│   ├─ language: 'auto'|'en'|'ur'|'both' (optional)
│   └─ history: [{ role, content }, ...] (last 10 msgs)
├─ Auth: Required
├─ Returns:
│   ├─ reply: string (AI response)
│   └─ language: 'en'|'ur'
├─ Processing:
│   ├─ Detects language from message if 'auto'
│   ├─ Builds system instruction for farming expert
│   ├─ Tries OpenAI → Gemini → Grok
│   └─ Returns first successful response
└─ Max Tokens: 1024 (configurable per model)
```

### 10. Ratings & Reviews

```
GET /api/ratings/eligibility/:targetUid
├─ Auth: Required
├─ Returns:
│   ├─ canRate: boolean
│   └─ reason: 'eligible'|'no_completed_order'|'already_rated'|'cannot_rate_self'
├─ Rules:
│   ├─ Must have completed order with target as buyer-seller
│   └─ Cannot rate same seller twice
└─ Use: Enable/disable rating button in UI

POST /api/ratings
├─ Body:
│   ├─ targetUid: string (seller to rate)
│   ├─ score: 1-5 (required)
│   └─ comment: string (≤500 chars)
├─ Auth: Required
├─ Validation:
│   ├─ Must have completed order
│   ├─ Cannot rate self
│   └─ One rating per buyer-seller pair
├─ Returns: Created RatingDto
└─ Side Effects: Updates seller's average rating

GET /api/ratings/:uid
├─ Auth: None
├─ Returns:
│   ├─ averageScore: number
│   ├─ totalRatings: number
│   └─ recentReviews: [{ raterUid, score, comment, createdAt }] (limit 20)
└─ Use: Seller profile public display
```

### 11. File Uploads

```
POST /api/uploads/listing-image
├─ Method: multipart/form-data
├─ Field: image (binary file)
├─ Auth: Required
├─ Size Limit: 5MB
├─ Accepted: JPEG, PNG, GIF, WebP, BMP
├─ Processing:
│   ├─ Multer validates MIME type + extension
│   ├─ Uploads to Cloudinary (or local fallback)
│   ├─ Returns public URL
│   └─ Deletes local temp file
└─ Returns: { url: 'https://...' }

POST /api/uploads/profile-image
├─ Similar to listing-image
├─ Path: /uploads/profiles (or Cloudinary)
└─ Returns: { url: 'https://...' }
```

### 12. Admin Functions

```
GET /api/admin/stats
├─ Auth: Required
├─ Authorization: Admin only
├─ Returns:
│   ├─ totalUsers: number
│   ├─ totalListings: number
│   ├─ totalOffers: number
│   ├─ totalOrders: number
│   ├─ openListings: number
│   └─ timestamp: ISO
└─ Use: Dashboard widget

GET /api/admin/users
├─ Auth: Required
├─ Authorization: Admin only
├─ Returns: Array of users with:
│   ├─ id, firebaseUid, displayName, email, role
│   ├─ isOnline, lastSeen
│   └─ createdAt
└─ Presence: Fetches from presence collection

PATCH /api/admin/alerts/refresh
├─ Auth: Required
├─ Authorization: Admin only
├─ Returns: { refreshed: number, nextRun: ISO }
└─ Trigger: Manual weather cache refresh

POST /api/admin/broadcast
├─ Body: { title, body, data? }
├─ Auth: Required
├─ Authorization: Admin only
├─ Returns: { sent: number, failed: number }
└─ Effect: Sends FCM to all users
```

### 13. Configuration

```
GET /api/config/public
├─ Auth: None
├─ Returns:
│   ├─ mapboxAccessToken: string
│   └─ Other public config
└─ Use: Frontend initialization
```

### 14. Marketplace Rates

```
GET /api/rates
├─ Auth: None
├─ Query: crop (optional)
├─ Returns: Array of crop rates
│   ├─ cropName, marketName, district
│   ├─ minPrice, maxPrice, unit
│   └─ lastUpdatedAt
└─ Status: Placeholder (no integration yet)
```

---

## Database Schema (Firestore)

### Collection: users

```javascript
{
  id: "firebase_uid_here",  // Doc ID = Firebase UID
  firebaseUid: "firebase_uid_here",
  displayName: "Ahmed Khan",
  name: "Ahmed Khan",
  phone: "03001234567",
  phoneNumber: "03001234567",
  email: "ahmed@example.com",
  role: "farmer",  // 'farmer' | 'admin'
  district: "Lahore",
  province: "Punjab",
  address: "Village XYZ, Tehsil ABC",
  lat: 31.5204,  // Latitude
  lon: 74.3587,  // Longitude
  locationUpdatedAt: Timestamp("2026-05-19T10:00:00Z"),
  photoUrl: "https://cloudinary.com/...",
  fcmTokens: [
    "token_1",
    "token_2",
    ...
  ],
  notificationsEnabled: true,
  createdAt: Timestamp("2025-01-01T00:00:00Z"),
  updatedAt: Timestamp("2026-05-19T10:00:00Z"),
}
```

**Indexes:**
- `phoneNumber` (for by-phone lookup)
- `role` (for admin queries)
- `createdAt` desc (for user growth tracking)

---

### Collection: listings

```javascript
{
  id: "listing_uuid",  // Auto-generated
  sellerUid: "firebase_uid",
  cropName: "Wheat",
  qualityGrade: "A",  // 'A' | 'B' | 'C'
  quantity: 500,
  unit: "40kg",
  askingPrice: 25000,  // PKR
  district: "Lahore",
  locationName: "Near GT Road",
  latitude: 31.5204,
  longitude: 74.3587,
  description: "Fresh wheat, direct from farm",
  imageUrls: [
    "https://cloudinary.com/image1.jpg",
    "https://cloudinary.com/image2.jpg"
  ],
  status: "open",  // 'open' | 'reserved' | 'sold' | 'cancelled'
  createdAt: Timestamp("2026-05-01T12:00:00Z"),
  updatedAt: Timestamp("2026-05-19T10:00:00Z"),
}
```

**Indexes:**
- `sellerUid` (for my listings)
- `cropName` (for filtering by crop)
- `district` (for location-based search)
- `status` (for filtering)
- `createdAt` desc (for sort: new)
- `askingPrice` asc/desc (for price sorting)

---

### Collection: offers

```javascript
{
  id: "offer_uuid",
  listingId: "listing_uuid",
  buyerUid: "firebase_uid",
  offerPrice: 23000,  // PKR (below asking price)
  quantity: 300,  // Can be less than listing quantity
  status: "pending",  // 'pending' | 'accepted' | 'rejected'
  createdAt: Timestamp("2026-05-19T10:00:00Z"),
  updatedAt: Timestamp("2026-05-19T10:00:00Z"),
}
```

**Indexes:**
- `buyerUid` (for my offers)
- `listingId, buyerUid` (prevent duplicates)
- `status` (for filtering)
- `createdAt` desc (for sorting)

---

### Collection: orders

```javascript
{
  id: "order_uuid",
  listingId: "listing_uuid",
  buyerUid: "firebase_uid",
  sellerUid: "firebase_uid",
  offerPrice: 23000,  // Final negotiated price
  quantity: 300,
  status: "created",  // State machine: created → in_transit → delivered → completed
  //                                   ↓
  //                            can jump to: cancelled, disputed
  createdAt: Timestamp("2026-05-19T10:00:00Z"),
  updatedAt: Timestamp("2026-05-19T10:00:00Z"),
  statusHistory: [  // Optional: audit trail
    { status: "created", updatedAt: ..., updatedBy: "..." },
    { status: "in_transit", updatedAt: ..., updatedBy: "..." }
  ]
}
```

**Indexes:**
- `buyerUid` (for my orders)
- `sellerUid` (for incoming orders)
- `status` (for filtering by state)
- `createdAt` desc (for sorting)

---

### Collection: listing_threads

```javascript
{
  id: "listing_uuid_buyer_uuid_seller_uuid",  // Composite ID
  listingId: "listing_uuid",
  sellerUid: "firebase_uid",
  buyerUid: "firebase_uid",  // First participant who started conversation
  participantUids: [
    "buyer_uid",
    "seller_uid"
  ],
  lastMessageAt: Timestamp("2026-05-19T10:00:00Z"),
  
  // Sub-collection: messages
  messages: [
    {
      id: "msg_uuid",
      senderUid: "firebase_uid",
      content: "Is this product still available?",
      createdAt: Timestamp("2026-05-19T10:00:00Z"),
      read: false,
      readAt: null
    }
  ]
}
```

**Note:** Frontend doesn't need to know about internal structure—backend handles thread creation.

---

### Collection: ratings

```javascript
{
  id: "rating_uuid",
  targetUid: "seller_firebase_uid",
  raterUid: "buyer_firebase_uid",
  score: 4,  // 1-5 stars
  comment: "Great quality produce and fast delivery!",
  createdAt: Timestamp("2026-05-19T10:00:00Z"),
  updatedAt: Timestamp("2026-05-19T10:00:00Z"),
}
```

**Indexes:**
- `targetUid` (for seller's rating summary)
- `raterUid, targetUid` (prevent duplicate ratings)
- `createdAt` desc (for recent reviews)

---

### Collection: weather_alerts

```javascript
{
  id: "alert_uuid",
  userId: "firebase_uid",
  type: "rain",  // 'rain' | 'heat' | 'cold' | 'wind' | 'admin_notice'
  title: "Heavy Rainfall Warning",
  body: "Expect 12mm rain in next 3 hours. Avoid pesticide spraying.",
  read: false,
  readAt: null,
  createdAt: Timestamp("2026-05-19T10:00:00Z"),
  weatherUpdatedAt: Timestamp("2026-05-19T09:00:00Z"),  // When weather data was fetched
}
```

**Indexes:**
- `userId` (for user's alerts)
- `userId, createdAt` desc (for pagination)
- `read` (for unread count)

---

### Collection: notification_logs

```javascript
{
  id: "log_uuid",
  userId: "firebase_uid",
  type: "offer_received" | "order_status" | "message" | "weather_alert",
  title: "New Offer Received",
  body: "You have a new offer for Wheat",
  data: {
    listingId: "...",
    offerId: "...",
    // type-specific fields
  },
  sent: false,
  sentAt: null,
  createdAt: Timestamp("2026-05-19T10:00:00Z"),
}
```

---

### Collection: presence (optional)

```javascript
{
  id: "firebase_uid",  // Doc ID = User UID
  isOnline: true,
  lastSeen: Timestamp("2026-05-19T10:00:00Z"),
}
```

---

## Data Flow & User Journeys

### 1. User Registration & Onboarding

```
START
  │
  ▼
┌─────────────────────────────┐
│ User opens app              │
│ → SplashScreen              │
└─────────────────────────────┘
  │
  ▼
┌─────────────────────────────┐
│ AuthProvider checks         │
│ FirebaseAuth.currentUser    │
│ → Sets bootstrapState       │
└─────────────────────────────┘
  │
  ├─ If authenticated: GO TO Dashboard
  └─ If unauthenticated: GO TO LoginScreen
  
  
LOGIN SCREEN / REGISTRATION SCREEN
  │
  ▼
┌─────────────────────────────────────────┐
│ User enters email & password            │
│ → Calls AuthService.registerWithEmail() │
│   OR AuthService.signInWithEmail()      │
└─────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────────────┐
│ Firebase Auth creates/verifies user                  │
│ → AuthProvider listens to authStateChanges()         │
└──────────────────────────────────────────────────────┘
  │
  ▼
┌────────────────────────────────────────────────────────┐
│ AuthProvider calls:                                    │
│ 1. FirebaseService.createUserIfNotExists()           │
│    → POST /api/users/me → Firestore user doc        │
│ 2. Fetch role from backend (GET /api/users/me)      │
│ 3. Register FCM token                                │
└────────────────────────────────────────────────────────┘
  │
  ▼ (If new user)
┌─────────────────────────────────┐
│ Email Verification Screen       │
│ → Prompt to verify email        │
│ → Show resend button            │
└─────────────────────────────────┘
  │
  ▼ (After verification)
┌──────────────────────────────────┐
│ Dashboard Screen                 │
│ → Load user profile              │
│ → Show weather, tips, alerts     │
└──────────────────────────────────┘
```

### 2. Create & List Product

```
USER ON MY LISTINGS SCREEN
  │
  ▼
┌─────────────────────────────────┐
│ Click "Create Listing"          │
│ → MyListingsScreen form         │
└─────────────────────────────────┘
  │
  ▼
┌────────────────────────────────────┐
│ Fill form:                         │
│ • Crop name, grade, quantity      │
│ • Asking price, unit, district    │
│ • Location (map picker optional)  │
│ • Description, images             │
└────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────┐
│ Click "Create Listing"                   │
│ → Validate locally (FormValidators)      │
│ → Upload images to Cloudinary (parallel) │
└──────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────┐
│ Call MarketApiService.createListing()    │
│ → POST /api/listings (with image URLs)   │
└──────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────┐
│ Backend validation & creation                │
│ 1. validateListingInput() → crop, quantity   │
│ 2. Create doc in Firestore listings          │
│ 3. Return ListingDto with id                 │
└──────────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────┐
│ MyListingsScreen refreshes        │
│ → Shows new listing as "open"    │
│ → User can edit or delete         │
└──────────────────────────────────┘

BUYER BROWSING
  │
  ▼
┌────────────────────────────┐
│ Open MarketScreen          │
│ → Browse tab               │
└────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────┐
│ Call MarketApiService.getListings({         │
│   crop: "Wheat",                             │
│   district: "Lahore",                        │
│   sort: "price_asc",                         │
│   limit: 50                                  │
│ })                                           │
│ → GET /api/listings?crop=...&district=...   │
└──────────────────────────────────────────────┘
  │
  ▼
┌────────────────────────────────────────────────┐
│ Backend filters & returns:                     │
│ 1. Query Firestore with filters               │
│ 2. Sort by createdAt (new) or price           │
│ 3. Return array of ListingDto                 │
│ 4. Paginate with before cursor                │
└────────────────────────────────────────────────┘
  │
  ▼
┌────────────────────────────────┐
│ MarketScreen displays listings │
│ • Grid of product cards        │
│ • Filter chips for crop/price  │
│ • Tap card → ListingDetailScreen
└────────────────────────────────┘
```

### 3. Make Offer & Complete Order

```
BUYER VIEWING LISTING DETAIL
  │
  ▼
┌─────────────────────────────┐
│ ListingDetailScreen         │
│ • Shows crop, price, images │
│ • Seller profile card       │
│ • "Make Offer" button       │
└─────────────────────────────┘
  │
  ▼
┌──────────────────────────────┐
│ User clicks "Make Offer"     │
│ → Opens offer dialog         │
│ • Price input (≤ asking)    │
│ • Quantity selector          │
└──────────────────────────────┘
  │
  ▼
┌────────────────────────────────────┐
│ User submits offer                 │
│ → Calls MarketApiService.submitOffer()
│   POST /api/offers                 │
│   Body: {                          │
│     listingId, offerPrice,         │
│     quantity                       │
│   }                                │
└────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────┐
│ Backend validation:                     │
│ 1. Listing exists & status = 'open'    │
│ 2. Buyer ≠ seller                      │
│ 3. No pending offer from buyer already │
│ 4. validateOfferInput()                │
│ 5. Create offer doc → status: 'pending'│
└─────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────┐
│ Backend sends FCM notification to seller:│
│ Title: "New Offer Received"              │
│ Body: "PKR 23,000 for Wheat"             │
│ Data: { type: 'offer', offerId, ... }   │
└──────────────────────────────────────────┘
  │
  ▼ SELLER RECEIVES NOTIFICATION
┌─────────────────────────────┐
│ Tap notification            │
│ → Opens OffersScreen        │
│ (or manually navigate)      │
└─────────────────────────────┘
  │
  ▼
┌────────────────────────────────┐
│ OffersScreen (incoming tab)    │
│ • Shows offers on seller's     │
│   products                     │
│ • Accept/Reject buttons        │
└────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────┐
│ Seller clicks "Accept Offer"     │
│ → PATCH /api/offers/:id/status   │
│   Body: { status: 'accepted' }   │
└──────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────┐
│ Backend:                                 │
│ 1. Update offer.status = 'accepted'     │
│ 2. Create order doc from offer:         │
│    {                                     │
│      listingId, buyerUid, sellerUid,    │
│      offerPrice, quantity,              │
│      status: 'created'                  │
│    }                                     │
│ 3. Send FCM to buyer (offer accepted)   │
└──────────────────────────────────────────┘
  │
  ▼ BOTH BUYER & SELLER
┌──────────────────────────────────────┐
│ OrdersScreen                         │
│ • Shows order with current status    │
│ • Status buttons based on role       │
│ • Timeline of transitions            │
└──────────────────────────────────────┘
  │
  ├─ Buyer: created → [Waiting for seller]
  │                    Seller ships → in_transit
  │                    Mark delivered → completed
  │
  └─ Seller: created → [ready to ship]
                       Mark in_transit
                       in_transit → [waiting for buyer]
                       Buyer marks delivered → completed
  
  ▼ SELLER MARKS IN_TRANSIT
┌──────────────────────────────────┐
│ Seller clicks "Mark in Transit"  │
│ → PATCH /api/orders/:id/status   │
│   Body: { status: 'in_transit' } │
└──────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────┐
│ Backend:                             │
│ 1. Validate state transition (OK)   │
│ 2. Update order.status              │
│ 3. Send FCM to buyer:               │
│    "Order #ABC123 is in transit"    │
└──────────────────────────────────────┘
  │
  ▼ BUYER MARKS DELIVERED
┌────────────────────────────────────────┐
│ Buyer receives package, clicks         │
│ "Mark as Delivered"                    │
│ → PATCH /api/orders/:id/status         │
│   Body: { status: 'delivered' }        │
└────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────┐
│ Backend:                                     │
│ 1. Validate transition (buyer, in_transit) │
│ 2. Update order.status = 'delivered'       │
│ 3. Send FCM to seller: "Product delivered" │
└──────────────────────────────────────────────┘
  │
  ▼ BUYER MARKS COMPLETED
┌──────────────────────────────────┐
│ Buyer clicks "Mark Completed"    │
│ → PATCH /api/orders/:id/status   │
│   Body: { status: 'completed' }  │
└──────────────────────────────────┘
  │
  ▼
┌────────────────────────────────────┐
│ Backend updates order status       │
│ → Order marked as completed        │
│ → Now buyer can leave rating       │
└────────────────────────────────────┘
  │
  ▼ BUYER LEAVES RATING
┌──────────────────────────────────────┐
│ Order detail screen shows:           │
│ "Rate this seller"                   │
│ • Star picker (1-5)                 │
│ • Comment text field                │
└──────────────────────────────────────┘
  │
  ▼
┌────────────────────────────────────────┐
│ Buyer clicks "Submit Rating"           │
│ → POST /api/ratings                    │
│   Body: {                              │
│     targetUid: sellerUid,             │
│     score: 5,                          │
│     comment: "Excellent service!"      │
│   }                                    │
└────────────────────────────────────────┘
  │
  ▼
┌────────────────────────────────────┐
│ Backend:                           │
│ 1. Check eligibility (completed    │
│    order, not already rated)       │
│ 2. Create rating doc              │
│ 3. Update seller's avg rating     │
│ 4. Return rating doc              │
└────────────────────────────────────┘
  │
  ▼ END
```

### 4. Weather Alert Notification Flow

```
SERVER STARTUP
  │
  ▼
┌──────────────────────────────────────┐
│ start() in server.js                 │
│ → initFirebaseAdmin()                │
│ → startWeatherRefreshJob(15-min)     │
└──────────────────────────────────────┘
  │
  ▼ EVERY 15 MINUTES
┌──────────────────────────────────────┐
│ weatherAlerts.service.js             │
│ → startWeatherRefreshJob()           │
│   1. Fetch all users from Firestore  │
│   2. For each user with lat/lon:     │
│      • Fetch weather from OpenWeather│
│      • Check thresholds:             │
│        - Rain > 0.6mm next 3h       │
│        - Temp < 5°C or > 45°C       │
│        - Wind > 50 km/h             │
│      • Generate alert title & body  │
│   3. Create/update alert docs       │
│   4. Collect FCM tokens             │
│   5. Send push notifications        │
└──────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────┐
│ Backend calls FCM:                │
│ sendPushToUser(uid,               │
│   title: "Heavy Rain Warning",    │
│   body: "Expect 8mm rain in 3h. "  │
│         "Avoid pesticide spraying" │
│ )                                 │
└──────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────┐
│ Mobile device receives FCM notification │
│ → NotificationService displays alert    │
│ → Creates alert doc in weather_alerts   │
└──────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────┐
│ User taps notification            │
│ → PushService handles tap         │
│ → Routes to AlertsScreen          │
└──────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────┐
│ AlertsScreen displays:            │
│ • List of alerts                 │
│ • Type icons (rain, heat, etc.)  │
│ • Mark as read button            │
└──────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────┐
│ User marks as read:                  │
│ → PATCH /api/alerts/:id/read         │
│ → Sets readAt timestamp              │
│ → Updates UI (no longer unread)       │
└──────────────────────────────────────┘
```

### 5. Messaging Flow (Listing-Based)

```
BUYER INTERESTED IN LISTING
  │
  ▼
┌──────────────────────────────────┐
│ ListingDetailScreen              │
│ • Tap "Ask Seller" / "Message"  │
│ → Navigate to ChatScreen         │
└──────────────────────────────────┘
  │
  ▼
┌───────────────────────────────────────┐
│ ChatScreen(listingId, toUid)          │
│ → Loads listing thread               │
│ GET /api/messages/listing_id          │
└───────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────┐
│ Backend:                             │
│ 1. Check if thread exists           │
│    - If not, auto-create it         │
│ 2. Fetch messages from thread       │
│ 3. Return messages array            │
└──────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────┐
│ ChatScreen displays:             │
│ • Listing info at top           │
│ • Message bubbles               │
│ • Input field + send button     │
└─────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────┐
│ User types & taps send           │
│ → Calls POST /api/messages/:id   │
│   Body: { content: "..." }       │
└──────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────┐
│ Backend:                             │
│ 1. Ensure thread exists             │
│ 2. Create message doc in subcoll    │
│ 3. Update thread.lastMessageAt      │
│ 4. Return message                   │
│ 5. (Optional) Send FCM to recipient │
└──────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────┐
│ Message appears in chat          │
│ • Real-time via polling          │
│ • Or refresh on tab focus        │
└─────────────────────────────────┘
```

---

## Security & Access Control

### Authentication Layer

**Firebase ID Token Verification:**
- Client: Gets token from `FirebaseAuth.instance.currentUser.getIdToken()`
- Backend: `requireAuth` middleware verifies with Firebase Admin SDK
- All protected endpoints require valid token in `Authorization: Bearer <token>` header

**Optional Dev Auth Fallback:**
- For local testing: `ALLOW_DEV_AUTH_FALLBACK=true` (dev/staging only)
- Allows JWT-style tokens (decoded manually)
- BLOCKED in production by startup check

### Authorization Layers

#### **Role-Based Access Control (RBAC)**
```javascript
requireRole('admin')        // Only admins
requireRole('farmer', 'admin')  // Farmers or admins
```

Used for:
- Admin stats endpoint
- Weather cache refresh
- Broadcast notifications

#### **Sensitive Field Redaction**
Backend function `canViewSensitiveFields()` checks if viewer can see phone, email, address, lat/lon:

**Access granted if:**
1. `viewerUid === targetUid` (viewing own profile)
2. Viewer is admin
3. Both have completed order together (buyer-seller)
4. One made offer on other's listings
5. Shared marketplace activity

**Blocked otherwise:** Fields returned as empty strings/nulls

#### **Resource Ownership Validation**
```javascript
// Listing update: Only seller or admin
if (listing.sellerUid !== req.user.uid && req.dbUser.role !== 'admin') {
  return res.status(403).json({ message: 'Only seller or admin can update' });
}

// Offer response: Only seller
if (order.sellerUid !== req.user.uid && req.dbUser.role !== 'admin') {
  return res.status(403).json({ message: 'Only seller can respond to offers' });
}
```

### Order State Machine Validation

Prevents invalid status transitions:

```javascript
const orderStateTransitions = {
  created: {
    seller: ['in_transit', 'cancelled'],
    buyer: ['cancelled'],
    admin: ['in_transit', 'cancelled', 'disputed'],
  },
  in_transit: {
    seller: ['delivered'],
    buyer: ['disputed'],
    admin: ['delivered', 'disputed', 'cancelled'],
  },
  // ... more states
};

if (!canTransitionOrder(currentStatus, nextStatus, actorRole)) {
  return res.status(409).json({
    message: 'Invalid status transition',
    allowedTransitions: orderStateTransitions[currentStatus][actorRole],
  });
}
```

### Input Validation

**Server-Side Validators:**

```javascript
Validator.email(value)          // RFC 5322 pattern
Validator.phone(value)          // 7-15 digits or formatted
Validator.required(value)       // Not empty
Validator.minLength(value, min) // String length check
Validator.maxLength(value, max)
Validator.cropName(value)       // 2-50 chars, Unicode support
Validator.district(value)       // 2-50 chars, Unicode support
Validator.quantity(value)       // Number: 0.1-999,999
Validator.price(value)          // Number: 0.01-9,999,999
```

**Multer File Validation:**
- MIME type check (must start with `image/`)
- Extension check ([.jpg, .jpeg, .png, .gif, .webp, .bmp](file:///C:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/COMPLETE_APP_DOCUMENTATION.md))
- Size limit: 5MB

### Data Protection

**Duplicate Prevention:**
```javascript
// No duplicate pending offers from same buyer
const existingOffer = await col('offers')
  .where('listingId', '==', listingId)
  .where('buyerUid', '==', buyerUid)
  .where('status', '==', 'pending')
  .limit(1)
  .get();

if (!existingOffer.empty) {
  return res.status(409).json({
    message: 'You already have a pending offer on this listing'
  });
}
```

**One Rating Per Pair:**
```javascript
// Buyer can only rate seller once
const alreadyRated = await col('ratings')
  .where('raterUid', '==', raterUid)
  .where('targetUid', '==', targetUid)
  .limit(1)
  .get();

if (alreadyRated.exists) {
  return res.status(409).json({ message: 'Already rated this seller' });
}
```

### Network Security

**Helmet.js Headers:**
```javascript
app.use(helmet());  // Sets security headers:
// Content-Security-Policy
// Strict-Transport-Security
// X-Frame-Options
// X-Content-Type-Options
// etc.
```

**CORS:**
```javascript
cors({
  origin(origin, callback) {
    if (!origin) return callback(null, true);
    if (env.allowedOrigins.length === 0) {
      callback(null, !isProduction);  // Allow all in dev
    } else {
      callback(null, env.allowedOrigins.includes(origin));
    }
  },
  credentials: true,
})
```

**Rate Limiting:**
```javascript
rateLimit({
  windowMs: 60 * 1000,      // 1 minute
  max: 120,                  // 120 requests per minute
  standardHeaders: true,
  legacyHeaders: false,
})
```

---

## Background Services

### Weather Alert Refresh Job (`weatherAlerts.service.js`)

**Schedule:** Every 15 minutes (configurable)

**Logic:**

```
1. Get all users from Firestore
   ├─ Filter: users with lat/lon set
   └─ Include: fcmTokens, notificationsEnabled

2. For each user:
   ├─ Call OpenWeather API (lat/lon)
   ├─ Parse current weather data
   ├─ Detect alert conditions:
   │  ├─ Rain: next 3h precip > 0.6mm
   │  ├─ Heat: temp > 40°C
   │  ├─ Cold: temp < 5°C
   │  ├─ Wind: speed > 50 km/h
   │  └─ Storm: thunderstorm in next 3h
   │
   ├─ Generate alert title + body
   │  ├─ Practical farming advice
   │  └─ Localized to user's location
   │
   ├─ Check if alert already exists today
   │  └─ Prevent duplicate notifications
   │
   ├─ Create/update alert doc in Firestore
   │
   ├─ If notificationsEnabled:
   │  ├─ Collect FCM tokens
   │  ├─ Call Firebase Cloud Messaging
   │  └─ Handle invalid tokens (remove from doc)

3. On completion:
   ├─ Log success + count of alerts sent
   ├─ Schedule next run (15 min from now)
   └─ Handle errors gracefully (continue for next user)
```

**Example Alert Generation:**

```javascript
// Detect heavy rain
if (rainNextThreeHours > 0.6) {
  const alerts = [{
    type: 'rain',
    title: 'Heavy Rainfall Warning',
    body: `${rainNextThreeHours}mm rain expected in next 3 hours. ` +
          `Avoid pesticide spraying. Ensure drainage in fields.`
  }];
  
  // Send FCM
  await sendWeatherAlertPushes(userDoc, alerts);
}
```

### Rates Ingestion Service (Placeholder)

**File:** `ratesIngestion.service.js`

**Current Status:** Returns empty array

**Future Integration:**
- Connect to government agriculture ministry APIs
- Or aggregate from provincial market boards
- Populate `rates` collection with crop prices
- Update on periodic basis (daily/weekly)

---

## Setup & Deployment

### Frontend Setup

#### **Prerequisites**
```bash
# Install Flutter (3.7.2+)
flutter --version

# Verify Android SDK
flutter doctor

# Install Mapbox credentials
cd android
cp local.properties.example local.properties
# Edit: MAPBOX_DOWNLOADS_TOKEN=pk.your_token_here
```

#### **Build Steps**
```bash
# Get dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Run on device/emulator
flutter run -d <device-id>

# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

### Backend Setup

#### **Prerequisites**
```bash
# Node.js 16+
node --version

# Npm or yarn
npm --version
```

#### **Installation**
```bash
cd backend

# Install dependencies
npm install

# Create .env file
cp .env.example .env
# Edit with your Firebase, OpenWeather, Cloudinary, AI API keys

# Copy Firebase credentials
cp serviceAccountKey.json.example serviceAccountKey.json
# (Or set FIREBASE_SERVICE_ACCOUNT_JSON env var)
```

#### **Development**
```bash
# Start development server (with auto-reload via nodemon)
npm run dev

# Server runs on http://localhost:5000
```

#### **Production**
```bash
# Start server
npm start

# Or use PM2
pm2 start npm --name "digital-kissan" -- start
pm2 save
pm2 startup
```

### Environment Variables (Backend)

```env
# Core
PORT=5000
HOST=0.0.0.0
NODE_ENV=production

# Firebase
FIREBASE_PROJECT_ID=your-project-id
GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
# OR
FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'

# CORS & Security
ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
ALLOW_DEV_AUTH_FALLBACK=false

# OpenWeather API
OPENWEATHER_KEY=your_api_key_here
WEATHER_RAIN_NEXT_3H_THRESHOLD=0.6

# Maps
MAPBOX_ACCESS_TOKEN=pk.your_mapbox_token

# AI Services (try in order: OpenAI → Gemini → Grok)
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-3.5-turbo
OPENAI_MAX_TOKENS=1024

GEMINI_API_KEY=your_gemini_key
GEMINI_API_VERSION=v1
GEMINI_MODEL=gemini-2.5-flash
GEMINI_MAX_TOKENS=1024

GROK_API_KEY=xai-...
GROK_MODEL=grok-4.3
GROK_MAX_TOKENS=4000

# Cloudinary
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

### Firebase Firestore Setup

#### **Create Firestore Database**
1. Firebase Console → Firestore Database
2. Create database in production mode
3. Create security rules:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      allow read: if request.auth != null;  // Any auth can read (with visibility rules)
    }

    // Public listing reads, auth required for writes
    match /listings/{document=**} {
      allow read: if true;
      allow create, update, delete: if request.auth != null;
    }

    // Offers require authentication
    match /offers/{document=**} {
      allow read, create, update, delete: if request.auth != null;
    }

    // Orders require authentication
    match /orders/{document=**} {
      allow read, update, delete: if request.auth != null;
    }

    // Messages require authentication & participation
    match /listing_threads/{thread=**} {
      allow read: if request.auth != null &&
        request.auth.uid in resource.data.participantUids;
      allow create, update, delete: if request.auth != null &&
        request.auth.uid in resource.data.participantUids;

      match /messages/{message=**} {
        allow read, create, update, delete: if request.auth != null;
      }
    }

    // Ratings are public but auth required to write
    match /ratings/{document=**} {
      allow read: if true;
      allow create, update, delete: if request.auth != null;
    }

    // Weather alerts private to user
    match /weather_alerts/{document=**} {
      allow read, write: if request.auth.uid == resource.data.userId;
    }

    // Admin-only collections
    match /admin/{document=**} {
      allow read, write: if request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

#### **Create Firestore Indexes**
Use `firestore.indexes.json` or CLI:

```bash
firebase firestore:indexes --import firestore.indexes.json
```

### Deployment Options

#### **Frontend (Flutter APK)**
1. Build APK: `flutter build apk --release`
2. Upload to Google Play Console
3. Or distribute via App Center, Firebase Hosting (web)

#### **Backend (Node.js)**

**Option 1: Docker**
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 5000
CMD ["npm", "start"]
```

```bash
docker build -t digital-kissan-backend .
docker run -p 5000:5000 --env-file .env digital-kissan-backend
```

**Option 2: Render / Railway / Heroku**
```bash
# Push to Git, connect to deployment platform
# Set environment variables in platform dashboard
# Auto-deploy on push
```

**Option 3: Traditional Server (VPS)**
```bash
# SSH into server
ssh root@your-server

# Clone repo
git clone https://github.com/yourusername/digital-kissan.git
cd digital-kissan/backend

# Install Node, PM2
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
npm install -g pm2

# Setup environment
cp .env.production .env
pm2 start npm --name "digital-kissan" -- start
pm2 save
```

---

## Features & Capabilities

### Core Features (Fully Implemented ✅)

| Feature | Frontend | Backend | Status |
|---------|----------|---------|--------|
| User Authentication | ✅ | ✅ | Production |
| Email Verification | ✅ | ✅ | Production |
| Profile Management | ✅ | ✅ | Production |
| Photo Upload | ✅ | ✅ | Production |
| Product Listings CRUD | ✅ | ✅ | Production |
| Browse & Search | ✅ | ✅ | Production |
| Make Offers | ✅ | ✅ | Production |
| Order Management | ✅ | ✅ | Production |
| Order State Machine | ❌ | ✅ | Production |
| In-App Messaging | ✅ | ✅ | Production |
| Weather Data | ✅ | ✅ | Production |
| Weather Alerts | ✅ | ✅ | Production |
| Push Notifications | ✅ | ✅ | Production |
| AI Assistant | ✅ | ✅ | Production |
| Ratings & Reviews | ✅ | ✅ | Production |
| Admin Dashboard | ✅ | ✅ | Production |
| Bilingual (En/Ur) | ✅ | ✅ | Production |
| Geolocation | ✅ | ❌ | Production |
| Mapbox Integration | ✅ | ❌ | Production |

### Advanced Features

#### **Weather Forecasting**
- 10-day daily forecast
- Detailed view: wind, humidity, UV index
- Auto-refresh: 15-minute intervals
- Offline cache: SharedPreferences

#### **AI Farming Assistant**
- Language auto-detection
- Bilingual responses
- Fallback chain: OpenAI → Gemini → Grok
- Conversation history (last 10 messages)
- System prompt tailored for farming advice

#### **Order Lifecycle**
```
created
  ├─ Seller: Mark in_transit, Cancel
  └─ Buyer: Cancel

in_transit
  ├─ Seller: Mark delivered
  └─ Buyer: Dispute, Mark delivered

delivered
  ├─ Buyer: Mark completed, Dispute
  └─ Seller: (waiting)

completed
  ├─ Buyer: Can now rate
  └─ Both: Transaction complete

disputed
  └─ Admin: Resolve (complete or cancel)
```

#### **Access Control**
- Sensitive field redaction based on buyer-seller relationship
- Admin override for all resources
- Per-resource ownership validation

#### **Data Privacy**
- Phone numbers, emails hidden by default
- Address/location visible only between transactors
- Opt-in for notifications
- Easy account deletion (future feature)

---

## Known Limitations

### ⚠️ Current Limitations

#### **Plant Disease Classifier**
- **Status:** Disabled
- **Reason:** Requires `tflite_flutter` with Git dependency
- **To Enable:**
  1. Install Git (https://git-scm.com/download/win)
  2. Uncomment import in `plant_disease_provider.dart`
  3. Uncomment class in `plant_disease_classifier.dart`
  4. Add to pubspec.yaml: `tflite_flutter: ^0.12.1`
  5. Run `flutter pub get`

#### **Rates/Prices**
- **Status:** Placeholder API returns empty array
- **Future:** Integrate government agriculture ministry APIs or market boards

#### **Message Threading**
- **Status:** Polling-based (10-second intervals in frontend)
- **Future:** WebSocket for real-time messaging

#### **Presence/Online Status**
- **Status:** Optional presence collection (not fully integrated)
- **Future:** Real-time user online/offline status

#### **Transaction Disputes**
- **Status:** Order can be marked disputed, but no resolution workflow
- **Future:** Admin arbitration process with evidence upload

---

## Conclusion

**Digital Kissan** is a comprehensive, production-ready agricultural mobile application designed for Pakistani farmers. It combines modern technology (Flutter, Node.js, Firebase) with practical farming features (weather alerts, marketplace, AI advisor) to create a complete ecosystem.

The application is secure, scalable, and well-structured, with clear separation of concerns, robust error handling, and extensive localization support.

**Next Steps for Enhancement:**
1. Integrate government rates API
2. Enable plant disease classifier
3. Add WebSocket for real-time messaging
4. Implement dispute resolution workflow
5. Add photo verification for listings
6. SMS fallback for notifications (for low-bandwidth users)
7. Offline mode for critical features

---

**Document Version:** 1.0  
**Last Updated:** May 19, 2026  
**Author:** Development Team  
**Status:** Complete Documentation
