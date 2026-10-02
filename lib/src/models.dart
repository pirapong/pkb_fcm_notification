import 'dart:convert';

/// ที่มาของข้อความ
enum PkbFcmSource {
  /// ได้รับขณะแอปเปิดอยู่
  foreground,

  /// กดแจ้งเตือนขณะแอปอยู่เบื้องหลัง
  background,

  /// กดแจ้งเตือนแล้วแอปถูกเปิดขึ้นมาใหม่ (แอปปิดอยู่)
  launch,
}

/// ข้อความแจ้งเตือนที่ได้รับ / ถูกกด
class PkbFcmMessage {
  PkbFcmMessage({
    required this.source,
    this.title,
    this.body,
    this.messageId,
    Map<String, String>? data,
  }) : data = data ?? const {};

  final PkbFcmSource source;

  /// id ของ FCM (ใช้กันข้อความเดียวกันถูกส่งซ้ำ)
  final String? messageId;
  final String? title;
  final String? body;

  /// ค่าที่ส่งมาจาก Laravel (`$data`) + `push_message_id` + `category`
  final Map<String, String> data;

  /// id ของข้อความใน Inbox (ใช้กับ `PkbFcm.api.markRead`)
  int? get id => int.tryParse(data['push_message_id'] ?? '');

  String? get category => data['category'];

  /// หน้าที่ควรพาไป เช่น `deposit`, `loan`, `news` (ตามที่ไซต์ส่งใน `$data['screen']`)
  String? get screen => data['screen'];

  static Map<String, String> stringMap(Map<dynamic, dynamic>? raw) {
    final out = <String, String>{};
    raw?.forEach((key, value) {
      if (value != null) out['$key'] = '$value';
    });
    return out;
  }

  /// payload ที่ฝากไว้กับแจ้งเตือนที่ pkb_fcm_notification แสดงเอง (Android)
  String toPayload() => jsonEncode({'title': title, 'body': body, 'messageId': messageId, 'data': data});

  static PkbFcmMessage? fromPayload(String? payload, PkbFcmSource source) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      return PkbFcmMessage(
        source: source,
        title: json['title'] as String?,
        body: json['body'] as String?,
        messageId: json['messageId'] as String?,
        data: stringMap(json['data'] as Map?),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'PkbFcmMessage($source, $title, $data)';
}

/// ผลของ `PkbFcm.login()`
enum PkbFcmStatus {
  /// ลงทะเบียนเครื่องสำเร็จ และผู้ใช้อนุญาตแจ้งเตือน
  registered,

  /// ลงทะเบียนเครื่องแล้ว แต่ผู้ใช้ไม่อนุญาตแจ้งเตือน (เปิดได้ที่การตั้งค่าของเครื่อง)
  permissionDenied,

  /// ยังไม่ได้ล็อกอิน (authToken คืนค่าว่าง)
  notLoggedIn,

  /// ยังไม่ได้เรียก `PkbFcm.init()` หรือ init ไม่สำเร็จ (เช่น ไม่ได้ตั้งค่า Firebase)
  notInitialized,

  /// ขอ FCM token ไม่ได้ (iOS simulator / ยังไม่ได้อัปโหลด APNs key / ไม่มี Google Play services)
  noToken,

  /// เรียก API ไม่สำเร็จ (ดู `error`)
  failed,
}

class PkbFcmResult {
  const PkbFcmResult(this.status, [this.error]);

  final PkbFcmStatus status;
  final String? error;

  /// ลงทะเบียนเครื่องกับเซิร์ฟเวอร์แล้ว (แม้ผู้ใช้จะไม่อนุญาตแจ้งเตือน)
  bool get isRegistered => status == PkbFcmStatus.registered || status == PkbFcmStatus.permissionDenied;

  @override
  String toString() => error == null ? '$status' : '$status: $error';
}

/// ข้อความใน Inbox (GET /api/push/inbox)
class PkbFcmInboxItem {
  PkbFcmInboxItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    this.category,
    this.createdAt,
  });

  factory PkbFcmInboxItem.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return PkbFcmInboxItem(
      id: (json['id'] as num).toInt(),
      type: '${json['type'] ?? ''}',
      category: json['category'] as String?,
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      data: rawData is Map ? PkbFcmMessage.stringMap(rawData) : const {},
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal(),
      read: json['read'] == true,
    );
  }

  final int id;

  /// member / group / broadcast
  final String type;
  final String? category;
  final String title;
  final String body;
  final Map<String, String> data;
  final DateTime? createdAt;
  bool read;
}

class PkbFcmInboxPageResult {
  PkbFcmInboxPageResult({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<PkbFcmInboxItem> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}
