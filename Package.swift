// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "mac-cleaner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "MacCleanerCore", targets: ["MacCleanerCore"]),
        .executable(name: "mac-cleaner", targets: ["MacCleanerCLI"]),
        .executable(name: "MacCleanerGUI", targets: ["MacCleanerGUI"])
    ],
    targets: [
        .target(
            name: "MacCleanerCore",
            path: "Sources/MacCleanerCore"
        ),
        .executableTarget(
            name: "MacCleanerCLI",
            dependencies: ["MacCleanerCore"],
            path: "Sources/MacCleanerCLI"
        ),
        .executableTarget(
            name: "MacCleanerGUI",
            dependencies: ["MacCleanerCore"],
            path: "Sources/MacCleanerGUI"
        )
    ]
)
