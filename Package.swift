// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EMLViewer",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "EMLCore", targets: ["EMLCore"]),
        .executable(name: "emlcheck", targets: ["emlcheck"]),
        .executable(name: "EMLViewer", targets: ["EMLViewer"]),
    ],
    targets: [
        .target(name: "EMLCore"),
        .executableTarget(name: "emlcheck", dependencies: ["EMLCore"]),
        .executableTarget(
            name: "EMLViewer",
            dependencies: ["EMLCore"],
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
    ]
)
