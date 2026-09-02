# Digital Kissan

Digital Kissan is a Flutter-based agricultural platform for farmers, buyers,
sellers, and agricultural professionals. It brings weather intelligence,
market information, produce trading, communication, and farming assistance
into one mobile application.

The application supports English and Urdu. Firebase provides authentication
and cloud services, while the Node.js backend manages domain data such as
market rates, listings, offers, and orders.

## Project Purpose

Farmers need timely information before deciding what to grow, when to work,
or where to sell. Digital Kissan connects that information with a practical
marketplace workflow:

1. A user signs in and sets a location.
2. The dashboard presents local weather, alerts, and market information.
3. A farmer publishes produce, manages listings, and communicates with buyers.
4. A buyer browses listings, contacts sellers, makes offers, and tracks orders.
5. The assistant and plant-disease tools provide additional farming support.

## Main Features

### Weather and Location

- Current weather, detailed forecasts, and seven-day forecasts
- Location selection with Mapbox, geolocation, and geocoding
- Weather and agricultural alerts

### Market Information

- Latest agricultural commodity rates
- Rate administration for authorized users
- Market data delivered through the backend API

### Digital Marketplace

- Browse and filter produce listings
- Create, edit, and manage listings
- View product and seller details
- Create offers and manage order status
- Upload listing and profile images through the backend

### Communication and Assistance

- Buyer and seller conversations
- AI agriculture assistant
- Farming suggestions and guidance
- Plant-disease classification using the TensorFlow Lite model in `assets/model`

### Accounts and Localization

- Firebase phone and email authentication flows
- User profiles, seller profiles, ratings, and settings
- English and Urdu localization
- Push notifications and local alerts

## App Screenshots

These previews show the main user journeys. Select any image to open the
original full-size screenshot.

<table>
  <tr>
    <td align="center"><a href="images/splash%20screen.jpeg"><img src="images/splash%20screen.jpeg" alt="Splash screen" width="180"></a><br><strong>Splash</strong></td>
    <td align="center"><a href="images/dashboard%20screen.jpeg"><img src="images/dashboard%20screen.jpeg" alt="Dashboard screen" width="180"></a><br><strong>Dashboard</strong></td>
    <td align="center"><a href="images/rates.jpeg"><img src="images/rates.jpeg" alt="Market rates" width="180"></a><br><strong>Market rates</strong></td>
  </tr>
  <tr>
    <td align="center"><a href="images/marketplace.jpeg"><img src="images/marketplace.jpeg" alt="Marketplace" width="180"></a><br><strong>Marketplace</strong></td>
    <td align="center"><a href="images/buy%20sell.jpeg"><img src="images/buy%20sell.jpeg" alt="Buy and sell" width="180"></a><br><strong>Buy and sell</strong></td>
    <td align="center"><a href="images/listing%20detail.jpeg"><img src="images/listing%20detail.jpeg" alt="Listing details" width="180"></a><br><strong>Listing details</strong></td>
  </tr>
  <tr>
    <td align="center"><a href="images/edit%20listing.jpeg"><img src="images/edit%20listing.jpeg" alt="Edit listing" width="180"></a><br><strong>Edit listing</strong></td>
    <td align="center"><a href="images/seller%20profile.jpeg"><img src="images/seller%20profile.jpeg" alt="Seller profile" width="180"></a><br><strong>Seller profile</strong></td>
    <td align="center"><a href="images/profile.jpeg"><img src="images/profile.jpeg" alt="User profile" width="180"></a><br><strong>User profile</strong></td>
  </tr>
  <tr>
    <td align="center"><a href="images/edit%20profile.jpeg"><img src="images/edit%20profile.jpeg" alt="Edit profile" width="180"></a><br><strong>Edit profile</strong></td>
    <td align="center"><a href="images/setting.jpeg"><img src="images/setting.jpeg" alt="Settings" width="180"></a><br><strong>Settings</strong></td>
    <td align="center"><a href="images/setting%20location.jpeg"><img src="images/setting%20location.jpeg" alt="Location settings" width="180"></a><br><strong>Location</strong></td>
  </tr>
  <tr>
    <td align="center"><a href="images/7%20day%20forecast.jpeg"><img src="images/7%20day%20forecast.jpeg" alt="Seven day forecast" width="180"></a><br><strong>7-day forecast</strong></td>
    <td align="center"><a href="images/detailed%20forecast.jpeg"><img src="images/detailed%20forecast.jpeg" alt="Detailed forecast" width="180"></a><br><strong>Detailed forecast</strong></td>
    <td align="center"><a href="images/alerts.jpeg"><img src="images/alerts.jpeg" alt="Alerts screen" width="180"></a><br><strong>Alerts</strong></td>
  </tr>
  <tr>
    <td align="center"><a href="images/alerts%20button.jpeg"><img src="images/alerts%20button.jpeg" alt="Alerts button" width="180"></a><br><strong>Alert button</strong></td>
    <td align="center"><a href="images/chat.jpeg"><img src="images/chat.jpeg" alt="Chat screen" width="180"></a><br><strong>Chat</strong></td>
    <td align="center"><a href="images/chatbot.jpeg"><img src="images/chatbot.jpeg" alt="Agriculture chatbot" width="180"></a><br><strong>AI chatbot</strong></td>
  </tr>
</table>

## Technology Stack

### Flutter Application

- Flutter and Dart
- Provider for state management
- Firebase Auth, Firestore, Messaging, and Core
- Mapbox Maps Flutter, Geolocator, and Geocoding
- HTTP client for REST API communication
- Shared Preferences for local settings
- TensorFlow Lite model for plant-disease classification

### Backend

- Node.js with Express
- Firebase Admin SDK and Firestore
- Firebase ID-token verification
- Multer and Cloudinary for image uploads
- Helmet, CORS, and rate limiting
- Grok AI for assistant responses
- OpenWeather integration for weather data

## Project Structure

```text
digital-kissan-app/
├── lib/
│   ├── main.dart                 # Flutter entry point
│   ├── config/                   # App configuration
│   ├── l10n/                     # English and Urdu localization
│   ├── models/                   # Application data models
│   ├── providers/                # Shared application state
│   ├── screens/                  # App screens and user workflows
│   ├── services/                 # Auth, API, weather, alerts, and ML services
│   ├── utils/                    # Shared Dart utilities
│   └── widgets/                  # Reusable UI components
├── assets/model/                 # Model file and classification labels
├── images/                       # README screenshots
├── test/                         # Flutter and service tests
├── android/                      # Android and Gradle configuration
├── web/                          # Flutter web configuration and icons
├── backend/
│   ├── src/
│   │   ├── app.js                # Express application configuration
│   │   ├── server.js             # Backend entry point
│   │   ├── config/               # Backend configuration
│   │   ├── middlewares/          # Auth and request middleware
│   │   ├── models/               # Domain data models
│   │   ├── routes/               # REST API routes
│   │   ├── services/             # Backend business logic
│   │   └── utils/                # Backend helpers
│   ├── scripts/                  # Backend validation and utility scripts
│   ├── uploads/                  # Local upload directories
│   ├── package.json              # Backend dependencies and commands
│   └── README.md                 # Backend documentation
├── pubspec.yaml                  # Flutter dependencies and assets
├── analysis_options.yaml         # Dart analysis rules
├── firebase.json                 # Firebase configuration
└── render.yaml                   # Render deployment definition
```

Generated build output, installed dependencies, local environment files, and
service-account credentials are intentionally excluded from this overview.

## Requirements

- Flutter SDK with Dart `^3.7.2`
- Android Studio and Android SDK
- Java 17 for the current Android Gradle configuration
- Node.js and npm for the backend
- Firebase project with Authentication and Firestore enabled
- Mapbox account and access token
- Optional Grok, Cloudinary, and OpenWeather credentials

## Installation and Local Setup

### 1. Install Flutter dependencies

Run from the `digital-kissan-app` directory:

```powershell
flutter pub get
```

### 2. Configure Android secrets

Copy `android/local.properties.example` to `android/local.properties` and add:

```properties
MAPBOX_DOWNLOADS_TOKEN=pk.YOUR_MAPBOX_DOWNLOADS_TOKEN_HERE
```

Do not commit `android/local.properties`.

### 3. Configure Firebase

Place the Firebase Android configuration file at
`android/app/google-services.json` and confirm that its package ID matches
`com.example.mockup_app`.

### 4. Start the backend

From `digital-kissan-app/backend`, create `.env` from `.env.example`, add the
required credentials, and run:

```powershell
npm install
npm run seed
npm run dev
```

The API is normally available at `http://localhost:5000`.

### 5. Run the Flutter application

For an Android emulator:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

For a physical device, replace the address with the computer's LAN IP:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR-LAN-IP:5000
```

Keep the phone and computer on the same network. For USB debugging, use
`adb reverse tcp:5000 tcp:5000` when appropriate.

## Backend Authentication and API

Firebase handles user identity. The Flutter client sends the Firebase ID token
to protected backend routes as:

```text
Authorization: Bearer <firebase_id_token>
```

The backend verifies the token with Firebase Admin before allowing protected
operations. Domain data such as rates, listings, offers, and orders is served
through the REST API.

Important routes include:

| Method | Route | Purpose |
| --- | --- | --- |
| GET | `/api/health` | Service health check |
| GET | `/api/config/public` | Public app configuration |
| GET | `/api/rates/latest` | Latest market rates |
| GET | `/api/listings` | Browse marketplace listings |
| POST | `/api/listings` | Create a listing |
| POST | `/api/offers` | Create an offer |
| GET | `/api/orders/me` | View the signed-in user's orders |
| POST | `/api/assistant/chat` | Ask the agriculture assistant |

See `backend/README.md` for the complete route list and environment setup.

## Testing

Run Flutter tests and static analysis from the project directory:

```powershell
flutter test
flutter analyze
```

Backend validation and integration scripts are available in `backend/scripts`.

## Deployment

The backend includes `render.yaml` for Render deployment. Configure secrets in
the hosting provider rather than committing them:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_SERVICE_ACCOUNT_JSON` or `GOOGLE_APPLICATION_CREDENTIALS`
- `MAPBOX_ACCESS_TOKEN`
- `GROK_API_KEY`
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

After deployment, run Flutter with the hosted API URL:

```powershell
flutter run --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

## Security Guidelines

- Never commit `.env`, `android/local.properties`, or service-account files.
- Never place private API keys in Flutter source code.
- Rotate credentials exposed in source control or build logs.
- Restrict third-party keys to the required scopes and environments.
- Use secret management provided by the deployment platform in production.

## Project Status

Digital Kissan is an active final-year project implementation. Authentication,
weather, market, marketplace, messaging, assistant, profile, localization,
plant-disease, and Android workflows are present in the current codebase.

## License

This project is currently maintained as a private academic project. Add a
license file before distributing it publicly.