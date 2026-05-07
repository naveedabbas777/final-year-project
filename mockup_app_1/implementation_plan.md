# Migrate Backend from MongoDB to Firebase Firestore

Replace all MongoDB/Mongoose usage in the backend with Firestore, keeping the same REST API contract so the Flutter frontend requires zero changes.

## Current State

The backend currently uses a **hybrid storage model**:
- **Firestore**: users, weather_cache, weather_alerts, messages, typing_status, presence, admin_notification_logs
- **MongoDB (Mongoose)**: listings, offers, orders, crop_rates, ratings

**Goal**: Move the 5 MongoDB collections → Firestore collections, then remove MongoDB entirely.

## User Review Required

> [!IMPORTANT]
> **No breaking changes to the Flutter app**. The REST API endpoints, request/response shapes, and authentication flow all remain identical. Only the backend storage layer changes.

> [!WARNING]  
> **MongoDB `_id` → Firestore doc ID**: MongoDB uses ObjectId (`_id`), Firestore uses auto-generated string IDs. Existing response fields like `_id` will be replaced with `id`. The Flutter frontend already handles both formats via its safe JSON helpers (it checks both `_id` and `id`). I'll verify this is seamless.

> [!IMPORTANT]
> **Mongoose features that disappear**: `.populate()` (used in offers to embed listing data) will be replaced with manual lookups. Aggregation (used in ratings for avg score) will be replaced with client-side computation. The `$in` operator (used in offers/messages) will be replaced with batch queries.

## Open Questions

> [!IMPORTANT]
> **Firestore compound indexes**: Some queries (e.g., listings filtered by `cropName + district + status`, sorted by `createdAt`) will require Firestore composite indexes. These will be auto-suggested by Firestore when first hit — I'll add a `firestore.indexes.json` file for them. Is this acceptable?

## Proposed Changes

### Backend Config

#### [DELETE] [db.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/config/db.js)
Remove MongoDB connection module entirely.

#### [MODIFY] [server.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/server.js)
- Remove `import { connectDb }` and `await connectDb(env.mongoUri)` call
- Remove `MONGO_URI` from env config

#### [MODIFY] [env.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/config/env.js)
- Remove `mongoUri` property

#### [MODIFY] [.env](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/.env)
- Remove `MONGO_URI` line

#### [MODIFY] [package.json](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/package.json)
- Remove `mongoose` dependency

---

### Backend Models → Delete All

#### [DELETE] [user.model.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/models/user.model.js)
#### [DELETE] [listing.model.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/models/listing.model.js)
#### [DELETE] [offer.model.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/models/offer.model.js)
#### [DELETE] [order.model.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/models/order.model.js)
#### [DELETE] [cropRate.model.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/models/cropRate.model.js)
#### [DELETE] [rating.model.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/models/rating.model.js)

---

### New Firestore Helper Module

#### [NEW] [firestoreHelpers.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/utils/firestoreHelpers.js)
Utility functions shared across routes:
- `docToJson(doc)` — converts Firestore DocumentSnapshot to `{ id, ...data, createdAt, updatedAt }` with proper timestamp serialization
- `queryToJson(snapshot)` — converts QuerySnapshot to array of JSON objects
- `serverTimestamp()` — shorthand for `admin.firestore.FieldValue.serverTimestamp()`

---

### Route Rewrites (6 files)

#### [MODIFY] [listings.routes.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/listings.routes.js)
- Replace `ListingModel.find(query)` → Firestore `collection('listings').where(...).orderBy(...).limit(...).get()`
- Replace `ListingModel.create()` → `collection('listings').add()`
- Replace `ListingModel.findById()` → `collection('listings').doc(id).get()`
- Replace `.save()` → `doc.ref.update()`
- Replace `.deleteOne()` → `doc.ref.delete()`
- Sorting: `createdAt: -1` → `.orderBy('createdAt', 'desc')`
- Sorting by price → `.orderBy('askingPrice', 'asc'|'desc')`
- **Response format**: keep same fields, replace `_id` with `id`

#### [MODIFY] [offers.routes.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/offers.routes.js)
- Replace all Mongoose CRUD with Firestore equivalents
- **Accept offer logic**: Replace `OfferModel.updateMany({ listingId, _id: { $ne }, status: 'pending' })` → batch query for pending offers on same listing, reject all except accepted one
- **Populate replacement**: When returning offers, manually fetch the associated listing doc and merge data
- FCM notification code stays identical (already uses Firestore)

#### [MODIFY] [orders.routes.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/orders.routes.js)
- Replace `OrderModel.find({ $or })` → two separate Firestore queries (buyer + seller), merge & sort
- Replace `OrderModel.findById()` → `collection('orders').doc(id).get()`
- State machine logic (`orderStateTransitions`) stays identical

#### [MODIFY] [rates.routes.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/rates.routes.js)
- Replace `CropRateModel.find()` → Firestore query on `crop_rates` collection
- Replace `CropRateModel.create()` → `collection('crop_rates').add()`
- Replace `CropRateModel.insertMany()` → batch writes

#### [MODIFY] [ratings.routes.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/ratings.routes.js)
- Replace `RatingModel.create()` → `collection('ratings').add()`
- Replace `RatingModel.find()` → Firestore query
- Replace `RatingModel.aggregate()` (avg/count) → fetch all ratings for user, compute avg/count in JS

#### [MODIFY] [messages.routes.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/messages.routes.js)
- Replace `ListingModel.findById()` → `collection('listings').doc(id).get()` (used for participant check & seller lookup)
- Replace `OfferModel.exists()` → Firestore query with `.limit(1)`
- Replace `OrderModel.exists()` → Firestore query with `.limit(1)`
- Messages already use Firestore — no changes needed for message CRUD

---

### Routes That Need Minor Fixes

#### [MODIFY] [users.routes.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/users.routes.js)
- Replace `OrderModel.exists()` and `ListingModel.find()` and `OfferModel.exists()` in `canViewSensitiveFields()` → Firestore queries
- User CRUD already uses Firestore — no other changes

#### [MODIFY] [admin.routes.js](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/admin.routes.js)
- Replace `ListingModel.countDocuments()` → Firestore `count()` aggregation
- Replace `OrderModel.countDocuments()` → Firestore `count()`
- Replace `OfferModel.countDocuments()` → Firestore `count()`
- Replace `CropRateModel.countDocuments()` → Firestore `count()`
- Replace `ListingModel.find()` → Firestore query for admin listings list
- Replace `OrderModel.find()` → Firestore query for admin orders list
- Replace `CropRateModel.find()` → Firestore query for admin rates list

---

### No Changes Needed

These files **already use Firestore exclusively** or don't touch data:
- `weather.routes.js` — already Firestore
- `alerts.routes.js` — already Firestore
- `config.routes.js` — no data storage
- `health.routes.js` — no data storage
- `uploads.routes.js` — no MongoDB usage (Cloudinary only)
- `weatherAlerts.service.js` — already Firestore
- `ratesIngestion.service.js` — stub, no storage calls
- `attachDbUser.js` — already Firestore
- `auth.js` — no data storage
- `app.js` — route mounting only
- `firebaseAdmin.js` — already Firebase-only
- `errors.js`, `validators.js` — no data storage

### Flutter Frontend — No Changes

The Flutter app communicates with the backend via REST API. Since the API contract (endpoints, request/response shapes) remains identical, **zero Flutter code changes are needed**.

---

### New: Firestore Indexes

#### [NEW] [firestore.indexes.json](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/firestore.indexes.json)
Composite indexes required for the Firestore queries:
- `listings`: `cropName + district + status + createdAt`
- `offers`: `listingId + status + createdAt`
- `orders`: `buyerUid + createdAt`, `sellerUid + createdAt`
- `crop_rates`: `cropName + district + rateDate`
- `ratings`: `targetUid + createdAt`

---

## Verification Plan

### Automated Tests
1. Start backend with `npm run dev` — verify it starts without MongoDB errors
2. Hit `GET /api/health` — confirm backend is running
3. Hit `GET /api/listings` — confirm Firestore query works
4. Test listing CRUD cycle: create → read → update status → delete
5. Test offer lifecycle: create offer → accept → verify order created
6. Test ratings: create rating → fetch user ratings with stats

### Manual Verification
- Run the Flutter app and verify:
  - Dashboard loads weather data
  - Market tab shows listings
  - Can create/edit listings
  - Can make/accept/reject offers
  - Orders display correctly
  - Chat/messaging works
  - Admin console shows correct counts
