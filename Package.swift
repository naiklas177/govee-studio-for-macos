// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "GoveeStudio",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "GoveeStudio", targets: ["GoveeStudio"])],
    targets: [
        .target(name: "AmbienceCore"),
        .executableTarget(name: "GoveeStudio", dependencies: ["AmbienceCore"]),
        .testTarget(name: "AmbienceCoreTests", dependencies: ["AmbienceCore"]),
        .testTarget(name: "GoveeStudioTests", dependencies: ["GoveeStudio", "AmbienceCore"])
    ],
    swiftLanguageModes: [.v5]
)
