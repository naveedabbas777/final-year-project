# Digital Kissan Agricultural Mobile App - Complete Code Analysis

## Executive Summary

Digital Kissan is a bilingual (English/Urdu) Flutter mobile application with a Node.js backend that provides comprehensive agricultural support to Pakistani farmers. The system integrates real-time weather alerts, marketplace functionality, crop pricing information, and plant disease detection to enable smart farming decisions.

**Architecture**: Flutter Frontend → Firebase Auth → Node.js REST API → MongoDB + Firebase Firestore  
**Key Users**: Farmers (primary), Buyers, Admin (marketplace managers)

---

# PART 1: FLUTTER MOBILE APP ARCHITECTURE

## 1. Main Entry Point

### **File**: `main.dart`

**Purpose**: Application bootstrap with Firebase initialization, Provider setup, and navigation routing.

**Key Logic**:
- Initializes Firebase and sets Mapbox access token globally
- Sets up FCM (Firebase Cloud Messaging) for push notifications
- Registers background message handler for when app is terminated
- Requests notification permissions for iOS/Android 13+
- Creates MultiProvider for state management (LanguageProvider, AuthProvider, PlantDiseaseProvider, AlertService, NotificationService)
- Renders DigitalKissanApp widget with Material 3 theme

**Navigation Flow**:
- App starts → SplashScreen (2 sec delay)
- If `authProvider.isSignedIn` → MainNavigationShell (5 tabs)
- Else → LoginScreenWrapper

**Bottom Navigation**:
1. Dashboard (Home)
2. Forecast (7-day weather)
3. Alerts (Weather-based alerts)
4. Market (Buy/Sell listings)
5. Settings

**Theme Configuration**:
- Primary color: Green (agriculture theme)
- Typography: Google Fonts (Noto Sans for Urdu support)
- Material Design 3 enabled

**Issues/Observations**:
- Mapbox token is hardcoded (should be in environment)
- No error handling for Firebase initialization failure
- Background message handler only logs, doesn't persist alerts

---

## 2. Authentication Flow

### **File**: `screens/login_screen.dart`

**Purpose**: Email/password authentication with multi-language support.

**Key Logic**:
- Email validation using regex pattern
- Password field with visibility toggle
- Checks email verification status after sign-in
- If not verified → EmailVerificationScreen
- If verified → MainNavigationShell
- Forgot password redirection
- Registration screen navigation
- Language selector (English/Urdu)

**Error Handling**:
- User-not-found: "No account found for this email. Please register first."
- wrong-password/invalid-credential: "Incorrect password or invalid credentials."
- network-request-failed: "Network issue detected. Please check internet and try again."
- too-many-requests: "Too many attempts. Please wait a moment and try again."
- Timeout exception (45 sec): Friendly network error message

**Database Operations**:
- None directly (Firebase Auth only)

**Issues/Observations**:
- `_hasNavigated` flag prevents multiple navigation attempts
- Uses `FirebaseAuth.instance.currentUser` directly to avoid Pigeon overhead
- Attempts automatic verification email sending

---

### **File**: `screens/registration_screen.dart`

**Purpose**: New user account creation with profile information.

**Key Logic**:
- Collects: Full name, email, country code + phone, password (with confirmation)
- Country codes dropdown (includes +92, +1, +44, +91, etc.)
- Multi-step registration:
  1. Firebase account creation with email/password
  2. Firestore user profile creation
  3. Email verification email sending
  4. Navigation to EmailVerificationScreen

**Validation**:
- Name: Non-empty
- Email: Valid format (regex)
- Phone: Non-empty
- Password: Min 6 characters, must match confirmation

**Error Handling**:
- email-already-in-use: "This email is already registered..."
- weak-password: "Password is too weak. Use at least 6 characters."
- network-request-failed, too-many-requests: Friendly messages
- Timeout after 45 seconds for Firebase operations

**Database Operations**:
- `_auth.registerWithEmailPassword()` → Firebase Auth
- `_firebaseService.createUserIfNotExists()` → Firestore (users collection)
- Stores: uid, email, displayName, phoneNumber, createdAt timestamp

**Issues/Observations**:
- Handles Firebase init failure gracefully (continues anyway)
- Stores full phone as `countryCode + phone_digits`
- Uses `SetOptions(merge: true)` to avoid overwriting existing data

---

### **File**: `screens/email_verification_screen.dart`

**Purpose**: Verifies user email before allowing app access.

**Key Logic**:
- Shows email address user registered with
- Provides "Check verification" button to reload user status
- Provides "Resend verification email" button
- "Continue to login" button only enabled if verified
- "Back to login" button signs out user

**Status Indicators**:
- Green (verified) → Icon: verified
- Orange (checking) → Icon: hourglass_top
- Red (not verified) → Icon: mark_email_unread

**Error Handling**:
- too-many-requests: "Too many requests. Please try again in a moment."
- network-request-failed: "Network issue detected. Please check internet and retry."
- Generic Firebase errors: Show e.message

**Flow**:
- User verified → Navigator.pop(true) → MainNavigationShell
- User not verified → Navigator.pop(false) → Back to login
- If user manually signs out → Signs out via AuthService

**Issues/Observations**:
- Uses `PopScope(canPop: false)` to prevent back navigation
- Reloads user status with `_auth.reloadCurrentUser()`
- Sign-out happens only if user manually chooses to go back

---

### **File**: `screens/forgot_password_screen.dart`

**Purpose**: Password reset via email link.

**Key Logic**:
- Input: Email address
- Sends password reset email via Firebase Auth
- Shows dialog: "If this email is registered, a reset link has been sent"
- Returns to login screen after completion

**Error Handling**:
- invalid-email: "Please enter a valid email address."
- operation-not-allowed: "Password reset is currently disabled in Firebase."
- network-request-failed: "Network issue detected..."
- user-not-found: "No account found for this email..."
- too-many-requests: "Too many attempts..."

**Issues/Observations**:
- Shows same message regardless of whether email exists (security best practice)
- No timeout handling (may hang indefinitely)

---

## 3. State Management (Providers)

### **File**: `providers/auth_provider.dart`

**Purpose**: Manages authentication state and Firebase user document lifecycle.

**Key Logic**:
- Listens to `FirebaseAuth.authStateChanges()` stream
- For each auth state change:
  1. Updates `_user` and notifies listeners
  2. If user signed in:
     - Calls `_firestoreService.createUserIfNotExists()` to ensure user doc exists
     - Updates FCM token in Firestore for push notifications
  3. If user signed out:
     - Clears `_user` to null

**State Variables**:
- `_user`: Current Firebase User or null
- `_sub`: Stream subscription

**Public Methods**:
- `get user` → Current User
- `get isSignedIn` → bool (user != null)
- `signOut()` → Calls FirebaseAuth.signOut()

**Database Operations**:
- Creates/updates Firestore `users/{uid}` document
- Stores: uid, email, displayName, phoneNumber, createdAt, fcmToken

**Issues/Observations**:
- Silent error handling on background operations (logs to console, doesn't crash app)
- FCM token updated every time auth state changes (efficient)
- Subscription cleaned up in dispose()

---

### **File**: `providers/language_provider.dart`

**Purpose**: Manages app language (English/Urdu) for localization.

**Key Logic**:
- Default locale: English ('en', '')
- Supported locales: English, Urdu
- `setLocale()` validates locale before updating
- Notifies listeners on language change

**Public Methods**:
- `get locale` → Current Locale
- `setLocale(Locale locale)` → Updates locale if valid

**Issues/Observations**:
- Language preference not persisted to SharedPreferences
- No locale persistence between app sessions

---

### **File**: `providers/plant_disease_provider.dart`

**Purpose**: Plant disease classification from image (DISABLED).

**Status**: Disabled due to tflite_flutter Git dependency

**Key Logic** (commented out):
- Would load TensorFlow Lite model from assets
- Preprocess image: Resize to model input dimensions, normalize RGB values
- Run inference through interpreter
- Parse output and sort predictions by confidence score
- Return top-K predictions

**Current State**:
- `classifyBytes()` sets error message: "Plant disease detection is disabled (requires Git for tflite_flutter)"
- Model file exists at `assets/model/model.tflite`
- Labels file exists at `assets/model/labels.txt`

**To Enable**:
1. Install Git from https://git-scm.com/download/win
2. Uncomment tflite_flutter import and classifyBytes implementation
3. Add "tflite_flutter: ^0.12.1" to pubspec.yaml
4. Run `flutter pub get`

---

## 4. Authentication & Firebase Services

### **File**: `services/auth_service.dart`

**Purpose**: Firebase Authentication wrapper with email/password auth.

**Public Methods**:

| Method | Purpose |
|--------|---------|
| `signInAnonymously()` | Anonymous sign-in (unused in current flow) |
| `signOut()` | Sign out current user |
| `registerWithEmailPassword({email, password})` | Create new account |
| `signInWithEmailPassword({email, password})` | Sign in with credentials |
| `sendPasswordResetEmail({email})` | Send password reset link |
| `sendCurrentUserVerificationEmail()` | Send verification link to current user |
| `reloadCurrentUser()` | Reload user data from Firebase |
| `get currentUser` | Returns FirebaseAuth.instance.currentUser |

**Error Handling**: All methods rethrow exceptions with debug logging

**Issues/Observations**:
- No custom error messages (rethrows raw FirebaseAuthException)
- Async operations timeout after ~45 seconds
- All methods log to console in debug mode

---

### **File**: `services/firebase_service.dart`

**Purpose**: Firestore database operations for user profiles and general data.

**Key Collections**:
- `users/{uid}`: User profile documents
- `messages`: Sample message collection (debug only)

**Public Methods for Users**:

| Method | Purpose | Operation |
|--------|---------|-----------|
| `createUserIfNotExists(User, {displayName, phoneNumber})` | Ensure user doc exists on signup/login | CREATE or UPDATE |
| `getUserByUid(uid)` | Fetch user by Firebase UID | READ |
| `getUserByPhone(phoneNumber)` | Fetch user by phone number | READ |
| `updateUserProfile(uid, {displayName, phoneNumber})` | Update user profile | UPDATE |
| `updateNotificationPreference(uid, enabled)` | Enable/disable notifications | UPDATE |
| `updateUserNotificationData(uid, {fcmToken, lat, lon, address, ...})` | Store location + FCM token | UPDATE |

**User Document Schema**:
```json
{
  "uid": "firebase-uid",
  "email": "user@example.com",
  "displayName": "User Name",
  "phoneNumber": "+923001234567",
  "isAnonymous": false,
  "notificationsEnabled": true,
  "fcmToken": "firebase-fcm-token",
  "lat": 33.7128,
  "lon": 74.2241,
  "address": "Lahore, Pakistan",
  "createdAt": Timestamp,
  "passwordHash": FieldValue.delete() // Legacy field cleanup
}
```

**Data Normalization**:
- Timestamps converted from Firestore Timestamp to DateTime
- Empty fields deleted via `FieldValue.delete()`
- All updates use `merge: true` to avoid overwriting

**Issues/Observations**:
- `createUserIfNotExists()` silently deletes legacy `passwordHash` field
- Phone index is sparse (allows nulls) and unique (prevents duplicates)
- Location updates intended for weather alert targeting

---

### **File**: `services/notification_service.dart`

**Purpose**: Local notifications and FCM integration.

**Initialization**:
- Sets up flutter_local_notifications plugin
- Initializes Android/iOS notification channels
- Registers FCM foreground listener
- Requests notification permissions

**Public Methods**:

| Method | Purpose |
|--------|---------|
| `init()` | Initialize notification system on app startup |
| `requestNotificationPermissions()` | Request OS notification permissions |
| `getFcmToken()` | Get device FCM token for server registration |
| `showNotification({id, title, body, payload})` | Show local notification |

**Notification Channels**:
- Channel ID: 'your_channel_id'
- Channel Name: 'your_channel_name'
- Android: max importance, high priority
- iOS: default settings

**FCM Integration**:
- `FirebaseMessaging.onMessage`: Foreground handler → shows local notification
- `FirebaseMessaging.onMessageOpenedApp`: Handles tap on background notification
- `FirebaseMessaging.instance.getInitialMessage()`: Handles app open from terminated state

**Permission Handling**:
- iOS: Uses permission_handler + FCM permissions
- Android 13+: Requests POST_NOTIFICATIONS permission
- Older Android: Permission granted at install time

**Issues/Observations**:
- Respects user's notification preference from SharedPreferences
- Returns true/false to indicate if notification actually shown
- Payload passed as JSON string to notification tap handlers

---

## 5. Weather & Alert Services

### **File**: `services/weather_service.dart`

**Purpose**: Fetches weather data from OpenWeather API and parses into model objects.

**API Endpoints Used**:
- Current: `https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&units=metric&appid={key}`
- Forecast: `https://api.openweathermap.org/data/2.5/forecast?lat={lat}&lon={lon}&units=metric&appid={key}`

**API Key**: `56b582e0e133537210a6fb19d53b805c` (hardcoded - security risk!)

**Data Models**:

**CurrentWeather**:
```dart
temperature, description, icon, windSpeed, windDirection, windDegree,
precipitation, humidity, cloudCover, sunrise, sunset
```

**DailyForecast**:
```dart
day, description, maxTemperature, minTemperature, avgTemperature, icon,
pop (probability of precipitation), uv, avgHumidity, visibilityKm,
sunrise, sunset, moonPhase, maxWindSpeed, windDirection, windDegree,
cloudCoverage, hourlyForecasts[]
```

**HourlyForecast**:
```dart
time, temperature, icon, description, chanceOfRain
```

**Data Processing**:
- Transforms OpenWeather "weather" + "forecast" endpoints into One Call format
- Groups 3-hourly forecast data into daily aggregates
- Calculates min/max temps, average humidity, probability of precipitation
- Converts timestamps to human-readable times (Intl package)
- Converts wind degrees (0-360°) to compass directions (N, NNE, NE, etc.)

**Helper Functions**:
- `_degToCompass(int? deg)`: Degree → Cardinal direction (16-point compass)
- `_extractPrecip(Map)`: Extracts rain/1h or snow/1h from current data
- `_formatTime(int? epochSeconds)`: Formats Unix timestamp to "h:mm a"
- `_toOneCallCurrent()`: Transforms current endpoint to One Call format
- `_toDailyFromForecast()`: Groups 3-hourly forecast into daily summaries

**Issues/Observations**:
- API key exposed in client code (should use backend proxy)
- No retry logic for API failures
- Manual transformation of API response (fragile to API changes)

---

### **File**: `services/alert_service.dart`

**Purpose**: Generates weather-based alerts and manages alert persistence.

**Alert Types**:
| Type | Condition |
|------|-----------|
| rain | Probability of precipitation ≥ 50% OR current precipitation > 0.1mm |
| heat | Current temperature ≥ 35°C |
| cold | Current temperature ≤ 5°C |
| wind | Current wind speed ≥ 10 m/s |

**AlertItem Model**:
```dart
{
  id: string (microsecond timestamp),
  type: 'rain' | 'heat' | 'cold' | 'wind',
  title: string,
  body: string,
  createdAt: DateTime
}
```

**Persistence**:
- Storage key: 'saved_alerts' (SharedPreferences)
- Max items: 50
- Max age: 7 days
- Automatically prunes old/excess alerts

**Public Methods**:

| Method | Purpose |
|--------|---------|
| `loadAlerts()` | Load alerts from SharedPreferences |
| `clearAlerts()` | Clear all stored alerts |
| `processWeather(CurrentWeather?, DailyForecast?)` | Analyze weather and generate alerts if needed |

**Alert Generation Logic**:
- Checks if alert of same type already exists today
- If condition met AND no duplicate today → Create alert
- Shows local notification via NotificationService
- Persists to SharedPreferences

**Notification Integration**:
- Calls `notificationService.showNotification()` for each new alert
- Passes alert data as JSON payload

**Issues/Observations**:
- Checks `createdAt.isBefore(start)` to detect today's alerts (naive, only checks date)
- No deduplication across multiple alert checks in same minute
- Alert thresholds hardcoded (35°C heat, 5°C cold, 10 m/s wind)

---

### **File**: `services/market_api_service.dart`

**Purpose**: Marketplace API communication via ApiClient wrapper.

**Data Transfer Objects (DTOs)**:

**UserProfileDto**:
```dart
firebaseUid, name, phone, role, district, province
```

**CropRateDto**:
```dart
id, cropName, marketName, district, minPrice, maxPrice, unit,
sourceName, sourceUrl, rateDate
```

**ListingDto**:
```dart
id, cropName, qualityGrade, quantity, unit, askingPrice, district,
sellerUid, status, createdAt, imageUrls[]
```

**OfferDto**:
```dart
id, listingId, buyerUid, offerPrice, quantity, status, createdAt, listing?
```

**OrderDto**:
```dart
id, listingId, offerId, buyerUid, sellerUid, finalPrice, quantity, unit,
status, createdAt
```

**Public Methods**:

| Endpoint | Method | Auth |
|----------|--------|------|
| `/api/rates/latest` | GET | No |
| `/api/listings` | GET | No |
| `/api/listings` | POST | Yes |
| `/api/offers` | POST | Yes |
| `/api/offers/me` | GET | Yes |
| `/api/offers/incoming` | GET | Yes |
| `/api/offers/{id}/accept` | POST | Yes |
| `/api/offers/{id}/reject` | POST | Yes |
| `/api/offers/{id}/cancel` | POST | Yes |
| `/api/uploads/listing-image` | POST | Yes |
| `/api/users/me` | GET | Yes |

**Issues/Observations**:
- Query parameters use trim() to clean input
- Image URLs stored as array of strings
- Status enum: 'open', 'reserved', 'sold', 'cancelled' (listings)
- Offer statuses: 'pending', 'accepted', 'rejected', 'cancelled'

---

### **File**: `services/api_client.dart`

**Purpose**: HTTP client wrapper with Firebase authentication.

**Features**:
- Constructs requests with proper headers and auth
- Handles Bearer token injection from Firebase IDToken
- JSON request/response serialization
- Error response parsing and re-throwing
- File upload support (multipart/form-data)

**Public Methods**:

| Method | Purpose | Headers |
|--------|---------|---------|
| `get(path, {query, auth})` | GET request | JSON |
| `post(path, {body, auth})` | POST request | JSON |
| `patch(path, {body, auth})` | PATCH request | JSON |
| `uploadFile(path, {fieldName, filePath, auth})` | Multipart file upload | Multipart |

**Base URL**: `http://10.224.247.221:5000` (from AppConfig, hardcoded!)

**Auth Flow**:
- If `auth=true`:
  - Gets current Firebase user
  - Calls `getIdToken(true)` to refresh token
  - Adds header: `Authorization: Bearer {idToken}`

**Response Handling**:
- Status 200-299: Parse JSON and return
- Status ≥ 300: Extract error message from `response.message` or use status text
- Empty body: Return null

**Issues/Observations**:
- Base URL hardcoded to development machine (10.224.247.221:5000)
- No retry logic on failure
- Firebase IDToken refresh on every request (could cache)
- File upload returns full URL (built from request origin)

---

## 6. Main Screens

### **File**: `screens/splash_screen.dart`

**Purpose**: Loading screen shown for 2 seconds before routing to login/dashboard.

**UI Elements**:
- Green agriculture icon (Icons.agriculture)
- App title: "Digital Kissan App"
- App tagline: "Smart Agriculture for Farmers"
- Loading spinner

**Background Color**: Green.shade100

**Navigation**: Handled in main.dart after 2-second delay

---

### **File**: `screens/dashboard_screen.dart`

**Purpose**: Main home screen showing current weather, quick tips, and alerts.

**Layout Structure**:
1. **Location Section** (Editable via LocationScreen)
   - Current saved address
   - Edit icon to change location

2. **Current Weather Card** (FutureBuilder)
   - Temperature with icon
   - Weather description
   - Sunrise/Sunset times
   - Rain probability (if > 0)

3. **Quick Tips Carousel** (PageView)
   - Auto-scrolls through 5 farming tips every 3 seconds
   - Pauses on user interaction
   - Manual navigation possible
   - Tips: Avoid pesticide, Irrigate fields, Check soil moisture, Delay fertilizer, Harvest early

4. **Suggestions Card**
   - Expandable list of farming recommendations based on weather

5. **Recent Alerts** (ListView)
   - Shows latest weather alerts (max 3)
   - Color-coded by type (rain=blue, heat=orange, cold=teal, wind=indigo)

**State Management**:
- `_savedAddress`: Current location from SharedPreferences
- `_latitude`, `_longitude`: Coordinates for weather API
- `_currentWeatherFuture`: Fetches current weather via WeatherService
- `_todayForecastFuture`: Fetches today's forecast
- `_tipsPageController`: Manages carousel pagination
- `_tipsAutoScrollTimer`: Auto-scroll timer

**Alert Processing**:
- Dashboard triggers `AlertService.processWeather()` on load
- Checks weather every 60 minutes via timer
- Auto-generates and displays alerts

**Icon Mapping** (Weather conditions):
- 01x (clear): Sunny/Moon icon
- 02-04x (clouds): Cloud icon
- 09-10x (rain): Grain/Rain icon
- 11x (thunder): Thunderstorm icon
- 13x (snow): Snowflake icon
- 50x (mist): Foggy icon

**Issues/Observations**:
- Tips carousel uses fixed 3-second interval (not user-adjustable)
- Weather icon mapping fragile (relies on specific OpenWeather codes)
- Alert UI limits display to 3 alerts (should be scrollable)
- No pull-to-refresh functionality

---

### **File**: `screens/forecast_screen.dart`

**Purpose**: 7-day weather forecast display.

**Data Fetching**:
- Loads location from SharedPreferences
- Calls WeatherService with lat/lon
- Aggregates 3-hourly forecast into daily summaries
- Groups by date (yyyy-MM-dd)

**UI Components**:
- AppBar with "7-Day Forecast" title
- ListView of DailyForecast cards
- Each card shows:
  - Day name (EEE, MMM d format)
  - Weather icon
  - High/Low temperature
  - Wind direction + speed
  - Probability of rain
  - Visibility
  - Tap to view detailed forecast

**Sorting**:
- Oldest forecast first (ascending date order)

**Issues/Observations**:
- No refresh indicator (manual reload needed)
- Forecast cards not clickable on web (if cross-platform)

---

### **File**: `screens/detailed_forecast_screen.dart`

**Purpose**: Detailed view of single day's forecast with hourly breakdown.

**Content**:
1. **Main Card** (centered)
   - Large weather icon
   - Description
   - Max/Min/Avg temperature
   - Chance of rain with color coding

2. **Daily Details Card** (key metrics)
   - UV index
   - Average humidity (%)
   - Chance of rain
   - Visibility (km) with status (Excellent/Good/Moderate/Poor/Very Poor)
   - Max wind speed
   - Wind direction
   - Sunrise/Sunset times
   - Moon phase

3. **Hourly Forecast** (horizontal scroll)
   - Grid of hourly cards (100px width)
   - Time, weather icon, temperature, rain chance
   - Rain chance in badge if > 0

**Visibility Logic**:
- Converts meters to km (if > 100)
- Maps to status: ≥10km (Excellent), ≥6km (Good), ≥3km (Moderate), ≥1km (Poor), <1km (Very Poor)
- Colors: Green → Yellow → Orange → Deep Orange → Red

**Issues/Observations**:
- Hourly forecast requires manually scrolling (no pagination)
- Visibility conversion assumes meters (could be km from some sources)

---

### **File**: `screens/alerts_screen.dart`

**Purpose**: Display all weather-based alerts with type indicators.

**Data Fetching**:
- Loads alerts from AlertService on init
- Displays in reverse chronological order (newest first)

**Alert Display**:
- CircleAvatar with type-specific icon + background color
- Title (bold)
- Formatted timestamp (yMMMd + time)
- Full alert body text

**Alert Type Icons**:
- Rain: Water droplet (blue background)
- Heat: Sun (orange background)
- Cold: Snowflake (teal background)
- Wind: Air/Wind icon (indigo background)
- Other: Warning icon (grey background)

**Empty State**:
- Shows: "No alerts yet. Alerts will appear here when weather conditions trigger them."

**Issues/Observations**:
- No manual alert dismissal
- No filtering by type
- No sorting options

---

### **File**: `screens/market_screen.dart`

**Purpose**: Marketplace with two tabs: Crop Rates and Buy/Sell Listings.

**Tab 1: Rates Tab**:
- Search by crop name and district
- Filter button to load rates (GET /api/rates/latest)
- Admin-only "Ingest Official Rates" button (triggers POST /api/rates/ingest/official)
- List view of CropRateDto items

**Tab 2: Marketplace Tab**:
- Search listings by crop and district
- Create new listing form:
  - Crop name, District, Quantity, Price
  - Image picker (up to 5 images)
  - Upload images via /api/uploads/listing-image
  - Submit creates listing via POST /api/listings
- Browse listings with:
  - Crop name + grade + district
  - Quality grade (A/B/C)
  - Min quantity + unit
  - Tap to make offer dialog

**Offer Dialog**:
- Prompt for offer price and quantity
- Sends offer via POST /api/offers
- Shows success/error snackbar

**Issues/Observations**:
- No pagination for long listing lists
- Image picker limited to 5 images (hardcoded)
- No image preview before upload
- Rates ingestion returns empty (service is placeholder)

---

### **File**: `screens/offers_screen.dart`

**Purpose**: Manage buy/sell offers with two tabs.

**Tab 1: My Offers** (Offers user placed as buyer)
- Lists all offers with status pending/accepted/rejected/cancelled
- For pending offers: Cancel button
- Shows listing details: crop, district, offering price, quantity

**Tab 2: Incoming Offers** (Offers seller received)
- Lists all incoming offers for user's listings
- For pending offers: Accept/Reject buttons
- Accept flow:
  1. Sets offer status to "accepted"
  2. Rejects all other pending offers for same listing
  3. Marks listing as "reserved"
  4. Creates Order document

**Data Fetching**:
- My offers: GET /api/offers/me (populated with listing details)
- Incoming: GET /api/offers/incoming (finds all offers on user's listings)

**Issues/Observations**:
- No real-time updates (must manually refresh)
- Accepts only show pending offers (rejected/cancelled hidden)
- No confirmation dialogs before accept/reject

---

### **File**: `screens/orders_screen.dart`

**Purpose**: View order history and update order status.

**Display**:
- Lists all orders (buyer or seller side)
- Shows: Order ID (first 8 chars), Price, Quantity + Unit, Current status
- Status choice chips for manual updates

**Order Statuses**:
- created, in_transit, delivered, completed, cancelled, disputed

**Data Fetching**:
- GET /api/orders/me returns orders where user is buyer OR seller

**Status Updates**:
- PATCH /api/orders/{id}/status allows any participant to change status
- Updates persisted to MongoDB

**Issues/Observations**:
- No validation of status transitions (e.g., can go backward)
- All participants (buyer, seller, admin) can change status
- No timestamp tracking of status changes
- Order ID truncated to 8 chars in UI

---

### **File**: `screens/profile_screen.dart`

**Purpose**: Display user profile information and edit capability.

**Display**:
- Avatar with first letter of name
- User profile card:
  - Full name
  - Phone number
  - Member since (formatted date)

**Edit Profile**:
- Dialog with name and phone fields
- Saves via `FirebaseService.updateUserProfile(uid, ...)`
- Updates Firestore directly

**Sign Out**:
- Button clears auth and returns to LoginScreenWrapper

**Data Fetching**:
- Loads from Firestore users collection on init
- Falls back to SharedPreferences if no Firestore data

**Issues/Observations**:
- Phone number display doesn't parse country code
- No validation on edit form
- No loading state during save

---

### **File**: `screens/settings_screen.dart`

**Purpose**: App configuration and testing utilities.

**Sections**:
1. **User Info**
   - Shows Firebase UID
   - Sign out button

2. **Language**
   - Dropdown to switch English/Urdu
   - Updates via LanguageProvider

3. **Notifications**
   - Toggle to enable/disable
   - Requests OS permissions if enabling
   - Stores preference in SharedPreferences
   - Updates Firestore preference

4. **Location**
   - Shows current saved location
   - Button to navigate to LocationScreen
   - Dynamically reloads after location change

5. **About App**
   - Version 1.0
   - Description: "Digital Kissan App for smart agriculture"

6. **Contact Support**
   - Placeholder (no action)

7. **Test Actions** (Developer utilities):
   - "Save sample data to Firebase": Writes test message
   - "Show Test Notification": Triggers local notification

**Issues/Observations**:
- Test actions exposed in production (should be debug-only)
- Notification toggle doesn't query system permission status initially
- Language changes don't persist between sessions

---

### **File**: `screens/plant_disease_screen.dart`

**Purpose**: Plant disease detection via TensorFlow Lite model.

**Status**: Disabled on web, enabled on mobile (but model loading is commented out).

**Current Flow**:
1. Pick image from gallery
2. Display picked image
3. Run classification (currently shows error message)
4. Display predictions as list (label + confidence %)

**Image Picker**:
- Using image_picker package
- Source: Gallery only
- No camera option

**UI**:
- App bar with title
- Picked image display (220px height)
- Pick image button
- Predictions list (if any)

**Issues/Observations**:
- tflite_flutter disabled entirely (commented out)
- Error message permanent: "Plant disease detection is disabled..."
- No loading indicator during classification
- No image size validation

---

### **File**: `screens/location_screen.dart`

**Purpose**: Set/update user location with map visualization.

**Features**:
1. **Map View** (Mapbox)
   - Centered on saved location or current GPS position
   - Draggable marker
   - Satellite/Standard toggle

2. **Location Services**
   - Geolocator: Get current GPS position
   - Geocoding: Convert coordinates ↔ address
   - Permissions handling for location access

3. **Search/Manual Entry**
   - TextField to search address
   - Searches via geocoding.locationFromAddress()
   - Updates map and marker

4. **Save Location**
   - Persists to SharedPreferences (last_latitude, last_longitude, last_address)
   - Updates Firestore users document (lat, lon, address fields)

**Marker Image**:
- Loads from assets/marker.png
- Displayed on map as custom annotation

**Permission Handling**:
- Checks location service enabled
- Requests permission if denied
- Guides to app settings if permanently denied

**Issues/Observations**:
- Marker image loading deferred (causes initial null error)
- No map interaction feedback (silent success)
- Address parsing joins multiple location fields with commas
- Map lifecycle not properly managed (potential memory leak)

---

### **File**: `screens/suggestions_screen.dart`

**Purpose**: Display farming recommendations based on weather/season.

**Suggestions** (5 items):
| Title | Icon | Reason |
|-------|------|--------|
| Avoid pesticide spraying today | bug_report | Wind or rain spreads chemicals poorly |
| Irrigate fields tomorrow | water_drop | Light irrigation reduces heat stress |
| Check soil moisture | analytics | Prevents overwatering and fungus |
| Delay fertilizer application | grass | Rain washes away nutrients |
| Harvest early due to rain | agriculture | Protects crop quality before rain spoils it |

**UI**:
- Expandable tiles (ExpansionTile)
- Each has icon + title above, reason below
- Color scheme: Green themed

**Localization**:
- All titles and reasons fetched from AppLocalizations
- Supports English/Urdu

**Issues/Observations**:
- Suggestions are static (don't change based on actual weather)
- No timestamps on suggestions
- No ability to dismiss or mark as read

---

## 7. Widgets

### **File**: `widgets/tip_card.dart`

**Purpose**: Reusable card component for farming tips (used in dashboard carousel).

**Properties**:
- `text`: Tip content string

**Styling**:
- Background: Green.shade100
- Icon: Tips and updates icon
- Shadow: Subtle
- Border radius: 12px

---

## 8. Configuration & Localization

### **File**: `config/app_config.dart`

**Purpose**: Centralized app configuration.

**Configuration**:
```dart
static const String apiBaseUrl = 'http://10.224.247.221:5000';
```

**Issue**: Hardcoded IP address (development only)

---

### **Files**: `l10n/app_en.arb` and `l10n/app_ur.arb`

**Purpose**: Localization strings for English and Urdu.

**Supported Strings** (100+ keys):
- UI labels: appTitle, dashboard, home, forecast, alerts, settings
- Messages: welcomeMessage, loginDescription
- Tips and suggestions: avoidPesticide, irrigateFields, etc.
- Error messages: errorFetchingWeather, locationPermissionsDenied
- Field labels: language, notifications, location

**Generated Files** (auto-generated):
- `app_localizations.dart`: Main translations class
- `app_localizations_en.dart`: English implementation
- `app_localizations_ur.dart`: Urdu implementation

**Usage**:
```dart
Text(AppLocalizations.of(context)!.appTitle)
```

---

# PART 2: NODE.JS BACKEND ARCHITECTURE

## Server Setup

### **File**: `server.js`

**Purpose**: Application entry point and server launcher.

**Startup Flow**:
1. Connects to MongoDB
2. Initializes Firebase Admin SDK
3. Creates Express app
4. Listens on port 5000 (or process.env.PORT)

**Error Handling**:
- Catches startup errors and logs to console
- Exits process if connection fails

---

### **File**: `app.js`

**Purpose**: Express app creation with middleware and routing setup.

**Middleware Stack**:
1. **CORS**: Allows cross-origin requests
   - Origin checking from env.allowedOrigins
   - Credentials enabled

2. **Express.json**: JSON body parsing (2MB limit)

3. **Static Files**: Serves `/uploads` directory

**Routes**:
- `GET /api/health` → Health check
- `/api/users` → User management
- `/api/rates` → Crop rates
- `/api/listings` → Marketplace listings
- `/api/offers` → Offers
- `/api/orders` → Orders
- `/api/uploads` → File uploads

**Error Handler**:
- Global error middleware catches all route errors
- Responds with status code + error message

---

## Configuration

### **File**: `config/env.js`

**Purpose**: Environment variable management.

**Variables**:
| Variable | Default | Purpose |
|----------|---------|---------|
| PORT | 5000 | Server port |
| MONGO_URI | mongodb://127.0.0.1:27017/digital_kissan | MongoDB connection |
| ALLOWED_ORIGINS | (empty) | CORS allowed origins |
| FIREBASE_PROJECT_ID | (empty) | Firebase project for authentication |

**Parsing**:
- Loads from `.env` file via dotenv
- Splits ALLOWED_ORIGINS by comma into array

---

### **File**: `config/db.js`

**Purpose**: MongoDB connection setup.

**Options**:
- `autoIndex: true` - Auto-creates indexes on schema definitions

---

### **File**: `config/firebaseAdmin.js`

**Purpose**: Firebase Admin SDK initialization for token verification.

**Initialization Modes**:

**Mode 1: Production** (with service account key):
- Loads `serviceAccountKey.json` from project root
- Uses official Firebase authentication

**Mode 2: Development** (fallback):
- Uses FIREBASE_PROJECT_ID from env
- Uses GOOGLE_APPLICATION_CREDENTIALS env variable
- Falls back to mock auth if Firebase unavailable

**Mock Auth** (for development without Firebase):
- Extracts uid/email from JWT payload
- Creates mock user object if parsing fails

**Issues/Observations**:
- Silently falls back to development mode if Firebase unavailable
- Mock auth less secure than Firebase verification

---

## Models

### **File**: `models/user.model.js`

**Purpose**: User profile document schema.

**Schema Fields**:

| Field | Type | Constraints | Purpose |
|-------|------|-----------|---------|
| firebaseUid | String | required, unique, indexed | Link to Firebase Auth |
| name | String | trim | User's full name |
| phone | String | sparse, unique with countryCode | Phone number |
| countryCode | String | default '+92' | Country code (+92 for Pakistan) |
| role | Enum | enum: farmer/buyer/admin, default: farmer | User role |
| district | String | trim | User's district |
| province | String | trim | User's province |
| timestamps | - | auto | createdAt, updatedAt |

**Indexes**:
- Primary: firebaseUid (unique)
- Compound: (phone, countryCode) unique, sparse

**Relationships**:
- Referenced by Listing.sellerRef
- Referenced by Offer.buyerRef

---

### **File**: `models/listing.model.js`

**Purpose**: Product/crop marketplace listing.

**Schema Fields**:

| Field | Type | Purpose |
|-------|------|---------|
| sellerUid | String | Firebase UID of seller |
| sellerRef | ObjectId | Reference to User document |
| cropName | String | Crop type (e.g., "Wheat", "Rice") |
| qualityGrade | String | Grade A/B/C |
| quantity | Number | Amount available |
| unit | String | Unit of measurement (e.g., "40kg") |
| askingPrice | Number | Price per unit |
| district | String | Geographic location |
| description | String | Product description |
| imageUrls | Array[String] | URLs to product images |
| status | Enum | open/reserved/sold/cancelled |

**Indexes**:
- sellerUid (indexed)
- cropName, district, status, createdAt

**Statuses**:
- **open**: Available for offers
- **reserved**: Accepted offer, pending order completion
- **sold**: Transaction completed
- **cancelled**: Listing withdrawn

---

### **File**: `models/offer.model.js`

**Purpose**: Buyer's offer on a listing.

**Schema Fields**:

| Field | Type | Purpose |
|-------|------|---------|
| listingId | ObjectId | Reference to Listing |
| buyerUid | String | Firebase UID of buyer |
| buyerRef | ObjectId | Reference to User document |
| offerPrice | Number | Offered price |
| quantity | Number | Quantity being offered |
| status | Enum | pending/accepted/rejected/cancelled |

**Statuses**:
- **pending**: Awaiting seller response
- **accepted**: Seller agreed, Order created
- **rejected**: Seller declined
- **cancelled**: Buyer withdrew offer

---

### **File**: `models/order.model.js`

**Purpose**: Finalized transaction between buyer and seller.

**Schema Fields**:

| Field | Type | Purpose |
|-------|------|---------|
| listingId | ObjectId | Reference to Listing |
| offerId | ObjectId | Reference to accepted Offer |
| buyerUid | String | Firebase UID of buyer |
| sellerUid | String | Firebase UID of seller |
| finalPrice | Number | Final agreed price |
| quantity | Number | Quantity |
| unit | String | Unit of measurement |
| status | Enum | Order progress status |

**Order Statuses**:
- **created**: Order just created from accepted offer
- **in_transit**: Item in delivery
- **delivered**: Item received by buyer
- **completed**: Transaction finished
- **cancelled**: Order cancelled
- **disputed**: Issue raised by buyer/seller

**Indexes**:
- buyerUid + createdAt (for buyer's order history)
- sellerUid + createdAt (for seller's order history)

---

### **File**: `models/cropRate.model.js`

**Purpose**: Market price information for crops.

**Schema Fields**:

| Field | Type | Purpose |
|-------|------|---------|
| cropName | String | Crop type |
| marketName | String | Market/mandi name |
| district | String | Geographic location |
| minPrice | Number | Minimum price |
| maxPrice | Number | Maximum price |
| unit | String | Unit (e.g., "40kg sack") |
| sourceName | String | Source/authority name |
| sourceUrl | String | URL to source |
| isOfficialSource | Boolean | From official govt source? |
| rateDate | Date | Date of rate information |

**Indexes**:
- (cropName, district, rateDate) for efficient queries

**Purpose**: Helps farmers see market rates before selling

---

## Middleware

### **File**: `middlewares/auth.js`

**Purpose**: Firebase token verification and user authentication.

**Function: `requireAuth(req, res, next)`**

**Flow**:
1. Extract Bearer token from Authorization header
2. Verify token with Firebase Admin SDK
3. Extract user info (uid, email, phoneNumber, name)
4. Attach to `req.user`
5. Call next()

**Error Cases**:
- No Bearer token → 401 "Missing bearer token"
- Invalid/expired token → 401 "Invalid or expired auth token"
- Firebase unavailable → Falls back to mock auth (dev mode)

**Mock Auth** (development):
- Parses JWT base64 payload
- Extracts uid, email, phone, name
- Creates mock user object

**Function: `requireRole(...roles)`**

**Returns**: Middleware that checks if user has one of specified roles

**Flow**:
1. Gets role from `req.dbUser.role` (must be populated by attachDbUser first)
2. Checks if role is in allowed list
3. If not → 403 "Forbidden"

**Issues/Observations**:
- Falls back to 'farmer' role if req.dbUser missing
- Assumes requireAuth runs before requireRole

---

### **File**: `middlewares/attachDbUser.js`

**Purpose**: Populates `req.dbUser` from MongoDB after auth verification.

**Flow**:
1. Skip if no `req.user` (no auth token)
2. Query User collection by firebaseUid
3. If not found → Create new user document with defaults
4. Attach to `req.dbUser`
5. Call next()

**Auto-creation on First Request**:
- firebaseUid, phone, name populated from Firebase token
- role defaults to 'farmer'

---

## Routes

### **File**: `routes/health.routes.js`

**Purpose**: Health check endpoint for monitoring.

**Endpoint**: `GET /api/health`

**Response**:
```json
{
  "ok": true,
  "service": "digital-kissan-backend",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

---

### **File**: `routes/users.routes.js`

**Purpose**: User profile management.

**Endpoints**:

**GET `/api/users/me`** (requireAuth, attachDbUser)
- Returns current user profile
- Response:
```json
{
  "firebaseUid": "uid",
  "name": "User Name",
  "phone": "+923001234567",
  "role": "farmer",
  "district": "Lahore",
  "province": "Punjab"
}
```

**PATCH `/api/users/me`** (requireAuth, attachDbUser)
- Updates user profile
- Request body: { name?, phone?, district?, province?, role? }
- Role update only by admin or self-assignment
- Phone uniqueness enforced (compound index with countryCode)
- Response: { message, user: updatedUser }

**Errors**:
- 409: Phone number already registered (E11000 index violation)

---

### **File**: `routes/rates.routes.js`

**Purpose**: Crop rate management.

**Endpoints**:

**GET `/api/rates/latest`** (public)
- Query params: crop?, district?, limit? (default 100, max 300)
- Returns array of CropRateDto sorted by rateDate DESC
- Response:
```json
[{
  "cropName": "Wheat",
  "marketName": "Lahore Mandi",
  "district": "Lahore",
  "minPrice": 2500,
  "maxPrice": 2800,
  "unit": "40kg",
  "sourceName": "AMIS",
  "sourceUrl": "https://...",
  "rateDate": "2024-01-15T00:00:00Z"
}]
```

**POST `/api/rates`** (requireAuth, attachDbUser, requireRole('admin'))
- Creates new rate entry
- Requires admin role
- Request body: { cropName, marketName, district, minPrice, maxPrice, unit?, sourceName, sourceUrl, isOfficialSource?, rateDate? }
- Response: Created rate document

**POST `/api/rates/ingest/official`** (requireAuth, attachDbUser, requireRole('admin'))
- Imports official government rates
- Calls `fetchOfficialRates()` from service
- Service currently returns empty array (placeholder)
- Response: { message, inserted: count }

---

### **File**: `routes/listings.routes.js`

**Purpose**: Marketplace listing management.

**Endpoints**:

**GET `/api/listings`** (public)
- Query: crop?, district?, status? (default 'open'), sort? (new/price_asc/price_desc), limit?
- Returns array of listings sorted by createdAt DESC (or by price)
- Response: Array of ListingDto

**POST `/api/listings`** (requireAuth, attachDbUser)
- Creates new marketplace listing
- Request body: { cropName, district, quantity, askingPrice, qualityGrade?, unit?, description?, imageUrls?[] }
- Automatically sets:
  - sellerUid from req.user.uid
  - sellerRef from req.dbUser._id
  - status: 'open'
- Response: Created listing document

**PATCH `/api/listings/:id/status`** (requireAuth, attachDbUser)
- Updates listing status
- Only seller or admin can update
- Request body: { status }
- Allowed statuses: open/reserved/sold/cancelled
- Response: Updated listing or 404/403 error

**Business Logic**:
- Cannot make offer on other seller's listing
- Listing must be 'open' to receive offers
- When offer accepted: status → 'reserved'
- When order completed: status → 'sold'

---

### **File**: `routes/offers.routes.js`

**Purpose**: Buy/sell offer management.

**Endpoints**:

**GET `/api/offers/me`** (requireAuth, attachDbUser)
- Returns all offers placed by current user (as buyer)
- Populated with full listing details
- Sorted by createdAt DESC

**GET `/api/offers/incoming`** (requireAuth, attachDbUser)
- Returns all offers received on user's listings
- Finds user's listings, then finds offers on those listings
- Populated with full listing details

**POST `/api/offers`** (requireAuth, attachDbUser)
- Create new offer
- Request body: { listingId, offerPrice, quantity }
- Validations:
  - Listing must exist
  - Listing must be 'open'
  - Buyer cannot be seller
- Response: Created offer document

**POST `/api/offers/:id/accept`** (requireAuth, attachDbUser)
- Accept offer and create order
- Only listing seller or admin can accept
- Flow:
  1. Mark offer as 'accepted'
  2. Mark all other pending offers for same listing as 'rejected'
  3. Update listing status to 'reserved'
  4. Create Order document with offer data
- Response: { message, order: newOrder }

**POST `/api/offers/:id/reject`** (requireAuth, attachDbUser)
- Reject offer
- Only seller or admin can reject
- Sets offer status to 'rejected'

**POST `/api/offers/:id/cancel`** (requireAuth, attachDbUser)
- Cancel pending offer (by buyer)
- Only buyer or admin can cancel
- Only pending offers can be cancelled
- Sets status to 'cancelled'

---

### **File**: `routes/orders.routes.js`

**Purpose**: Order fulfillment tracking.

**Endpoints**:

**GET `/api/orders/me`** (requireAuth, attachDbUser)
- Returns all orders for current user (as buyer or seller)
- Query: { $or: [{ buyerUid }, { sellerUid }] }
- Sorted by createdAt DESC

**PATCH `/api/orders/:id/status`** (requireAuth, attachDbUser)
- Update order status
- Only participants (buyer, seller, admin) can update
- Request body: { status }
- Allowed statuses: created/in_transit/delivered/completed/cancelled/disputed
- Response: Updated order document

**Business Logic**:
- No validation of status transitions (can go backward if needed)
- All participants have equal update rights

---

### **File**: `routes/uploads.routes.js`

**Purpose**: File upload handling for marketplace images.

**Middleware**:
- Multer disk storage configuration
- Destination: `uploads/listings/` directory
- Filename: `{timestamp}-{sanitized_original_name}`
- Max size: 5MB
- Only image MIME types allowed

**Endpoints**:

**POST `/api/uploads/listing-image`** (requireAuth, attachDbUser, multer.single('image'))
- Upload listing product image
- Form field: 'image' (multipart)
- Storage: Local filesystem
- Validation:
  - File required
  - Must be image/* MIME type
  - Max 5MB
- Response:
```json
{
  "message": "Image uploaded",
  "imageUrl": "http://host:5000/uploads/listings/{filename}",
  "relativeUrl": "/uploads/listings/{filename}",
  "filename": "{filename}",
  "size": 45000,
  "mimeType": "image/jpeg"
}
```

**File Organization**:
- Uploaded files served statically from `/uploads` directory
- Accessible at `GET /uploads/listings/{filename}`

**Issues/Observations**:
- No image optimization/compression
- Filenames sanitized by removing special characters
- No cleanup of old/orphaned uploads

---

### **File**: `routes/health.routes.js`

**Purpose**: Service health monitoring.

**Endpoint**: `GET /api/health`

**Response**: JSON status with timestamp

---

## Services

### **File**: `services/ratesIngestion.service.js`

**Purpose**: Import official government/market board crop rates.

**Function**: `fetchOfficialRates()`

**Current Status**: Placeholder (returns empty array)

**Expected Integration Points**:
- Government ministries (Ministry of Food Security & Research)
- Provincial market committees (AMIS)
- Mandi boards (major markets in Punjab, Sindh, KPK)

**To Implement**:
1. Add APIs for specific market data sources
2. Implement data transformation to match CropRateModel schema
3. Handle missing/invalid data
4. Schedule periodic ingestion (daily)
5. Support for historical rates

**Example**: Could fetch from AMIS (Agricultural Marketing Information System)

---

# PART 3: DATA FLOW & INTEGRATION

## Authentication Flow

```
Mobile App
    ↓
[Login/Registration Screen]
    ↓ (Email + Password)
Firebase Auth
    ↓ (Creates user + generates IDToken)
AuthProvider (listens to authStateChanges)
    ↓
FirebaseService.createUserIfNotExists()
    ↓ (Creates MongoDB user doc from Firebase token)
MongoDB (users collection)
    ↓
Dashboard/MainNavigationShell
```

## Weather Alert Flow

```
Dashboard Screen Loads
    ↓
Load saved location from SharedPreferences
    ↓
WeatherService.fetchWeatherData(lat, lon)
    ↓ (OpenWeather API)
OpenWeather Returns: current + 5-day forecast
    ↓
AlertService.processWeather(current, forecast)
    ↓ (Checks: rain, heat, cold, wind thresholds)
Generate AlertItem if condition met & no duplicate today
    ↓
NotificationService.showNotification()
    ↓ (Shows local notification)
AlertService._persist()
    ↓ (Saves to SharedPreferences)
AlertsScreen can then display all alerts
```

## Marketplace Transaction Flow

```
Seller Creates Listing
    ↓ (POST /api/listings)
Backend: Create Listing doc
    ↓
Marketplace shows to all buyers (GET /api/listings)
    ↓
Buyer makes offer
    ↓ (POST /api/offers)
Backend: Create Offer doc (status=pending)
    ↓
Seller sees incoming offer (GET /api/offers/incoming)
    ↓
Seller accepts offer
    ↓ (POST /api/offers/:id/accept)
Backend:
  - Offer status → 'accepted'
  - Other pending offers for same listing → 'rejected'
  - Listing status → 'reserved'
  - Create Order doc
    ↓
Buyer/Seller can track order status (GET /api/orders/me)
    ↓
Either party updates status (in_transit, delivered, completed)
    ↓ (PATCH /api/orders/:id/status)
Backend: Updates order status in MongoDB
```

## API Authentication

```
Mobile App
    ↓
Get Firebase IDToken: FirebaseAuth.instance.currentUser.getIdToken(true)
    ↓
Include in every request: Authorization: Bearer {idToken}
    ↓
Backend requireAuth middleware
    ↓
Verify token with Firebase Admin
    ↓ (or mock parse if Firebase unavailable)
Attach user info to req.user
    ↓
attachDbUser middleware
    ↓
Lookup user in MongoDB
    ↓
Auto-create if first request
    ↓
Attach user doc to req.dbUser
    ↓
Route handler accesses req.user & req.dbUser
```

---

# PART 4: SYSTEM ARCHITECTURE DIAGRAM

```
┌─────────────────────────────────────────────────────────────────┐
│                      DIGITAL KISSAN ARCHITECTURE                 │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│   FLUTTER APP    │                    ┌─────────────────┐
│  (Android/iOS)   │                    │  FIREBASE AUTH  │
│                  │◄───────Login────► │  (Email/Pwd)    │
│ • Dashboard      │                    └─────────────────┘
│ • Forecast       │
│ • Alerts         │                    ┌──────────────────┐
│ • Market         │◄─────Token───────►│  FIREBASE CORE   │
│ • Settings       │                    │  • Messaging     │
│ • Profile        │                    │  • Firestore     │
└──────────────────┘                    └──────────────────┘
        │
        │ HTTP REST (Bearer token)
        ▼
┌──────────────────────────────────────────────┐
│      NODE.JS EXPRESS BACKEND (Port 5000)    │
│ ┌────────────────────────────────────────┐  │
│ │  Routes:                               │  │
│ │  • GET  /api/health                    │  │
│ │  • GET/POST /api/users                 │  │
│ │  • GET/POST /api/listings              │  │
│ │  • GET/POST /api/offers                │  │
│ │  • GET/PATCH /api/orders               │  │
│ │  • GET/POST /api/rates                 │  │
│ │  • POST /api/uploads/listing-image     │  │
│ └────────────────────────────────────────┘  │
│ ┌────────────────────────────────────────┐  │
│ │  Middleware:                           │  │
│ │  • auth.js (Firebase token verify)     │  │
│ │  • attachDbUser.js (MongoDB lookup)    │  │
│ │  • CORS, Express JSON parser           │  │
│ └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
        │
        ├─ MongoDB (digital_kissan DB)
        │  • users
        │  • listings
        │  • offers
        │  • orders
        │  • cropRates
        │
        ├─ Filesystem (/uploads/listings/)
        │  • Uploaded product images
        │
        └─ External APIs
           • Firebase Admin SDK (token verify)
           • OpenWeather API (weather data)

┌──────────────────────────────────────────────┐
│         EXTERNAL SERVICES                    │
├──────────────────────────────────────────────┤
│ • OpenWeather API (weather forecasts)        │
│ • Mapbox (geolocation + mapping)             │
│ • Geocoding (address ↔ coordinates)          │
│ • Firebase Cloud Messaging (push notifs)     │
└──────────────────────────────────────────────┘
```

---

# PART 5: KEY IMPLEMENTATION NOTES

## Security Considerations

### ✅ Implemented
- Firebase Auth for secure account creation
- JWT Bearer token verification on backend
- Middleware to check user role (farmer/buyer/admin)
- Password hashing by Firebase
- CORS origin validation

### ⚠️ Potential Issues
- OpenWeather API key hardcoded in client
- Mapbox token hardcoded in client
- Backend allows development mode without Firebase (mock auth less secure)
- No input sanitization on text fields
- File uploads not validated for malicious content
- Orders don't validate state transitions (can go backward)

---

## Performance Considerations

### Optimizations
- SQLite-like database indexing on frequently queried fields
- SharedPreferences caching for location/settings
- Alert deduplication (daily check)
- Weather polling every 60 minutes (not per-screen load)

### Potential Bottlenecks
- Image uploads not compressed (5MB limit helps)
- Weather service makes 2 API calls per location (current + forecast)
- No pagination in marketplace listings
- No caching of API responses
- Firestore operations merge instead of replace (reads entire doc first)

---

## Testing & Debugging

### Available Debug Features
- Settings screen has "Save sample data to Firebase" action
- Settings screen has "Show Test Notification" action
- All services log to console in debug mode
- Health check endpoint available

### Missing
- Unit tests
- Integration tests
- E2E tests
- Error boundary widgets
- Crash reporting (Sentry, Firebase Crashlytics)

---

## Deployment Considerations

### Environment Variables Needed
```
# Backend (.env)
PORT=5000
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/digital_kissan
ALLOWED_ORIGINS=https://app.digitalkissan.com,https://admin.digitalkissan.com
FIREBASE_PROJECT_ID=digital-kissan-xxx

# Frontend (--dart-define)
API_BASE_URL=https://api.digitalkissan.com
MAPBOX_TOKEN=pk.xxx
OPENWEATHER_KEY=xxx
```

### Deployment Targets
- **Mobile**: Google Play Store, Apple App Store
- **Backend**: AWS/GCP/DigitalOcean Node.js hosting
- **Database**: MongoDB Atlas (cloud) or self-hosted
- **Storage**: AWS S3 or local filesystem with CDN

---

## Future Enhancements

1. **Plant Disease AI**: Re-enable TensorFlow Lite model after resolving Git dependency
2. **Crop Rates**: Implement official government data integration (AMIS)
3. **Push Notifications**: Configure Firebase Cloud Messaging backend
4. **Video Tutorials**: Add in-app farming videos
5. **Offline Mode**: Sync weather data and marketplace listings offline
6. **Social Features**: Farmer community forum/chat
7. **IoT Integration**: Connect with soil moisture sensors, weather stations
8. **Payment Gateway**: Add transaction payment processing (JazzCash, Easypaisa)
9. **Analytics**: Track user behavior, crop trends
10. **ML Alerts**: Predictive crop health alerts

---

**Document Generated**: 2024  
**Project Version**: 1.0.0  
**Language**: Dart (Flutter), JavaScript (Node.js), English + Urdu  
**Database**: MongoDB + Firebase (Firestore + Auth)
