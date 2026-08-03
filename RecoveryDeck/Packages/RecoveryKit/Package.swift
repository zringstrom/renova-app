// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RecoveryKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "RecoveryKit", targets: ["RecoveryKit"]),
    ],
    targets: [
        .target(name: "RecoveryKit"),
        .testTarget(name: "RecoveryKitTests", dependencies: ["RecoveryKit"]),
    ]
)
