// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Composed",
    platforms: [
        .iOS(.v13),
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
            dependencies: ["Quick", "Nimble", "Composed"]),

        .target(
            name: "ComposedUI",
            dependencies: ["Composed"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "ComposedUITests",
            dependencies: ["Quick", "Nimble", "ComposedLayouts", "ComposedUI"]),

        .target(
            name: "ComposedLayouts",
            dependencies: ["Composed", "ComposedUI"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
