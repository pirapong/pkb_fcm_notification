import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// error จาก API ของ soat/laravel-soat-fcm-notification
class PkbFcmApiException implements Exception {
  PkbFcmApiException(this.statusCode, this.message, {this.notLoggedIn = false});

  /// HTTP status (0 = ไม่ได้ยิง request / เครือข่ายมีปัญหา)
  final int statusCode;
  final String message;

  /// `authToken` คืนค่าว่าง (ยังไม่ได้ล็อกอินแอป) — ไม่ได้ยิง request
  final bool notLoggedIn;

  @override
  String toString() => 'PkbFcmApiException($statusCode): $message';
}

/// เรียก API `/api/push/*` ของไซต์สหกรณ์ (auth ด้วย Bearer token ที่แอปมีอยู่แล้ว)
class PkbFcmApi {
  PkbFcmApi({
    required this.baseUrl,
    required this.authToken,
    this.prefix = 'api/push',
    this.timeout = const Duration(seconds: 15),
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final FutureOr<String?> Function() authToken;
  final String prefix;
  final Duration timeout;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final pre = prefix.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final uri = Uri.parse('$base/$pre/$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final token = await authToken();
    if (token == null || token.trim().isEmpty) {
      throw PkbFcmApiException(0, 'ยังไม่ได้ล็อกอิน (authToken ว่าง)', notLoggedIn: true);
    }

    final request = http.Request(method, _uri(path, query))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token.trim()}',
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(request).timeout(timeout));
    } on TimeoutException {
      throw PkbFcmApiException(0, 'หมดเวลาเชื่อมต่อ ${request.url.host}');
    } catch (e) {
      throw PkbFcmApiException(0, 'เชื่อมต่อไม่ได้: $e');
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      json = <String, dynamic>{};
    }

    if (res.statusCode >= 400) {
      throw PkbFcmApiException(res.statusCode, '${json['message'] ?? res.reasonPhrase ?? 'error'}');
    }
    return json;
  }

  /// POST /device — ลงทะเบียน/อัปเดตเครื่อง
  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
    String? appVersion,
    String? deviceModel,
    String? permission,
  }) async {
    final body = <String, dynamic>{'fcm_token': fcmToken, 'platform': platform};
    if (appVersion != null && appVersion.isNotEmpty) body['app_version'] = _cut(appVersion, 20);
    if (deviceModel != null && deviceModel.isNotEmpty) body['device_model'] = _cut(deviceModel, 100);
    if (permission != null && permission.isNotEmpty) body['permission'] = _cut(permission, 20);
    await _send('POST', 'device', body: body);
  }

  /// GET /device?fcm_token= — ลงทะเบียนแล้วหรือยัง
  Future<bool> isRegistered(String fcmToken) async {
    final json = await _send('GET', 'device', query: {'fcm_token': fcmToken});
    return json['registered'] == true;
  }

  /// DELETE /device — ตอนล็อกเอาต์
  Future<void> unregisterDevice(String fcmToken) => _send('DELETE', 'device', body: {'fcm_token': fcmToken});

  /// GET /inbox?page=
  Future<PkbFcmInboxPageResult> inbox({int page = 1}) async {
    final json = await _send('GET', 'inbox', query: {'page': '$page'});
    final rawItems = json['data'];
    final items = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().map(PkbFcmInboxItem.fromJson).toList()
        : <PkbFcmInboxItem>[];
    return PkbFcmInboxPageResult(
      items: items,
      page: (json['page'] as num?)?.toInt() ?? page,
      lastPage: (json['last_page'] as num?)?.toInt() ?? page,
      total: (json['total'] as num?)?.toInt() ?? items.length,
    );
  }

  /// GET /inbox/unread-count
  Future<int> unreadCount() async {
    final json = await _send('GET', 'inbox/unread-count');
    return (json['unread'] as num?)?.toInt() ?? 0;
  }

  /// POST /inbox/{id}/read
  Future<void> markRead(int id) => _send('POST', 'inbox/$id/read');

  /// POST /inbox/read-all
  Future<void> markAllRead() => _send('POST', 'inbox/read-all');

  static String _cut(String value, int max) => value.length > max ? value.substring(0, max) : value;
}
