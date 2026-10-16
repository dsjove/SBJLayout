// swift-tools-version: 6.4

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SBJLayout",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "SBJLayout",
            targets: ["SBJLayout"]
        ),
    ],
    dependencies: [
        .package(path: "../SBJFoundation/Packages/SBJLocalization"),
        .package(path: "../SBJFoundation"),
    ],
    targets: [
        .target(
            name: "SBJLayout",
            dependencies: ["SBJFoundation", .product(name: "SBJLocalization", package: "SBJLocalization")],
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ],
        ),
        .testTarget(
            name: "SBJLayoutTests",
            dependencies: ["SBJLayout", .product(name: "SBJLocalization", package: "SBJLocalization")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(nil),
            ],
        ),
    ]
)
