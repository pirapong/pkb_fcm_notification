# pkb_fcm_notification

Push notifications (Firebase Cloud Messaging) for Flutter apps in **three calls** —
system permission prompt, device registration with your backend, foreground display,
tap handling and an optional inbox page. Built for cooperative (credit union) apps
whose backend runs the Laravel package `soat/laravel-soat-fcm-notification`,
but any backend that implements the [API below](#backend-api) works.

> 🇹🇭 คู่มือภาษาไทย: [doc/README.th.md](doc/README.th.md)

```dart
await PkbFcm.init(baseUrl: 'https://coop.example.com', authToken: () => storage.read(key: 'token'));
await PkbFcm.login();   // after the member signs in
await PkbFcm.logout();  // before clearing the app's login token
```

## Features

| | |
|---|---|
| Permission | only the system dialog — no extra screens |
| Registration | `POST /api/push/device` with the app's existing login token (the member id is resolved on the server, never sent by the app) |
| Broadcasts | subscribes to topic `all_members` |
| Foreground | Android: shown by the plugin's native code · iOS: system presentation |
| Tap | `PkbFcm.onOpened` stream + marks the message as read (de-duplicated on cold start) |
| Next launch / token refresh | re-registers silently (no repeated permission prompt) |
| Logout | removes the device from the server and deletes the FCM token |
| Inbox (optional) | ready-made `PkbFcmInboxPage()` |

- Android & iOS, Flutter **3.22+** (Dart 3.4+)
- Only 3 dependencies: `firebase_core`, `firebase_messaging`, `http` — native code is bundled (no `flutter_local_notifications`)
- The main methods never throw; results are returned as `PkbFcmResult`

## Requirements

| | Minimum | Notes |
|---|---|---|
| Flutter / Dart | 3.22 / 3.4 | |
| Android | minSdk 23, Kotlin 1.9 | Firebase requirements (Flutter 3.22-era apps default to Kotlin 1.7 — bump it in `android/settings.gradle`) |
| iOS | 15.0 | Firebase requirement; push needs a real device |
| Backend | see [Backend API](#backend-api) | |

## Setup (once per app)

1. Add the package
   ```bash
   flutter pub add pkb_fcm_notification
   ```
2. Connect the app to its Firebase project
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<firebase-project-id>
   ```
3. **Android** — `minSdk` ≥ 23, Kotlin ≥ 1.9. Optional white notification icon in `AndroidManifest.xml` (inside `<application>`):
   ```xml
   <meta-data android:name="com.google.firebase.messaging.default_notification_icon"
              android:resource="@drawable/ic_notification" />
   ```
4. **iOS** — in Xcode → Runner → Signing & Capabilities add **Push Notifications** and **Background Modes → Remote notifications**;
   set `platform :ios, '15.0'` in `ios/Podfile`; upload an **APNs authentication key (.p8)** in
   Firebase → Project settings → Cloud Messaging (one key works for every app in your Apple team).

## Usage

```dart
import 'package:pkb_fcm_notification/pkb_fcm_notification.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PkbFcm.init(
    baseUrl: 'https://coop.example.com',
    authToken: () => storage.read(key: 'token'),          // the token your app already sends as Bearer
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

// after sign-in — shows the system permission dialog and registers the device
final result = await PkbFcm.login();

// sign-out — call BEFORE deleting the login token (it is needed for DELETE /device)
await PkbFcm.logout();
```

### Navigate when a notification is tapped
```dart
PkbFcm.onOpened.listen((message) {
  switch (message.screen) {            // value of data['screen'] sent by the backend
    case 'deposit': navigatorKey.currentState?.pushNamed('/deposit'); break;
    default:        navigatorKey.currentState?.pushNamed('/notifications');
  }
});
```
A tap that launched the app is buffered and delivered as soon as you start listening.

### Inbox (optional)
```dart
Navigator.push(context, MaterialPageRoute(builder: (_) => const PkbFcmInboxPage()));
final unread = await PkbFcm.unreadCount();   // for a badge
```
Or call the API directly: `PkbFcm.api.inbox(page: 1)`, `markRead(id)`, `markAllRead()`.

### App icon badge (unread count)
```dart
await PkbFcm.setBadge(unread);   // e.g. after loading your notification list or marking one read
await PkbFcm.clearBadge();       // logout() also clears it
```
- **iOS** sets the number directly. **Android** has no public API — `setBadge` returns `false` and the launcher shows a dot
  (or a number on launchers that support it) from pending notifications.
- To make the number go **up when a push arrives while the app is closed**, the server must send it with the push:
  the Laravel package does this for per-member messages when `PUSH_BADGE=true`
  (`apns.payload.aps.badge`, `android.notification.notification_count`, `data.badge`).
  Foreground messages with `data.badge` update the badge automatically.

### Result of `login()`

| `result.status` | Meaning |
|---|---|
| `registered` | registered, notifications allowed |
| `permissionDenied` | registered, but the user denied notifications |
| `notLoggedIn` | `authToken` returned null/empty |
| `notInitialized` | `init()` not called or Firebase not configured (see `result.error`) |
| `noToken` | no FCM token — iOS: real device + Push capability + APNs key; Android: Google Play services |
| `failed` | backend call failed (see `result.error`, e.g. 401 = wrong auth guard on the server) |

### Options (`PkbFcmOptions`)

| Option | Default | |
|---|---|---|
| `apiPrefix` | `api/push` | backend route prefix |
| `topic` | `all_members` | broadcast topic |
| `androidChannelId` / `androidChannelName` | `coop_default` / `การแจ้งเตือน` | must match the channel the backend sends to |
| `showForegroundNotification` | `true` | show notifications while the app is open |
| `markReadOnOpen` | `true` | mark as read when tapped |
| `registerOnStart` | `true` | re-register on launch if previously logged in |
| `timeout` | 15 s | API timeout |
| `debug` | `false` | print `[pkb_fcm] ...` logs |

## Backend API

All endpoints are under `{baseUrl}/{apiPrefix}` (default `/api/push`), authenticated with
`Authorization: Bearer <authToken>`, JSON in/out. The server resolves the member from the token.

| Method | Path | Body / query | Response |
|---|---|---|---|
| POST | `/device` | `fcm_token`, `platform` (`android`/`ios`), `app_version`, `device_model`, `permission` | `{"ok":true,"registered":true}` |
| GET | `/device?fcm_token=` | | `{"ok":true,"registered":bool,"device_count":int}` |
| DELETE | `/device` | `fcm_token` | `{"ok":true}` |
| GET | `/inbox?page=` | | `{"ok":true,"data":[{id,type,category,title,body,data,created_at,read}],"page","last_page","total"}` |
| GET | `/inbox/unread-count` | | `{"ok":true,"unread":int}` |
| POST | `/inbox/{id}/read` | | `{"ok":true}` |
| POST | `/inbox/read-all` | | `{"ok":true}` |

Push payloads should include `data.push_message_id` (for read tracking) and optionally `data.screen` / `data.category`,
and use Android channel `coop_default`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Android build: `Module was compiled with an incompatible version of Kotlin` | set Kotlin ≥ 1.9 |
| iOS build: `requires a higher minimum iOS deployment version` | `platform :ios, '15.0'` in `ios/Podfile` |
| `login()` → `noToken` on iOS | simulator, missing Push capability, or no APNs key in Firebase |
| `login()` → `failed` 401 | backend auth middleware does not match the app's guard |
| Android works, iOS does not | APNs key not uploaded, or Remote notifications not enabled |
