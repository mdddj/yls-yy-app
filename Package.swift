// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "yls-yy-app",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "yls-yy-app",
            targets: ["yls-yy-app"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "yls-yy-app"
        ),
    ]
)
