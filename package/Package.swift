// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AstroPiperKit",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AstroPiperKit",
            targets: ["AstroPiperCore", "AstroPiperUI"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AstroPiperCore"
        ),
        .target(
            name: "AstroPiperUI",
            dependencies: ["AstroPiperCore"],
            exclude: ["Documentation"]
        ),
        .testTarget(
            name: "AstroPiperUITests",
            dependencies: ["AstroPiperCore", "AstroPiperUI"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AstroPiperCoreTests",
            dependencies: ["AstroPiperCore"],
            resources: [.process("Resources")]
        ),
    ]
)
