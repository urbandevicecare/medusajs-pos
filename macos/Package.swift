// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "UrbanDevicePOS",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "UrbanDevicePOS", targets: ["UrbanDevicePOS"])
    ],
    targets: [
        .executableTarget(
            name: "UrbanDevicePOS",
            path: "Sources"
        )
    ]
)
