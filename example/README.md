# pkb_fcm_notification_example

ตัวอย่างการใช้ `pkb_fcm_notification` (ดูโค้ดใน `lib/main.dart`)

```bash
flutterfire configure --project=<firebase-project-id>      # สร้างไฟล์ Firebase (ไม่อยู่ใน git)
flutter run --dart-define=PKB_BASE_URL=https://coop.example.com --dart-define=PKB_TOKEN=<token ล็อกอิน>
```

ทดสอบส่วน native บนเครื่อง: `flutter test integration_test -d <device>`
