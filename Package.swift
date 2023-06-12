// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "Stinsen",
    platforms: [
        .iOS(.v14),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v7)
    ],
    products: [
        .library(name: "Stinsen", targets: ["Stinsen"])
    ],
    targets: [
        .target(name: "Stinsen", path: "Sources")
    ]
)
