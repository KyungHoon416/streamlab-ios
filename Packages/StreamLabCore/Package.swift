// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StreamLabCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "StreamLabDomain", targets: ["StreamLabDomain"]),
        .library(name: "StreamLabCatalogData", targets: ["StreamLabCatalogData"])
    ],
    targets: [
        .target(name: "StreamLabDomain"),
        .target(name: "StreamLabCatalogData", dependencies: ["StreamLabDomain"], resources: [.process("Resources")]),
        .testTarget(name: "StreamLabCatalogDataTests", dependencies: ["StreamLabDomain", "StreamLabCatalogData"])
    ]
)
