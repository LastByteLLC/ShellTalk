import Testing
@testable import ShellTalkKit

@Suite("TemplateResolver")
struct TemplateResolverTests {

  @Test("Resolves simple command without slots")
  func simpleCommand() {
    let profile = makeMockProfile(os: .macOS)
    let resolver = TemplateResolver(profile: profile)
    let template = CommandTemplate(id: "test", intents: ["test"], command: "git status")
    let result = resolver.resolve(template: template, extractedSlots: [:])
    #expect(result == "git status")
  }

  @Test("Resolves user slots")
  func userSlots() {
    let profile = makeMockProfile(os: .macOS)
    let resolver = TemplateResolver(profile: profile)
    let template = CommandTemplate(
      id: "test", intents: ["test"],
      command: "find {PATH} -name '{PATTERN}' -type f",
      slots: [
        "PATH": SlotDefinition(type: .path, defaultValue: "."),
        "PATTERN": SlotDefinition(type: .glob, defaultValue: "*"),
      ]
    )
    let result = resolver.resolve(
      template: template,
      extractedSlots: ["PATH": "src", "PATTERN": "*.swift"]
    )
    #expect(result == "find src -name '*.swift' -type f")
  }

  @Test("Resolves platform slots for macOS")
  func platformSlotsMacOS() {
    let profile = makeMockProfile(os: .macOS)
    let resolver = TemplateResolver(profile: profile)
    let template = CommandTemplate(
      id: "test", intents: ["test"],
      command: "{SED} {SED_INPLACE} 's/old/new/g' file.txt"
    )
    let result = resolver.resolve(template: template, extractedSlots: [:])
    #expect(result == "sed -i '' 's/old/new/g' file.txt")
  }

  @Test("Resolves platform slots for Linux")
  func platformSlotsLinux() {
    let profile = makeMockProfile(os: .linux)
    let resolver = TemplateResolver(profile: profile)
    let template = CommandTemplate(
      id: "test", intents: ["test"],
      command: "{SED} {SED_INPLACE} 's/old/new/g' file.txt"
    )
    let result = resolver.resolve(template: template, extractedSlots: [:])
    #expect(result == "sed -i 's/old/new/g' file.txt")
  }

  @Test("Falls back to default slot values")
  func defaultSlotValues() {
    let profile = makeMockProfile(os: .macOS)
    let resolver = TemplateResolver(profile: profile)
    let template = CommandTemplate(
      id: "test", intents: ["test"],
      command: "find {PATH} -name '{PATTERN}'",
      slots: [
        "PATH": SlotDefinition(type: .path, defaultValue: "."),
        "PATTERN": SlotDefinition(type: .glob, defaultValue: "*"),
      ]
    )
    let result = resolver.resolve(template: template, extractedSlots: [:])
    #expect(result == "find . -name '*'")
  }

  @Test("Mixed platform and user slots")
  func mixedSlots() {
    let profile = makeMockProfile(os: .macOS)
    let resolver = TemplateResolver(profile: profile)
    let template = CommandTemplate(
      id: "test", intents: ["test"],
      command: "{SED} {SED_INPLACE} 's/{FIND}/{REPLACE}/g' {FILE}",
      slots: [
        "FIND": SlotDefinition(type: .string),
        "REPLACE": SlotDefinition(type: .string),
        "FILE": SlotDefinition(type: .path),
      ]
    )
    let result = resolver.resolve(
      template: template,
      extractedSlots: ["FIND": "foo", "REPLACE": "bar", "FILE": "config.yaml"]
    )
    #expect(result == "sed -i '' 's/foo/bar/g' config.yaml")
  }

  @Test("CLIPBOARD_COPY resolves per platform")
  func clipboardSlot() {
    let macResolver = TemplateResolver(profile: makeMockProfile(os: .macOS))
    let linuxResolver = TemplateResolver(profile: makeMockProfile(os: .linux))
    let template = CommandTemplate(
      id: "test", intents: ["test"],
      command: "echo 'hello' | {CLIPBOARD_COPY}"
    )
    #expect(macResolver.resolve(template: template, extractedSlots: [:]) == "echo 'hello' | pbcopy")
    #expect(linuxResolver.resolve(template: template, extractedSlots: [:])
      == "echo 'hello' | xclip -selection clipboard")
  }

  // MARK: - Helpers

  private func makeMockProfile(os: OS) -> SystemProfile {
    SystemProfile(
      os: os,
      arch: "arm64",
      osVersion: "1.0",
      shell: .zsh,
      packageManager: os == .macOS ? .brew : .apt,
      availableCommands: ["sed", "grep", "find"],
      commandPaths: [:],
      commandVersions: [:],
      gnuOverrides: [:],
      missingAlternatives: [:]
    )
  }
}
