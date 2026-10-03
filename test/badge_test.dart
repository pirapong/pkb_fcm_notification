import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkb_fcm_notification/pkb_fcm_notification.dart';
import 'package:pkb_fcm_notification/src/native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pkb_fcm_notification');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    PkbFcm.debugSetNative(PkbFcmNative(channel));
  });

  void mockNative(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  test('PkbFcmMessage.badge อ่านตัวเลขจาก data', () {
    expect(PkbFcmMessage(source: PkbFcmSource.foreground, data: {'badge': '3'}).badge, 3);
    expect(PkbFcmMessage(source: PkbFcmSource.foreground, data: {'badge': 'x'}).badge, isNull);
    expect(PkbFcmMessage(source: PkbFcmSource.foreground, data: {}).badge, isNull);
  });

  test('setBadge ส่งตัวเลขไป native (ติดลบ = 0) และคืนผลจาก native', () async {
    mockNative((call) => true);

    expect(await PkbFcm.setBadge(5), isTrue);
    expect(await PkbFcm.setBadge(-2), isTrue);
    expect(await PkbFcm.clearBadge(), isTrue);

    expect(calls.map((c) => c.method).toList(), ['setBadge', 'setBadge', 'setBadge']);
    expect(calls.map((c) => (c.arguments as Map)['count']).toList(), [5, 0, 0]);
  });

  test('setBadge ไม่ throw เมื่อ native error / ไม่รองรับ (Android คืน false)', () async {
    mockNative((call) => throw PlatformException(code: 'x'));
    expect(await PkbFcm.setBadge(1), isFalse);

    mockNative((call) => false);
    expect(await PkbFcm.setBadge(1), isFalse);
  });

  test('logout ล้าง badge แม้ยังไม่ได้ init', () async {
    mockNative((call) => call.method == 'setBadge' ? true : null);

    await PkbFcm.logout();

    final badgeCalls = calls.where((c) => c.method == 'setBadge').toList();
    expect(badgeCalls, hasLength(1));
    expect((badgeCalls.first.arguments as Map)['count'], 0);
  });
}
