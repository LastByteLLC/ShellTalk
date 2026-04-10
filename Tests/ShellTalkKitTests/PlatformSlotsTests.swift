import Testing
@testable import ShellTalkKit

@Suite("PlatformSlots")
struct PlatformSlotsTests {

  @Test("Resolves SED_INPLACE for macOS")
  func sedInplaceMacOS() {
    let profile = makeMockProfile(os: .macOS)
    let slots = PlatformSlots(profile: profile)
    #expect(slots.resolve("SED_INPLACE") == "-i ''")
  }

  @Test("Resolves SED_INPLACE for Linux")
  func sedInplaceLinux() {
    let profile = makeMockProfile(os: .linux)
    let slots = PlatformSlots(profile: profile)
    #expect(slots.resolve("SED_INPLACE") == "-i")
  }

  @Test("Resolves STAT_SIZE per platform")
  func statSize() {
    let macOS = PlatformSlots(profile: makeMockProfile(os: .macOS))
    let linux = PlatformSlots(profile: makeMockProfile(os: .linux))
    #expect(macOS.resolve("STAT_SIZE") == "-f '%z'")
    #expect(linux.resolve("STAT_SIZE") == "-c '%s'")
  }

  @Test("Resolves clipboard per platform")
  func clipboard() {
    let macOS = PlatformSlots(profile: makeMockProfile(os: .macOS))
    let linux = PlatformSlots(profile: makeMockProfile(os: .linux))
    #expect(macOS.resolve("CLIPBOARD_COPY") == "pbcopy")
    #expect(linux.resolve("CLIPBOARD_COPY") == "xclip -selection clipboard")
  }

  @Test("Resolves OPEN_CMD per platform")
  func openCmd() {
    let macOS = PlatformSlots(profile: makeMockProfile(os: .macOS))
    let linux = PlatformSlots(profile: makeMockProfile(os: .linux))
    #expect(macOS.resolve("OPEN_CMD") == "open")
    #expect(linux.resolve("OPEN_CMD") == "xdg-open")
  }

  @Test("Resolves package manager install")
  func pkgInstall() {
    let brew = PlatformSlots(profile: makeMockProfile(os: .macOS, pm: .brew))
    let apt = PlatformSlots(profile: makeMockProfile(os: .linux, pm: .apt))
    #expect(brew.resolve("PKG_INSTALL") == "brew install")
    #expect(apt.resolve("PKG_INSTALL") == "sudo apt-get install -y")
  }

  @Test("User overrides take precedence")
  func userOverrides() {
    let profile = makeMockProfile(os: .macOS)
    let slots = PlatformSlots(profile: profile, overrides: ["SED_INPLACE": "-i.bak"])
    #expect(slots.resolve("SED_INPLACE") == "-i.bak")
  }

  @Test("Unknown slot returns nil")
  func unknownSlot() {
    let slots = PlatformSlots(profile: makeMockProfile(os: .macOS))
    #expect(slots.resolve("NONEXISTENT_SLOT") == nil)
  }

  // MARK: - Helpers

  private func makeMockProfile(
    os: OS,
    pm: PackageManager = .unknown,
    commands: Set<String> = []
  ) -> SystemProfile {
    SystemProfile(
      os: os,
      arch: "arm64",
      osVersion: "1.0",
      shell: .zsh,
      packageManager: pm,
      availableCommands: commands,
      commandPaths: [:],
      commandVersions: [:],
      gnuOverrides: [:],
      missingAlternatives: [:]
    )
  }
}
