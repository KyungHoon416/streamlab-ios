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
            .product(name: "StreamLabDomain", package: "StreamLabCore")
        ]),
        .target(name: "StreamLabProfileFeature", dependencies: [
            "StreamLabDesignSystem",
            .product(name: "StreamLabDomain", package: "StreamLabCore")
        ]),
        .target(name: "StreamLabCatalogFeature", dependencies: [
            "StreamLabDesignSystem",
            .product(name: "StreamLabDomain", package: "StreamLabCore")
        ])
    ]
)
