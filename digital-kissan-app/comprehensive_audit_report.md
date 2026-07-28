# Digital Kissan — Comprehensive Audit Report

> Full-stack audit covering **bugs**, **UI/UX polish**, **performance**, and **functionality improvements** across both the Flutter frontend and the Express/Firestore backend.

---

## 🔴 Critical Bugs (Must Fix)

### 1. `ConnectivityService` leaks a `Timer` and never cancels periodic checks
- **File**: [connectivity_service.dart](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/services/connectivity_service.dart#L50-L56)
- **Issue**: `startPeriodicHealthCheck()` creates a `Timer.periodic` but never stores the reference — there's no way to cancel it. The `dispose()` method only closes the stream, not the timer.
- **Impact**: Memory leak; the timer fires forever even after the service is conceptually "disposed".
- **Fix**: Store the timer reference and cancel it in `dispose()`.

### 2. `DropdownButtonFormField` uses deprecated `initialValue` parameter
- **File**: [market_screen.dart](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/screens/market_screen.dart#L541)
- **Issue**: `DropdownButtonFormField` does not have an `initialValue` parameter — this should be `value:`. This causes a compile-time error or a silent runtime failure depending on the Flutter version.
- **Fix**: Replace `initialValue:` with `value:` on both crop and district dropdowns (lines 541, 573).

### 3. `_sending` flag never reset on successful login
- **File**: [login_screen.dart](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/screens/login_screen.dart#L58-L132)
- **Issue**: When login succeeds and email is verified, the `_sending = true` flag is set at line 58 but never reset to `false`. If the user navigates back to login (e.g., after sign-out), the button stays disabled forever.
- **Fix**: Add `if (mounted) setState(() => _sending = false);` in the `finally` block, or before `widget.onLogin()`.

### 4. `sendMulticast` is deprecated in `firebase-admin v12+`
- **Files**: [messages.routes.js:138](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/messages.routes.js#L138), [weatherAlerts.service.js:44](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/services/weatherAlerts.service.js#L44)
- **Issue**: `admin.messaging().sendMulticast()` was deprecated in firebase-admin SDK v12. It will throw in newer versions.
- **Fix**: Replace with `admin.messaging().sendEachForMulticast()` or loop with `send()`.

### 5. `arrayRemove` spread with zero arguments crashes
- **File**: [weatherAlerts.service.js:18](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/services/weatherAlerts.service.js#L15-L21)
- **Issue**: `removeInvalidTokens` calls `arrayRemove(...invalidTokens)`. If `invalidTokens` is empty (the guard checks length > 0 so it's OK here), but the same pattern in [messages.routes.js:145](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/messages.routes.js#L145) does NOT guard — spreading zero args into `arrayRemove()` causes a Firestore error.
- **Fix**: Add a `if (invalidTokens.length > 0)` guard in `messages.routes.js`.

---

## 🟡 Medium Priority — Bugs & Edge Cases

### 6. `_RatesTab` applies crop/district filter only on "Apply" button but rebuilds `_filteredRates` on every search keystroke
- **File**: [market_screen.dart:359-368](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/screens/market_screen.dart#L359-L368)
- **Issue**: The text search (`_searchController`) filters in real-time via `_filteredRates` getter, but the dropdown filters (`_selectedCropFilter`, `_selectedDistrictFilter`) require clicking "Apply" to re-fetch. This is inconsistent UX.
- **Fix**: Either make dropdowns filter client-side like search, or debounce the text search and batch all filters into the "Apply" action.

### 7. `_RatesTab._buildOptions` rebuilds after every `_load` but doesn't respect current filter state
- **Issue**: When a user selects a crop filter and loads, `_cropOptions` and `_districtOptions` are rebuilt from the **filtered** results, causing available options to shrink. When the user clears a filter, the original full list is gone.
- **Fix**: Store the full unfiltered rate list separately and derive options from it.

### 8. No error boundary on `fetchListingsWithCache` `sellerUid` parameter in SellerProfile
- **File**: [seller_profile_screen.dart:38-39](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/screens/seller_profile_screen.dart#L38-L39)
- **Issue**: If `fetchUserProfileByUidWithCache` returns null AND `fetchUserProfileByUid` throws, the whole `Future.wait` fails and the screen shows a permanent loading state (no error UI).
- **Fix**: Wrap in try-catch and show an error state instead of just `_loading = true` forever.

### 9. `DashboardScreen` creates a new `ConnectivityService()` and `WeatherService()` on every refresh
- **File**: [dashboard_screen.dart:201](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/screens/dashboard_screen.dart#L201)
- **Issue**: `ConnectivityService` is a singleton (factory constructor), but `WeatherService` is a new instance each time. If `WeatherService` has any state or setup, it's lost.
- **Fix**: Cache or inject `WeatherService` instance.

### 10. `markAllAsRead` fires sequentially — slow for many alerts
- **File**: [alert_service.dart:113-118](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/services/alert_service.dart#L113-L118)
- **Issue**: Uses a sequential `for` loop with `await markAsRead(alert.id)` for each unread alert. With 20+ alerts this is extremely slow.
- **Fix**: Use a batch endpoint `POST /api/alerts/mark-all-read` or at least fire requests in parallel with `Future.wait`.

### 11. `profile_screen.dart` uses `_field` as a local function name (shadows potential issues)
- **File**: [profile_screen.dart:171](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/screens/profile_screen.dart#L171)
- **Issue**: The function `_field` is defined inside `_showEditDialog` with a leading underscore, which is unconventional for a local function. More importantly, if this widget is ever refactored, this pattern is fragile.
- Minor — cosmetic only.

---

## 🟢 UI/UX Polish Suggestions

### 12. Login screen lacks loading overlay — user can tap "Register" while logging in
- **File**: [login_screen.dart](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/screens/login_screen.dart#L262-L292)
- **Issue**: While `_sending` is true, the "Login" button is disabled but the "Register" link and "Forgot Password" link remain tappable. This can cause navigation conflicts.
- **Fix**: Disable all interactive elements when `_sending` is true, or use `AbsorbPointer` / `IgnorePointer` wrapper.

### 13. Login screen — no "Enter key submits form" support
- **Fix**: Wrap in a `Form` widget and add `textInputAction: TextInputAction.done` to the password field with `onSubmitted: (_) => _attemptLogin()`.

### 14. Dashboard weather card is deeply nested (7+ levels of FutureBuilder → Stack → Positioned → FutureBuilder)
- **File**: [dashboard_screen.dart:596-882](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/screens/dashboard_screen.dart#L596-L882)
- **Issue**: The weather card uses nested `FutureBuilder` widgets sharing the same futures (`_currentWeatherFuture`, `_todayForecastFuture`). This makes the code extremely hard to maintain and causes redundant rebuilds.
- **Fix**: Extract to a dedicated `_WeatherCard` widget that takes resolved data, not futures.

### 15. Profile screen — no confirmation before sign-out
- **File**: [profile_screen.dart:275-279](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/screens/profile_screen.dart#L275-L279)
- **Issue**: Sign out happens immediately with no confirmation dialog. Accidental taps sign the user out.
- **Fix**: Add a confirmation `AlertDialog` before calling `auth.signOut()`.

### 16. Orders screen — no date/time shown on order cards
- **File**: [orders_screen.dart:330-549](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/screens/orders_screen.dart#L330-L549)
- **Issue**: Order cards show crop name, amount, and quantity but no creation date or last-updated timestamp. Users can't tell when orders were placed.
- **Fix**: Add a small timestamp subtitle showing `createdAt` or `updatedAt`.

### 17. Seller profile — rating dialog doesn't show loading state during submission
- **File**: [seller_profile_screen.dart:148-176](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/screens/seller_profile_screen.dart#L148-L176)
- **Issue**: After tapping "Submit Rating", the dialog closes immediately and the API call happens in the background. If it fails, the user doesn't see the error in context.
- **Fix**: Keep the dialog open with a loading indicator until the API completes.

### 18. Empty states need illustrations, not just icons
- **Impact**: The orders empty state and market empty state use basic Material icons. A custom illustration or SVG would look significantly more professional.
- **Fix**: Use a Lottie animation or a custom SVG asset for empty states.

### 19. Navigation bar icons don't have unique accessibility labels
- **File**: [main.dart:261-307](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/main.dart#L261-L307)
- **Fix**: Add `tooltip` property to each `NavigationDestination` for screen readers.

---

## ⚡ Performance Improvements

### 20. `IndexedStack` keeps all 5 screens alive simultaneously
- **File**: [main.dart:250-253](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/main.dart#L250-L253)
- **Issue**: `IndexedStack` keeps all child widgets mounted and alive, meaning all 5 screens (Dashboard, Forecast, Alerts, Market, Settings) and their state are in memory at all times, including active timers and futures.
- **Fix**: Use `AutomaticKeepAliveClientMixin` with a `PageView` or lazy-build tabs with only a 1-2 tab cache.

### 21. `fetchIncomingOffersForListing` fetches ALL incoming offers then filters client-side
- **File**: [market_api_service.dart:817-820](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/services/market_api_service.dart#L817-L820)
- **Issue**: `fetchIncomingOffersForListing(listingId)` calls `fetchIncomingOffers()` (which returns ALL incoming offers for the user) and then filters by `listingId`. This over-fetches data.
- **Fix**: Add a backend endpoint `GET /api/offers/incoming?listingId=xxx` and filter server-side.

### 22. `unread-count` endpoint fetches ALL messages for a listing
- **File**: [messages.routes.js:367-383](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/messages.routes.js#L367-L383)
- **Issue**: The unread count is computed by fetching EVERY message doc for the listing and iterating. For listings with 100s of messages this is expensive and slow.
- **Fix**: Maintain a `lastReadAt` timestamp per-user per-listing and use a `where('timestamp', '>', lastReadAt)` query with `count()`.

### 23. `allSnap` in ratings endpoint fetches ALL ratings for aggregation
- **File**: [ratings.routes.js:136-137](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/ratings.routes.js#L134-L137)
- **Issue**: `GET /api/ratings/:uid` does two queries: one for recent (limited to 20) and one fetching ALL ratings to compute averages. As a seller gets more ratings, this becomes a full collection scan.
- **Fix**: Maintain a `ratingStats` sub-document on the user profile (updated on each new rating via a transaction) so the aggregation is pre-computed.

### 24. `refreshAllWeatherCaches` processes users sequentially
- **File**: [weatherAlerts.service.js:450-462](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/services/weatherAlerts.service.js#L450-L462)
- **Issue**: Each user's weather refresh runs one at a time. With 100 users, this takes 100× the latency.
- **Fix**: Use `Promise.allSettled` with batches of 5-10 concurrent users.

### 25. Dashboard makes 3+ network calls before showing any content
- **Issue**: `_loadDashboardData()` calls: health check → user profile → weather data (2 parallel API calls). Until ALL complete, the user sees a loading spinner.
- **Fix**: Show cached/stale data immediately, then refresh in the background. Use an optimistic UI pattern.

---

## 🔒 Security Improvements

### 26. `POST /api/messages` has no message length validation
- **File**: [messages.routes.js:90](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/messages.routes.js#L90)
- **Issue**: Only checks if message is empty, but doesn't cap length. A client could send a 10MB string.
- **Fix**: Add `if (message.length > 5000) return res.status(400).json(...)`.

### 27. `POST /api/ratings` doesn't sanitize `comment` length
- **File**: [ratings.routes.js:117](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/ratings.routes.js#L117)
- **Issue**: Comment is trimmed but not length-capped. A malicious user could store arbitrarily large text.
- **Fix**: Add `const comment = ... ; if (comment.length > 500) return res.status(400)...`.

### 28. `requireRole` middleware only checks `req.dbUser.role` — but `attachDbUser` must run first
- **File**: [auth.js:87-96](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/middlewares/auth.js#L87-L96)
- **Issue**: If `requireRole` is used without `attachDbUser` in the middleware chain, `req.dbUser` is `undefined` and the default role becomes `'farmer'`, granting farmer-level access to anyone. This is a subtle misconfiguration risk.
- **Fix**: Add a guard: `if (!req.dbUser) return res.status(500).json({message: 'attachDbUser must precede requireRole'})`.

### 29. Weather routes use `try/catch/next(err)` instead of `asyncHandler`
- **File**: [weather.routes.js:163](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/routes/weather.routes.js#L163)
- **Issue**: The main weather endpoint uses a manual `try/catch/next(err)` pattern while all other routes use the `asyncHandler` wrapper. This is inconsistent and error-prone if `next` is forgotten.
- **Fix**: Wrap with `asyncHandler` for consistency.

---

## 🧩 Functionality Improvements

### 30. No pagination on listings or orders
- **Files**: `fetchMyOrders`, `fetchListings`, `fetchIncomingOffers`
- **Issue**: All endpoints return everything in one shot. As data grows, response times and memory increase linearly.
- **Fix**: Implement cursor-based pagination with `startAfter` + `limit` on both backend and frontend.

### 31. Presence system (`setPresence`) has no automatic heartbeat
- **File**: [market_api_service.dart:1067-1078](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/services/market_api_service.dart#L1067-L1078)
- **Issue**: `setPresence(isOnline: true)` is called once but there's no periodic heartbeat. If the app crashes, the user appears "online" forever.
- **Fix**: Add a heartbeat timer (every 60s) and a server-side TTL check (if no heartbeat for 2min, mark offline).

### 32. `AlertService.processWeather` ignores its parameters
- **File**: [alert_service.dart:125-128](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/lib/services/alert_service.dart#L125-L128)
- **Issue**: The method signature is `processWeather(_, __)` — it accepts weather data but ignores it completely, only calling `_ensureLoaded()`. The dashboard calls it expecting local alert processing, but it just loads from the server.
- **Impact**: Client-side weather alert processing is effectively dead code. All alerts come from the server background job only.
- **Fix**: Either implement client-side alert generation or remove the misleading signature.

### 33. `Validator.cropName` rejects Unicode crop names
- **File**: [validators.js:49](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/utils/validators.js#L49)
- **Issue**: The regex `^[a-zA-Z0-9\s-]+$` rejects crop names in Urdu or other non-Latin scripts. Since the app supports Urdu, this is a functional blocker for Urdu-speaking farmers.
- **Fix**: Use a more permissive regex: `^[\p{L}\p{N}\s-]+$/u` (Unicode letters and numbers).

### 34. `Validator.district` has the same Unicode issue
- **File**: [validators.js:56](file:///c:/Users/Naveed/Documents/GitHub/final-year-project/mockup_app_1/backend/src/utils/validators.js#L56)
- **Same fix**: Use Unicode-aware regex.

### 35. No offline support / cache-first architecture
- **Issue**: When the backend is unreachable, most screens show an error. Only the dashboard has a partial fallback (cached lat/lon). The marketplace, orders, and alerts screens have no offline capability.
- **Fix**: Implement a local SQLite or Hive cache for listings, orders, and alerts with a "stale data" indicator.

---

## 📋 Summary Priority Matrix

| Priority | Count | Examples |
|----------|-------|---------|
| 🔴 Critical | 5 | Timer leak, deprecated API, compile error, crash bugs |
| 🟡 Medium | 6 | UX inconsistencies, missing error states, slow operations |
| 🟢 UI Polish | 8 | Confirmation dialogs, empty states, accessibility |
| ⚡ Performance | 6 | Over-fetching, sequential processing, IndexedStack |
| 🔒 Security | 4 | Input validation, middleware ordering |
| 🧩 Functionality | 6 | Pagination, offline, Unicode, presence |

---

## ✅ Recommended Next Steps

1. **Immediate**: Fix bugs #1-5 (compilation/crash issues)
2. **This Sprint**: Address #6-11 (UX edge cases) + #26-29 (security)
3. **Next Sprint**: Performance optimizations #20-25
4. **Backlog**: UI polish #12-19, functionality #30-35

> [!TIP]
> Let me know which items you'd like me to fix first — I can implement them in batches. I'd recommend starting with the **5 Critical bugs** since some may cause compile errors or crashes.
