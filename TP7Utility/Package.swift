// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TP7Utility",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TP7Utility",
            targets: ["TP7Utility"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TP7Utility"
        )
    ]
)