/// ตั้งค่าเพิ่มเติมของ pkb_fcm_notification — ทุกค่ามีค่าเริ่มต้นที่ตรงกับ soat/laravel-soat-fcm-notification แล้ว
class PkbFcmOptions {
  const PkbFcmOptions({
    this.apiPrefix = 'api/push',
    this.topic = 'all_members',
    this.androidChannelId = 'coop_default',
    this.androidChannelName = 'การแจ้งเตือน',
    this.androidChannelDescription = 'แจ้งเตือนรายการและประกาศจากสหกรณ์',
    this.showForegroundNotification = true,
    this.markReadOnOpen = true,
    this.registerOnStart = true,
    this.timeout = const Duration(seconds: 15),
    this.debug = false,
  });

  /// prefix ของ API ฝั่ง Laravel (config push.api.prefix)
  final String apiPrefix;

  /// topic สำหรับประกาศถึงทุกคน (config push.broadcast_topic)
  final String topic;

  /// Android notification channel (ต้องตรงกับ PUSH_ANDROID_CHANNEL ฝั่ง Laravel)
  final String androidChannelId;
  final String androidChannelName;
  final String androidChannelDescription;

  /// แสดงแจ้งเตือนแม้แอปเปิดอยู่ (Android แสดงผ่าน native, iOS ผ่าน firebase_messaging)
  final bool showForegroundNotification;

  /// กดแจ้งเตือนแล้วเรียก POST /inbox/{id}/read ให้อัตโนมัติ
  final bool markReadOnOpen;

  /// เปิดแอปแล้วลงทะเบียนเครื่องซ้ำเอง ถ้าเคย login() ไว้ (อัปเดตเวลาเปิดแอปล่าสุด / token ใหม่)
  final bool registerOnStart;

  /// timeout ของการเรียก API
  final Duration timeout;

  /// พิมพ์ log `[pkb_fcm_notification] ...` ใน console
  final bool debug;
}
