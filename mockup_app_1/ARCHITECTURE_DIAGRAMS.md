# Digital Kissan - Component Architecture & Data Flow Diagrams

## 1. Overall System Architecture

```
╔════════════════════════════════════════════════════════════════════════════╗
║                      DIGITAL KISSAN ECOSYSTEM                              ║
╚════════════════════════════════════════════════════════════════════════════╝

┌──────────────────────────────────┐         ┌──────────────────────────┐
│    FLUTTER MOBILE APP            │         │  CLOUD SERVICES          │
│  (iOS/Android - Bilingual EN/UR) │         │                          │
│                                  │         │ ┌────────────────────┐   │
│ ┌────────────────────────────┐   │         │ │ Firebase Auth      │   │
│ │ UI Screens (17 screens)    │   │         │ │ • Email/Password   │   │
│ │ • Splash, Login, Reg       │   │         │ │ • Token management │   │
│ │ • Dashboard, Forecast      │   │         │ │ • Email verify     │   │
│ │ • Alerts, Market, Settings │   │         │ └────────────────────┘   │
│ │ • Plant Disease, Profile   │   │         │                          │
│ │ • Location, Offers, Orders │   │         │ ┌────────────────────┐   │
│ └────────────────────────────┘   │         │ │ Firestore (Real-   │   │
│                                  │◄────────┤ │ time Database)     │   │
│ ┌────────────────────────────┐   │         │ │ • User profiles    │   │
│ │ Providers (State Mgmt)     │   │         │ │ • FCM tokens       │   │
│ │ • AuthProvider             │   │         │ │ • Location data    │   │
│ │ • LanguageProvider         │   │         │ └────────────────────┘   │
│ │ • PlantDiseaseProvider     │   │         │                          │
│ │ • AlertService             │   │         │ ┌────────────────────┐   │
│ │ • NotificationService      │   │         │ │ Cloud Messaging    │   │
│ └────────────────────────────┘   │         │ │ (Push Notif)       │   │
│                                  │         │ └────────────────────┘   │
│ ┌────────────────────────────┐   │         └──────────────────────────┘
│ │ Services                   │   │
│ │ • AuthService              │   │         ┌──────────────────────────┐
│ │ • FirebaseService          │   │         │  EXTERNAL APIs           │
│ │ • ApiClient                │   │         │                          │
│ │ • WeatherService           │   │◄────────┤ • OpenWeather (2.5)      │
│ │ • MarketApiService         │   │         │ • Mapbox Maps/Geocoding  │
│ │ • NotificationService      │   │         │ • Google Fonts CDN       │
│ │ • PlantDiseaseClassifier   │   │         └──────────────────────────┘
│ └────────────────────────────┘   │
│                                  │
│ ┌────────────────────────────┐   │
│ │ Local Storage              │   │
│ │ • SharedPreferences        │   │
│ │   - Location (lat/lon)     │   │
│ │   - Language preference    │   │
│ │   - Notification settings  │   │
│ │ • Local Notifications      │   │
│ │ • Alerts (JSON in prefs)   │   │
│ └────────────────────────────┘   │
└──────────────────────────────────┘
           │
           │ HTTP REST (Firebase Bearer Token)
           │ Port: 5000
           │
┌──────────────────────────────────────────────────────────────────────────┐
│                 NODE.JS EXPRESS REST API                                 │
│                 (Digital Kissan Backend)                                 │
│                                                                          │
│ ┌──────────────────────────────────────────────────────────────────┐   │
│ │ Middleware Stack                                                 │   │
│ │  ↓ CORS (Origin validation)                                      │   │
│ │  ↓ express.json (2MB limit)                                      │   │
│ │  ↓ Static /uploads/listings serve                               │   │
│ │  ↓ requireAuth (Firebase token verify)                          │   │
│ │  ↓ attachDbUser (MongoDB lookup)                                │   │
│ │  ↓ Route handler                                                │   │
│ │  ↓ Error handler                                                │   │
│ └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│ ┌──────────────────────────────────────────────────────────────────┐   │
│ │ API Routes                                                       │   │
│ │                                                                  │   │
│ │ /api/health ..................... Health check                  │   │
│ │ /api/users ...................... Profile management             │   │
│ │ /api/listings ................... Marketplace listings           │   │
│ │ /api/offers ..................... Buy/Sell offers                │   │
│ │ /api/orders ..................... Order tracking                 │   │
│ │ /api/rates ....................... Crop prices                  │   │
│ │ /api/uploads .................... Image uploads                  │   │
│ │                                                                  │   │
│ └──────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────┘
           │
           ├─────────────────┬──────────────────┬──────────────────┐
           │                 │                  │                  │
    ┌──────▼──────┐  ┌──────▼──────┐  ┌───────▼─────┐  ┌────────▼────────┐
    │   MongoDB   │  │  Firebase   │  │  Filesystem │  │  Configuration  │
    │  Database   │  │  Admin SDK  │  │  /uploads   │  │                 │
    │             │  │             │  │  /listings  │  │ • env.js        │
    │ Collections:│  │ Token verify│  │             │  │ • db.js         │
    │             │  │ User lookup │  │ • JPEGs     │  │ • firebaseAdmin │
    │ • users     │  │             │  │ • PNGs      │  │ .js             │
    │ • listings  │  │             │  │ • WebP      │  └─────────────────┘
    │ • offers    │  │             │  │             │
    │ • orders    │  │             │  └─────────────┘
    │ • cropRates │  │             │
    │             │  │             │
    │ Indexes:    │  └─────────────┘
    │ (composite) │
    └─────────────┘
```

---

## 2. Authentication Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    AUTHENTICATION FLOW                                    │
└──────────────────────────────────────────────────────────────────────────┘

REGISTRATION FLOW:
─────────────────

  USER INPUT                 FIREBASE AUTH              FIRESTORE
  ┌─────────┐               ┌──────────┐              ┌────────┐
  │ Name    │               │          │              │        │
  │ Email   │──Register────>│ Create   │──IDToken──>  │ Create │
  │ Phone   │               │ User     │              │ User   │
  │ Password│               │          │              │ Doc    │
  └─────────┘               └──────────┘              └────────┘
                                  │
                                  ├──> Send Verification Email
                                  │
                                  ▼
                            EMAIL VERIFY SCREEN
                                  │
                            User clicks link
                                  │
                                  ▼
                          Email verified ✓
                                  │
                                  ▼
                          proceed to Dashboard


LOGIN FLOW:
───────────

  USER INPUT                 FIREBASE AUTH              AUTHPROVIDER
  ┌─────────┐               ┌──────────┐              ┌────────────┐
  │ Email   │──Sign In─────>│ Verify   │──Success──>  │ Listen to  │
  │ Password│               │ Creds    │              │ authState  │
  └─────────┘               └──────────┘              │ Changes    │
                                  │                    └────────────┘
                                  │                          │
                                  │        ┌────────────────┘
                                  │        │
                                  │        ▼
                              Check email    FIRESTORE SERVICE
                              verified?      ┌─────────────────┐
                                  │          │ Create user doc │
                                  │          │ Update FCM token│
                                  │          └─────────────────┘
                                  │
                        If not verified:
                             │
                             ▼
                    EMAIL VERIFY SCREEN
                             │
                    (resend link or check)
                             │
                        If verified:
                             │
                             ▼
                       → DASHBOARD


TOKEN USAGE (Every API Request):
────────────────────────────────

  FLUTTER APP                     NODE.JS BACKEND
  ┌─────────┐
  │ Firebase│
  │ Auth    │──getIdToken(true)──┐
  └─────────┘                    │
                                 ▼
                        ┌──────────────────┐
                        │ Authorization:   │
                        │ Bearer {token}   │
                        └──────────────────┘
                                 │
                                 │ HTTP Request
                                 │
                                 ▼
                        ┌──────────────────┐
                        │ requireAuth()    │
                        │ middleware:      │
                        │ Verify token     │
                        │ Extract user info│
                        └──────────────────┘
                                 │
                        ✓ Valid | ✗ Invalid
                                 │
                        ┌────────┴────────┐
                        │                 │
                        ▼                 ▼
                   Attach req.user   401 Unauthorized
                        │
                        ▼
                   attachDbUser()
                   middleware:
                   - Lookup in MongoDB
                   - Auto-create if needed
                        │
                        ▼
                   Attach req.dbUser
                        │
                        ▼
                   Route handler
                        │
                        ▼
                   Send response
```

---

## 3. Weather Alert Generation Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                   WEATHER ALERT FLOW                                      │
└──────────────────────────────────────────────────────────────────────────┘

DASHBOARD INITIALIZATION:
─────────────────────────

   Dashboard Screen onCreate
           │
           ▼
   Load saved location
   from SharedPreferences
           │
           ▼
   lat, lon available?
      │        │
   YES│        │NO
      │        └─> Show "No location set"
      │
      ▼
   WeatherService.fetchWeatherData()
           │
           ├──> OpenWeather /weather endpoint
           │    Current: temp, wind, humidity, etc.
           │
           └──> OpenWeather /forecast endpoint
                5-day 3-hourly data
                │
                ▼
           Parse & transform to DailyForecast
                │
                ▼
           AlertService.processWeather()
                │
                ├─────────────────────────────────┐
                │   Check ALERT CONDITIONS:        │
                │                                  │
                │ 1. RAIN?                         │
                │    POP ≥ 50% OR precip > 0.1mm   │
                │                                  │
                │ 2. HEAT?                         │
                │    Temp ≥ 35°C                   │
                │                                  │
                │ 3. COLD?                         │
                │    Temp ≤ 5°C                    │
                │                                  │
                │ 4. WIND?                         │
                │    Wind speed ≥ 10 m/s           │
                │                                  │
                └─────────────────────────────────┘
                │
                │ For each condition met:
                │
                ├─ Check: Already alert today?
                │          │
                │      NO  │ YES
                │          │
                │          └─> Skip (prevent duplicates)
                │
                ▼
           CREATE ALERT
                │
                ├─ Generate AlertItem
                │  (id, type, title, body, createdAt)
                │
                ├─ NotificationService.showNotification()
                │  (Local notification + payload)
                │
                ├─ AlertService._persist()
                │  (Save to SharedPreferences)
                │
                └─ Notify listeners (ChangeNotifier)
                   │
                   ▼
              AlertsScreen updates
              (auto-refresh on tab visit)


PERIODIC ALERT CHECK:
─────────────────────

   Dashboard init
           │
           ▼
   Start alert timer
   (60 minute interval)
           │
           ├─► Every 60 min: Run alert check
           │   └──> Fetch weather again
           │        Process alerts
           │        Show notifications
           │
           ▼
   Dashboard dispose
           │
           ▼
   Cancel timer


ALERT PERSISTENCE:
──────────────────

   SharedPreferences
   Key: 'saved_alerts'
   ┌──────────────────────┐
   │ [                    │
   │  {                   │
   │    id: timestamp,    │
   │    type: 'rain',     │
   │    title: 'Rain...', │
   │    body: '50% chance'│
   │    createdAt: date   │
   │  },                  │
   │  ...                 │
   │ ]                    │
   │                      │
   │ Rules:               │
   │ • Max 50 items       │
   │ • Max 7 days old     │
   │ • Auto-pruned        │
   └──────────────────────┘
```

---

## 4. Marketplace Transaction Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                MARKETPLACE TRANSACTION FLOW                               │
└──────────────────────────────────────────────────────────────────────────┘

STATE DIAGRAM:
──────────────

         LISTING
           │
           ├─ CREATE
           │
           ▼
      ┌─────────────┐
      │ LISTING:    │
      │ status=open │ ◄──── No offers yet
      └─────────────┘
           ▲ │
           │ │ Buyer places offer
           │ │ (POST /api/offers)
           │ ▼
      ┌──────────────────┐
      │ OFFER            │
      │ status=pending   │ ◄── Waiting for seller decision
      └──────────────────┘
           ▲ │
           │ ├─ Seller rejects
           │ │  └─> offer.status = rejected
           │ │
           │ └─ Seller accepts
           │    (POST /api/offers/:id/accept)
           │
           ▼
      ┌──────────────────┐
      │ OFFER status=    │
      │ accepted         │
      └──────────────────┘
           │
           ├─ LISTING status → reserved
           │  (blocks new offers)
           │
           ▼
      ┌──────────────────┐
      │ ORDER            │
      │ status=created   │ ◄── Transaction created
      └──────────────────┘
           │
           ├─ update status
           │  (in_transit, delivered,
           │   completed, cancelled,
           │   disputed)
           │
           ▼
      ┌──────────────────┐
      │ ORDER status=    │
      │ completed        │ ◄── Transaction finished
      └──────────────────┘
           │
           ▼
      ┌──────────────────┐
      │ LISTING status   │
      │ = sold           │
      └──────────────────┘


DETAILED FLOW:
──────────────

SELLER SIDE:
────────────

1. Navigate to MarketplaceTab (Market Screen)
                │
                ▼
        Fill listing form:
        - Crop name
        - District
        - Quantity
        - Price per unit
        - Images (pick & upload)
                │
                ▼
        Click "Create Listing"
                │
                ├─► Image upload (multipart)
                │   POST /api/uploads/listing-image
                │   ↓
                │   Backend returns imageUrl
                │
                ▼
        POST /api/listings
        {
          cropName, district, quantity,
          askingPrice, imageUrls, ...
        }
                │
                ▼
        Backend creates Listing doc
        (sellerUid, status=open)
                │
                ▼
        Show success snackbar
        Reload listings


BUYER SIDE:
───────────

1. Browse Marketplace
                │
                ├─► Filter by crop/district
                │
                ▼
        View listing cards
        - Crop + grade
        - Quantity + unit
        - Asking price
        - Images
        - Seller info
                │
                ▼
        Tap "Make Offer"
                │
                ▼
        Dialog: Enter offer price
                 & quantity
                │
                ▼
        POST /api/offers
        {
          listingId,
          offerPrice,
          quantity
        }
                │
                ▼
        Backend creates Offer doc
        (status=pending)
                │
                ▼
        Show "Offer sent successfully"


SELLER RECEIVES OFFER:
──────────────────────

1. Navigate to Offers Screen
                │
                ▼
        Click "Incoming Offers" tab
                │
                ▼
        GET /api/offers/incoming
        (Fetch offers on seller's listings)
                │
                ▼
        Show pending offers with
        Accept/Reject buttons
                │
        ┌───────┴────────┐
        │                │
   Accept           Reject
        │                │
        ▼                ▼
   POST /api/         POST /api/
   offers/:id/        offers/:id/
   accept             reject
        │                │
        ▼                ▼
   Backend:        Backend:
   - Mark offer     - Mark offer
     accepted        rejected
   - Reject other   - Stop
     pending
   - Mark listing
     reserved
   - Create Order
        │
        ▼
   Show success


ORDER TRACKING:
───────────────

1. Navigate to Orders Screen
                │
                ▼
        GET /api/orders/me
        (Orders as buyer or seller)
                │
                ▼
        Show status chips:
        [created] [in_transit]
        [delivered] [completed]
        [cancelled] [disputed]
                │
                ▼
        Either party can click
        status chip to update
                │
                ▼
        PATCH /api/orders/:id/status
        { status: "in_transit" }
                │
                ▼
        Backend updates order
                │
                ▼
        Other participant sees
        updated status (on refresh)
```

---

## 5. Notification System Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                 NOTIFICATION SYSTEM ARCHITECTURE                          │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│                  FLUTTER LOCAL NOTIFICATIONS                              │
│                                                                          │
│  NotificationService                                                    │
│  ┌───────────────────────────────────────────────────────────┐          │
│  │ init()                                                    │          │
│  │  ├─ Initialize android/iOS channels                      │          │
│  │  │  - Channel ID: your_channel_id                        │          │
│  │  │  - Max importance/high priority                       │          │
│  │  │                                                        │          │
│  │  └─ Register FCM foreground listener                     │          │
│  │     └─> onMessage: Show local notif when app open       │          │
│  │                                                          │          │
│  │ requestNotificationPermissions()                         │          │
│  │  ├─ Android 13+: REQUEST_POST_NOTIFICATIONS             │          │
│  │  ├─ iOS: Prompt user                                    │          │
│  │  └─ Return: granted boolean                             │          │
│  │                                                          │          │
│  │ getFcmToken()                                            │          │
│  │  └─ Return: "fcm-token-xyz..."                           │          │
│  │     (used to register device on backend)                 │          │
│  │                                                          │          │
│  │ showNotification({id, title, body, payload})            │          │
│  │  ├─ Check user preference (SharedPreferences)           │          │
│  │  ├─ Android: AndroidNotificationDetails                 │          │
│  │  │  └─ Importance.max, Priority.high                    │          │
│  │  ├─ iOS: DarwinNotificationDetails                      │          │
│  │  └─ Show via FlutterLocalNotifications                  │          │
│  │                                                          │          │
│  └───────────────────────────────────────────────────────────┘          │
│                                                                          │
│  LocalNotifications Display:                                            │
│  ┌──────────────────────┐  Tap  ┌──────────────────┐                    │
│  │ Notification Title   │──────>│ onDidReceive     │                    │
│  │ • Body message       │       │ NotificationResp │                    │
│  │ • Payload: JSON      │       │ • Handle payload │                    │
│  └──────────────────────┘       │ • Navigate if    │                    │
│                                  │   needed         │                    │
│                                  └──────────────────┘                    │
└──────────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ FCM Token sent to
                                  │ Firestore on login
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────┐
│              FIREBASE CLOUD MESSAGING (FCM)                               │
│                                                                          │
│  1. Send from Backend / Firebase Console:                               │
│     ┌────────────────────────────────────┐                             │
│     │ POST /send                         │                             │
│     │ {                                  │                             │
│     │   to: "fcm-token-xyz",             │                             │
│     │   notification: {                  │                             │
│     │     title: "Rain Alert",           │                             │
│     │     body: "50% chance at 3 PM"    │                             │
│     │   },                               │                             │
│     │   data: {                          │                             │
│     │     alertType: "rain",             │                             │
│     │     alertId: "123"                 │                             │
│     │   }                                │                             │
│     │ }                                  │                             │
│     └────────────────────────────────────┘                             │
│                                                                          │
│  2. Message received by device:                                         │
│     ┌────────────────────────────────────┐                             │
│     │ Foreground (app open):             │                             │
│     │ FirebaseMessaging.onMessage        │                             │
│     │  └─> showNotification() locally    │                             │
│     │                                    │                             │
│     │ Background (app in bg):            │                             │
│     │ System shows notification          │                             │
│     │  └─> Tap opens app                 │                             │
│     │                                    │                             │
│     │ Terminated (app not running):      │                             │
│     │ System shows notification          │                             │
│     │  └─> Tap launches app              │                             │
│     └────────────────────────────────────┘                             │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

ALERT NOTIFICATION FLOW:
────────────────────────

AlertService.processWeather() detected rain condition
           │
           ▼
Create AlertItem
  {
    id: "1704067200000001",
    type: "rain",
    title: "Rain expected near your fields",
    body: "Chance of rain around 50%. Secure equipment.",
    createdAt: DateTime.now()
  }
           │
           ├─► NotificationService.showNotification(
           │    id: alert.id.hashCode,
           │    title: alert.title,
           │    body: alert.body,
           │    payload: jsonEncode({
           │      type: alert.type,
           │      id: alert.id
           │    })
           │  )
           │
           ├─► Show local notification
           │   (if app open: foreground)
           │   (if in bg: OS shows it)
           │
           └─► Persist to SharedPreferences
               (for AlertsScreen to display)

User taps notification → App opens → Process payload
                                     └─> Navigate to AlertsScreen
```

---

## 6. State Management Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                      STATE MANAGEMENT (Providers)                         │
└──────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ AuthProvider (ChangeNotifier)                                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│ Listens to: FirebaseAuth.authStateChanges()                             │
│                                                                          │
│ State:                                                                   │
│  _user: User? (current Firebase user)                                   │
│  _sub: StreamSubscription (to authStateChanges)                         │
│                                                                          │
│ When auth state changes:                                                │
│  │                                                                       │
│  ├─ No user → _user = null → notifyListeners()                          │
│  │                                                                       │
│  └─ User exists →                                                       │
│     ├─ _user = user → notifyListeners()                                 │
│     ├─ FirebaseService.createUserIfNotExists()                          │
│     │  └─ Creates/updates Firestore users/{uid} doc                     │
│     └─ NotificationService.getFcmToken()                                │
│        └─ FirebaseService.updateUserNotificationData()                  │
│           └─ Saves FCM token to Firestore (for push alerts)             │
│                                                                          │
│ Consumers:                                                               │
│  • MainNavigationShell (checks isSignedIn)                              │
│  • ProfileScreen (displays user.displayName, user.email)                │
│  • SettingsScreen (sign out button)                                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│ LanguageProvider (ChangeNotifier)                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│ State:                                                                   │
│  _locale: Locale (current language)                                     │
│                                                                          │
│ Methods:                                                                 │
│  setLocale(Locale locale) →                                             │
│    if locale in L10n.all →                                              │
│      _locale = locale → notifyListeners()                               │
│                                                                          │
│ Supported locales:                                                       │
│  • Locale('en', '') - English                                           │
│  • Locale('ur', '') - Urdu                                              │
│                                                                          │
│ Consumers:                                                               │
│  • DigitalKissanApp (sets MaterialApp.locale)                           │
│  • Login/Settings screen (language dropdown)                            │
│  • All screens (access AppLocalizations.of(context)!)                   │
│                                                                          │
│ Notes:                                                                   │
│  • NOT persisted to disk (resets on app restart)                        │
│  • Could add SharedPreferences persistence for UX improvement           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│ PlantDiseaseProvider (ChangeNotifier)                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│ State:                                                                   │
│  _isLoading: bool                                                        │
│  _error: String? (error message)                                        │
│  _predictions: List<Prediction> (model output)                          │
│                                                                          │
│ Methods:                                                                 │
│  classifyBytes(Uint8List bytes) →                                       │
│    Disabled: sets _error = "Plant disease detection is disabled..."    │
│                                                                          │
│    Would do (if enabled):                                               │
│    • Load TFLite model                                                  │
│    • Preprocess image bytes                                             │
│    • Run inference                                                      │
│    • Parse predictions                                                  │
│    • Update _predictions → notifyListeners()                            │
│                                                                          │
│ Consumers:                                                               │
│  • PlantDiseaseScreen (watch provider, display predictions)             │
│                                                                          │
│ Note: Commented out due to tflite_flutter Git dependency               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│ AlertService (ChangeNotifier)                                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│ State:                                                                   │
│  _alerts: List<AlertItem> (all stored alerts)                           │
│  _loaded: bool (tracking if loaded from disk)                           │
│                                                                          │
│ Storage:                                                                 │
│  SharedPreferences key: 'saved_alerts'                                  │
│  JSON array of alert objects                                            │
│  Rules: Max 50 items, Max 7 days old                                    │
│                                                                          │
│ Methods:                                                                 │
│  loadAlerts() →                                                          │
│    Read from SharedPreferences                                          │
│    Deserialize JSON → AlertItem list                                    │
│    _prune() (remove old)                                                │
│    notifyListeners()                                                    │
│                                                                          │
│  processWeather(current, forecast) →                                    │
│    Check rain/heat/cold/wind conditions                                │
│    If condition met & no duplicate today:                               │
│      _addAlert() → show notification → persist                          │
│                                                                          │
│  clearAlerts() →                                                         │
│    _alerts.clear() → _persist() → notifyListeners()                     │
│                                                                          │
│ Consumers:                                                               │
│  • AlertsScreen (displays alerts list)                                  │
│  • DashboardScreen (shows 3 recent alerts)                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Error Handling Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    ERROR HANDLING PATTERNS                                │
└──────────────────────────────────────────────────────────────────────────┘

LAYER 1: Firebase Auth Errors
──────────────────────────────

try {
  await _auth.signInWithEmailPassword(email: email, password: pass)
} on FirebaseAuthException catch (e) {
  // Friendly error messages
  String message = _friendlyAuthError(e); // Map e.code to user-friendly text
  // Show in ScaffoldMessenger.showSnackBar()
} on TimeoutException catch (e) {
  // Handle network timeout (45 seconds)
  ScaffoldMessenger.showSnackBar("Login timed out...")
} catch (e) {
  // Generic error
  ScaffoldMessenger.showSnackBar("Login failed: ${e.toString()}")
}

Codes handled:
  • user-not-found
  • wrong-password / invalid-credential
  • invalid-email
  • user-disabled
  • weak-password
  • network-request-failed
  • too-many-requests


LAYER 2: Firestore/Firebase Service Errors
────────────────────────────────────────────

FirebaseService methods silently catch errors:
  • Log to console: print('Failed creating user doc: $e')
  • Don't throw (prevents app crash)
  • Continue execution

Example (from auth_provider.dart):
  try {
    await _firestoreService.createUserIfNotExists(u);
  } catch (e) {
    print('Failed creating user doc: $e');
    // Continue - user data will be created on next login
  }


LAYER 3: API Client Errors
──────────────────────────

try {
  final data = await _client.get('/api/rates/latest', query: query);
} catch (e) {
  if (kDebugMode) {
    debugPrint('[MarketApi] Error fetching rates: $e');
  }
  rethrow; // Let caller handle
}

Response error parsing:
  if (data is Map && data['message'] is String) {
    throw Exception(data['message']); // Backend error message
  }
  if (statusCode >= 300) {
    throw Exception('Request failed (${statusCode}): ${body}');
  }


LAYER 4: Screen-Level Error Handling
────────────────────────────────────

FutureBuilder pattern:
  FutureBuilder<List<DailyForecast>>(
    future: _dailyForecastFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      } else if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return Center(child: Text('No data available'));
      } else {
        return ListView(...); // Success
      }
    }
  )

SnackBar for user feedback:
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errorMessage))
  );


LAYER 5: Graceful Degradation
───────────────────────────────

Dashboard screen:
  • Location not set → "No location set"
  • Weather API fails → "Error fetching weather"
  • Forecast unavailable → Show current weather only
  • Alerts unavailable → Don't crash, empty list

Market screen:
  • API unreachable → "Error fetching listings"
  • No listings exist → "No listings available"
  • Image upload fails → Show error, allow retry

Settings screen:
  • Firebase write fails → "Save sample data to Firebase" button becomes error
  • Notification permission denied → Guide to app settings


LAYER 6: Development Mode Debug Features
─────────────────────────────────────────

if (kDebugMode) {
  debugPrint('[Service] Action performed');
  debugPrint('[ApiClient] Response: ${res.statusCode} - ${res.body}');
}

// Only shown when running in debug mode (not in production builds)
```

---

## 8. Data Models Relationship Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                      DATA MODEL RELATIONSHIPS                             │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────┐
│ USER         │ (MongoDB + Firestore)
├──────────────┤
│ _id (Mongo) ←┼─────┐
│ uid (Firestore) │  │
│ name         │  │  One-to-many
│ phone        │  │  ┌─────────────────────┐
│ countryCode  │  │  │                     │
│ role         │  │  ▼                     │
│ district     │  ├─►LISTING (Seller)    │
│ province     │  │  ├─ sellerUid (FK)   │
│ timestamps   │  │  ├─ sellerRef (FK)◄──┘
│              │  │  ├─ cropName         │
│ Firestore:   │  │  ├─ quantity         │
│ • email      │  │  ├─ askingPrice      │
│ • fcmToken   │  │  └─ status          │
│ • lat/lon    │  │
│ • address    │  │  One-to-many        │
│              │  │  ┌─────────────────────┐
│              │  │  │                     │
│              │  │  ▼                     │
│              │  └─►OFFER (Buyer)       │
│              │     ├─ buyerUid (FK)    │
│              │     ├─ buyerRef (FK)◄───┘
│              │     ├─ listingId (FK)◄──────┐
│              │     ├─ offerPrice          │
│              │     └─ status              │
│              │        │                   │
│              │        │ When accepted     │
│              │        │ creates ↓         │
│              │        │                   │
│              │        ▼                   │
│              │     ORDER                  │
│              │     ├─ offerId (FK)       │
│              │     ├─ listingId (FK)◄────┘
│              │     ├─ buyerUid (FK)◄──┐
│              │     ├─ sellerUid (FK)◄─┼─┘
│              │     ├─ finalPrice       │
│              │     └─ status          │
│              │                         │
│              └─────────────────────────┘


CROP RATE (standalone)
──────────────────────

┌────────────────────┐
│ CROPRATE           │
├────────────────────┤
│ cropName (indexed) │
│ marketName         │
│ district (indexed) │
│ minPrice           │
│ maxPrice           │
│ unit               │
│ sourceName         │
│ sourceUrl          │
│ rateDate (indexed) │
│ isOfficialSource   │
└────────────────────┘


INDEX STRATEGY:
───────────────

User:
  • firebaseUid: unique, indexed
  • (phone, countryCode): unique compound index

Listing:
  • sellerUid: indexed (for "my listings")
  • (cropName, district, status, createdAt): compound index

Offer:
  • listingId: indexed
  • (listingId, status, createdAt): compound index
  • buyerUid: indexed (for "my offers")

Order:
  • (buyerUid, createdAt): compound index (for buyer's orders)
  • (sellerUid, createdAt): compound index (for seller's orders)

CropRate:
  • (cropName, district, rateDate): compound index
```

---

## 9. Request-Response Cycle Example

```
┌──────────────────────────────────────────────────────────────────────────┐
│            TYPICAL API REQUEST-RESPONSE CYCLE                             │
└──────────────────────────────────────────────────────────────────────────┘

EXAMPLE: Fetch Marketplace Listings
────────────────────────────────────

STEP 1: CLIENT SIDE (Flutter App)
───────────────────────────────────

  MarketplaceTabState._load()
  │
  ├─ setState(() {
  │    _loading = true;
  │    _error = null;
  │  });
  │
  ├─ _service.fetchListings(
  │    crop: "Wheat",
  │    district: "Lahore"
  │  )
  │
  └─ MarketApiService.fetchListings()
     │
     └─ _client.get(
        '/api/listings',
        query: {
          'crop': 'Wheat',
          'district': 'Lahore'
        },
        auth: false
      )
           │
           └─ ApiClient.get()
              │
              ├─ Construct URL:
              │  http://10.224.247.221:5000/api/listings
              │  ?crop=Wheat&district=Lahore
              │
              ├─ Add headers:
              │  {
              │    'Content-Type': 'application/json'
              │  }
              │  (no auth header needed for public endpoint)
              │
              └─ http.get(url, headers)
                 │
                 └─ Send HTTP GET request


STEP 2: NETWORK
───────────────

  HTTP GET /api/listings?crop=Wheat&district=Lahore


STEP 3: SERVER SIDE (Node.js)
──────────────────────────────

  Express app receives request
  │
  ├─ Middleware 1: CORS check
  │  └─ Origin header check → Allow
  │
  ├─ Middleware 2: express.json
  │  └─ Parse body (GET has no body)
  │
  ├─ Middleware 3: Static files
  │  └─ Not a file request, continue
  │
  ├─ Router: GET /api/listings
  │
  └─ Route Handler:
     │
     ├─ Extract query params:
     │  crop = "Wheat"
     │  district = "Lahore"
     │  status = "open" (default)
     │  sort = "new" (default)
     │
     ├─ Build MongoDB query:
     │  {
     │    cropName: "Wheat",
     │    district: "Lahore",
     │    status: "open"
     │  }
     │
     ├─ Execute query:
     │  ListingModel.find(query)
     │    .sort({createdAt: -1})
     │    .limit(50)
     │
     ├─ Results received:
     │  [
     │    {
     │      _id: ObjectId("..."),
     │      sellerUid: "firebase-uid",
     │      cropName: "Wheat",
     │      qualityGrade: "A",
     │      quantity: 100,
     │      unit: "40kg",
     │      askingPrice: 2500,
     │      district: "Lahore",
     │      status: "open",
     │      imageUrls: ["http://..."],
     │      createdAt: ISODate("..."),
     │      updatedAt: ISODate("...")
     │    },
     │    ...
     │  ]
     │
     └─ Send response:
        res.json(rows)


STEP 4: NETWORK
───────────────

  HTTP 200 OK
  Content-Type: application/json
  
  [
    {
      "_id": "507f1f77bcf86cd799439011",
      "sellerUid": "uid123",
      "cropName": "Wheat",
      "qualityGrade": "A",
      "quantity": 100,
      "unit": "40kg",
      "askingPrice": 2500,
      "district": "Lahore",
      "status": "open",
      "imageUrls": ["http://..."],
      "createdAt": "2024-01-15T10:00:00Z",
      "updatedAt": "2024-01-15T10:00:00Z"
    }
  ]


STEP 5: CLIENT SIDE (continued)
────────────────────────────────

  ApiClient._decode(response)
  │
  ├─ Check status code: 200
  │  ✓ Success (200-299 range)
  │
  ├─ Parse JSON body:
  │  [
  │    {...},
  │    ...
  │  ]
  │
  └─ Return: List<Map>
     │
     └─ MarketApiService.fetchListings()
        │
        ├─ Parse response as List<dynamic>
        │
        ├─ Convert each item to ListingDto:
        │  ListingDto(
        │    id: json['_id'],
        │    cropName: json['cropName'],
        │    quantity: json['quantity'],
        │    ...
        │  )
        │
        └─ Return: List<ListingDto>
           │
           └─ _MarketplaceTabState._load()
              │
              ├─ setState(() {
              │    _rows = data;
              │    _loading = false;
              │  });
              │
              └─ Widget rebuilds with listings
                 │
                 └─ ListView shows listing cards
                    (user can now browse/tap to make offer)


ERROR CASE EXAMPLE:
───────────────────

If Network fails or server error:

  HTTP Error Response
  ┌────────────────────┐
  │ 500 Internal Error │
  │ {                  │
  │   message: "DB"    │
  │   "error"          │
  │ }                  │
  └────────────────────┘
           │
           ▼
  ApiClient._decode()
  │
  ├─ Check status: 500
  │  ✗ Error (not 200-299)
  │
  ├─ Parse JSON:
  │  data['message'] = "DB error"
  │
  ├─ Throw Exception:
  │  throw Exception("DB error")
  │
  └─ Propagates up
     │
     └─ _MarketplaceTabState._load() catch block:
        │
        ├─ setState(() {
        │    _error = e.toString(); // "DB error"
        │    _loading = false;
        │  });
        │
        └─ Widget rebuilds
           │
           └─ Shows error message instead of listings
```

---

This comprehensive architecture documentation provides complete visibility into:

✅ **Frontend Architecture** (Flutter with Dart)
✅ **Backend Architecture** (Node.js with Express)  
✅ **State Management** (Provider pattern)
✅ **Database Schema** (MongoDB collections + Firestore)
✅ **Authentication Flow** (Firebase Auth + JWT tokens)
✅ **API Communication** (RESTful endpoints)
✅ **Data Persistence** (SharedPreferences + MongoDB)
✅ **Error Handling** (Multi-layer strategy)
✅ **User Flows** (Marketplace, Alerts, Weather)
✅ **Notification System** (FCM + Local)

