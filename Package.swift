// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CuboMagico",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "CubeCore"),
        .executableTarget(name: "CuboMagico", dependencies: ["CubeCore"]),
        .executableTarget(name: "cubetest", dependencies: ["CubeCore"]),
    ]
)
