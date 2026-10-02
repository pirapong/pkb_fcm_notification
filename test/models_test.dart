import 'package:flutter_test/flutter_test.dart';
import 'package:pkb_fcm_notification/pkb_fcm_notification.dart';

void main() {
  test('PkbFcmMessage อ่าน push_message_id / category / screen จาก data', () {
    final m = PkbFcmMessage(
      source: PkbFcmSource.background,
      title: 'แจ้งรายการเงินฝาก',
      data: PkbFcmMessage.stringMap({'push_message_id': 12, 'category': 'deposit', 'screen': 'deposit', 'x': null}),
    );
    expect(m.id, 12);
    expect(m.category, 'deposit');
    expect(m.screen, 'deposit');
    expect(m.data.containsKey('x'), isFalse);
  });

  test('payload ไป-กลับ (ใช้กับแจ้งเตือนที่แสดงเองบน Android)', () {
    final m = PkbFcmMessage(
      source: PkbFcmSource.foreground,
      title: 'หัวข้อ',
      body: 'ข้อความ',
      data: {'push_message_id': '5', 'screen': 'loan'},
    );
    final back = PkbFcmMessage.fromPayload(m.toPayload(), PkbFcmSource.launch)!;
    expect(back.title, 'หัวข้อ');
    expect(back.body, 'ข้อความ');
    expect(back.id, 5);
    expect(back.source, PkbFcmSource.launch);
    expect(PkbFcmMessage.fromPayload('ไม่ใช่ json', PkbFcmSource.launch), isNull);
    expect(PkbFcmMessage.fromPayload(null, PkbFcmSource.launch), isNull);
  });

  test('PkbFcmResult.isRegistered', () {
    expect(const PkbFcmResult(PkbFcmStatus.registered).isRegistered, isTrue);
    expect(const PkbFcmResult(PkbFcmStatus.permissionDenied).isRegistered, isTrue);
    expect(const PkbFcmResult(PkbFcmStatus.failed, 'x').isRegistered, isFalse);
  });

  test('เรียก login / logout / unreadCount ก่อน init ไม่ throw', () async {
    final r = await PkbFcm.login();
    expect(r.status, PkbFcmStatus.notInitialized);
    await PkbFcm.logout();
    expect(PkbFcm.isLoggedIn, isFalse);
    expect(await PkbFcm.unreadCount(), 0);
  });
}
