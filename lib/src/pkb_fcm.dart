import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';
import 'native.dart';
import 'options.dart';

/// Push Notification สำหรับแอปสหกรณ์ — ใช้คู่กับ soat/laravel-soat-fcm-notification
///
/// ```dart
/// await PkbFcm.init(baseUrl: 'https://coop.example.com', authToken: () => storage.read('token'));
/// await PkbFcm.login();   // หลังสมาชิกล็อกอิน: ขอสิทธิ์ + ลงทะเบียนเครื่อง
/// await PkbFcm.logout();  // ก่อนลบ token ล็อกอินของแอป
/// ```
///
/// ทุกเมธอดไม่ throw — ผลลัพธ์ดูจาก [PkbFcmResult] และ log (เปิด `debug: true`)
class PkbFcm {
  PkbFcm._();

  static const _kLoggedIn = 'logged_in';
  static const _kToken = 'fcm_token';

  static PkbFcmOptions _options = const PkbFcmOptions();
  static PkbFcmApi? _api;
  static PkbFcmNative _native = PkbFcmNative();
  static bool _ready = false;
  static String? _initError;
  static String? _fcmToken;
  static bool _loggedIn = false;
  static final List<StreamSubscription<dynamic>> _subs = [];

  // Android cold start: getInitialMessage และ onMessageOpenedApp ส่งข้อความเดียวกันมาทั้งคู่ → กันซ้ำด้วย messageId
  static final List<String> _openedIds = [];

  static final StreamController<PkbFcmMessage> _onMessage = StreamController<PkbFcmMessage>.broadcast();
  static final List<PkbFcmMessage> _pendingOpened = [];
  static final StreamController<PkbFcmMessage> _onOpened = StreamController<PkbFcmMessage>.broadcast(
    onListen: () {
      // ข้อความที่ถูกกดก่อนมีคนฟัง (เช่น เปิดแอปจากแจ้งเตือน) ส่งให้ตอนเริ่มฟัง
      final pending = List<PkbFcmMessage>.from(_pendingOpened);
      _pendingOpened.clear();
      scheduleMicrotask(() {
        for (final m in pending) {
          _onOpened.add(m);
        }
      });
    },
  );

  /// ข้อความที่ได้รับขณะแอปเปิดอยู่
  static Stream<PkbFcmMessage> get onMessage => _onMessage.stream;

  /// ผู้ใช้กดแจ้งเตือน (แอปเบื้องหลัง / แอปปิดอยู่ / แจ้งเตือนที่แสดงตอนแอปเปิด)
  /// ใช้พาไปหน้าที่ต้องการ เช่น `message.screen`
  static Stream<PkbFcmMessage> get onOpened => _onOpened.stream;

  /// เรียก API ของ Inbox เอง (หรือใช้ [PkbFcmInboxPage])
  static PkbFcmApi get api {
    final api = _api;
    if (api == null) throw StateError('เรียก PkbFcm.init() ก่อน');
    return api;
  }

  /// FCM token ของเครื่องนี้ (หลัง login)
  static String? get fcmToken => _fcmToken;

  /// เคย login() และยังไม่ logout()
  static bool get isLoggedIn => _loggedIn;

  /// init สำเร็จ (Firebase พร้อม)
  static bool get isReady => _ready;

  /// เรียกครั้งเดียวใน `main()` หลัง `WidgetsFlutterBinding.ensureInitialized()`
  ///
  /// - [baseUrl] โดเมนของไซต์สหกรณ์ เช่น `https://coop.example.com`
  /// - [authToken] คืน token ล็อกอินของแอป (ส่งเป็น `Bearer`) — คืน null ถ้ายังไม่ล็อกอิน
  /// - [firebaseOptions] ใส่ `DefaultFirebaseOptions.currentPlatform` ถ้าใช้ไฟล์จาก flutterfire configure
  ///   (ถ้าแอปเรียก `Firebase.initializeApp()` เองแล้ว ไม่ต้องใส่)
  static Future<void> init({
    required String baseUrl,
    required FutureOr<String?> Function() authToken,
    FirebaseOptions? firebaseOptions,
    PkbFcmOptions options = const PkbFcmOptions(),
  }) async {
    _options = options;
    _api = PkbFcmApi(
      baseUrl: baseUrl,
      authToken: authToken,
      prefix: options.apiPrefix,
      timeout: options.timeout,
    );

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: firebaseOptions);
      }
    } catch (e) {
      _initError = 'Firebase.initializeApp ไม่สำเร็จ: $e';
      _log(_initError!);
      return;
    }

    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();

    final messaging = FirebaseMessaging.instance;

    try {
      if (_isAndroid) {
        await _native.createChannel(
          id: options.androidChannelId,
          name: options.androidChannelName,
          description: options.androidChannelDescription,
        );
        _native.setOnTap((payload) {
          final m = PkbFcmMessage.fromPayload(payload, PkbFcmSource.background);
          if (m != null) _handleOpened(m);
        });
      } else if (_isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: options.showForegroundNotification,
          badge: options.showForegroundNotification,
          sound: options.showForegroundNotification,
        );
      }

      _subs.add(FirebaseMessaging.onMessage.listen(_handleForeground));
      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleOpened(_fromRemote(m, PkbFcmSource.background))));
      _subs.add(messaging.onTokenRefresh.listen(_handleTokenRefresh));

      _loggedIn = await _native.prefsGet(_kLoggedIn) == '1';
      _fcmToken = await _native.prefsGet(_kToken);
      _ready = true;
      _initError = null;

      // แอปถูกเปิดจากการกดแจ้งเตือน
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpened(_fromRemote(initial, PkbFcmSource.launch));
      if (_isAndroid) {
        final launch = PkbFcmMessage.fromPayload(await _native.getLaunchPayload(), PkbFcmSource.launch);
        if (launch != null) _handleOpened(launch);
      }

      if (_loggedIn && options.registerOnStart) {
        unawaited(login(requestPermission: false));
      }
      _log('init เรียบร้อย (loggedIn=$_loggedIn)');
    } catch (e) {
      _initError = 'init ไม่สำเร็จ: $e';
      _log(_initError!);
    }
  }

  /// เรียกหลังสมาชิกล็อกอินแอป: ขอสิทธิ์แจ้งเตือน (dialog ของระบบ) → ลงทะเบียนเครื่อง → subscribe ประกาศ
  ///
  /// เรียกซ้ำได้ทุกครั้งที่เปิดแอป (ไม่ถามสิทธิ์ซ้ำถ้าผู้ใช้ตอบไปแล้ว)
  static Future<PkbFcmResult> login({bool requestPermission = true}) async {
    if (!_ready || _api == null) {
      return PkbFcmResult(PkbFcmStatus.notInitialized, _initError ?? 'ยังไม่ได้เรียก PkbFcm.init()');
    }

    final messaging = FirebaseMessaging.instance;
    try {
      final settings = requestPermission
          ? await messaging.requestPermission(alert: true, badge: true, sound: true)
          : await messaging.getNotificationSettings();
      final permission = settings.authorizationStatus.name;

      final token = await _getToken();
      if (token == null) {
        return const PkbFcmResult(PkbFcmStatus.noToken, 'ขอ FCM token ไม่ได้');
      }

      final info = await _native.deviceInfo();
      await _api!.registerDevice(
        fcmToken: token,
        platform: info['platform'] ?? (_isIOS ? 'ios' : 'android'),
        appVersion: info['appVersion'],
        deviceModel: info['model'],
        permission: permission,
      );

      _fcmToken = token;
      _loggedIn = true;
      await _native.prefsSet(_kLoggedIn, '1');
      await _native.prefsSet(_kToken, token);

      // ประกาศถึงทุกคน — แยกจากการลงทะเบียน (บางเครื่องตอบช้า ไม่ควรทำให้ login ล้ม)
      unawaited(_subscribeTopic());

      final denied = settings.authorizationStatus == AuthorizationStatus.denied;
      _log('ลงทะเบียนเครื่องแล้ว ($permission)');
      return PkbFcmResult(denied ? PkbFcmStatus.permissionDenied : PkbFcmStatus.registered);
    } on PkbFcmApiException catch (e) {
      _log('ลงทะเบียนไม่สำเร็จ: $e');
      return PkbFcmResult(
        e.statusCode == 0 && e.message.contains('authToken') ? PkbFcmStatus.notLoggedIn : PkbFcmStatus.failed,
        e.toString(),
      );
    } catch (e) {
      _log('ลงทะเบียนไม่สำเร็จ: $e');
      return PkbFcmResult(PkbFcmStatus.failed, '$e');
    }
  }

  /// เรียกตอนสมาชิกล็อกอเอาต์ — **ก่อน** ลบ token ล็อกอินของแอป (ต้องใช้ token เรียก DELETE /device)
  static Future<void> logout() async {
    final token = _fcmToken;
    _loggedIn = false;
    try {
      await _native.prefsRemove(_kLoggedIn);
      await _native.prefsRemove(_kToken);
    } catch (_) {}

    if (!_ready) return;

    if (token != null && _api != null) {
      try {
        await _api!.unregisterDevice(token);
      } catch (e) {
        // token ที่ถูก deleteToken แล้ว FCM จะตอบ UNREGISTERED ฝั่งเซิร์ฟเวอร์ลบให้เองตอนส่งครั้งถัดไป
        _log('DELETE /device ไม่สำเร็จ: $e');
      }
    }
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(_options.topic).timeout(_options.timeout);
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _fcmToken = null;
    _log('logout เรียบร้อย');
  }

  /// จำนวนข้อความที่ยังไม่อ่าน (ใช้ทำ badge) — error คืน 0
  static Future<int> unreadCount() async {
    try {
      return await api.unreadCount();
    } catch (e) {
      _log('unreadCount ไม่สำเร็จ: $e');
      return 0;
    }
  }

  // ------------------------------------------------------------------ ภายใน

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  static Future<String?> _getToken() async {
    final messaging = FirebaseMessaging.instance;
    if (_isIOS) {
      // iOS ต้องได้ APNs token ก่อน (simulator / ไม่ได้อัปโหลด APNs key จะไม่ได้)
      String? apns;
      for (var i = 0; i < 10 && apns == null; i++) {
        apns = await messaging.getAPNSToken();
        if (apns == null) await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (apns == null) {
        _log('ไม่ได้ APNs token (ต้องเป็นเครื่องจริง + Push capability + APNs key ใน Firebase)');
        return null;
      }
    }
    return messaging.getToken();
  }

  static Future<void> _subscribeTopic() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(_options.topic).timeout(_options.timeout);
      _log('subscribe topic ${_options.topic} แล้ว');
    } catch (e) {
      _log('subscribe topic ${_options.topic} ไม่สำเร็จ (ลองใหม่ตอน login ครั้งถัดไป): $e');
    }
  }

  static Future<void> _handleTokenRefresh(String token) async {
    _log('FCM token เปลี่ยน');
    if (_loggedIn) await login(requestPermission: false);
  }

  static PkbFcmMessage _fromRemote(RemoteMessage m, PkbFcmSource source) => PkbFcmMessage(
        source: source,
        title: m.notification?.title,
        body: m.notification?.body,
        messageId: m.messageId,
        data: PkbFcmMessage.stringMap(m.data),
      );

  static Future<void> _handleForeground(RemoteMessage remote) async {
    final message = _fromRemote(remote, PkbFcmSource.foreground);
    _onMessage.add(message);

    // Android ไม่แสดงแจ้งเตือนเองตอนแอปเปิดอยู่ → แสดงผ่าน native (iOS แสดงเองจาก presentation options)
    if (_isAndroid && _options.showForegroundNotification && remote.notification != null) {
      try {
        await _native.show(
          id: remote.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelId: _options.androidChannelId,
          title: message.title,
          body: message.body,
          payload: message.toPayload(),
        );
      } catch (e) {
        _log('แสดงแจ้งเตือนไม่สำเร็จ: $e');
      }
    }
  }

  static void _handleOpened(PkbFcmMessage message) {
    final key = message.messageId;
    if (key != null) {
      if (_openedIds.contains(key)) {
        _log('ข้ามการกดซ้ำ ($key)');
        return;
      }
      _openedIds.add(key);
      if (_openedIds.length > 50) _openedIds.removeAt(0);
    }
    _log('กดแจ้งเตือน: ${message.title} ${message.data}');
    final id = message.id;
    if (_options.markReadOnOpen && id != null && _api != null) {
      _api!.markRead(id).catchError((Object e) => _log('mark read #$id ไม่สำเร็จ: $e'));
    }
    if (_onOpened.hasListener) {
      _onOpened.add(message);
    } else {
      _pendingOpened.add(message);
    }
  }

  static void _log(String message) {
    if (_options.debug) debugPrint('[pkb_fcm] $message');
  }

  /// สำหรับ test เท่านั้น
  @visibleForTesting
  static void debugSetNative(PkbFcmNative native) => _native = native;
}
