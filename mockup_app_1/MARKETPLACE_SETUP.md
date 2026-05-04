# Marketplace Setup Guide

## Current Status
Marketplace features (Rates, Buy/Sell, Offers, Orders) require a **backend API server** to function. Currently, you don't have a backend running.

## What's Needed

### 1. Backend API Server
The app expects a backend running at one of these addresses:

- **For Emulator**: `http://10.0.2.2:5000`
- **For Physical Device**: Update `lib/config/app_config.dart` with your backend address
  - Localhost machine: `http://192.168.x.x:5000` (replace x.x with your machine's IP)
  - Remote server: `http://your-server.com:5000`

### 2. Required API Endpoints

#### Rates Endpoints
- `GET /api/rates/latest` - Fetch latest crop rates
  - Query params: `crop`, `district` (optional)
  - Returns: `List<CropRateDto>`

#### Listings Endpoints
- `GET /api/listings` - Fetch marketplace listings
  - Query params: `crop`, `district` (optional)
  - Returns: `List<ListingDto>`
- `POST /api/listings` - Create a new listing (auth required)

#### User Endpoints
- `GET /api/users/me` - Get current user profile (auth required)
  - Returns: `UserProfileDto`

#### Offers Endpoints
- `GET /api/offers/me` - Get my offers (auth required)
- `GET /api/offers/incoming` - Get incoming offers (auth required)
- `POST /api/offers` - Make an offer (auth required)
- `POST /api/offers/{id}/accept` - Accept an offer (auth required)
- `POST /api/offers/{id}/reject` - Reject an offer (auth required)

#### Orders Endpoints
- `GET /api/orders` - Get my orders (auth required)

### 3. Update API Configuration

To use your backend, update `lib/config/app_config.dart`:

```dart
class AppConfig {
  static const String apiBaseUrl = 'http://192.168.x.x:5000'; // Your backend address
}
```

Then rebuild the app:
```bash
flutter clean
flutter pub get
flutter run -d RZCWA12SKKV
```

## Debugging

Added comprehensive debug logging to help troubleshoot API issues:

- Launch the app in verbose mode:
  ```bash
  flutter run -d RZCWA12SKKV -v
  ```

- Look for logs starting with:
  - `[ApiClient]` - API request/response details
  - `[MarketApi]` - Marketplace-specific operations

## Features Disabled Until Backend Available

1. **Market Rates Tab** - Shows crop prices from official sources
2. **Buy/Sell Tab** - Marketplace for buying/selling crops
3. **Offers Screen** - Manage purchase offers
4. **Orders Screen** - View order history
5. **User Profile** - Admin features

## Data Models

### CropRateDto
```
{
  "cropName": "Wheat",
  "marketName": "Central Market",
  "district": "Lahore",
  "minPrice": 2500,
  "maxPrice": 3000,
  "unit": "40kg",
  "sourceName": "Official Rate",
  "sourceUrl": "http://...",
  "rateDate": "2024-01-15T10:30:00Z"
}
```

### ListingDto
```
{
  "cropName": "Rice",
  "qualityGrade": "A",
  "quantity": 100,
  "unit": "40kg",
  "askingPrice": 4500,
  "district": "Karachi",
  "status": "active",
  "imageUrls": ["http://...", "http://..."],
  "createdAt": "2024-01-15T10:30:00Z"
}
```

### UserProfileDto
```
{
  "firebaseUid": "user-id",
  "name": "Farmer Name",
  "phone": "+92...",
  "role": "farmer|admin",
  "district": "Lahore",
  "province": "Punjab"
}
```

## Next Steps

1. Set up or connect to a backend API server
2. Update `lib/config/app_config.dart` with the backend URL
3. Ensure authentication tokens are properly sent with requests
4. Verify the backend implements the required endpoints
5. Rebuild and test the marketplace features
