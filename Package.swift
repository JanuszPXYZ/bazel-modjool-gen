// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "bazel-modjool-gen",
    platforms: [
      .macOS(.v13)
    ],
    products: [
      .executable(
        name: "bazel-modjool-gen",
        targets: ["bazel-modjool-gen"]
      ),
    ],
    dependencies: [
      .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
      .package(url: "https://github.com/jpsim/Yams.git", from: "6.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "bazel-modjool-gen",
            dependencies: [
              .product(name: "ArgumentParser", package: "swift-argument-parser"),
              .product(name: "Yams", package: "Yams"),
            ]
        ),
    ]
)
