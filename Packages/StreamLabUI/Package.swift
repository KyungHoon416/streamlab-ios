// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StreamLabUI",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "StreamLabDesignSystem", targets: ["StreamLabDesignSystem"]),
        .library(name: "StreamLabProfileFeature", targets: ["StreamLabProfileFeature"]),
        .library(name: "StreamLabCatalogFeature", targets: ["StreamLabCatalogFeature"])
    ],
    dependencies: [.package(path: "../StreamLabCore")],
    targets: [
        .target(name: "StreamLabDesignSystem", dependencies: [
            .product(name: "StreamLabCatalogData", package: "StreamLabCore"),
            .product(name: "StreamLabDomain", package: "StreamLabCore")
        ], resources: [.process("Resources")]),
        .target(name: "StreamLabProfileFeature", dependencies: [
            "StreamLabDesignSystem",
            .product(name: "StreamLabDomain", package: "StreamLabCore")
        ]),
        .target(name: "StreamLabCatalogFeature", dependencies: [
            .product(name: "StreamLabCatalogData", package: "StreamLabCore"),
            "StreamLabDesignSystem",
            .product(name: "StreamLabPresentation", package: "StreamLabCore"),
            .product(name: "StreamLabDomain", package: "StreamLabCore")
        ], resources: [.process("Resources")]),
        .testTarget(name: "StreamLabCatalogFeatureTests", dependencies: ["StreamLabCatalogFeature"])
    ]
)

