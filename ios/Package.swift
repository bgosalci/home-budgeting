// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "HomeBudgetingApp",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .iOSApplication(
            name: "HomeBudgeting",
            targets: ["HomeBudgetingApp"],
            bundleIdentifier: "com.homebudgeting.app",
            teamIdentifier: "TEAMID0000",
            displayVersion: "1.0",
            bundleVersion: "1",
            iconAssetName: "AppIcon",
            accentColorAssetName: "AccentColor",
            supportedDeviceFamilies: [.phone, .pad],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeLeft,
                .landscapeRight
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "HomeBudgetingApp",
            path: "HomeBudgetingApp",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
