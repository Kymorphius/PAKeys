// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PAKeys",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PAKeys", targets: ["PAKeys"])
    ],
    targets: [
        .executableTarget(name: "PAKeys"),
        .testTarget(name: "PAKeysTests", dependencies: ["PAKeys"])
    ]
)
