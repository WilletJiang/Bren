// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "BrenMac",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Bren", targets: ["Bren"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/colinc86/LaTeXSwiftUI.git",
            exact: "2.0.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "Bren",
            dependencies: [
                "Sparkle",
                .product(name: "LaTeXSwiftUI", package: "LaTeXSwiftUI"),
            ],
            path: "Sources/Bren",
            linkerSettings: [
                .linkedFramework("Carbon"),
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
