## 1.1.0

* App icon badge: `PkbFcm.setBadge(count)` / `PkbFcm.clearBadge()` — iOS sets the number directly; Android returns `false`
  (no public API; the launcher shows a dot/number from pending notifications).
* `PkbFcmMessage.badge` reads `data['badge']` sent by the server (Laravel package with `PUSH_BADGE=true`).
* Foreground messages carrying a badge update it automatically (iOS) or set the notification number (Android).
* `logout()` clears the badge.

## 1.0.0

* Initial release: `PkbFcm.init()` / `login()` / `logout()` / `onOpened` / `onMessage` / `unreadCount()` and `PkbFcmInboxPage`.
* Android: foreground notifications and tap handling via bundled native code (Java) — no `flutter_local_notifications`.
* iOS: foreground presentation via `firebase_messaging`; supports CocoaPods and Swift Package Manager.
* Concurrent `login()` calls share one registration; taps are de-duplicated on cold start.
* Flutter 3.22+ (`firebase_core` 3–4, `firebase_messaging` 15–16).
* Pairs with the Laravel package `soat/laravel-soat-fcm-notification`.
