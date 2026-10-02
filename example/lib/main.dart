import 'package:flutter/material.dart';
import 'package:pkb_fcm_notification/pkb_fcm_notification.dart';

// ค่าสำหรับทดสอบ: flutter run --dart-define-from-file=dev.json
// (แอปจริงใช้โดเมนสหกรณ์ และ token ล็อกอินที่แอปเก็บไว้อยู่แล้ว)
const baseUrl = String.fromEnvironment('PKB_BASE_URL', defaultValue: 'http://10.0.2.2:8000');
const loginToken = String.fromEnvironment('PKB_TOKEN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) ครั้งเดียวตอนเปิดแอป
  await PkbFcm.init(
    baseUrl: baseUrl,
    authToken: () => loginToken, // แอปจริง: () => storage.read(key: 'token')
    options: const PkbFcmOptions(debug: true),
  );

  runApp(const ExampleApp());
}

final navigatorKey = GlobalKey<NavigatorState>();

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  @override
  void initState() {
    super.initState();
    // กดแจ้งเตือน → พาไปหน้าที่ต้องการ (ตัวอย่าง: เปิด Inbox)
    PkbFcm.onOpened.listen((message) {
      navigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const PkbFcmInboxPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'pkb_fcm_notification',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = '-';
  int _unread = 0;

  Future<void> _login() async {
    // 2) หลังสมาชิกล็อกอิน: dialog ขอสิทธิ์ของระบบ + ลงทะเบียนเครื่อง
    final result = await PkbFcm.login();
    setState(() => _status = '$result');
    _refreshUnread();
  }

  Future<void> _logout() async {
    // 3) ล็อกเอาต์ (ก่อนลบ token ล็อกอินของแอป)
    await PkbFcm.logout();
    setState(() => _status = 'logout แล้ว');
  }

  Future<void> _refreshUnread() async {
    final n = await PkbFcm.unreadCount();
    if (mounted) setState(() => _unread = n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('pkb_fcm_notification'),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PkbFcmInboxPage()));
              _refreshUnread();
            },
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              child: const Icon(Icons.notifications),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('สถานะ: $_status'),
          const SizedBox(height: 16),
          FilledButton(onPressed: _login, child: const Text('PkbFcm.login()')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _logout, child: const Text('PkbFcm.logout()')),
        ],
      ),
    );
  }
}
