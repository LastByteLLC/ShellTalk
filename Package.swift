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
    .library(name: "ShellTalkDiscovery", targets: ["ShellTalkDiscovery"]),
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
        // Discovery layer is macOS/Linux only — the WASM executable
        // doesn't link it, keeping its bundle size small. The embedded
        // tldr corpus (CC-BY-4.0) ships as a SwiftPM resource of the
        // ShellTalkDiscovery target.
        .target(name: "ShellTalkDiscovery",
                condition: .when(platforms: [.macOS, .linux])),
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
    .target(
      name: "ShellTalkDiscovery",
      dependencies: ["ShellTalkKit", "CZlib"],
      path: "Sources/ShellTalkDiscovery",
      // Build-time leftover from harness/refresh-tldr-baseline.sh; the
      // .json.gz next to it is the actual shipped artifact. Gitignored,
      // but SwiftPM still warns on unhandled files.
      exclude: ["Resources/tldr-baseline.json"],
      // Embedded tldr-pages corpus (CC-BY-4.0). Gzipped at build time by
      // harness/refresh-tldr-baseline.sh; runtime decompresses on first
      // access. Trades ~5 ms cold-start CPU for ~3.7 MB binary savings.
      resources: [
        .process("Resources/tldr-baseline.json.gz"),
        .process("Resources/tldr-baseline.meta.json"),
      ]
    ),
    // System wrapper for libz. macOS ships zlib in the SDK; Linux ships
    // it as zlib1g (already on the swiftlang/swift Docker images). Used
    // exclusively by ShellTalkDiscovery to decompress the embedded
    // tldr-pages corpus — this is why we don't pull in Apple's
    // Compression.framework (Darwin-only).
    .systemLibrary(
      name: "CZlib",
      path: "Sources/CZlib"
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
    .testTarget(
      name: "ShellTalkDiscoveryTests",
      dependencies: ["ShellTalkDiscovery", "ShellTalkKit"],
      path: "Tests/ShellTalkDiscoveryTests"
    ),
  ],
  swiftLanguageModes: [.v6]
)
