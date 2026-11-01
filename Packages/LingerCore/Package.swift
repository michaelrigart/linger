// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LingerCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "LingerCore", targets: ["LingerCore"]),
    ],
    targets: [
        .target(name: "LingerCore", resources: [.copy("Resources/zone.tab")]),
        .testTarget(name: "LingerCoreTests", dependencies: ["LingerCore"]),
    ]
)
