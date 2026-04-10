// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ShellTalk",
  platforms: [.macOS(.v14)],  // Linux ignores this field
  products: [
    .executable(name: "shelltalk", targets: ["shelltalk"]),
    .library(name: "ShellTalkKit", targets: ["ShellTalkKit"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3"),
  ],
  targets: [
    .executableTarget(
      name: "shelltalk",
      dependencies: [
        "ShellTalkKit",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/shelltalk"
    ),
    .target(
      name: "ShellTalkKit",
      dependencies: [
        .product(name: "Yams", package: "Yams"),
      ],
      path: "Sources/ShellTalkKit"
    ),
    .testTarget(
      name: "ShellTalkKitTests",
      dependencies: ["ShellTalkKit"],
      path: "Tests/ShellTalkKitTests"
    ),
  ],
  swiftLanguageModes: [.v6]
)
