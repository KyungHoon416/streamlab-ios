// swift-tools-version: 6.0
import PackageDescription

// Standalone validation executable; never linked into the iOS application.
let package = Package(
    name: "F03CrashProbe",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../Packages/StreamLabCore")],
    targets: [.executableTarget(name: "F03CrashProbe", dependencies: [
        .product(name: "StreamLabDomain", package: "StreamLabCore"),
        .product(name: "StreamLabPresentation", package: "StreamLabCore"),
        .product(name: "StreamLabCatalogData", package: "StreamLabCore")
    ])]
)
