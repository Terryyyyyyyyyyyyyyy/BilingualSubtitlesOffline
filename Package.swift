// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "BilingualSubtitlesOffline",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/ggerganov/whisper.spm", from: "1.6.2")
    ],
    targets: [
        .executableTarget(
            name: "BilingualSubtitlesOffline",
            dependencies: [
                .product(name: "whisper", package: "whisper.spm")
            ],
            resources: [.copy("Resources")]
        )
    ]
)
