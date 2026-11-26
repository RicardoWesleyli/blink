// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Blink",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Blink", targets: ["Blink"])
    ],
    targets: [
        .executableTarget(
            name: "Blink",
            path: "Sources/Blink",
            resources: [.process("Assets")]
        )
    ]
)
