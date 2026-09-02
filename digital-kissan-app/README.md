# mockup_app

Digital Kissan — mockup_app

This repository contains a Flutter mockup app for a simple agriculture-focused
mobile application (English + Urdu). It uses Firebase (Auth, Firestore),
Mapbox maps, geolocation, and localized UI.

**This README covers:** project overview, local setup, handling secrets,
and commands to run the app on a development machine.

## App Screenshots

The screenshots below show the main user journeys and screens available in
Digital Kissan.

<table>
	<tr>
		<td align="center"><img src="images/splash%20screen.jpeg" alt="Splash screen" width="220"><br><strong>Splash screen</strong></td>
		<td align="center"><img src="images/dashboard%20screen.jpeg" alt="Dashboard screen" width="220"><br><strong>Dashboard</strong></td>
		<td align="center"><img src="images/rates.jpeg" alt="Market rates" width="220"><br><strong>Market rates</strong></td>
	</tr>
	<tr>
		<td align="center"><img src="images/marketplace.jpeg" alt="Marketplace" width="220"><br><strong>Marketplace</strong></td>
		<td align="center"><img src="images/listing%20detail.jpeg" alt="Listing detail" width="220"><br><strong>Listing details</strong></td>
		<td align="center"><img src="images/buy%20sell.jpeg" alt="Buy and sell screen" width="220"><br><strong>Buy and sell</strong></td>
	</tr>
	<tr>
		<td align="center"><img src="images/seller%20profile.jpeg" alt="Seller profile" width="220"><br><strong>Seller profile</strong></td>
		<td align="center"><img src="images/edit%20listing.jpeg" alt="Edit listing" width="220"><br><strong>Edit listing</strong></td>
		<td align="center"><img src="images/profile.jpeg" alt="User profile" width="220"><br><strong>User profile</strong></td>
	</tr>
	<tr>
		<td align="center"><img src="images/edit%20profile.jpeg" alt="Edit profile" width="220"><br><strong>Edit profile</strong></td>
		<td align="center"><img src="images/setting.jpeg" alt="Settings" width="220"><br><strong>Settings</strong></td>
		<td align="center"><img src="images/setting%20location.jpeg" alt="Location settings" width="220"><br><strong>Location settings</strong></td>
	</tr>
	<tr>
		<td align="center"><img src="images/7%20day%20forecast.jpeg" alt="Seven day forecast" width="220"><br><strong>Seven-day forecast</strong></td>
		<td align="center"><img src="images/detailed%20forecast.jpeg" alt="Detailed weather forecast" width="220"><br><strong>Detailed forecast</strong></td>
		<td align="center"><img src="images/alerts.jpeg" alt="Weather alerts" width="220"><br><strong>Weather alerts</strong></td>
	</tr>
	<tr>
		<td align="center"><img src="images/alerts%20button.jpeg" alt="Alerts button" width="220"><br><strong>Alerts</strong></td>
		<td align="center"><img src="images/chat.jpeg" alt="Chat screen" width="220"><br><strong>Chat</strong></td>
		<td align="center"><img src="images/chatbot.jpeg" alt="Agriculture chatbot" width="220"><br><strong>AI chatbot</strong></td>
	</tr>
</table>

**Quick facts**
- **Dart SDK constraint**: `^3.7.2` (see `pubspec.yaml`)
- **Android Java target**: Java 11 (configured in `android/app/build.gradle.kts`)
- **Localization**: English (`en`) and Urdu (`ur`) via generated `lib/l10n`

**Primary dependencies** (see full list in `pubspec.yaml`):
- `firebase_core`, `firebase_auth`, `cloud_firestore`
- `mapbox_maps_flutter`, `geolocator`, `geocoding`, `permission_handler`
- `provider`, `shared_preferences`, `google_fonts`, `intl`, `country_picker`

**Security note**: This project previously contained a Mapbox token in
Gradle files. Tokens must not be committed to VCS — follow the "Secrets"
section below.

## App Features & Screenshots

**Digital Kissan** is a comprehensive agricultural mobile application designed to empower farmers with real-time market information, weather forecasts, communication tools, and a digital marketplace. Below are the key features with visual demonstrations:

### 1. **Splash Screen**
![Splash Screen](digital-kissan-app/images/splash%20screen.jpeg)

The welcoming splash screen that greets users when they launch the application, featuring the Digital Kissan branding and loading animation.

---

### 2. **Dashboard Screen**
![Dashboard Screen](digital-kissan-app/images/dashboard%20screen.jpeg)

The main hub of the application where users can quickly access:
- Current weather conditions and quick weather overview
- Recent market rates for agricultural commodities
- Shortcuts to key features (marketplace, alerts, profile)
- User's location and relevant local information

---

### 3. **Weather & Forecasts**

#### **7-Day Forecast**
![7 Day Forecast](digital-kissan-app/images/7%20day%20forecast.jpeg)

Provides an extended weather outlook showing:
- Daily temperature ranges
- Precipitation probability
- Wind speed and direction
- Weather conditions for the next 7 days

#### **Detailed Forecast**
![Detailed Forecast](digital-kissan-app/images/detailed%20forecast.jpeg)

Comprehensive hourly and daily weather information including:
- Temperature trends
- Humidity levels
- UV index
- Visibility and atmospheric pressure

---

### 4. **Alerts System**

#### **Alerts Button & Notifications**
![Alerts Button](digital-kissan-app/images/alerts%20button.jpeg)

Quick access button to weather and market alerts from the main interface.

#### **Alerts Screen**
![Alerts](digital-kissan-app/images/alerts.jpeg)

Centralized alert management displaying:
- Critical weather warnings (frost, storms, extreme temperatures)
- Market price alerts for selected commodities
- Agricultural advisory notifications
- Customizable alert preferences

---

### 5. **Marketplace Features**

#### **Marketplace Overview**
![Marketplace](digital-kissan-app/images/marketplace.jpeg)

The digital marketplace for buying and selling agricultural products:
- Browse available listings from farmers and traders
- Filter by commodity type, location, and price range
- Real-time inventory updates
- Seller ratings and reviews

#### **Buy & Sell Interface**
![Buy Sell](digital-kissan-app/images/buy%20sell.jpeg)

Dual marketplace view allowing users to:
- Post new listings for sale
- Browse and purchase from others
- Manage active listings
- Track transaction history

#### **Listing Details**
![Listing Detail](digital-kissan-app/images/listing%20detail.jpeg)

Detailed product information including:
- Product images and specifications
- Quantity available
- Price and discounts
- Seller information and contact details
- Location on map
- Customer reviews

#### **Edit Listing**
![Edit Listing](digital-kissan-app/images/edit%20listing.jpeg)

Interface for updating product listings:
- Modify price and quantity
- Update product description
- Change product images
- Adjust delivery terms

---

### 6. **Market Rates & Pricing**
![Market Rates](digital-kissan-app/images/rates.jpeg)

Real-time commodity price information:
- Current market rates for major agricultural products
- Price trends and historical data
- Regional price comparisons
- Price alerts for tracked commodities
- Data sourced from official government and market sources

---

### 7. **Communication & Support**

#### **Chat**
![Chat](digital-kissan-app/images/chat.jpeg)

Direct messaging between buyers and sellers:
- Real-time chat with transaction partners
- Message history and search
- Image and file sharing
- Transaction-linked conversations

#### **AI Chatbot Assistant**
![Chatbot](digital-kissan-app/images/chatbot.jpeg)

Intelligent agricultural guidance powered by AI:
- Answer farming questions (crop selection, pest management, irrigation techniques)
- Provide weather-based farming recommendations
- Market advice and pricing insights
- Multilingual support (English & Urdu)
- 24/7 availability

---

### 8. **User Profile & Settings**

#### **User Profile**
![Profile](digital-kissan-app/images/profile.jpeg)

Personal profile dashboard showing:
- User's name, contact information, and avatar
- Account verification status
- Total transactions and ratings
- Listing count and activity status
- Quick links to edit profile and settings

#### **Edit Profile**
![Edit Profile](digital-kissan-app/images/edit%20profile.jpeg)

User information management:
- Update name and contact details
- Change profile picture
- Modify bio and agricultural specialization
- Update location and service area
- Manage account preferences

#### **Seller Profile**
![Seller Profile](digital-kissan-app/images/seller%20profile.jpeg)

View other sellers' profiles including:
- Seller ratings and review count
- Active listings
- Response time and reliability metrics
- Seller specialization areas
- Contact and location information

#### **Settings**
![Settings](digital-kissan-app/images/setting.jpeg)

Comprehensive application settings:
- Language preferences (English/Urdu)
- Notification settings
- Privacy and account security options
- App version and about information
- Help and feedback options

#### **Setting Location**
![Setting Location](digital-kissan-app/images/setting%20location.jpeg)

Location and area management:
- Set primary location for better local content
- Add multiple operating locations
- Configure service radius
- Location-based alert preferences
- Map-based location selection

---

## Technology Stack

**Frontend:**
- Flutter/Dart (84.6% of codebase)
- Multi-language support (English + Urdu)
- Firebase Authentication
- Mapbox Integration for location services

**Backend:**
- Node.js/Express REST API
- Firebase Firestore for data storage
- Firebase Authentication token verification
- Integration with third-party services:
  - Mapbox for maps and geocoding
  - Grok AI for chatbot functionality
  - Cloudinary for image management
  - OpenWeather API for weather data

---

## Setup (developer machine)

1. Install prerequisites:

	 - Flutter SDK (matching the project's channel and supporting Dart >= 3.7.2).
	 - Android SDK + Android Studio or command-line tools.
	 - Java 11 (required by Gradle config).

2. Prepare secrets (Mapbox token):

	 - Copy the example file and provide your token in `android/local.properties`.

		 Example file: `android/local.properties.example`.

		 Create `android/local.properties` (DO NOT commit this file). Example content:

		 ```text
		 # Flutter SDK path (optional on dev machines):
		 # flutter.sdk=C:\\path\\to\\flutter

		 # Mapbox downloads token used for the Mapbox Maven repository
		 MAPBOX_DOWNLOADS_TOKEN=pk.YOUR_MAPBOX_DOWNLOADS_TOKEN_HERE
		 ```

	 - Alternatively provide `MAPBOX_DOWNLOADS_TOKEN` as an environment variable.

		 In **PowerShell** (session only):

		 ```powershell
		 $env:MAPBOX_DOWNLOADS_TOKEN = 'pk.YOUR_MAPBOX_TOKEN'
		 ```

		 Persist across sessions (PowerShell):

		 ```powershell
		 setx MAPBOX_DOWNLOADS_TOKEN "pk.YOUR_MAPBOX_TOKEN"
		 ```

3. Firebase configuration:

	 - `android/app/google-services.json` should be present for Android builds.
		 This repository currently contains a `google-services.json` file under
		 `android/app/` — treat it as sensitive configuration.
	 - Ensure your Firebase project is configured for the app's package id
		 `com.example.mockup_app` or update `applicationId` in
		 `android/app/build.gradle.kts`.

4. Install Dart/Flutter packages and build:

	 ```powershell
	 flutter pub get
	 flutter pub run build_runner build --delete-conflicting-outputs  # if needed for generated code
	 ```

5. Run the app on a connected device or emulator:

	 ```powershell
	 flutter run -d <device-id>
	 ```

## Secrets & safety
- Do NOT commit `android/local.properties` or any file containing secrets.
- Rotate any token that was exposed in the repository (Mapbox token found
	previously). Create a new token in your Mapbox account and revoke the old one.
- Consider restricting tokens (scopes, allowed domains/hosts) where possible.
- If a secret has been committed to Git history, remove it from history using
	a tool such as the [BFG Repo-Cleaner](https://rtyley.github.io/bfg-repo-cleaner/)
	or `git filter-repo`. These operations rewrite history and require care.

## How Gradle loads Mapbox token now
- `android/settings.gradle.kts` and `android/build.gradle.kts` have been
	updated to read `MAPBOX_DOWNLOADS_TOKEN` from `android/local.properties` (key
	`MAPBOX_DOWNLOADS_TOKEN`) or fallback to the `MAPBOX_DOWNLOADS_TOKEN` env var.

## Recommended `.gitignore` checks
- Ensure `android/local.properties` is ignored (it usually is by default).
- Avoid committing any CI or secrets files.

## Developer notes / architecture
- `lib/main.dart` initializes Firebase and sets up `LanguageProvider` and
	`AuthProvider`.
- Phone-number authentication flows are implemented in
	`lib/screens/login_screen.dart` using `AuthService` and `FirebaseService`.
- Map and location functionality lives in `lib/screens/location_screen.dart`
	using `mapbox_maps_flutter`, `geolocator`, and `geocoding`.

## Next actions I can take (select one or more):
- Search the repository for other leaked tokens/credentials and report findings.
- Help rotate the exposed Mapbox token and (optionally) remove it from Git
	history — I can prepare git commands but will need your confirmation.
- Add a short docs section in `CONTRIBUTING.md` or expand this README with
	CI setup steps.

If you'd like me to run a repo-wide search for other secrets now, say
"Search for tokens" and I'll scan the workspace and report matches.

## Backend strategy (Firebase Auth + custom REST API + Firestore)
- Firebase is used for authentication tokens only.
- Domain features (rates, buy/sell listings, offers, orders) are served by the local REST backend in `backend/`.
- See `backend/README.md` for complete setup.

## Run backend (local)
```powershell
cd backend
npm install
npm run dev
```

## Run Flutter against backend
- Physical Android device: use your PC LAN IP.
- Android emulator: use `10.0.2.2`.
- USB debugging on a physical Android device: run `adb reverse tcp:5000 tcp:5000` before launching, or pass your PC LAN IP with `--dart-define=API_BASE_URL=http://<your-pc-ip>:5000`.

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.X.X:5000
```

## Current local command (this machine)
```powershell
flutter run --dart-define=API_BASE_URL=http://10.192.10.221:5000
```

## Phone <-> Laptop data exchange checklist
1. Start backend on laptop:
	```powershell
	npm --prefix e:\fyp\mockup_app_1\backend run start
	```
2. Verify backend is reachable from laptop on LAN IP:
	```powershell
	Invoke-RestMethod -Method GET -Uri http://10.192.10.221:5000/api/health
	```
3. Run Flutter with API base URL:
	```powershell
	flutter run --dart-define=API_BASE_URL=http://10.192.10.221:5000
	```
4. Keep phone and laptop on the same hotspot/Wi-Fi network.
5. If the app still cannot connect, allow TCP port 5000 in Windows Firewall.

## New app area
- A new `Market` tab is wired in `lib/main.dart`.
- UI is implemented in `lib/screens/market_screen.dart`.
- Client API services are implemented in `lib/services/api_client.dart` and `lib/services/market_api_service.dart`.

## Deployment

This repo includes a backend service suitable for deployment on Render.
The backend service definition is available in `render.yaml` at the repository root.

### Render deployment steps
1. Push this repo to your Git branch.
2. Create a new Render Web Service using the `backend` folder as the root.
3. Set the service build command to:
   ```bash
   npm install
   ```
4. Set the start command to:
   ```bash
   npm start
   ```
5. Configure required environment variables in Render:
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_SERVICE_ACCOUNT_JSON` (preferred) or `GOOGLE_APPLICATION_CREDENTIALS`
   - `MAPBOX_ACCESS_TOKEN`
   - `GROK_API_KEY`
   - `CLOUDINARY_CLOUD_NAME`
   - `CLOUDINARY_API_KEY`
   - `CLOUDINARY_API_SECRET`
6. Optional environment variables:
   - `OPENWEATHER_KEY`
   - `OPENAI_API_KEY`
   - `OPENAI_MODEL`
   - `OPENAI_MAX_TOKENS`

### Notes
- Do not commit `serviceAccountKey.json` or other secret files.
- The backend reads the API port from `process.env.PORT`, so Render's runtime port configuration is supported automatically.
- For Flutter local development with Render-hosted API, point `API_BASE_URL` to the deployed service URL.

### Flutter with deployed backend
After Render deploys the backend, use the deployed service URL in Flutter:

```powershell
flutter run --dart-define=API_BASE_URL=https://<your-render-service>.onrender.com
```

If you want to test the mobile app against the hosted backend from a local device, use the same `API_BASE_URL` value and ensure the desktop app is not required locally.
