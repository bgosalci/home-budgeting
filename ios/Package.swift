// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HomeBudgetingApp",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "HomeBudgetingKit",
            targets: ["HomeBudgetingApp"]
        )
    ],
    targets: [
        .target(
            name: "HomeBudgetingApp",
            path: "HomeBudgetingApp",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
