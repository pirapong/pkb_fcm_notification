package com.pkb.pkb_fcm_notification;

import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * ส่วน native ของ pkb_fcm_notification บน Android
 * - สร้าง notification channel และแสดงแจ้งเตือนตอนแอปเปิดอยู่ (FCM ไม่แสดงเองบน Android)
 * - ส่ง payload กลับไป Dart เมื่อผู้ใช้กดแจ้งเตือนที่แสดงเอง
 * - ข้อมูลเครื่อง/เวอร์ชันแอป และค่าที่ต้องจำ (แทน device_info_plus / package_info_plus / shared_preferences)
 */
public class PkbFcmNotificationPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler,
        ActivityAware, PluginRegistry.NewIntentListener {

    static final String CHANNEL = "pkb_fcm_notification";
    static final String EXTRA_PAYLOAD = "pkb_fcm_payload";
    static final String PREFS = "pkb_fcm_notification";

    private MethodChannel channel;
    private Context context;
    private Activity activity;
    private ActivityPluginBinding activityBinding;
    private String launchPayload;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        context = null;
    }

    // ------------------------------------------------------------------ activity

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        attach(binding);
        // แอปถูกเปิดจากการกดแจ้งเตือนที่ pkb_fcm_notification แสดง (แอปปิดอยู่)
        Intent intent = binding.getActivity().getIntent();
        if (intent != null && intent.hasExtra(EXTRA_PAYLOAD)) {
            launchPayload = intent.getStringExtra(EXTRA_PAYLOAD);
            intent.removeExtra(EXTRA_PAYLOAD);
        }
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        detach();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        attach(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        detach();
    }

    private void attach(ActivityPluginBinding binding) {
        activityBinding = binding;
        activity = binding.getActivity();
        binding.addOnNewIntentListener(this);
    }

    private void detach() {
        if (activityBinding != null) {
            activityBinding.removeOnNewIntentListener(this);
        }
        activityBinding = null;
        activity = null;
    }

    /** แอปเปิดอยู่เบื้องหลังแล้วผู้ใช้กดแจ้งเตือนที่ pkb_fcm_notification แสดง */
    @Override
    public boolean onNewIntent(@NonNull Intent intent) {
        if (!intent.hasExtra(EXTRA_PAYLOAD)) {
            return false;
        }
        String payload = intent.getStringExtra(EXTRA_PAYLOAD);
        intent.removeExtra(EXTRA_PAYLOAD);
        if (channel != null) {
            channel.invokeMethod("onTap", payload);
        }
        if (activity != null) {
            activity.setIntent(intent);
        }
        return true;
    }

    // ------------------------------------------------------------------ methods

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "deviceInfo":
                    result.success(deviceInfo());
                    break;
                case "createChannel":
                    createChannel(call.<String>argument("id"), call.<String>argument("name"),
                            call.<String>argument("description"));
                    result.success(null);
                    break;
                case "show":
                    show(call);
                    result.success(null);
                    break;
                case "setBadge":
                    // Android ไม่มี API กลางสำหรับตัวเลขบนไอคอน — launcher แสดงจุด/ตัวเลขจากแจ้งเตือนที่ค้างเอง
                    result.success(false);
                    break;
                case "getLaunchPayload":
                    String payload = launchPayload;
                    launchPayload = null;
                    result.success(payload);
                    break;
                case "areNotificationsEnabled":
                    result.success(NotificationManagerCompat.from(context).areNotificationsEnabled());
                    break;
                case "prefsGet":
                    result.success(prefs().getString(call.<String>argument("key"), null));
                    break;
                case "prefsSet":
                    prefs().edit().putString(call.<String>argument("key"), call.<String>argument("value")).apply();
                    result.success(null);
                    break;
                case "prefsRemove":
                    prefs().edit().remove(call.<String>argument("key")).apply();
                    result.success(null);
                    break;
                default:
                    result.notImplemented();
            }
        } catch (Exception e) {
            result.error("pkb_fcm_notification", e.getMessage(), null);
        }
    }

    private SharedPreferences prefs() {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private Map<String, Object> deviceInfo() throws PackageManager.NameNotFoundException {
        Map<String, Object> info = new HashMap<>();
        info.put("platform", "android");
        info.put("model", (Build.MANUFACTURER + " " + Build.MODEL).trim());
        info.put("osVersion", Build.VERSION.RELEASE);
        PackageInfo pkg = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
        info.put("appVersion", pkg.versionName);
        return info;
    }

    private void createChannel(String id, String name, String description) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }
        NotificationChannel ch = new NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH);
        if (description != null) {
            ch.setDescription(description);
        }
        NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm != null) {
            nm.createNotificationChannel(ch);
        }
    }

    private void show(MethodCall call) {
        Integer id = call.argument("id");
        String channelId = call.argument("channelId");
        String title = call.argument("title");
        String body = call.argument("body");
        String payload = call.argument("payload");
        Integer number = call.argument("number");

        Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (launch == null) {
            return;
        }
        launch.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        launch.putExtra(EXTRA_PAYLOAD, payload);

        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        int requestCode = id != null ? id : (int) System.currentTimeMillis();
        PendingIntent pending = PendingIntent.getActivity(context, requestCode, launch, flags);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, channelId)
                .setSmallIcon(smallIcon())
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pending);
        // ตัวเลขที่เซิร์ฟเวอร์ส่งมา (launcher ที่รองรับใช้แสดงบนไอคอน)
        if (number != null && number > 0) {
            builder.setNumber(number);
        }

        try {
            NotificationManagerCompat.from(context).notify(requestCode, builder.build());
        } catch (SecurityException e) {
            // ผู้ใช้ไม่อนุญาตแจ้งเตือน (Android 13+) — ไม่ต้องแสดง
        }
    }

    /**
     * ไอคอนแจ้งเตือน: ใช้ค่าเดียวกับ FCM (meta-data com.google.firebase.messaging.default_notification_icon)
     * ถ้าแอปไม่ได้ตั้ง ใช้ไอคอนแอป
     */
    private int smallIcon() {
        try {
            ApplicationInfo ai = context.getPackageManager()
                    .getApplicationInfo(context.getPackageName(), PackageManager.GET_META_DATA);
            Bundle meta = ai.metaData;
            if (meta != null) {
                int icon = meta.getInt("com.google.firebase.messaging.default_notification_icon", 0);
                if (icon != 0) {
                    return icon;
                }
            }
            return ai.icon;
        } catch (PackageManager.NameNotFoundException e) {
            return android.R.drawable.ic_dialog_info;
        }
    }
}
