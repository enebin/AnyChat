// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AnyChat",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "AnyChatUI", targets: ["AnyChatUI"])
    ],
    targets: [
        .target(name: "AnyChatCore"),
        .target(
            name: "AnyChatDesignSystem",
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .target(
            name: "AnyChatUI",
            dependencies: [
                "AnyChatCore",
                "AnyChatDesignSystem"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "AnyChatCoreTests",
            dependencies: ["AnyChatCore"]
        ),
        .testTarget(
            name: "AnyChatDesignSystemTests",
            dependencies: ["AnyChatDesignSystem"]
        ),
        // `defaultIsolation` is deliberately omitted here: it would make `XCTestCase`
        // subclasses main-actor isolated, which clashes with the nonisolated initializers
        // they inherit. Test types opt in with an explicit `@MainActor` instead.
        .testTarget(
            name: "AnyChatUITests",
            dependencies: ["AnyChatUI", "AnyChatCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
