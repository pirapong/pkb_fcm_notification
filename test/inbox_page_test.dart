import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pkb_fcm_notification/pkb_fcm_notification.dart';

void main() {
  testWidgets('แสดงรายการ, กดแล้ว mark read, อ่านทั้งหมด', (tester) async {
    final calls = <String>[];
    final api = PkbFcmApi(
      baseUrl: 'https://coop.test',
      authToken: () => 'tok',
      client: MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        final body = req.url.path.endsWith('/inbox')
            ? {
                'ok': true,
                'data': [
                  {'id': 1, 'type': 'member', 'title': 'แจ้งรายการเงินฝาก', 'body': 'มีรายการเข้า', 'data': {'screen': 'deposit'}, 'read': false},
                  {'id': 2, 'type': 'broadcast', 'title': 'ประกาศสหกรณ์', 'body': 'ประชุมใหญ่', 'data': [], 'read': true},
                ],
                'page': 1,
                'last_page': 1,
                'total': 2,
              }
            : {'ok': true};
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    );

    String? opened;
    await tester.pumpWidget(MaterialApp(
      home: PkbFcmInboxPage(api: api, onTap: (_, item) => opened = item.data['screen']),
    ));
    await tester.pumpAndSettle();

    expect(find.text('แจ้งรายการเงินฝาก'), findsOneWidget);
    expect(find.text('ประกาศสหกรณ์'), findsOneWidget);

    await tester.tap(find.text('แจ้งรายการเงินฝาก'));
    await tester.pumpAndSettle();
    expect(opened, 'deposit');
    expect(calls, contains('POST /api/push/inbox/1/read'));

    // อ่านครบแล้ว ปุ่มอ่านทั้งหมดถูกปิด
    final readAll = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.done_all));
    expect(readAll.onPressed, isNull);
  });

  testWidgets('ไม่มีข้อความ → แสดงข้อความว่าง', (tester) async {
    final api = PkbFcmApi(
      baseUrl: 'https://coop.test',
      authToken: () => 'tok',
      client: MockClient((_) async => http.Response('{"ok":true,"data":[],"page":1,"last_page":1,"total":0}', 200)),
    );
    await tester.pumpWidget(MaterialApp(home: PkbFcmInboxPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีการแจ้งเตือน'), findsOneWidget);
  });
}
