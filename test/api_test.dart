import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pkb_fcm_notification/pkb_fcm_notification.dart';

void main() {
  late List<http.Request> requests;

  PkbFcmApi api(http.Response Function(http.Request) handler, {String? token = 'tok-123'}) {
    requests = [];
    return PkbFcmApi(
      baseUrl: 'https://coop.test/',
      authToken: () => token,
      client: MockClient((req) async {
        requests.add(req);
        return handler(req);
      }),
    );
  }

  http.Response json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

  test('registerDevice ส่ง POST /api/push/device พร้อม Bearer และตัดความยาวตามที่ backend validate', () async {
    final a = api((_) => json({'ok': true, 'registered': true}));
    await a.registerDevice(
      fcmToken: 'fcm-abc',
      platform: 'android',
      appVersion: '1.2.3',
      deviceModel: 'x' * 150,
      permission: 'authorized',
    );

    final req = requests.single;
    expect(req.method, 'POST');
    expect(req.url.toString(), 'https://coop.test/api/push/device');
    expect(req.headers['Authorization'], 'Bearer tok-123');
    expect(req.headers['Accept'], 'application/json');
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['fcm_token'], 'fcm-abc');
    expect(body['platform'], 'android');
    expect((body['device_model'] as String).length, 100);
  });

  test('ไม่มี token ล็อกอิน → ไม่ยิง request และ throw statusCode 0', () async {
    final a = api((_) => json({}), token: null);
    expect(
      () => a.registerDevice(fcmToken: 'f', platform: 'ios'),
      throwsA(isA<PkbFcmApiException>()
          .having((e) => e.statusCode, 'statusCode', 0)
          .having((e) => e.notLoggedIn, 'notLoggedIn', isTrue)),
    );
    expect(requests, isEmpty);
  });

  test('401 จาก backend → PkbFcmApiException พร้อมข้อความ', () async {
    final a = api((_) => json({'message': 'Unauthenticated.'}, 401));
    await expectLater(
      a.unreadCount(),
      throwsA(isA<PkbFcmApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.message, 'message', 'Unauthenticated.')),
    );
  });

  test('inbox แปลงรูปแบบ JSON ของ Laravel (ภาษาไทย, data, read, หน้า)', () async {
    final a = api((req) {
      expect(req.url.queryParameters['page'], '2');
      return json({
        'ok': true,
        'data': [
          {
            'id': 15,
            'type': 'member',
            'category': 'deposit',
            'title': 'แจ้งรายการเงินฝาก',
            'body': 'มีรายการฝากเงินเข้าบัญชีของท่าน',
            'data': {'screen': 'deposit', 'ref': 'DP1'},
            'created_at': '2026-10-02T10:15:00+07:00',
            'read': false,
          },
          {'id': 9, 'type': 'broadcast', 'title': 'ประกาศ', 'body': 'ข้อความ', 'data': [], 'read': true},
        ],
        'page': 2,
        'last_page': 3,
        'total': 45,
      });
    });

    final page = await a.inbox(page: 2);
    expect(page.items, hasLength(2));
    expect(page.hasMore, isTrue);
    expect(page.total, 45);
    final first = page.items.first;
    expect(first.title, 'แจ้งรายการเงินฝาก');
    expect(first.data['screen'], 'deposit');
    expect(first.read, isFalse);
    expect(first.createdAt, isNotNull);
    expect(page.items[1].data, isEmpty); // Laravel ส่ง [] เมื่อ data ว่าง
  });

  test('unreadCount / markRead / markAllRead / unregister ใช้ path ถูกต้อง', () async {
    final a = api((req) => json(req.url.path.endsWith('unread-count') ? {'ok': true, 'unread': 3} : {'ok': true}));
    expect(await a.unreadCount(), 3);
    await a.markRead(15);
    await a.markAllRead();
    await a.unregisterDevice('fcm-abc');

    expect(requests.map((r) => '${r.method} ${r.url.path}').toList(), [
      'GET /api/push/inbox/unread-count',
      'POST /api/push/inbox/15/read',
      'POST /api/push/inbox/read-all',
      'DELETE /api/push/device',
    ]);
    expect(jsonDecode(requests.last.body), {'fcm_token': 'fcm-abc'});
  });

  test('prefix กำหนดเองได้', () async {
    requests = [];
    final a = PkbFcmApi(
      baseUrl: 'https://coop.test',
      authToken: () async => 't',
      prefix: '/mobile/push/',
      client: MockClient((req) async {
        requests.add(req);
        return json({'ok': true, 'unread': 0});
      }),
    );
    await a.unreadCount();
    expect(requests.single.url.toString(), 'https://coop.test/mobile/push/inbox/unread-count');
  });
}
