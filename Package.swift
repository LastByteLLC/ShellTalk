// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ShellTalk",
  platforms: [.macOS(.v14)],  // Linux and WASI ignore this field
  products: [
    .executable(name: "shelltalk", targets: ["shelltalk"]),
    .executable(name: "stm-eval", targets: ["stm-eval"]),
    .executable(name: "shelltalk-wasm", targets: ["shelltalk-wasm"]),
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
        .product(name: "Yams", package: "Yams",
                 condition: .when(platforms: [.macOS, .linux])),
      ],
      path: "Sources/ShellTalkKit"
    ),
    .executableTarget(
      name: "shelltalk-wasm",
      dependencies: ["ShellTalkKit"],
      path: "Sources/shelltalk-wasm"
    ),
    .executableTarget(
      name: "stm-eval",
      dependencies: ["ShellTalkKit"],
      path: "Sources/stm-eval"
    ),
    .testTarget(
      name: "ShellTalkKitTests",
      dependencies: ["ShellTalkKit"],
      path: "Tests/ShellTalkKitTests"
    ),
  ],
  swiftLanguageModes: [.v6]
)
