// swift-tools-version: 5.9
// รองรับ Swift Package Manager (Flutter รุ่นใหม่) — แอปที่ใช้ CocoaPods ใช้ ../pkb_fcm_notification.podspec แทน
import PackageDescription

let package = Package(
    name: "pkb_fcm_notification",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "pkb-fcm-notification", targets: ["pkb_fcm_notification"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "pkb_fcm_notification",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
