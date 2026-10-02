import 'package:flutter/services.dart';

/// ช่องทางคุยกับส่วน native ของ pkb_fcm_notification (android: PkbFcmNotificationPlugin.java, ios: PkbFcmNotificationPlugin.swift)
class PkbFcmNative {
  PkbFcmNative([MethodChannel? channel]) : _channel = channel ?? const MethodChannel('pkb_fcm_notification');

  final MethodChannel _channel;

  /// รับการกดแจ้งเตือนที่ pkb_fcm_notification แสดงเอง (Android) ระหว่างที่แอปยังเปิดอยู่
  void setOnTap(void Function(String? payload) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTap') handler(call.arguments as String?);
      return null;
    });
  }

  Future<Map<String, String>> deviceInfo() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('deviceInfo');
    final out = <String, String>{};
    raw?.forEach((key, value) {
      if (value != null) out[key] = '$value';
    });
    return out;
  }

  Future<void> createChannel({required String id, required String name, String? description}) =>
      _channel.invokeMethod('createChannel', {'id': id, 'name': name, 'description': description});

  Future<void> show({
    required int id,
    required String channelId,
    String? title,
    String? body,
    String? payload,
  }) =>
      _channel.invokeMethod('show', {
        'id': id,
        'channelId': channelId,
        'title': title,
        'body': body,
        'payload': payload,
      });

  /// payload ของแจ้งเตือนที่ทำให้แอปถูกเปิด (Android, ใช้ได้ครั้งเดียว)
  Future<String?> getLaunchPayload() => _channel.invokeMethod<String>('getLaunchPayload');

  Future<String?> prefsGet(String key) => _channel.invokeMethod<String>('prefsGet', {'key': key});

  Future<void> prefsSet(String key, String value) => _channel.invokeMethod('prefsSet', {'key': key, 'value': value});

  Future<void> prefsRemove(String key) => _channel.invokeMethod('prefsRemove', {'key': key});
}
