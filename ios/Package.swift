// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

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
            teamIdentifier: nil,
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
