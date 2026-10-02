import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pkb_fcm_notification/src/native.dart';

/// ทดสอบส่วน native (Android: Java / iOS: Swift) บนเครื่องจริงหรือ emulator/simulator
/// รัน: `cd example && flutter test integration_test -d <device>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final native = PkbFcmNative();

  testWidgets('deviceInfo คืน platform / model / osVersion / appVersion', (tester) async {
    final info = await native.deviceInfo();
    expect(info['platform'], Platform.isIOS ? 'ios' : 'android');
    expect(info['model'], isNotEmpty);
    expect(info['osVersion'], isNotEmpty);
    expect(info['appVersion'], isNotEmpty);
  });

  testWidgets('prefs เขียน / อ่าน / ลบ', (tester) async {
    await native.prefsSet('it_key', 'ค่าทดสอบ');
    expect(await native.prefsGet('it_key'), 'ค่าทดสอบ');
    await native.prefsRemove('it_key');
    expect(await native.prefsGet('it_key'), isNull);
  });

  testWidgets('createChannel / show / getLaunchPayload ไม่ error (iOS = no-op)', (tester) async {
    await native.createChannel(id: 'coop_default', name: 'การแจ้งเตือน', description: 'ทดสอบ');
    await native.show(id: 4242, channelId: 'coop_default', title: 'integration test', body: 'แสดงจาก native', payload: '{}');
    expect(await native.getLaunchPayload(), isNull);
  });
}
