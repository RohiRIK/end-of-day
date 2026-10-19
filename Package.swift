// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EndOfDay",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "EndOfDay", targets: ["EndOfDay"]),
        // Library product so Xcode makes a scheme for it: SwiftUI previews do not run in executable targets.
        .library(name: "EndOfDayUI", targets: ["EndOfDayUI"]),
    ],
    targets: [
        .target(name: "EndOfDayCore"),
        .target(name: "EndOfDayUI", dependencies: ["EndOfDayCore"]),
        .executableTarget(name: "EndOfDay", dependencies: ["EndOfDayUI"]),
        .testTarget(name: "EndOfDayCoreTests", dependencies: ["EndOfDayCore"]),
    ]
)
