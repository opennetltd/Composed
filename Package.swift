// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Composed",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "Composed",
            targets: ["Composed"]
        ),
        .library(
            name: "ComposedLayouts",
            targets: ["ComposedLayouts"]
        ),
        .library(
            name: "ComposedUI",
            targets: ["ComposedUI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Quick.git", from: "7.2.1"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.2.0"),
    ],
    targets: [
        .target(
            name: "Composed",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "ComposedTests",
            dependencies: ["Quick", "Nimble", "Composed"],
            swiftSettings: [
                // Quick doesn't play nice with types that need to be created on the main actor
                // under Swift 6 mode.
                .swiftLanguageMode(.v5),
            ],
        ),
        .testTarget(
            name: "ComposedPerformanceTests",
            dependencies: ["Composed"],
        ),

        .target(
            name: "ComposedUI",
            dependencies: ["Composed"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "ComposedUITests",
            dependencies: ["Composed", "ComposedUI"]
        ),

        .target(
            name: "ComposedLayouts",
            dependencies: ["Composed", "ComposedUI"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
