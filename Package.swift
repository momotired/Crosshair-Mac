// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CrosshairMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CrosshairMac", targets: ["CrosshairMac"])
    ],
    targets: [
        .executableTarget(name: "CrosshairMac")
    ]
)
