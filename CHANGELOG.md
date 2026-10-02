## 1.0.0

* แรกเริ่ม: `PkbFcm.init()` / `login()` / `logout()` / `onOpened` / `onMessage` / `unreadCount()` / `PkbFcmInboxPage`
* Android: แสดงแจ้งเตือนตอนแอปเปิดอยู่และรับการกดด้วย native (Java) — ไม่พึ่ง flutter_local_notifications
* iOS: แสดงแจ้งเตือนตอนแอปเปิดอยู่ผ่าน firebase_messaging, รองรับทั้ง CocoaPods และ Swift Package Manager
* รองรับ Flutter 3.22+ (firebase_core 3–4, firebase_messaging 15–16)
* ใช้คู่กับ Laravel package `soat/laravel-soat-fcm-notification`
