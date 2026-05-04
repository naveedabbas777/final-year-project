## Plan: Local Weather Alerts with UI
TL;DR: Add a lightweight alert model stored locally (SharedPreferences) with a 7-day retention policy. Reuse existing weather rule thresholds (rain/heat/cold/wind). Run a foreground periodic checker (while app is open) that fetches weather, generates alerts, saves them, and optionally shows a local notification. Surface saved alerts in the Alerts tab instead of dummy data.

**Steps**
1) Define alert model + storage keys: add a small model (id, title, body, type, createdAt) and JSON (de)serialization; choose a SharedPreferences key like `saved_alerts`; enforce max age 7 days on read/write; utility in a new service, e.g., lib/services/alert_service.dart.
2) Build AlertService: methods to load alerts (prune >7 days), add alert, clear/optional delete; optional limit (e.g., keep last 50). Expose a stream/notifier for UI consumption (e.g., ChangeNotifier inside service) so screens can listen.
3) Weather-to-alert generator: extract existing logic from `_handleWeatherNotification` in lib/screens/dashboard_screen.dart into a reusable method (e.g., generateAlertsForWeather(current, daily) in AlertService). When a rule hits, create an alert record and also call NotificationService.showNotification (respecting notifications_enabled).
4) Periodic trigger (in-app): in lib/screens/dashboard_screen.dart, start a foreground timer on init (e.g., every 60 min; cancel on dispose) that:
   - Loads saved lat/lon from prefs.
   - Fetches weather via WeatherService.fetchWeatherData.
   - Runs the alert generator; for each new alert, save via AlertService and send notification.
   - Still keep once-per-day throttle for per-type? (Optional: per-alert-type/day guard to avoid spamming; mirror existing last_weather_notification_date or per-rule timestamps.)
5) Wire alerts UI: replace dummy list in lib/screens/alerts_screen.dart with data from AlertService. Show empty state when none; list sorted newest-first; display date/type/body. Consider pull-to-refresh to re-run fetch or just rely on periodic timer.
6) App composition: provide AlertService via Provider at app root (lib/main.dart), similar to NotificationService. Ensure Settings respects notification toggle; AlertService should skip showNotification if notifications are disabled but still save alerts.
7) Cleanup & retention: ensure AlertService prunes on load/add; optional “Clear alerts” action in Alerts screen.

**Verification**
- Manual: set location, wait for periodic check (or trigger once via button) and confirm alerts appear in Alerts tab and notifications fire when enabled; toggle notifications off and verify alerts save without toast/notification.
- Edge: no location saved → no alerts; location saved → alerts generated; after 7 days, old alerts disappear on next load/add.

**Decisions**
- Storage: local SharedPreferences only.
- Trigger: foreground periodic timer while app open.
- Rules: keep current rain/heat/cold/wind thresholds.
- Retention: 7 days.
