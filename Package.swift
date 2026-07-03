// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacMTR",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacMTR", targets: ["MacMTR"]),
        .library(name: "MacMTRCore", targets: ["MacMTRCore"])
    ],
    targets: [
        .target(name: "MacMTRCore"),
        .executableTarget(
            name: "MacMTR",
            dependencies: ["MacMTRCore"]
        ),
        .testTarget(
            name: "MacMTRCoreTests",
            dependencies: ["MacMTRCore"]
        )
    ]
)
