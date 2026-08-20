// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "BrenMac",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Bren", targets: ["Bren"]),
    ],
    targets: [
        .executableTarget(
            name: "Bren",
            dependencies: [
                "Sparkle",
            ],
            path: "Sources/Bren",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ScreenCaptureKit"),
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                ]),
            ]
        ),
        .binaryTarget(
            name: "Sparkle",
            path: ".build/vendor/Sparkle.xcframework"
        ),
        .testTarget(
            name: "BrenTests",
            dependencies: ["Bren"],
            path: "Tests/BrenTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
