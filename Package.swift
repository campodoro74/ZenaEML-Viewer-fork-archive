// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EMLViewer",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "EMLCore", targets: ["EMLCore"]),
    ],
    targets: [
        .target(name: "EMLCore"),
    ]
)
