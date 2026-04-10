// PlatformSlots.swift — Platform-aware command slot resolution
//
// Maps abstract slot names (e.g., SED_INPLACE) to platform-correct values.
// Used by TemplateResolver to fill in platform-dependent parts of commands.

import Foundation

/// Resolves platform-dependent template slots based on the detected SystemProfile.
public struct PlatformSlots: Sendable {
  private let profile: SystemProfile
  private let overrides: [String: String]

  public init(profile: SystemProfile, overrides: [String: String] = [:]) {
    self.profile = profile
    self.overrides = overrides
  }

  /// Resolve a platform slot to its concrete value.
  /// Returns nil if the slot is unknown.
  public func resolve(_ slot: String) -> String? {
    // User overrides take precedence
    if let override = overrides[slot] { return override }

    switch slot {
    // sed
    case "SED":
      return "sed"
    case "SED_INPLACE":
      return profile.os == .macOS ? "-i ''" : "-i"
    case "SED_EXTENDED":
      return profile.os == .macOS ? "-E" : "-E"  // -E works on modern Linux too

    // stat
    case "STAT_SIZE":
      return profile.os == .macOS ? "-f '%z'" : "-c '%s'"
    case "STAT_MTIME":
      return profile.os == .macOS ? "-f '%m'" : "-c '%Y'"
    case "STAT_PERMS":
      return profile.os == .macOS ? "-f '%A'" : "-c '%a'"

    // date
    case "DATE_RELATIVE_DAYS":
      return profile.os == .macOS ? "-v+{N}d" : "-d '+{N} days'"
    case "DATE_ISO":
      return profile.os == .macOS ? "+%Y-%m-%d" : "--iso-8601"
    case "DATE_EPOCH":
      return profile.os == .macOS ? "-r {EPOCH}" : "-d @{EPOCH}"

    // readlink
    case "READLINK_CANONICAL":
      if profile.hasCommand("greadlink") { return "greadlink -f" }
      return profile.os == .macOS ? "readlink" : "readlink -f"

    // clipboard
    case "CLIPBOARD_COPY":
      return profile.os == .macOS ? "pbcopy" : "xclip -selection clipboard"
    case "CLIPBOARD_PASTE":
      return profile.os == .macOS ? "pbpaste" : "xclip -selection clipboard -o"

    // open
    case "OPEN_CMD":
      return profile.os == .macOS ? "open" : "xdg-open"

    // package manager
    case "PKG_INSTALL":
      switch profile.packageManager {
      case .brew: return "brew install"
      case .apt: return "sudo apt-get install -y"
      case .yum: return "sudo yum install -y"
      case .dnf: return "sudo dnf install -y"
      case .apk: return "sudo apk add"
      case .pacman: return "sudo pacman -S --noconfirm"
      case .port: return "sudo port install"
      case .nix: return "nix-env -i"
      case .unknown: return "echo 'No package manager detected:'"
      }
    case "PKG_SEARCH":
      switch profile.packageManager {
      case .brew: return "brew search"
      case .apt: return "apt-cache search"
      case .yum: return "yum search"
      case .dnf: return "dnf search"
      case .apk: return "apk search"
      case .pacman: return "pacman -Ss"
      case .port: return "port search"
      case .nix: return "nix-env -qa"
      case .unknown: return "echo 'No package manager:'"
      }

    // process count (for xargs -P)
    case "NPROC":
      return profile.os == .macOS ? "sysctl -n hw.ncpu" : "nproc"

    // find flags
    case "FIND_EMPTY_FLAG":
      return "-empty"  // Same on both platforms

    // ls color
    case "LS_COLOR":
      return profile.os == .macOS ? "-G" : "--color=auto"

    // grep color
    case "GREP_COLOR":
      return "--color=auto"  // Same on both

    // tar compression detect
    case "TAR_AUTO":
      return profile.os == .macOS ? "-a" : "--auto-compress"

    // md5
    case "MD5_CMD":
      return profile.os == .macOS ? "md5 -q" : "md5sum"

    // sha256
    case "SHA256_CMD":
      return profile.os == .macOS ? "shasum -a 256" : "sha256sum"

    // du human-readable sort
    case "DU_SORT_SIZE":
      // macOS sort supports -h, Linux sort supports -h
      return "du -sh * | sort -rh"

    // hostname
    case "HOSTNAME_CMD":
      return profile.os == .macOS ? "hostname" : "hostname"

    // notify (for long-running commands)
    case "NOTIFY_CMD":
      return profile.os == .macOS
        ? "osascript -e 'display notification \"{MSG}\" with title \"stm\"'"
        : "notify-send 'stm' '{MSG}'"

    default:
      return nil
    }
  }

  /// All known slot names.
  public static let allSlots: [String] = [
    "SED", "SED_INPLACE", "SED_EXTENDED",
    "STAT_SIZE", "STAT_MTIME", "STAT_PERMS",
    "DATE_RELATIVE_DAYS", "DATE_ISO", "DATE_EPOCH",
    "READLINK_CANONICAL",
    "CLIPBOARD_COPY", "CLIPBOARD_PASTE",
    "OPEN_CMD",
    "PKG_INSTALL", "PKG_SEARCH",
    "NPROC",
    "FIND_EMPTY_FLAG",
    "LS_COLOR", "GREP_COLOR",
    "TAR_AUTO",
    "MD5_CMD", "SHA256_CMD",
    "DU_SORT_SIZE",
    "HOSTNAME_CMD",
    "NOTIFY_CMD",
  ]
}
