Pod::Spec.new do |s|
  s.name             = 'pkb_fcm_notification'
  s.version          = '1.0.0'
  s.summary          = 'Push notifications (FCM) for SO-AT cooperative apps.'
  s.description      = <<-DESC
Push notifications (FCM) for SO-AT cooperative apps — pairs with the Laravel package soat/laravel-soat-fcm-notification.
                       DESC
  s.homepage         = 'https://pub.dev/packages/pkb_fcm_notification'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'SO-AT'
  s.source           = { :path => '.' }
  s.source_files     = 'pkb_fcm_notification/Sources/pkb_fcm_notification/**/*.swift'
  s.resource_bundles = { 'pkb_fcm_notification_privacy' => ['pkb_fcm_notification/Sources/pkb_fcm_notification/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
