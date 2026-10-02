# pkb_fcm_notification

Push notifications (Firebase Cloud Messaging) for SO-AT cooperative apps in a few lines of code —
system permission prompt, device registration, foreground display, tap handling and an optional inbox page.
Works with the Laravel package [`soat/laravel-soat-fcm-notification`](#backend).

```dart
await PkbFcm.init(baseUrl: 'https://coop.example.com', authToken: () => storage.read('token'));
await PkbFcm.login();   // after the member signs in
await PkbFcm.logout();  // before clearing the app's login token
```

- Android & iOS · Flutter **3.22+** (Dart 3.4+)
- Only 3 dependencies: `firebase_core`, `firebase_messaging`, `http` (native code is bundled — no `flutter_local_notifications`)
- No method throws — results are returned as `PkbFcmResult`

---

## ภาษาไทย

แพ็กเกจแจ้งเตือนสำหรับแอปสหกรณ์ ใช้แทน OneSignal — เรียก 3 คำสั่งก็ใช้งานได้
ส่งตรงจากเซิร์ฟเวอร์ของสหกรณ์ผ่าน Firebase (ฟรี ไม่จำกัดจำนวนผู้ใช้)

| ทำให้อัตโนมัติ | |
|---|---|
| ขอสิทธิ์แจ้งเตือน | dialog ของระบบเท่านั้น ไม่มีหน้าจออื่น |
| ลงทะเบียนเครื่องกับเซิร์ฟเวอร์ | `POST /api/push/device` ใช้ token ล็อกอินที่แอปมีอยู่ (ไม่ต้องส่งเลขสมาชิก) |
| ประกาศถึงทุกคน | subscribe topic `all_members` |
| แจ้งเตือนตอนแอปเปิดอยู่ | Android แสดงผ่าน native ของแพ็กเกจ, iOS แสดงผ่านระบบ |
| กดแจ้งเตือน | แจ้งแอปผ่าน `PkbFcm.onOpened` + mark อ่านแล้วให้ (กันกดซ้ำตอนเปิดแอปจากแจ้งเตือน) |
| เปิดแอปครั้งถัดไป / token เปลี่ยน | ลงทะเบียนซ้ำเองโดยไม่ถามสิทธิ์ซ้ำ |
| ล็อกเอาต์ | ลบเครื่องออกจากเซิร์ฟเวอร์ + ลบ FCM token |
| Inbox (ไม่บังคับ) | `PkbFcmInboxPage()` หน้ารายการแจ้งเตือนสำเร็จรูป |

### ความต้องการของระบบ

| | ขั้นต่ำ | หมายเหตุ |
|---|---|---|
| Flutter / Dart | 3.22 / 3.4 | ดูที่ `pubspec.yaml` ของแอป → `environment: sdk:` ต้อง ≥ 3.4 |
| Android | minSdk 23, Kotlin ≥ 1.9 | ข้อกำหนดของ Firebase (แอปยุค Flutter 3.22 มักตั้ง Kotlin 1.7 ต้องแก้ใน `android/settings.gradle`) |
| iOS | 15.0 | ข้อกำหนดของ Firebase · ต้องเป็นเครื่องจริง (simulator ไม่ได้รับ push) |
| Backend | `soat/laravel-soat-fcm-notification` | ติดตั้งบนไซต์สหกรณ์ ([คู่มือ](#backend)) |

---

## ติดตั้ง (ครั้งเดียวต่อแอป)

### 1. เพิ่มแพ็กเกจ
```bash
flutter pub add pkb_fcm_notification
```

### 2. ผูกแอปกับ Firebase project ของสหกรณ์ (1 สหกรณ์ = 1 project)
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<firebase-project-id>
```
ได้ `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`

### 3. Android
- `android/app/build.gradle(.kts)`: `minSdk` อย่างน้อย **23**
- Kotlin อย่างน้อย **1.9** (`android/settings.gradle` → `org.jetbrains.kotlin.android`)
- (แนะนำ) ไอคอนแจ้งเตือนสีขาวพื้นโปร่งใส — ใส่ใน `AndroidManifest.xml` ภายใน `<application>`:
  ```xml
  <meta-data android:name="com.google.firebase.messaging.default_notification_icon"
             android:resource="@drawable/ic_notification" />
  ```
  ถ้าไม่ใส่ จะใช้ไอคอนแอป (บาง Android แสดงเป็นสี่เหลี่ยมสีขาว)

### 4. iOS (Xcode → Runner → Signing & Capabilities)
1. **+ Capability → Push Notifications**
2. **+ Capability → Background Modes** → ติ๊ก **Remote notifications**
3. `ios/Podfile` → `platform :ios, '15.0'`
4. Apple Developer → Keys → สร้าง **APNs key (.p8)** → อัปโหลดใน Firebase → Project settings → Cloud Messaging → Apple app configuration

---

## ใช้งาน

### `main.dart` — ครั้งเดียว
```dart
import 'package:pkb_fcm_notification/pkb_fcm_notification.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PkbFcm.init(
    baseUrl: 'https://coop.example.com',                 // โดเมนไซต์สหกรณ์
    authToken: () => SecureStorage().readKey('token'),   // token ล็อกอินที่แอปเก็บไว้ (ส่งเป็น Bearer)
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}
```

### หลังสมาชิกล็อกอิน — แทน OneSignal ทั้งก้อน
```dart
final result = await PkbFcm.login();   // dialog ขอสิทธิ์ของระบบ + ลงทะเบียนเครื่อง
```

<details>
<summary>เทียบกับ OneSignal เดิม</summary>

```dart
// เดิม
await OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
OneSignal.initialize("app-id");
await OneSignal.Notifications.requestPermission(true);
await OneSignal.User.addTagWithKey("membership_no", membershipNo);
await OneSignal.User.pushSubscription.optIn();

// ใหม่
await PkbFcm.login();
```
ไม่ต้องส่ง `membership_no` — เซิร์ฟเวอร์อ่านจาก token ล็อกอิน (ปลอมเลขสมาชิกคนอื่นไม่ได้)
</details>

### ล็อกเอาต์ — เรียก **ก่อน** ลบ token ล็อกอินของแอป
```dart
await PkbFcm.logout();
await SecureStorage().deleteKey('token');
```

### กดแจ้งเตือนแล้วพาไปหน้าที่ต้องการ
```dart
PkbFcm.onOpened.listen((message) {
  switch (message.screen) {          // ค่า $data['screen'] ที่ไซต์ส่งมา
    case 'deposit': navigatorKey.currentState?.pushNamed('/deposit'); break;
    case 'loan':    navigatorKey.currentState?.pushNamed('/loan'); break;
    default:        navigatorKey.currentState?.pushNamed('/notifications');
  }
});
```
ข้อความที่ทำให้แอปถูกเปิด (แอปปิดอยู่) จะถูกเก็บไว้และส่งให้ทันทีที่เริ่ม `listen`

### Inbox (ไม่บังคับ — แอปที่มีหน้าแจ้งเตือนอยู่แล้วไม่ต้องใช้)
```dart
Navigator.push(context, MaterialPageRoute(builder: (_) => const PkbFcmInboxPage()));
final unread = await PkbFcm.unreadCount();   // ทำ badge
```
หรือเรียก API เอง: `PkbFcm.api.inbox(page: 1)`, `markRead(id)`, `markAllRead()`

---

## ผลของ `login()`

| `result.status` | ความหมาย | ทำอะไรต่อ |
|---|---|---|
| `registered` | ลงทะเบียนแล้ว ผู้ใช้อนุญาตแจ้งเตือน | — |
| `permissionDenied` | ลงทะเบียนแล้ว แต่ผู้ใช้ไม่อนุญาต | อาจแนะนำให้เปิดในการตั้งค่าเครื่อง |
| `notLoggedIn` | `authToken` คืนค่าว่าง | เรียกหลังล็อกอิน |
| `notInitialized` | ยังไม่ `init()` / Firebase ตั้งค่าไม่ครบ | ดู `result.error` |
| `noToken` | ขอ FCM token ไม่ได้ | iOS: เครื่องจริง + Push capability + APNs key · Android: ต้องมี Google Play services |
| `failed` | เรียก API ไม่สำเร็จ | ดู `result.error` (เช่น 401 = middleware ฝั่ง Laravel ไม่ตรงกับระบบล็อกอินแอป) |

## ตั้งค่าเพิ่ม (`PkbFcmOptions`) — ทุกค่ามีค่าเริ่มต้นแล้ว

| ค่า | ค่าเริ่มต้น | |
|---|---|---|
| `apiPrefix` | `api/push` | ตรงกับ `push.api.prefix` ฝั่ง Laravel |
| `topic` | `all_members` | topic ประกาศ |
| `androidChannelId` / `androidChannelName` | `coop_default` / `การแจ้งเตือน` | ต้องตรงกับ `PUSH_ANDROID_CHANNEL` |
| `showForegroundNotification` | `true` | แสดงแจ้งเตือนแม้แอปเปิดอยู่ |
| `markReadOnOpen` | `true` | กดแจ้งเตือนแล้ว mark อ่านแล้ว |
| `registerOnStart` | `true` | เปิดแอปแล้วลงทะเบียนซ้ำ (ถ้าเคย login) |
| `timeout` | 15 วินาที | |
| `debug` | `false` | พิมพ์ log `[pkb_fcm] ...` |

```dart
await PkbFcm.init(baseUrl: ..., authToken: ..., options: const PkbFcmOptions(debug: true));
```

---

## Backend

ไซต์สหกรณ์ต้องติดตั้ง Laravel package `soat/laravel-soat-fcm-notification` และตั้ง
`config/push.php` → `api.middleware` ให้ตรงกับระบบล็อกอินของแอป เช่น

| แอปล็อกอินด้วย | `push.api.middleware` |
|---|---|
| Sanctum | `['api', 'auth:sanctum']` |
| Passport (guard ชื่อ `mobile`) | `['api', 'auth:mobile']` |
| api_token / JWT | `['api', 'auth:api']` |

API ที่แพ็กเกจเรียก (prefix `api/push`): `POST/GET/DELETE /device`, `GET /inbox`, `GET /inbox/unread-count`,
`POST /inbox/{id}/read`, `POST /inbox/read-all`

## แก้ปัญหา

| อาการ | สาเหตุ / แก้ |
|---|---|
| Android build: `Module was compiled with an incompatible version of Kotlin` | Kotlin ของแอปเก่าเกินไป → ตั้ง ≥ 1.9 |
| iOS build: `requires a higher minimum iOS deployment version` | `ios/Podfile` → `platform :ios, '15.0'` |
| `login()` → `noToken` บน iOS | simulator / ไม่ได้เปิด Push capability / ไม่ได้อัปโหลด APNs key |
| `login()` → `failed` 401 | `push.api.middleware` ฝั่ง Laravel ไม่ตรงกับ guard ที่แอปใช้ |
| ได้รับ Android แต่ไม่ได้ iOS | APNs key ยังไม่ได้อัปโหลด หรือ Background Modes ไม่ได้ติ๊ก Remote notifications |
| แจ้งเตือนตอนแอปเปิดไม่เด้ง (Android) | ผู้ใช้ปิดแจ้งเตือนของแอป หรือ `showForegroundNotification: false` |
