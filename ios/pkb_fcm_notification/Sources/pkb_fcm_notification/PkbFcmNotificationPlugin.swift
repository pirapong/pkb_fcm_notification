import Flutter
import UIKit

/// ส่วน native ของ pkb_fcm_notification บน iOS
/// - แสดงแจ้งเตือนตอนแอปเปิดอยู่และการกดแจ้งเตือน firebase_messaging จัดการให้แล้ว (ฝั่ง Dart)
/// - ที่นี่มีแค่ข้อมูลเครื่อง/เวอร์ชันแอป และค่าที่ต้องจำ (UserDefaults)
public class PkbFcmNotificationPlugin: NSObject, FlutterPlugin {
  private let defaults = UserDefaults(suiteName: "pkb_fcm_notification") ?? UserDefaults.standard

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "pkb_fcm_notification", binaryMessenger: registrar.messenger())
    let instance = PkbFcmNotificationPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]

    switch call.method {
    case "deviceInfo":
      result([
        "platform": "ios",
        "model": PkbFcmNotificationPlugin.machine(),
        "osVersion": UIDevice.current.systemVersion,
        "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
      ])
    case "prefsGet":
      result(defaults.string(forKey: args?["key"] as? String ?? ""))
    case "prefsSet":
      if let key = args?["key"] as? String {
        defaults.set(args?["value"] as? String, forKey: key)
      }
      result(nil)
    case "prefsRemove":
      if let key = args?["key"] as? String {
        defaults.removeObject(forKey: key)
      }
      result(nil)
    case "createChannel", "show", "getLaunchPayload", "areNotificationsEnabled":
      // เฉพาะ Android
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// รหัสรุ่นเครื่อง เช่น iPhone15,2
  private static func machine() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
    }
  }
}
