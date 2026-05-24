// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NodeKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NodeKit",
            targets: ["NodeKit"]
        ),
    ],
    dependencies: [
        // Build-time plugin for generating Swift-DocC documentation. Not a
        // runtime dependency — does not link into consumer binaries.
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NodeKit",
        ),

    ],
    swiftLanguageModes: [.v6]
)
