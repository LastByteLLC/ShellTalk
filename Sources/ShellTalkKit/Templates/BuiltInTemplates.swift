// BuiltInTemplates.swift — Hardcoded template corpus
//
// Initial template set: file_operations, git, text_processing.
// These are compiled into the binary for zero-dependency startup.
// Additional categories added in Phase 5.

import Foundation

// swiftlint:disable function_body_length file_length

/// Built-in template definitions compiled into the binary.
public enum BuiltInTemplates {

  /// All built-in template categories.
  public static let all: [TemplateCategory] = [
    fileOperations, git, textProcessing,
    devTools, macOSSpecific, network, system, packages,
    compression, cloud, media, shellScripting, crypto,
  ]

  // MARK: - File Operations

  public static let fileOperations = TemplateCategory(
    id: "file_ops",
    name: "File Operations",
    description: "File and directory manipulation: list, copy, move, delete, find, permissions, disk usage, rsync, diff, chown",
    templates: [
      CommandTemplate(
        id: "ls_files",
        intents: [
          "list files", "show files", "what files are here",
          "directory listing", "show directory contents", "ls",
          "what's in this folder", "list directory",
          "what is in this folder", "list my files",
          "show folder contents", "show what files",
          "files in directory", "whats in this folder",
          "show hidden files", "show all files including hidden",
          "only directories", "show directories",
        ],
        command: "ls {LS_COLOR} -la {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: ".", extractPattern: #"(?:in|of|at)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "find_by_name",
        intents: [
          "find files named", "search for files", "locate files matching",
          "where are the files", "find all files named", "find file",
          "look for files called", "find files with name",
          "list all files named", "list files matching", "list files called",
          "show all files named", "find DS_Store files", "find dotfiles",
          "find hidden files named", "find files starting with dot",
          "where is the file", "locate file", "search for file named",
          "find a file called", "look for file named",
          "search for config files", "where is package.json",
          "find the nearest file", "find file by name",
        ],
        command: "find {PATH} -name '{PATTERN}' -type f",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
          "PATTERN": SlotDefinition(type: .glob, defaultValue: "*",
            extractPattern: #"(?:named|matching|called|for|all)\s+(\.\S+|\S+\.\S+|\*\.\w+)|list\s+(?:all\s+)?(\.\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "find_by_extension",
        intents: [
          "find swift files", "find all python files", "find json files",
          "list all typescript files", "show me the yaml files",
          "find files with extension", "find all .swift files",
          "find rust files", "find go files", "find markdown files",
        ],
        command: "find {PATH} -name '*.{EXT}' -type f",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
          // T1.8: added `-name '*.X'` literal form for CLI-style queries.
          "EXT": SlotDefinition(type: .fileExtension,
            extractPattern: #"(?:find|list|show)\s+(?:all\s+)?\.?(\w+)\s+files|files?\s+(?:with\s+)?\.(\w+)|-name\s+['"]?\*?\.(\w+)['"]?"#),
        ]
      ),
      CommandTemplate(
        id: "find_by_mtime",
        intents: [
          "find files modified today", "recently modified files",
          "files changed in the last week", "find files modified recently",
          "find recent files", "what files changed today",
          "show recently edited files",
          "find files modified yesterday", "files changed recently",
          "which files were modified", "which file was modified most recently",
          "most recently changed files", "latest modified files",
          "which files did I change today", "files I edited today",
        ],
        command: "find {PATH} -type f -mtime -{DAYS}",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
          // Captures: N days | N weeks | N months | N years | today | yesterday |
          //           (past|last) (week|month|year) | (since) (weekday)
          // Sanitize converts unit words and weekdays to day counts. The
          // "N units ago" branch captures the FULL "N units" phrase
          // (not just N) so the unit multiplier is preserved.
          "DAYS": SlotDefinition(type: .relativeDays, defaultValue: "1",
            extractPattern: #"(?:last|past)\s+(\d+\s+days?|\d+\s+weeks?|\d+\s+months?|\d+\s+years?|week|month|year)|(?:since|from)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)|(?:from\s+|since\s+)?(\d+\s+(?:days?|weeks?|months?|years?))\s+ago|(yesterday|today)"#),
        ],
        negativeKeywords: ["who", "blame", "author", "wrote"]
      ),
      CommandTemplate(
        id: "find_by_mmin",
        intents: [
          "files changed in the last hour", "modified in the last 30 minutes",
          "files modified within the last hour", "changes in the last hour",
          "modified in the past hour", "what changed in the last hour",
          "files from the last hour", "files edited in the last hour",
          "modified less than an hour ago", "changed in the past 15 minutes",
          "files modified in the last 10 minutes", "recently modified minutes ago",
        ],
        command: "find {PATH} -type f -mmin -{MINUTES}",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
          "MINUTES": SlotDefinition(type: .number, defaultValue: "60",
            extractPattern: #"(?:last|past)\s+(\d+)\s+minutes?"#),
        ],
        negativeKeywords: ["git", "commit", "branch", "who", "blame", "author", "wrote",
                           "days", "day", "week", "weeks", "month", "yesterday"],
        discriminators: ["hour", "minutes", "minute", "mmin"]
      ),
      CommandTemplate(
        id: "find_by_mmin_hours",
        intents: [
          "files changed in the last 2 hours", "modified in the past 3 hours",
          "files from the last few hours", "changed within hours",
          "files modified in last hours", "edited in the last 4 hours",
          "things changed in the past 6 hours", "files from past hours",
        ],
        command: "find {PATH} -type f -mmin -$(({HOURS} * 60))",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
          "HOURS": SlotDefinition(type: .number, defaultValue: "2",
            extractPattern: #"(?:last|past)\s+(\d+)\s+hours?"#),
        ],
        negativeKeywords: ["git", "commit", "branch", "who", "blame", "author", "wrote",
                           "days", "day", "week", "weeks", "month", "yesterday", "minutes", "minute"],
        discriminators: ["hours"]
      ),
      CommandTemplate(
        id: "find_large_files",
        intents: [
          "find large files", "find biggest files", "find files larger than",
          "show big files", "what are the largest files",
          "find files over 1mb", "find huge files",
        ],
        command: "find {PATH} -type f -size +{SIZE} | head -20",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
          "SIZE": SlotDefinition(type: .fileSize, defaultValue: "1M",
            extractPattern: #"(?:larger|bigger|over|above)\s+(?:than\s+)?(\d+[kKmMgGtT]?[bB]?)"#),
        ]
      ),
      CommandTemplate(
        id: "find_size_range",
        intents: [
          // Narrow: require "between" + size unit to minimize BM25 overlap
          // with find_large_files on single-bound queries.
          "files between sizes",
          "files between 10mb and 100mb",
          "size bounded files between",
        ],
        command: "find {PATH} -type f -size +{MIN_SIZE} -size -{MAX_SIZE}",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
          "MIN_SIZE": SlotDefinition(type: .string, defaultValue: "1M",
            extractPattern: #"between\s+(\d+[kKmMgG]?[bB]?)\s+and\s+\d+[kKmMgG]?[bB]?"#),
          "MAX_SIZE": SlotDefinition(type: .string, defaultValue: "100M",
            extractPattern: #"between\s+\d+[kKmMgG]?[bB]?\s+and\s+(\d+[kKmMgG]?[bB]?)"#),
        ],
        negativeKeywords: ["larger than", "bigger than", "over", "huge"]
      ),
      CommandTemplate(
        // T2.3: time-range counterpart to find_size_range.
        // 'between Monday and Friday', 'from yesterday to today', 'between 2026-01-01 and 2026-04-23'.
        // Uses BSD/GNU find -newermt which accepts loose date strings.
        // INTENT TIGHT: every intent contains "between"+pair to minimize
        // BM25 token spread (F2). Generic "files modified" must not match
        // here — that's find_by_mtime's territory.
        id: "find_mtime_range",
        intents: [
          "between monday and friday files",
          "between two dates modified files",
          "between yesterday and today files",
          "between iso dates files",
        ],
        command: "find {PATH} -type f -newermt '{START}' ! -newermt '{END}'",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
          "START": SlotDefinition(type: .string, defaultValue: "yesterday",
            extractPattern: #"(?:between|from)\s+([a-zA-Z0-9-]+(?:\s+[a-zA-Z0-9-]+)?)\s+(?:and|to)\s+[a-zA-Z0-9-]+"#),
          "END": SlotDefinition(type: .string, defaultValue: "today",
            extractPattern: #"(?:between|from)\s+[a-zA-Z0-9-]+(?:\s+[a-zA-Z0-9-]+)?\s+(?:and|to)\s+([a-zA-Z0-9-]+(?:\s+[a-zA-Z0-9-]+)?)"#),
        ],
        negativeKeywords: ["size", "mb", "gb", "kb", "larger", "smaller", "past", "month", "ago"]
      ),
      CommandTemplate(
        id: "cp_file",
        intents: [
          "copy file", "copy files", "duplicate file",
          "make a copy of", "cp", "copy from to",
          "backup file", "create backup", "back up file",
          "save a copy of", "backup my config",
        ],
        // T2.1: SOURCE may be multiple files joined with " and "/", ".
        // SlotDefinition.multi+regex captures each capture group as a
        // separate match and joins with space. cp accepts `cp a b dst/`.
        command: "cp {FLAGS} {SOURCE} {DEST}",
        slots: [
          // T2.1: .commandFlag type with empty entity-fallback prevents
          // a filename from binding to FLAGS (was emitting
          // `cp main.swift main.swift dst/`).
          "FLAGS": SlotDefinition(type: .commandFlag, defaultValue: "",
            extractPattern: #"\s(-[a-zA-Z]+|--[a-z]+)\b"#),
          "SOURCE": SlotDefinition(type: .path,
            extractPattern: #"(?:copy|cp)\s+(\S+\.\S+)|\b(\S+\.\S+)\s+(?:and|,)\s+\S+\.\S+|(?:and|,)\s+(\S+\.\S+)"#,
            multi: true),
          "DEST": SlotDefinition(type: .path, extractPattern: #"(?:to|into)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "mv_file",
        intents: [
          "move file", "rename file", "mv", "move files",
          "rename files", "move from to",
          "put file in", "transfer file to", "move to folder",
          "relocate file", "relocate to",
        ],
        command: "mv {SOURCE} {DEST}",
        slots: [
          // T2.1: same multi-source pattern as cp_file. D.5: added 'mv' to
          // the verb alternation (was matching only 'move'/'rename'; bare
          // 'mv FILE to DEST' fell through to entity matching which bound
          // DEST as SOURCE).
          "SOURCE": SlotDefinition(type: .path,
            extractPattern: #"(?:move|rename|mv)\s+(\S+\.\S+)|\b(\S+\.\S+)\s+(?:and|,)\s+\S+\.\S+|(?:and|,)\s+(\S+\.\S+)"#,
            multi: true),
          "DEST": SlotDefinition(type: .path, extractPattern: #"(?:to|into|as)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "rm_file",
        intents: [
          "delete file", "remove file", "rm", "delete files",
          "remove files", "trash file", "delete this", "erase file",
          "get rid of file", "trash files", "delete the file",
          "nuke file", "erase", "wipe file", "clean up files",
        ],
        command: "rm {FLAGS} {PATH}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
          "PATH": SlotDefinition(type: .path, extractPattern: #"(?:delete|remove|trash)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "mkdir_dir",
        intents: [
          "create directory", "make directory", "mkdir",
          "create folder", "new directory", "new folder",
        ],
        command: "mkdir -p {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path, extractPattern: #"(?:directory|folder|mkdir)\s+(\S+)|create\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "chmod_perms",
        intents: [
          "change permissions", "chmod", "make executable",
          "set file permissions", "make file executable",
          "give write access", "make read only", "set permissions",
          "restrict access", "lock down file", "make writable",
          "read only mode", "remove write permission",
        ],
        command: "chmod {MODE} {PATH}",
        slots: [
          "MODE": SlotDefinition(type: .string, defaultValue: "+x",
            extractPattern: #"(?:chmod|permissions?)\s+(\d{3}|[+\-][rwx]+)"#),
          "PATH": SlotDefinition(type: .path, extractPattern: #"(?:on|for|of)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "du_disk_usage",
        intents: [
          "disk usage", "directory size", "folder size",
          "how much space", "du", "show disk usage",
          "what's using space", "size of directory",
          "how big is this directory", "how big is this folder",
          "how large is this directory", "directory disk usage",
          "size of this folder", "folder disk usage",
          "disk usage of directory", "how much space does this use",
          "space used by directory",
        ],
        command: "du -sh {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "*",
            extractPattern: #"(?:of|for|in)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "file_count",
        intents: [
          "count files", "how many files", "number of files",
          "count files in directory", "how many swift files",
        ],
        command: "find {PATH} -type f -name '{PATTERN}' | wc -l",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
          "PATTERN": SlotDefinition(type: .glob, defaultValue: "*"),
        ],
        negativeKeywords: ["lines", "words", "characters", "bytes"]
      ),
      CommandTemplate(
        id: "tree_view",
        intents: [
          "show directory tree", "tree", "show folder structure",
          "directory structure", "show file tree", "project structure",
        ],
        command: "find {PATH} -type d -maxdepth {DEPTH} | sort",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
          "DEPTH": SlotDefinition(type: .number, defaultValue: "3",
            extractPattern: #"(\d+)\s+level"#),
        ]
      ),
      CommandTemplate(
        id: "file_info",
        intents: [
          "file info", "file type", "what type of file",
          "file details", "stat file", "file metadata",
        ],
        command: "file {PATH} && stat {STAT_SIZE} {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path, extractPattern: #"(?:of|about|for)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "touch_file",
        intents: [
          "create empty file", "touch file", "create file",
          "make new file", "touch",
        ],
        command: "touch {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path, extractPattern: #"(?:file|touch|create)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "symlink",
        intents: [
          "create symlink", "symbolic link", "make link",
          "create link to", "ln -s", "softlink",
        ],
        command: "ln -s {SOURCE} {DEST}",
        slots: [
          "SOURCE": SlotDefinition(type: .path, extractPattern: #"(?:link|symlink)\s+(?:to\s+)?(\S+)"#),
          "DEST": SlotDefinition(type: .path, extractPattern: #"(?:as|at|named)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "find_and_delete",
        intents: [
          "find and delete", "remove all folders named",
          "delete all node_modules", "remove all DS_Store files",
          "recursively remove", "find and remove",
          "delete folders matching", "remove directories named",
        ],
        command: "find {PATH} -name '{PATTERN}' -type d -exec rm -rf {} +",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
          "PATTERN": SlotDefinition(type: .glob,
            extractPattern: #"(?:named|all|remove|delete)\s+(\S+)"#),
        ],
        negativeKeywords: ["find", "list", "show", "search", "locate", "where"]
      ),
      CommandTemplate(
        id: "find_images",
        intents: [
          "find images", "find all images", "find photos",
          "find pictures", "find jpg files", "find png files",
          "list all images", "find image files",
          "find all photos in folder",
        ],
        command: "find {PATH} -type f \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' -o -name '*.webp' -o -name '*.svg' \\)",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
        ],
        negativeKeywords: ["todo", "fixme", "reference", "comment", "variable", "function",
                           "class", "import", "error", "warning", "string", "pattern",
                           "word", "text", "code", "occurrences", "grep"]
      ),
      CommandTemplate(
        id: "chmod_executable",
        intents: [
          "make executable", "chmod +x", "add execute permission",
          "make file executable", "set executable",
          "add executable permission", "mark as executable",
          "make runnable", "make script runnable",
          "make this script executable", "allow execution",
          "set execute bit", "give execute rights",
          "make it executable", "add run permission",
        ],
        command: "chmod +x {FILE}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:permission|executable|chmod)\s+(?:to\s+)?(\S+\.\S+)"#),
        ],
        negativeKeywords: ["lambda", "invoke", "aws", "function"]
      ),
      CommandTemplate(
        id: "rsync_copy",
        intents: [
          "rsync", "rsync files", "sync files with rsync",
          "rsync copy", "mirror directory", "rsync directory",
          "synchronize folders", "rsync to remote",
        ],
        command: "rsync -avz {SOURCE} {DEST}",
        slots: [
          "SOURCE": SlotDefinition(type: .path,
            extractPattern: #"(?:rsync|sync|mirror)\s+(\S+)"#),
          "DEST": SlotDefinition(type: .path,
            extractPattern: #"(?:to|into)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "diff_files",
        intents: [
          "diff files", "compare files", "diff two files",
          "file difference", "compare two files",
          "what's different between files",
        ],
        command: "diff {FLAGS} {FILE1} {FILE2}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: "-u"),
          "FILE1": SlotDefinition(type: .path,
            extractPattern: #"(?:diff|compare)\s+(\S+)"#),
          "FILE2": SlotDefinition(type: .path,
            extractPattern: #"(?:and|with|to)\s+(\S+)"#),
        ],
        negativeKeywords: ["git", "staged", "branch", "commit"]
      ),
      CommandTemplate(
        id: "chown_owner",
        intents: [
          "change owner", "chown", "change file ownership",
          "set file owner", "change ownership",
          "who owns this file", "file owner", "who owns file",
          "change owner of file", "transfer ownership",
        ],
        command: "chown {FLAGS} {OWNER} {PATH}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
          "OWNER": SlotDefinition(type: .string,
            extractPattern: #"(?:chown|owner)\s+(\S+)"#),
          "PATH": SlotDefinition(type: .path,
            extractPattern: #"(?:of|on|for)\s+(\S+)"#),
        ]
      ),
    ]
  )

  // MARK: - Git

  public static let git = TemplateCategory(
    id: "git",
    name: "Git",
    description: "Git version control: status, diff, log, commit, branch, merge, rebase, stash, remote, tag, clone, fetch, reset",
    templates: [
      CommandTemplate(
        id: "git_status",
        intents: [
          "git status", "show git status", "what changed",
          "show changes", "what files changed", "modified files",
          "uncommitted changes", "working tree status",
          "show me changes", "what has changed", "changes in git",
          "pending changes", "status of repo", "repo status",
        ],
        command: "git status"
      ),
      CommandTemplate(
        id: "git_diff",
        intents: [
          "git diff", "show diff", "what's different",
          "show changes in detail", "compare changes",
          "show modifications", "view diff",
          "what changed", "what has changed since last commit",
          "show me the changes", "diff since last commit",
          "what did I change", "show code changes",
          "view the differences", "show me the diff",
        ],
        command: "git diff {FLAGS} {PATH}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
          "PATH": SlotDefinition(type: .path, defaultValue: "",
            extractPattern: #"(?:diff|changes?\s+(?:in|of|for))\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "git_diff_staged",
        intents: [
          "staged changes", "show staged diff", "what's staged",
          "git diff staged", "cached changes", "show what will be committed",
        ],
        command: "git diff --cached"
      ),
      CommandTemplate(
        id: "git_log",
        intents: [
          "git log", "show commit history", "recent commits",
          "commit log", "what was committed", "show history",
          "last commits", "git history", "show log",
          "view commits", "history of commits", "commit history",
          "show git log", "log of changes",
          "git log with file changes", "git log with diffs",
          "show what files changed in each commit",
          "commit log with stats", "log with patches",
        ],
        command: "git log --oneline -n {COUNT}",
        slots: [
          "COUNT": SlotDefinition(type: .number, defaultValue: "20",
            extractPattern: #"(?:last|recent|past)\s+(\d+)"#),
        ]
      ),
      CommandTemplate(
        id: "git_log_graph",
        intents: [
          "git log graph", "branch graph", "show branch tree",
          "visual git log", "git graph", "show branch history",
        ],
        command: "git log --oneline --graph --all -n {COUNT}",
        slots: [
          "COUNT": SlotDefinition(type: .number, defaultValue: "30"),
        ]
      ),
      CommandTemplate(
        id: "git_log_range",
        intents: [
          // Narrow: require "between" explicitly. "git log between" was
          // colliding with "git log --oneline -n 10" via shared tokens.
          "commits between two refs",
          "range between commits",
          "commits between revisions",
        ],
        command: "git log --oneline {FROM}..{TO}",
        slots: [
          "FROM": SlotDefinition(type: .string, defaultValue: "HEAD~10",
            extractPattern: #"between\s+(\S+)\s+and\s+\S+"#),
          "TO": SlotDefinition(type: .string, defaultValue: "HEAD",
            extractPattern: #"between\s+\S+\s+and\s+(\S+)"#),
        ],
        negativeKeywords: ["tag", "display", "status", "--oneline", "-n"]
      ),
      CommandTemplate(
        // T2.3: time-range counterpart to git_log_range. git log accepts
        // --since=DATE --until=DATE with loose date strings.
        // 'commits between yesterday and today', 'commits from monday to friday'.
        id: "git_log_date_range",
        intents: [
          // D.2: ALL intents start with "commits between" — anchors the
          // template-specific phrase. Phrase-match index should boost
          // these above git_log_since for the "between" form.
          "commits between two dates",
          "commits between yesterday and today",
          "commits between today and yesterday",
          "commits between monday and friday",
          "commits between today and tomorrow",
          "commits between two days",
          "commits between dates",
          "commits between iso dates",
        ],
        command: "git log --oneline --since='{START}' --until='{END}'",
        slots: [
          "START": SlotDefinition(type: .string, defaultValue: "yesterday",
            extractPattern: #"(?:between|from)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|yesterday|today|\d{4}-\d{2}-\d{2})\s+(?:and|to)"#),
          "END": SlotDefinition(type: .string, defaultValue: "today",
            extractPattern: #"(?:and|to)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|yesterday|today|\d{4}-\d{2}-\d{2})\s*$"#),
        ],
        negativeKeywords: ["v1", "v2", "v3", "tag", "release", "ref", "most", "recent", "latest"],
        discriminators: ["between"]                                       // D.2 — phrase anchor
      ),
      CommandTemplate(
        id: "git_log_no_merges",
        intents: [
          // Narrow: "merges" / "no-merges" as the anchor, not generic "commits".
          "commits without merges",
          "git log no merges",
          "git log without merge commits",
          "non-merge commits",
        ],
        command: "git log --oneline --no-merges -n {COUNT}",
        slots: [
          "COUNT": SlotDefinition(type: .number, defaultValue: "20",
            extractPattern: #"(?:last|recent|past)\s+(\d+)"#),
        ],
        negativeKeywords: ["origin", "branch", "tag", "display"]
      ),
      CommandTemplate(
        id: "git_add",
        intents: [
          "stage files", "git add", "add files to staging",
          "stage changes", "add to git", "stage all changes",
        ],
        command: "git add {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:add|stage)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "git_commit",
        intents: [
          "commit changes", "git commit", "make a commit",
          "commit with message", "save changes to git",
        ],
        command: "git commit -m '{MESSAGE}'",
        slots: [
          "MESSAGE": SlotDefinition(type: .string,
            extractPattern: #"(?:message|msg)\s+['\"]?(.+?)['\"]?$"#),
        ]
      ),
      CommandTemplate(
        id: "git_branch_list",
        intents: [
          "list branches", "show branches", "git branch",
          "what branches exist", "all branches",
          "show git branches", "git branch list",
          "list git branches", "available branches",
          "which branches", "see branches",
        ],
        command: "git branch -a"
      ),
      CommandTemplate(
        id: "git_branch_create",
        intents: [
          "create branch", "new branch", "git checkout -b",
          "make a new branch", "branch off",
        ],
        command: "git checkout -b {BRANCH}",
        slots: [
          "BRANCH": SlotDefinition(type: .branch,
            extractPattern: #"(?:branch|checkout\s+-b)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "git_switch",
        intents: [
          "switch branch", "checkout branch", "change branch",
          "go to branch", "git switch", "git checkout",
          "check out branch", "switch to branch",
          "change to branch", "move to branch",
          "go to the branch", "hop to branch",
          "checkout the branch", "check out the branch",
        ],
        command: "git switch {BRANCH}",
        slots: [
          "BRANCH": SlotDefinition(type: .branch,
            extractPattern: #"(?:switch|checkout|to)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "git_stash",
        intents: [
          "stash changes", "git stash", "save work temporarily",
          "stash current changes", "put aside changes",
          "stash my work", "git stash save", "shelve changes",
          "stash everything",
        ],
        command: "git stash"
      ),
      CommandTemplate(
        id: "git_stash_pop",
        intents: [
          "pop stash", "restore stash", "git stash pop",
          "apply stash", "get back stashed changes",
        ],
        command: "git stash pop"
      ),
      CommandTemplate(
        id: "git_merge",
        intents: [
          "merge branch", "git merge", "merge into current branch",
          "combine branches", "merge from",
        ],
        command: "git merge {BRANCH}",
        slots: [
          "BRANCH": SlotDefinition(type: .branch,
            extractPattern: #"(?:merge)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "git_rebase",
        intents: [
          "rebase on", "git rebase", "rebase branch",
          "rebase onto main", "rebase onto master",
        ],
        command: "git rebase {BRANCH}",
        slots: [
          "BRANCH": SlotDefinition(type: .branch, defaultValue: "main",
            extractPattern: #"(?:rebase\s+(?:on(?:to)?|from))\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "git_remote",
        intents: [
          "show remotes", "git remote", "list remotes",
          "what remote", "remote url", "origin url",
        ],
        command: "git remote -v"
      ),
      CommandTemplate(
        id: "git_pull",
        intents: [
          "pull changes", "git pull", "update from remote",
          "fetch and merge", "pull latest",
        ],
        command: "git pull"
      ),
      CommandTemplate(
        id: "git_push",
        intents: [
          "push changes", "git push", "push to remote",
          "push commits", "upload to remote",
          "ship code", "ship to origin", "deploy to remote",
        ],
        command: "git push"
      ),
      CommandTemplate(
        // Compound: commit-then-push. Deterministic (no planner) — pure
        // phrase match on "commit and push" pattern. MESSAGE defaults to
        // "wip" which is a common placeholder; user can override via
        // explicit message in the query.
        id: "git_commit_push",
        intents: [
          "commit and push", "commit then push", "git commit and push",
          "commit changes and push", "add commit push", "stage commit push",
        ],
        command: "git commit -m \"{MESSAGE}\" && git push",
        slots: [
          "MESSAGE": SlotDefinition(type: .string, defaultValue: "wip",
            extractPattern: #"(?:with\s+message|message|-m)\s+['\"]?(.+?)['\"]?(?:$|\s+and)"#),
        ],
        negativeKeywords: ["pull"]
      ),
      CommandTemplate(
        id: "git_blame",
        intents: [
          "git blame", "who changed this", "blame file",
          "who wrote this", "show line authors",
          "who changed file", "who modified this file",
          "who edited this", "annotate file", "git annotate",
          "who changed", "who last modified", "who touched this file",
          "blame", "who authored these lines",
        ],
        command: "git blame {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path,
            extractPattern: #"(?:blame|who\s+(?:changed|wrote))\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "git_cherry_pick",
        intents: [
          "cherry pick", "git cherry-pick", "pick commit",
          "apply specific commit",
        ],
        command: "git cherry-pick {COMMIT}",
        slots: [
          "COMMIT": SlotDefinition(type: .string,
            extractPattern: #"(?:cherry[- ]?pick|pick|commit)\s+([a-f0-9]{6,40})"#),
        ]
      ),
      CommandTemplate(
        id: "git_tag",
        intents: [
          "create tag", "git tag", "tag release",
          "add tag", "tag version",
        ],
        command: "git tag {TAG}",
        slots: [
          "TAG": SlotDefinition(type: .string,
            extractPattern: #"(?:tag)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "git_clone",
        intents: [
          "git clone", "clone repository", "clone repo",
          "clone from github", "download repository",
          "clone git repo", "git clone url",
        ],
        command: "git clone {URL} {DIR}",
        slots: [
          "URL": SlotDefinition(type: .url,
            extractPattern: #"((?:https?://|git@)\S+)"#),
          "DIR": SlotDefinition(type: .path, defaultValue: "",
            extractPattern: #"(?:into|to)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "git_fetch",
        intents: [
          "git fetch", "fetch from remote", "fetch upstream",
          "fetch origin", "fetch all remotes",
          "fetch without merging",
        ],
        command: "git fetch {REMOTE} {FLAGS}",
        slots: [
          "REMOTE": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:fetch)\s+(\S+)"#),
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        negativeKeywords: ["url", "http", "https", "curl", "download", "api"]
      ),
      CommandTemplate(
        id: "git_reset",
        intents: [
          "git reset", "reset to commit", "unstage files",
          "undo last commit", "reset head",
          "git reset hard", "discard commits",
          "roll back to previous commit", "roll back commit",
          "go back to previous commit", "undo commits",
          "reset to previous state", "rewind commits",
          "go back one commit", "step back a commit",
        ],
        command: "git reset {FLAGS} {REF}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(--hard|--soft|--mixed)"#),
          "REF": SlotDefinition(type: .string, defaultValue: "HEAD",
            extractPattern: #"(?:to|reset)\s+([a-f0-9]{6,40}|HEAD~?\d*)"#),
        ]
      ),
      CommandTemplate(
        id: "git_restore",
        intents: [
          "git restore", "discard changes", "undo changes",
          "undo all changes", "undo uncommitted changes",
          "discard all modifications", "restore working tree",
          "revert uncommitted changes", "checkout all files",
          "throw away changes", "reset my changes",
          "get rid of changes", "drop all modifications",
          "clean working directory", "undo local changes",
          "discard local modifications", "restore files to last commit",
        ],
        command: "git restore {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:restore|discard|undo)\s+(?:changes\s+(?:in|to)\s+)?(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "git_revert",
        intents: [
          "git revert", "revert commit", "revert last commit",
          "revert the last merge", "undo a commit",
          "reverse a commit", "revert last change",
        ],
        command: "git revert {COMMIT}",
        slots: [
          "COMMIT": SlotDefinition(type: .string, defaultValue: "HEAD",
            extractPattern: #"(?:revert|undo)\s+(?:the\s+)?(?:last\s+)?(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "git_squash",
        intents: [
          "squash commits", "squash last commits",
          "git squash", "combine commits", "squash my commits",
          "interactive rebase", "git rebase interactive",
        ],
        command: "git rebase -i HEAD~{COUNT}",
        slots: [
          "COUNT": SlotDefinition(type: .number, defaultValue: "3",
            extractPattern: #"(?:last|squash)\s+(\d+)"#),
        ]
      ),
      CommandTemplate(
        id: "git_log_since",
        intents: [
          "commits since yesterday", "git log since",
          "show what I committed yesterday", "recent commits today",
          "commits from today", "what did I commit",
          "show yesterday's commits", "my commits today",
        ],
        command: "git log --oneline --since='{SINCE}' --author=\"$(git config user.name)\"",
        slots: [
          // T1.1: tightened to match only known time anchors. Previously
          // captured `\S*` which on "show today's commits" pulled the
          // apostrophe-fragment "'s" → broken shell quoting. Now matches
          // an explicit time word OR falls back to defaultValue.
          "SINCE": SlotDefinition(type: .string, defaultValue: "yesterday",
            extractPattern: #"(?:since\s+|from\s+)?(yesterday|today|last\s+\w+|this\s+\w+|\d+\s+\w+\s+ago)"#),
        ]
      ),
      CommandTemplate(
        id: "git_tag_sorted",
        intents: [
          "list tags", "show all tags", "git tags sorted",
          "tags sorted by date", "show tags by date",
          "latest tags", "all git tags",
        ],
        command: "git tag --sort=-creatordate"
      ),
      CommandTemplate(
        id: "gh_pr_create",
        intents: [
          "create pull request", "open pull request",
          "create pr", "gh pr create", "new pull request",
          "open a pr", "submit pull request",
          "make a pull request", "create github pr",
        ],
        command: "gh pr create --title '{TITLE}' --body '{BODY}'",
        slots: [
          "TITLE": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:title|titled)\s+['\"]?(.+?)['\"]?$"#),
          "BODY": SlotDefinition(type: .string, defaultValue: ""),
        ]
      ),
    ]
  )

  // MARK: - Text Processing

  public static let textProcessing = TemplateCategory(
    id: "text_processing",
    name: "Text Processing",
    description: "Search, filter, transform text: grep, sed, awk, sort, uniq, wc, cut, tr, jq, head, tail, pipes",
    templates: [
      CommandTemplate(
        id: "grep_search",
        intents: [
          "search for text", "grep", "find text in files",
          "search files for pattern", "search for string",
          "find occurrences of", "search code for",
          "look for text", "find in files",
          "recursively search for", "search recursively",
          "search for word", "search entire project",
          "find files containing", "extract lines matching",
          "extract pattern from", "pull lines matching",
          "find lines with", "files containing word",
          "find references to", "find all occurrences",
          "find TODO comments", "find FIXME comments",
          "find all references", "find where used",
          "search for TODO", "search for FIXME",
        ],
        command: "grep -rn '{PATTERN}' {PATH}",
        slots: [
          "PATTERN": SlotDefinition(type: .pattern,
            extractPattern: #"(?:containing|for|of|matching)\s+(?:the\s+)?(?:word\s+)?['\"]?(\S+)['\"]?|(?:search|grep)\s+['\"]?(\S+)['\"]?"#),
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:in|within|under)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "grep_count",
        intents: [
          "count occurrences", "how many times", "count matches",
          "grep count", "how many occurrences",
        ],
        command: "grep -rc '{PATTERN}' {PATH}",
        slots: [
          "PATTERN": SlotDefinition(type: .pattern,
            extractPattern: #"(?:of|for)\s+['\"]?(\S+)['\"]?"#),
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
        ],
        discriminators: ["count", "many", "number", "occurrences", "times"]
      ),
      CommandTemplate(
        id: "rg_search",
        intents: [
          "ripgrep", "rg search", "fast search",
          "search with ripgrep", "rg",
        ],
        command: "rg '{PATTERN}' {PATH}",
        slots: [
          "PATTERN": SlotDefinition(type: .pattern,
            extractPattern: #"(?:rg|search|for)\s+['\"]?(\S+)['\"]?"#),
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
        ],
        negativeKeywords: ["brew", "homebrew", "install", "package"]
      ),
      CommandTemplate(
        id: "sed_replace",
        intents: [
          "replace text", "find and replace", "substitute",
          "sed replace", "change text", "replace string",
          "replace in file", "find replace",
        ],
        command: "{SED} {SED_INPLACE} 's/{FIND}/{REPLACE}/g' {FILE}",
        slots: [
          "FIND": SlotDefinition(type: .string,
            extractPattern: #"(?:replace|change|substitute)\s+['\"]?(\S+)['\"]?"#),
          "REPLACE": SlotDefinition(type: .string,
            extractPattern: #"(?:with|to|for)\s+['\"]?(\S+)['\"]?"#),
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:in|of)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "sed_delete_lines",
        intents: [
          "delete lines matching", "remove lines containing",
          "sed delete", "strip lines with",
          "remove blank lines", "delete empty lines",
          "strip blank lines", "remove lines with pattern",
          "delete lines with", "filter out lines matching",
          "remove lines from file", "clean blank lines",
        ],
        command: "{SED} {SED_INPLACE} '/{PATTERN}/d' {FILE}",
        slots: [
          "PATTERN": SlotDefinition(type: .pattern,
            extractPattern: #"(?:matching|containing|with)\s+['\"]?(\S+)['\"]?"#),
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:in|from)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "awk_column",
        intents: [
          "extract column", "get column", "awk column",
          "print field", "extract field", "get nth column",
        ],
        command: "awk '{print ${COL}}' {FILE}",
        slots: [
          "COL": SlotDefinition(type: .number, defaultValue: "1",
            extractPattern: #"(?:column|field|col)\s+(\d+)"#),
          // Widened to also catch "the X file" / "X.csv" / "X.tsv" / "X.log"
          // patterns common in "process the csv file"-style queries.
          // T1.6: defaultValue empty (was the literal "{FILE}" placeholder
          // which leaked into output). awk reads stdin when no file is
          // given — the cleaner UX.
          "FILE": SlotDefinition(type: .path, defaultValue: "",
            extractPattern: #"(?:from|in|of)\s+(\S+)|the\s+(\S+\.(?:csv|tsv|txt|log|out))|(\S+\.(?:csv|tsv|txt|log|out))"#),
        ]
      ),
      CommandTemplate(
        id: "sort_file",
        intents: [
          "sort file", "sort lines", "sort output",
          "sort alphabetically", "sort numerically",
        ],
        command: "sort {FLAGS} {FILE}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"sort\s+(-[a-z]+)"#),
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:sort)\s+(?:-\w+\s+)?(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "sort_unique",
        intents: [
          "unique lines", "remove duplicates", "deduplicate",
          "sort unique", "uniq", "distinct lines",
        ],
        command: "sort {FILE} | uniq",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:in|from|of)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "wc_count",
        intents: [
          "count lines", "line count", "word count",
          "how many lines", "wc", "count words",
          "number of lines", "how many lines in file",
          "count lines in", "lines in file", "character count",
        ],
        command: "wc -{MODE} {FILE}",
        slots: [
          "MODE": SlotDefinition(type: .string, defaultValue: "l",
            extractPattern: #"(?:count|number of)\s+(lines?|words?|chars?|bytes?)"#),
          "FILE": SlotDefinition(type: .path, defaultValue: "",
            extractPattern: #"(?:in|of)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "head_file",
        intents: [
          "first lines", "head", "show top of file",
          "beginning of file", "first n lines",
          "preview file", "top of file",
        ],
        command: "head -n {COUNT} {FILE}",
        slots: [
          "COUNT": SlotDefinition(type: .number, defaultValue: "10",
            extractPattern: #"(?:first|top)\s+(\d+)"#),
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:of|from|in)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "tail_file",
        intents: [
          "last lines", "tail", "end of file",
          "bottom of file", "last n lines",
          "show end of file", "tail of file",
        ],
        command: "tail -n {COUNT} {FILE}",
        slots: [
          "COUNT": SlotDefinition(type: .number, defaultValue: "10",
            extractPattern: #"(?:last|bottom)\s+(\d+)"#),
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:of|from|in)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "tail_follow",
        intents: [
          "follow log", "tail -f", "watch log file",
          "stream log", "follow file changes",
          "live log", "monitor log",
        ],
        command: "tail -f {FILE}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:follow|watch|stream|monitor)\s+(\S+)"#),
        ],
        negativeKeywords: ["remove", "delete", "old", "clean"],
        discriminators: ["follow", "-f", "stream", "monitor", "live", "watch", "real"]
      ),
      CommandTemplate(
        id: "cut_columns",
        intents: [
          "cut columns", "extract columns", "split by delimiter",
          "cut field", "csv column",
        ],
        command: "cut -d'{DELIM}' -f{FIELD} {FILE}",
        slots: [
          "DELIM": SlotDefinition(type: .string, defaultValue: ",",
            extractPattern: #"(?:delimiter|delim|by)\s+['\"]?(.)['\"]?"#),
          "FIELD": SlotDefinition(type: .number, defaultValue: "1",
            extractPattern: #"(?:field|column)\s+(\d+)"#),
          "FILE": SlotDefinition(type: .path),
        ]
      ),
      CommandTemplate(
        id: "tr_replace",
        intents: [
          "translate characters", "tr replace", "convert case",
          "lowercase", "uppercase", "to lowercase", "to uppercase",
        ],
        command: "tr '{FROM}' '{TO}'",
        slots: [
          "FROM": SlotDefinition(type: .string, defaultValue: "[:upper:]",
            extractPattern: #"(?:from|replace)\s+['\"]?(\S+)['\"]?"#),
          "TO": SlotDefinition(type: .string, defaultValue: "[:lower:]",
            extractPattern: #"(?:to|with)\s+['\"]?(\S+)['\"]?"#),
        ]
      ),
      CommandTemplate(
        id: "jq_parse",
        intents: [
          "parse json", "jq", "extract from json",
          "query json", "json field", "read json",
          "pretty print json", "format json",
        ],
        command: "jq '{QUERY}' {FILE}",
        slots: [
          "QUERY": SlotDefinition(type: .string, defaultValue: ".",
            extractPattern: #"(?:jq|query|field|extract)\s+['\"]?(\S+)['\"]?"#),
          "FILE": SlotDefinition(type: .path, defaultValue: "",
            extractPattern: #"(?:from|in)\s+(\S+)|the\s+(\S+\.json)|(\S+\.json)"#),
        ],
        negativeKeywords: ["install", "brew", "package", "add", "dependency"]
      ),
      CommandTemplate(
        // T2.4: yq parses YAML the way jq parses JSON.
        // Narrow: must be "process the yaml file" / "yq …" / "parse yaml"
        // -- not generic yaml-mention queries (mv config.yml; find yaml files).
        id: "yq_parse",
        intents: [
          "parse yaml", "yq", "extract from yaml",
          "query yaml", "yaml field", "read yaml",
          "pretty print yaml", "format yaml",
        ],
        command: "yq '{QUERY}' {FILE}",
        slots: [
          "QUERY": SlotDefinition(type: .string, defaultValue: ".",
            extractPattern: #"(?:yq|query|field|extract)\s+['\"]?(\S+)['\"]?"#),
          "FILE": SlotDefinition(type: .path, defaultValue: "",
            extractPattern: #"(?:from|in)\s+(\S+)|the\s+(\S+\.(?:yaml|yml))|(\S+\.(?:yaml|yml))"#),
        ],
        negativeKeywords: [
          "install", "brew", "package", "add", "dependency",
          "find", "mv", "rename", "show", "replace", "substitute",
        ]
      ),
      CommandTemplate(
        id: "xargs_pipe",
        intents: [
          "xargs", "pipe to xargs", "parallel xargs",
          "apply command to each", "for each line run",
        ],
        command: "{PRODUCER} | xargs {FLAGS} {COMMAND}",
        slots: [
          "PRODUCER": SlotDefinition(type: .command),
          "FLAGS": SlotDefinition(type: .string, defaultValue: "-I{}"),
          "COMMAND": SlotDefinition(type: .command),
        ]
      ),
    ]
  )

  // MARK: - Dev Tools

  public static let devTools = TemplateCategory(
    id: "dev_tools",
    name: "Dev Tools",
    description: "Development toolchains: Swift build test run, cargo, go, node npm, python3, docker, docker compose, kubectl, make",
    templates: [
      CommandTemplate(
        id: "swift_build",
        intents: [
          "swift build", "build swift project", "compile swift",
          "build the project", "run swift build", "compile this package",
        ],
        command: "swift build {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ]
      ),
      CommandTemplate(
        id: "swift_build_release",
        intents: [
          "swift build release", "build release", "compile for release",
          "build optimized", "production build swift",
          "swift build -c release", "release build",
          "build for production", "production build",
          "compile for production", "optimized build",
          "build for deployment", "release mode build",
        ],
        command: "swift build -c release {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        discriminators: ["release", "optimized", "production"]
      ),
      CommandTemplate(
        id: "swift_test",
        intents: [
          "swift test", "run swift tests", "run tests",
          "test the project", "run unit tests", "execute tests",
        ],
        command: "swift test {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        negativeKeywords: ["mkdir", "fixtures", "directory", "folder", "create", "make"]
      ),
      CommandTemplate(
        // Compound: swift build && swift test. Ships a correct end-to-end
        // command for "build and test" queries; previously routed to
        // solo swift_test which skipped the build step.
        id: "swift_build_and_test",
        intents: [
          "build and test", "build and run tests", "compile and test",
          "build then test", "swift build and test",
        ],
        command: "swift build && swift test",
        negativeKeywords: ["go", "cargo", "npm", "python", "docker"]
      ),
      CommandTemplate(
        id: "swift_run",
        intents: [
          "swift run", "run swift executable", "run the tool",
          "execute swift binary", "run this package",
        ],
        command: "swift run {TARGET} {ARGS}",
        slots: [
          "TARGET": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:run)\s+(\S+)"#),
          "ARGS": SlotDefinition(type: .string, defaultValue: ""),
        ]
      ),
      CommandTemplate(
        id: "cargo_build",
        intents: [
          "cargo build", "build rust project", "compile rust",
          "rust build", "cargo compile",
        ],
        command: "cargo build {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ]
      ),
      CommandTemplate(
        id: "cargo_test",
        intents: [
          "cargo test", "run rust tests", "test rust project",
          "rust test", "cargo run tests",
        ],
        command: "cargo test {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        negativeKeywords: ["mkdir", "fixtures", "directory", "folder", "create"]
      ),
      CommandTemplate(
        id: "cargo_run",
        intents: [
          "cargo run", "run rust project", "execute rust binary",
          "rust run", "run rust program",
        ],
        command: "cargo run {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ]
      ),
      CommandTemplate(
        id: "go_build",
        intents: [
          "go build", "build go project", "compile go",
          "golang build", "build go binary",
        ],
        command: "go build {FLAGS} {PATH}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
          "PATH": SlotDefinition(type: .path, defaultValue: "./..."),
        ]
      ),
      CommandTemplate(
        id: "go_test",
        intents: [
          "go test", "run go tests", "test go project",
          "golang test", "run golang tests",
        ],
        command: "go test {FLAGS} {PATH}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
          "PATH": SlotDefinition(type: .path, defaultValue: "./..."),
        ],
        negativeKeywords: ["mkdir", "fixtures", "directory", "folder", "create"]
      ),
      CommandTemplate(
        id: "npm_run",
        intents: [
          "npm run", "run npm script", "npm start",
          "start node project", "run node script",
          "npm run dev", "start dev server",
        ],
        command: "npm run {SCRIPT}",
        slots: [
          "SCRIPT": SlotDefinition(type: .string, defaultValue: "start",
            extractPattern: #"(?:run|script)\s+(\S+)"#),
        ],
        negativeKeywords: ["install", "add", "dependency", "package"]
      ),
      CommandTemplate(
        id: "python_run",
        intents: [
          "run python", "python3 run", "execute python script",
          "run python script", "python3 script",
          "run py file", "execute python",
        ],
        command: "python3 {FILE} {ARGS}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:run|execute)\s+(\S+\.py)"#),
          "ARGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        negativeKeywords: ["which", "where", "locate", "path", "version", "install"]
      ),
      CommandTemplate(
        id: "docker_build",
        intents: [
          "docker build", "build docker image", "build container",
          "create docker image", "docker image build",
          "build Dockerfile",
        ],
        command: "docker build -t {TAG} {PATH}",
        slots: [
          "TAG": SlotDefinition(type: .string,
            extractPattern: #"(?:tag|named?|-t)\s+(\S+)"#),
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
        ],
        negativeKeywords: ["trash", "artifacts", "remove", "delete", "clean", "sweep"],
        discriminators: ["build", "dockerfile", "image"]
      ),
      CommandTemplate(
        id: "docker_run",
        intents: [
          "docker run", "run docker container", "start container",
          "run image", "docker start", "launch container",
        ],
        command: "docker run {FLAGS} {IMAGE} {CMD}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: "--rm -it"),
          "IMAGE": SlotDefinition(type: .string,
            extractPattern: #"(?:run|image|container)\s+(\S+)"#),
          "CMD": SlotDefinition(type: .command, defaultValue: ""),
        ]
      ),
      CommandTemplate(
        id: "docker_ps",
        intents: [
          "docker ps", "list containers", "running containers",
          "show docker containers", "what containers are running",
        ],
        command: "docker ps {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        negativeKeywords: ["process", "nginx", "apache", "node", "service", "pid", "kill"]
      ),
      CommandTemplate(
        id: "docker_exec",
        intents: [
          "docker exec", "exec into container", "shell into container",
          "enter container", "connect to container shell",
          "bash into container", "attach to container",
        ],
        command: "docker exec -it {CONTAINER} {SHELL}",
        slots: [
          "CONTAINER": SlotDefinition(type: .string,
            extractPattern: #"(?:exec|into|container)\s+(\S+)"#),
          "SHELL": SlotDefinition(type: .string, defaultValue: "/bin/sh"),
        ]
      ),
      CommandTemplate(
        id: "docker_volume_ls",
        intents: [
          "docker volume ls", "list docker volumes", "show docker volumes",
          "docker volumes", "what volumes exist",
        ],
        command: "docker volume ls"
      ),
      CommandTemplate(
        id: "docker_image_prune",
        intents: [
          "docker image prune", "remove unused docker images",
          "clean up docker images", "prune docker images",
          "delete unused images", "docker cleanup",
          "docker system prune",
        ],
        command: "docker image prune -a {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ]
      ),
      CommandTemplate(
        id: "docker_stop_all",
        intents: [
          "stop all containers", "stop all running containers",
          "docker stop all", "kill all containers",
        ],
        command: "docker stop $(docker ps -q)"
      ),
      CommandTemplate(
        id: "docker_logs",
        intents: [
          "docker logs", "show container logs", "container log output",
          "logs for container", "docker container logs",
          "show docker logs", "tail container logs",
        ],
        command: "docker logs {FLAGS} {CONTAINER}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: "--tail 100"),
          "CONTAINER": SlotDefinition(type: .string,
            extractPattern: #"(?:logs?|container|for)\s+(?:the\s+)?(\S+)"#),
        ],
        negativeKeywords: ["move", "relocate", "copy", "transfer", "put", "backup"]
      ),
      CommandTemplate(
        id: "python_http_server",
        intents: [
          "start a local http server", "python http server",
          "simple http server", "serve files locally",
          "start web server on port", "local file server",
        ],
        command: "python3 -m http.server {PORT}",
        slots: [
          "PORT": SlotDefinition(type: .port, defaultValue: "8000",
            extractPattern: #"(?:port)\s+(\d+)|(\d{4,5})"#),
        ],
        negativeKeywords: ["flask", "django", "node", "npm", "express"]
      ),
      CommandTemplate(
        id: "kubectl_get",
        intents: [
          "kubectl get pods", "list pods", "show kubernetes resources",
          "get k8s pods", "kubectl get", "show pods",
        ],
        command: "kubectl get {RESOURCE} {FLAGS}",
        slots: [
          "RESOURCE": SlotDefinition(type: .string, defaultValue: "pods",
            extractPattern: #"(?:get|list|show)\s+(\w+)"#),
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ]
      ),
      CommandTemplate(
        id: "docker_compose_up",
        intents: [
          "docker compose up", "start docker compose", "docker-compose up",
          "bring up compose services", "start compose stack",
          "run docker compose", "start all containers",
        ],
        command: "docker compose up {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: "-d"),
        ],
        discriminators: ["compose", "docker-compose", "services", "stack"]
      ),
      CommandTemplate(
        id: "docker_compose_down",
        intents: [
          "docker compose down", "stop docker compose", "docker-compose down",
          "tear down compose", "stop compose services",
          "stop all containers",
        ],
        command: "docker compose down {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        discriminators: ["compose", "docker-compose", "down"]
      ),
      CommandTemplate(
        id: "make_target",
        intents: [
          "make", "run make", "make build", "make install",
          "run makefile", "make clean", "make target",
          "build with make", "run make target",
        ],
        command: "make {TARGET}",
        slots: [
          "TARGET": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:make)\s+(\S+)"#),
        ],
        negativeKeywords: ["directory", "folder", "file", "new", "copy", "branch",
                           "executable", "script", "link", "symlink", "empty",
                           "request", "get", "post", "http", "url", "sure",
                           "package", "library", "module", "utility", "software"]
      ),
    ]
  )

  // MARK: - macOS Specific

  public static let macOSSpecific = TemplateCategory(
    id: "macos",
    name: "macOS Specific",
    description: "macOS-only commands: open, pbcopy, pbpaste, say, defaults, mdfind, mdls, osascript, sips, caffeinate, launchctl, screencapture, diskutil, plutil",
    templates: [
      CommandTemplate(
        id: "open_file",
        intents: [
          "open file", "open in default app", "launch file",
          "open this", "open with default application",
          "open folder in Finder", "reveal in Finder",
          "open document", "open in default", "open a file",
          "open the file", "open it",
        ],
        command: "{OPEN_CMD} {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:open|launch|reveal)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "open_with_app",
        intents: [
          "open with app", "open in specific app", "open file with",
          "open using", "launch with application",
        ],
        command: "open -a '{APP}' {PATH}",
        slots: [
          "APP": SlotDefinition(type: .string,
            extractPattern: #"(?:with|in|using)\s+['\"]?(\w[\w\s]*\w)['\"]?"#),
          "PATH": SlotDefinition(type: .path, defaultValue: "",
            extractPattern: #"(?:open)\s+(\S+)"#),
        ],
        discriminators: ["with", "using", "via"]
      ),
      CommandTemplate(
        id: "pbcopy",
        intents: [
          "copy to clipboard", "pbcopy", "clipboard copy",
          "copy output to clipboard", "put in clipboard",
          "yank to clipboard",
        ],
        command: "{COMMAND} | {CLIPBOARD_COPY}",
        slots: [
          "COMMAND": SlotDefinition(type: .command,
            extractPattern: #"copy\s+(?:output\s+of\s+)?(.+?)(?:\s+to\s+clipboard)"#),
        ]
      ),
      CommandTemplate(
        id: "pbpaste",
        intents: [
          "paste from clipboard", "pbpaste", "clipboard paste",
          "show clipboard contents", "get clipboard", "what's in clipboard",
        ],
        command: "{CLIPBOARD_PASTE}"
      ),
      CommandTemplate(
        id: "say_text",
        intents: [
          "say text", "speak text", "text to speech",
          "read aloud", "say something", "make mac talk",
        ],
        command: "say '{TEXT}'",
        slots: [
          "TEXT": SlotDefinition(type: .string,
            extractPattern: #"(?:say|speak|read)\s+['\"]?(.+?)['\"]?$"#),
        ]
      ),
      CommandTemplate(
        id: "defaults_read",
        intents: [
          "read defaults", "defaults read", "check preference",
          "read macOS setting", "show default value",
          "read plist setting",
        ],
        command: "defaults read {DOMAIN} {KEY}",
        slots: [
          "DOMAIN": SlotDefinition(type: .string,
            extractPattern: #"(?:read|domain)\s+(\S+)"#),
          "KEY": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:key)\s+(\S+)"#),
        ],
        negativeKeywords: ["permission", "access", "executable", "owner", "chmod", "chown", "folder", "directory"]
      ),
      CommandTemplate(
        id: "defaults_write",
        intents: [
          "write defaults", "defaults write", "set preference",
          "change macOS setting", "set default value",
        ],
        command: "defaults write {DOMAIN} {KEY} {VALUE}",
        slots: [
          "DOMAIN": SlotDefinition(type: .string,
            extractPattern: #"(?:write|domain)\s+(\S+)"#),
          "KEY": SlotDefinition(type: .string,
            extractPattern: #"(?:key)\s+(\S+)"#),
          "VALUE": SlotDefinition(type: .string,
            extractPattern: #"(?:to|value)\s+(\S+)"#),
        ],
        negativeKeywords: ["permission", "access", "executable", "owner", "chmod", "chown", "folder", "directory"]
      ),
      CommandTemplate(
        id: "mdfind_search",
        intents: [
          "spotlight search", "mdfind", "search with spotlight",
          "find file using spotlight", "search mac for",
          "spotlight find", "search files on mac",
        ],
        command: "mdfind {FLAGS} '{QUERY}'",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
          "QUERY": SlotDefinition(type: .string,
            extractPattern: #"(?:search|find|mdfind)\s+(?:for\s+)?['\"]?(.+?)['\"]?$"#),
        ],
        negativeKeywords: ["extract", "email", "addresses", "containing", "grep", "pattern", "regex"]
      ),
      CommandTemplate(
        id: "mdls_metadata",
        intents: [
          "file metadata", "mdls", "show spotlight metadata",
          "file attributes", "get file metadata",
        ],
        command: "mdls {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path,
            extractPattern: #"(?:metadata|mdls|attributes)\s+(?:of|for)?\s*(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "osascript_run",
        intents: [
          "run applescript", "osascript", "applescript command",
          "execute applescript", "tell application",
          "run osascript",
        ],
        command: "osascript -e '{SCRIPT}'",
        slots: [
          "SCRIPT": SlotDefinition(type: .string,
            extractPattern: #"osascript\s+(?:-e\s+)?['\"]?(.+?)['\"]?$"#),
        ]
      ),
      CommandTemplate(
        id: "sips_resize",
        intents: [
          "resize image sips", "sips resize", "resize image macOS",
          "scale image with sips", "shrink image sips",
        ],
        command: "sips -Z {SIZE} {PATH}",
        slots: [
          "SIZE": SlotDefinition(type: .number, defaultValue: "800",
            extractPattern: #"(\d+)\s*(?:px|pixels?)?"#),
          "PATH": SlotDefinition(type: .path,
            extractPattern: #"(?:resize|scale)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "caffeinate",
        intents: [
          "prevent sleep", "caffeinate", "keep mac awake",
          "stop screen from sleeping", "disable sleep",
          "keep display on",
        ],
        command: "caffeinate {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: "-d"),
        ]
      ),
      CommandTemplate(
        id: "screencapture",
        intents: [
          "take screenshot", "screencapture", "capture screen",
          "screenshot to file", "screen grab",
          "save screenshot", "capture full screen",
        ],
        command: "screencapture {FLAGS} {PATH}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
          "PATH": SlotDefinition(type: .path, defaultValue: "screenshot.png",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "screencapture_window",
        intents: [
          "screenshot of window", "capture window", "screenshot of app",
          "capture specific window", "screenshot of Firefox",
          "screenshot of Safari", "screenshot of application",
          "take a screenshot of", "capture app window",
        ],
        command: "screencapture -w {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "screenshot.png",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "diskutil_list",
        intents: [
          "list disks", "diskutil list", "show volumes",
          "show disk partitions", "what disks are mounted",
        ],
        command: "diskutil list"
      ),
      CommandTemplate(
        id: "plutil_lint",
        intents: [
          "validate plist", "plutil", "check plist syntax",
          "lint plist", "plist format check",
        ],
        command: "plutil -lint {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path,
            extractPattern: #"(?:validate|check|lint)\s+(\S+)"#),
        ]
      ),
    ]
  )

  // MARK: - Network

  public static let network = TemplateCategory(
    id: "network",
    name: "Network",
    description: "Networking commands: curl GET POST download, ssh, scp, nc, dig, host, lsof ports, ping",
    templates: [
      CommandTemplate(
        id: "curl_get",
        intents: [
          "curl get", "http get", "fetch url",
          "download url", "curl request", "get endpoint",
          "hit url", "make get request",
        ],
        command: "curl -s {FLAGS} '{URL}'",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
          "URL": SlotDefinition(type: .url,
            extractPattern: #"(https?://\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "curl_post_json",
        intents: [
          "curl post json", "post request with json", "send json",
          "http post", "post data to endpoint",
          "curl post body", "send post request",
        ],
        command: "curl -s -X POST -H 'Content-Type: application/json' -d '{BODY}' '{URL}'",
        slots: [
          "URL": SlotDefinition(type: .url,
            extractPattern: #"(?:to)\s+(https?://\S+|localhost:\d+|\S+:\d{2,5})|(https?://\S+|localhost:\d+)"#),
          "BODY": SlotDefinition(type: .string,
            extractPattern: #"(?:body|data|json)\s+['\"]?(\{.+\})['\"]?"#),
        ],
        discriminators: ["post", "send", "body", "json"]
      ),
      CommandTemplate(
        id: "curl_download",
        intents: [
          "download file with curl", "curl download", "save url to file",
          "download from url", "fetch and save file",
          "curl output to file",
          "download this webpage", "download webpage as file",
          "save webpage to file", "download a file from the internet",
          "download file from url", "save url content",
          "download this file", "download a file with curl",
        ],
        command: "curl -L -o {OUTPUT} '{URL}'",
        slots: [
          "URL": SlotDefinition(type: .url,
            extractPattern: #"(https?://\S+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "output",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["download", "save", "output"]
      ),
      CommandTemplate(
        id: "curl_headers",
        intents: [
          "curl headers", "show response headers", "http headers",
          "check headers", "get headers from url",
          "view response headers",
        ],
        command: "curl -sI '{URL}'",
        slots: [
          "URL": SlotDefinition(type: .url,
            extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["headers", "header", "response"]
      ),
      CommandTemplate(
        id: "curl_auth",
        intents: [
          "curl with auth", "authenticated request", "curl bearer token",
          "curl with authorization", "api request with token",
        ],
        command: "curl -s -H 'Authorization: Bearer {TOKEN}' '{URL}'",
        slots: [
          "TOKEN": SlotDefinition(type: .string,
            extractPattern: #"(?:token|bearer)\s+(\S+)"#),
          "URL": SlotDefinition(type: .url,
            extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["auth", "token", "bearer", "authorization", "authenticated"]
      ),
      // --- Wave 2: curl deep coverage (incant) ---
      CommandTemplate(
        id: "curl_put",
        intents: [
          "curl PUT request", "http put request", "send put",
          "curl -X PUT", "update resource via PUT",
        ],
        command: "curl -s -X PUT -H 'Content-Type: application/json' -d '{BODY}' '{URL}'",
        slots: [
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
          "BODY": SlotDefinition(type: .string, defaultValue: "{}",
            extractPattern: #"(?:body|data|json)\s+['\"]?(\{.+\})['\"]?"#),
        ],
        discriminators: ["put", "PUT", "update resource"]
      ),
      CommandTemplate(
        id: "curl_patch",
        intents: [
          "curl PATCH request", "http patch request", "send patch",
          "curl -X PATCH", "partial update via PATCH",
        ],
        command: "curl -s -X PATCH -H 'Content-Type: application/json' -d '{BODY}' '{URL}'",
        slots: [
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
          "BODY": SlotDefinition(type: .string, defaultValue: "{}",
            extractPattern: #"(?:body|data|json)\s+['\"]?(\{.+\})['\"]?"#),
        ],
        discriminators: ["patch", "PATCH", "partial update"]
      ),
      CommandTemplate(
        id: "curl_delete",
        intents: [
          "curl DELETE request", "http delete request",
          "curl -X DELETE", "delete resource via curl",
          "send a DELETE method via curl",
        ],
        command: "curl -s -X DELETE '{URL}'",
        slots: [
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        negativeKeywords: ["file", "temp", "log", "txt", "old", "trash", "rm"],
        discriminators: ["http", "https", "DELETE method", "remove resource", "url"]
      ),
      CommandTemplate(
        id: "curl_follow_redirects",
        intents: [
          "curl follow redirects", "curl -L follow",
          "fetch with redirects", "follow location header",
          "curl following 30x redirects",
        ],
        command: "curl -sL '{URL}'",
        slots: [
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["follow", "redirects", "-L", "30x"]
      ),
      CommandTemplate(
        id: "curl_basic_auth",
        intents: [
          "curl basic auth", "curl with username password",
          "http basic authentication",
          "curl -u user:pass", "authenticate via basic auth",
        ],
        command: "curl -s -u {USER}:{PASS} '{URL}'",
        slots: [
          "USER": SlotDefinition(type: .string,
            extractPattern: #"(?:user|as)\s+(\w+)|(\w+):"#),
          "PASS": SlotDefinition(type: .string, defaultValue: "PASSWORD",
            extractPattern: #":(\S+)"#),
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["basic auth", "basic", "username password", "-u"]
      ),
      CommandTemplate(
        id: "curl_form_upload",
        intents: [
          "curl upload file", "curl form data upload",
          "post file via curl", "multipart form upload",
          "curl -F file upload",
        ],
        command: "curl -s -F 'file=@{FILE}' '{URL}'",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:upload|file)\s+(\S+\.\w+)"#),
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["upload file", "form data", "multipart", "-F"]
      ),
      CommandTemplate(
        id: "curl_download_progress",
        intents: [
          "curl download with progress", "curl with progress display",
          "show curl progress", "download with progress meter",
          "curl --progress-bar",
        ],
        command: "curl -L --progress-bar -o {OUTPUT} '{URL}'",
        slots: [
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "output",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        negativeKeywords: ["grep", "and", "logs", "search", "foo"],
        discriminators: ["progress", "progress bar", "--progress-bar"]
      ),
      CommandTemplate(
        id: "curl_resume",
        intents: [
          "curl resume download", "continue interrupted download",
          "curl -C - resume", "resume partial download",
          "curl pick up where stopped",
        ],
        command: "curl -L -C - -o {OUTPUT} '{URL}'",
        slots: [
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "output",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["resume", "continue", "-C -", "interrupted"]
      ),
      CommandTemplate(
        id: "curl_mtls",
        intents: [
          "curl mutual tls", "curl with client certificate",
          "curl --cert client cert", "mtls request",
          "curl with mTLS",
        ],
        command: "curl -s --cert {CERT} --key {KEY} '{URL}'",
        slots: [
          "CERT": SlotDefinition(type: .path, defaultValue: "client.crt",
            extractPattern: #"(?:cert)\s+(\S+\.(?:crt|pem))"#),
          "KEY": SlotDefinition(type: .path, defaultValue: "client.key",
            extractPattern: #"(?:key)\s+(\S+\.(?:key|pem))"#),
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["mtls", "mutual tls", "client cert", "--cert"]
      ),
      CommandTemplate(
        id: "curl_cookies",
        intents: [
          "curl with cookies", "curl save cookies",
          "curl -b cookie jar", "include cookies in request",
          "curl using cookie file",
        ],
        command: "curl -s -b {COOKIES} -c {COOKIES} '{URL}'",
        slots: [
          "COOKIES": SlotDefinition(type: .path, defaultValue: "cookies.txt",
            extractPattern: #"(?:cookies?)\s+(?:from|file)?\s*(\S+)"#),
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["cookies", "cookie jar", "-b", "-c"]
      ),
      CommandTemplate(
        id: "curl_user_agent",
        intents: [
          "curl with custom user agent", "curl -A user agent",
          "set user agent string", "curl --user-agent",
          "curl pretending to be browser",
        ],
        command: "curl -s -A '{UA}' '{URL}'",
        slots: [
          "UA": SlotDefinition(type: .string, defaultValue: "Mozilla/5.0",
            extractPattern: #"(?:agent|UA)\s+['\"]?([^'\"]+)['\"]?"#),
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["user agent", "user-agent", "-A", "agent string"]
      ),
      CommandTemplate(
        id: "curl_timing",
        intents: [
          "curl timing breakdown", "curl with timing details",
          "show curl request timing", "curl response time",
          "curl -w timing format",
        ],
        command: "curl -s -o /dev/null -w 'time_namelookup: %{time_namelookup}\\ntime_connect: %{time_connect}\\ntime_total: %{time_total}\\n' '{URL}'",
        slots: [
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["timing", "time breakdown", "response time", "-w"]
      ),
      CommandTemplate(
        id: "curl_save_headers",
        intents: [
          "curl save response headers to file",
          "curl write headers to file",
          "curl -D dump headers to file",
          "save curl headers to a separate file",
          "dump headers to txt file",
        ],
        command: "curl -s -D {HEADERS} -o {BODY} '{URL}'",
        slots: [
          "HEADERS": SlotDefinition(type: .path, defaultValue: "headers.txt",
            extractPattern: #"(?:headers?)\s+(?:to|file)?\s*(\S+\.txt)"#),
          "BODY": SlotDefinition(type: .path, defaultValue: "body.html",
            extractPattern: #"(?:body)\s+(?:to|file)?\s*(\S+)"#),
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        negativeKeywords: ["check", "show", "view", "for"],
        discriminators: ["save", "dump", "-D", "to file", "to txt"]
      ),
      CommandTemplate(
        id: "curl_head_method",
        intents: [
          "curl HEAD request", "send HEAD method",
          "curl -I HEAD only", "fetch only headers via HEAD",
          "curl head method",
        ],
        command: "curl -sI -X HEAD '{URL}'",
        slots: [
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["HEAD method", "HEAD request", "-X HEAD"]
      ),
      CommandTemplate(
        id: "curl_max_time",
        intents: [
          "curl with max time", "curl timeout",
          "curl --max-time", "limit curl request duration",
          "curl with deadline",
        ],
        command: "curl -s --max-time {SECS} '{URL}'",
        slots: [
          "SECS": SlotDefinition(type: .number, defaultValue: "30",
            extractPattern: #"(\d+)\s*(?:s|sec|seconds|timeout)"#),
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["timeout", "max time", "--max-time", "deadline"]
      ),
      CommandTemplate(
        id: "curl_ipv4",
        intents: [
          "curl ipv4 only", "force ipv4 for curl",
          "curl -4 ipv4", "use ipv4 only in curl request",
        ],
        command: "curl -s -4 '{URL}'",
        slots: [
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["ipv4", "-4", "force ipv4"]
      ),
      CommandTemplate(
        id: "curl_ipv6",
        intents: [
          "curl ipv6 only", "force ipv6 for curl",
          "curl -6 ipv6", "use ipv6 only in curl request",
        ],
        command: "curl -s -6 '{URL}'",
        slots: [
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["ipv6", "-6", "force ipv6"]
      ),
      CommandTemplate(
        id: "curl_verbose",
        intents: [
          "curl verbose", "curl -v debug",
          "show curl request and response details",
          "curl with verbose output",
        ],
        command: "curl -v '{URL}'",
        slots: [
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["verbose", "-v", "debug curl"]
      ),
      CommandTemplate(
        id: "curl_status_only",
        intents: [
          "curl status code only", "curl -o /dev/null status",
          "get http status with curl",
          "curl -w status only",
        ],
        command: "curl -s -o /dev/null -w '%{http_code}\\n' '{URL}'",
        slots: [
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["status code", "http status", "%{http_code}"]
      ),
      CommandTemplate(
        id: "curl_post_form",
        intents: [
          "curl post form data", "curl -d form encoded post",
          "post application/x-www-form-urlencoded",
          "curl form fields post",
        ],
        command: "curl -s -X POST -d '{DATA}' '{URL}'",
        slots: [
          "DATA": SlotDefinition(type: .string, defaultValue: "key=value",
            extractPattern: #"(?:data|fields)\s+['\"]?([^'\"]+)['\"]?"#),
          "URL": SlotDefinition(type: .url, extractPattern: #"(https?://\S+)"#),
        ],
        discriminators: ["form data", "form fields", "form encoded", "x-www-form-urlencoded"]
      ),
      CommandTemplate(
        id: "ssh_connect",
        intents: [
          "ssh into server", "ssh connect", "remote shell",
          "connect to server", "ssh to host",
          "log into remote machine",
        ],
        command: "ssh {USER}@{HOST}",
        slots: [
          "USER": SlotDefinition(type: .string,
            extractPattern: #"(?:as|user)\s+(\w+)|(\w+)@"#),
          "HOST": SlotDefinition(type: .string,
            extractPattern: #"(?:to|into|host)\s+(\S+)|@(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "scp_copy",
        intents: [
          "scp file", "copy file to server", "copy from remote",
          "scp transfer", "upload file to server",
          "download file from server",
        ],
        command: "scp {SOURCE} {DEST}",
        slots: [
          "SOURCE": SlotDefinition(type: .path,
            extractPattern: #"(?:copy|scp|transfer)\s+(\S+)"#),
          "DEST": SlotDefinition(type: .path,
            extractPattern: #"(?:to|into)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "nc_listen",
        intents: [
          "netcat listen", "nc listen", "listen on port",
          "open port listener", "netcat server",
        ],
        command: "nc -l {PORT}",
        slots: [
          "PORT": SlotDefinition(type: .port,
            extractPattern: #"(?:port)\s+(\d+)|(\d{2,5})"#),
        ]
      ),
      CommandTemplate(
        id: "dig_lookup",
        intents: [
          "dns lookup", "dig domain", "resolve dns",
          "check dns", "lookup domain", "dig",
          "query dns records",
        ],
        command: "dig {TYPE} {DOMAIN}",
        slots: [
          "TYPE": SlotDefinition(type: .string, defaultValue: "A",
            extractPattern: #"(?:type|record)\s+(A|AAAA|MX|NS|TXT|CNAME|SOA|SRV)"#),
          "DOMAIN": SlotDefinition(type: .string,
            extractPattern: #"(?:for|domain|lookup)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "host_lookup",
        intents: [
          "host lookup", "resolve hostname", "host command",
          "find ip of domain", "reverse dns",
        ],
        command: "host {DOMAIN}",
        slots: [
          "DOMAIN": SlotDefinition(type: .string,
            extractPattern: #"(?:of|for|lookup|host)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "lsof_ports",
        intents: [
          "what's on port", "check port", "who is using port",
          "lsof port", "find process on port",
          "which process is listening", "port in use",
          "check which ports are open", "what is listening on port",
          "what is using port", "is port open",
          "check if port is open", "show what is on port",
          "which ports are in use", "port check",
        ],
        command: "lsof -i :{PORT}",
        slots: [
          "PORT": SlotDefinition(type: .port,
            extractPattern: #"(?:port)\s+(\d+)|:(\d+)|(\d{2,5})"#),
        ],
        discriminators: ["port", "listening", "socket"]
      ),
      CommandTemplate(
        id: "ping_host",
        intents: [
          "ping host", "ping server", "check if host is up",
          "ping address", "test connectivity",
          "is server reachable",
          "ping google", "ping a website", "check if site is up",
          "is server up", "is my server still up",
          "is the server reachable", "check server connectivity",
          "can I reach the server", "test if server is online",
        ],
        command: "ping -c {COUNT} {HOST}",
        slots: [
          "COUNT": SlotDefinition(type: .number, defaultValue: "4",
            extractPattern: #"(\d+)\s+(?:times|pings?)"#),
          "HOST": SlotDefinition(type: .string,
            extractPattern: #"(?:ping|host|server)\s+(\S+)"#),
        ]
      ),
    ]
  )

  // MARK: - System

  public static let system = TemplateCategory(
    id: "system",
    name: "System",
    description: "System administration: ps, kill, top, lsof, df, du, sw_vers, uname, env, which, uptime, whoami",
    templates: [
      CommandTemplate(
        id: "ps_list",
        intents: [
          "list processes", "ps", "show running processes",
          "what processes are running", "process list",
          "show all processes", "ps aux", "system processes",
          "list all system processes", "running programs",
        ],
        command: "ps aux {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ]
      ),
      CommandTemplate(
        id: "ps_grep",
        intents: [
          "find process", "search processes", "ps grep",
          "is process running", "check if running",
          "find process by name", "is service running",
          "check if process is running", "grep process",
          "which process is running", "ps aux grep",
          "find running process", "search for process",
        ],
        command: "ps aux | grep '{PATTERN}'",
        slots: [
          "PATTERN": SlotDefinition(type: .pattern,
            extractPattern: #"(?:process|for|named?|grep)\s+(\S+)"#),
        ],
        negativeKeywords: ["port", "listening", "socket"]
      ),
      CommandTemplate(
        id: "kill_process",
        intents: [
          "kill process", "stop process", "terminate process",
          "kill pid", "end process", "force quit process",
        ],
        command: "kill {SIGNAL} {PID}",
        slots: [
          "SIGNAL": SlotDefinition(type: .string, defaultValue: "-15",
            extractPattern: #"(?:signal|-)(\d+|TERM|KILL|HUP|INT)"#),
          "PID": SlotDefinition(type: .number,
            extractPattern: #"(?:pid|process)\s+(\d+)|(\d+)"#),
        ]
      ),
      CommandTemplate(
        id: "killall_name",
        intents: [
          "killall", "kill all processes named", "kill by name",
          "stop all instances of", "terminate app",
        ],
        command: "killall {NAME}",
        slots: [
          "NAME": SlotDefinition(type: .string,
            extractPattern: #"(?:killall|kill|stop|terminate)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "top_snapshot",
        intents: [
          "top processes", "cpu usage", "memory usage",
          "what's using cpu", "system resource usage",
          "top", "show top processes",
          "what is eating my cpu", "what is consuming cpu",
          "which process is using the most cpu",
          "what processes are using the most memory",
          "show resource hogs", "cpu hog",
          "what is hogging the cpu", "heaviest processes",
        ],
        command: "top -l 1 -n {COUNT} -o {SORT}",
        slots: [
          "COUNT": SlotDefinition(type: .number, defaultValue: "10",
            extractPattern: #"(?:top)\s+(\d+)"#),
          "SORT": SlotDefinition(type: .string, defaultValue: "cpu",
            extractPattern: #"(?:by|sort)\s+(cpu|mem|pid)"#),
        ]
      ),
      CommandTemplate(
        id: "lsof_open_files",
        intents: [
          "lsof", "what files are open by processes",
          "list open file descriptors", "files opened by process",
          "show open file handles", "which process has file open",
        ],
        command: "lsof {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:by|for)\s+(\S+)"#),
        ],
        negativeKeywords: ["safari", "chrome", "finder", "app", "application", "xcode", "list", "directory", "folder",
                           "permission", "owner", "access", "chmod"]
      ),
      CommandTemplate(
        id: "df_disk_free",
        intents: [
          "disk free space", "df", "how much disk space",
          "check disk space", "free space remaining",
          "disk usage summary", "available disk space",
        ],
        command: "df -h {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "",
            extractPattern: #"(?:on|for|of)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "du_summary",
        intents: [
          "directory sizes", "du sorted", "biggest directories",
          "what's using disk space", "largest directories",
          "space usage by directory", "what takes up the most space",
          "disk usage sorted by size", "what is using disk space",
          "biggest folders", "largest folders",
        ],
        command: "du -sh {PATH}/* | sort -rh | head -n {COUNT}",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:in|of)\s+(\S+)"#),
          "COUNT": SlotDefinition(type: .number, defaultValue: "20"),
        ]
      ),
      CommandTemplate(
        id: "uname_info",
        intents: [
          "system info", "uname", "os info",
          "kernel version", "what os is this",
          "system version", "machine info",
        ],
        command: "uname -a"
      ),
      CommandTemplate(
        id: "sw_vers",
        intents: [
          "macos version", "sw_vers", "what version of macos",
          "os version number", "check macos version",
        ],
        command: "sw_vers"
      ),
      CommandTemplate(
        id: "env_vars",
        intents: [
          "show environment", "env", "environment variables",
          "list env vars", "print environment",
          "show env",
        ],
        command: "env | sort"
      ),
      CommandTemplate(
        id: "which_cmd",
        intents: [
          "which command", "where is binary", "find executable",
          "which", "path to command", "locate binary",
          "where is command", "find where command is",
          "full path to binary", "command location",
          "which binary", "where is installed",
          "where is python installed", "where is node installed",
          "find where program is", "path to executable",
          "where is the binary for", "location of command",
        ],
        command: "which {CMD}",
        slots: [
          "CMD": SlotDefinition(type: .string,
            extractPattern: #"(?:which|where|find)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "uptime",
        intents: [
          "uptime", "how long has system been running",
          "system uptime", "when was last reboot",
          "check uptime",
        ],
        command: "uptime"
      ),
      CommandTemplate(
        id: "whoami",
        intents: [
          "whoami", "current user", "who am i",
          "what user am i", "my username",
        ],
        command: "whoami"
      ),
      CommandTemplate(
        id: "date_show",
        intents: [
          "date", "show date", "current date",
          "what date is it", "show time",
          "current time", "date and time",
        ],
        command: "date '{FORMAT}'",
        slots: [
          "FORMAT": SlotDefinition(type: .string, defaultValue: "+%Y-%m-%d %H:%M:%S",
            extractPattern: #"(?:format)\s+['\"]?(\S+)['\"]?"#),
        ]
      ),
      CommandTemplate(
        id: "history_search",
        intents: [
          "history", "shell history", "command history",
          "show history", "recent commands",
          "search history", "what commands did I run",
        ],
        command: "history {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:last)\s+(\d+)"#),
        ],
        negativeKeywords: ["git", "commit", "log", "branch"]
      ),
      CommandTemplate(
        id: "ssh_keygen",
        intents: [
          "ssh keygen", "generate ssh key", "create ssh key",
          "new ssh key", "ssh-keygen", "generate key pair",
          "create rsa key", "create ed25519 key",
        ],
        command: "ssh-keygen -t {TYPE} -C '{COMMENT}'",
        slots: [
          "TYPE": SlotDefinition(type: .string, defaultValue: "ed25519",
            extractPattern: #"(?:type|algorithm)\s+(rsa|ed25519|ecdsa)"#),
          "COMMENT": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:comment|email)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "pwd",
        intents: [
          "pwd", "print working directory", "current directory",
          "where am i", "what directory am i in",
          "show current path", "show current directory",
        ],
        command: "pwd"
      ),
      CommandTemplate(
        id: "clear_terminal",
        intents: [
          "clear", "clear terminal", "clear screen",
          "reset terminal", "cls", "clear the screen",
        ],
        command: "clear"
      ),
      CommandTemplate(
        id: "export_var",
        intents: [
          "export", "set environment variable", "export variable",
          "set env var", "define environment variable",
          "set variable", "export env",
        ],
        command: "export {NAME}={VALUE}",
        slots: [
          "NAME": SlotDefinition(type: .string,
            extractPattern: #"(?:export|variable|set)\s+(\w+)"#),
          "VALUE": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:=|to)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "man_page",
        intents: [
          "man", "manual for", "help with command",
          "how to use", "how do I use", "explain command",
          "what does command do", "show manual",
          "command help", "documentation for",
        ],
        command: "man {COMMAND}",
        slots: [
          "COMMAND": SlotDefinition(type: .string,
            extractPattern: #"(?:man|use|explain|for|about|with)\s+(\w+)"#),
        ]
      ),
      CommandTemplate(
        id: "command_help",
        intents: [
          "help flags", "what flags", "show options",
          "what options does", "command options",
          "what arguments", "allowed flags",
        ],
        command: "{COMMAND} --help",
        slots: [
          "COMMAND": SlotDefinition(type: .string,
            extractPattern: #"(?:does|for|of)\s+(\w+)"#),
        ],
        discriminators: ["flags", "options", "arguments", "allowed"]
      ),
      CommandTemplate(
        id: "command_version",
        intents: [
          "what version of", "check version", "version of",
          "which version", "show version number",
          "what version do I have", "version installed",
        ],
        command: "{COMMAND} --version",
        slots: [
          "COMMAND": SlotDefinition(type: .string,
            extractPattern: #"(?:version\s+of|of)\s+(\w+)"#),
        ],
        discriminators: ["version"]
      ),
      CommandTemplate(
        id: "ifconfig_show",
        intents: [
          "ifconfig", "network interfaces", "show network interfaces",
          "list network interfaces", "ip address", "show ip address",
          "my ip address", "what is my ip",
        ],
        command: "ifconfig"
      ),
      CommandTemplate(
        id: "service_restart",
        intents: [
          "restart service", "restart nginx", "restart apache",
          "restart postgres", "systemctl restart",
          "launchctl restart", "reload service",
        ],
        command: "{SVC_RESTART} {SERVICE}",
        slots: [
          "SERVICE": SlotDefinition(type: .string,
            extractPattern: #"(?:restart|reload|start|stop)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "free_memory",
        intents: [
          "free memory", "ram usage", "memory usage",
          "how much ram", "available memory",
          "show memory", "system memory",
          "how much memory is being used",
        ],
        command: "vm_stat"
      ),
      CommandTemplate(
        id: "crontab_list",
        intents: [
          "crontab", "list cron jobs", "show cron jobs",
          "crontab -l", "my cron jobs", "scheduled tasks",
          "what cron jobs do I have",
        ],
        command: "crontab -l"
      ),
      CommandTemplate(
        id: "crontab_edit",
        intents: [
          "edit crontab", "create cron job", "add cron job",
          "crontab -e", "schedule a job", "create scheduled task",
          "set up cron", "new cron job",
        ],
        command: "crontab -e"
      ),
      CommandTemplate(
        id: "md5_hash",
        intents: [
          "md5 hash", "calculate md5", "md5sum",
          "md5 checksum", "checksum of file",
          "sha256 hash", "file hash", "compute hash",
        ],
        command: "{MD5_CMD} {FILE}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:of|for|hash)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "cal_show",
        intents: [
          "calendar", "cal", "show calendar",
          "this month calendar", "cal this month",
          "show this month",
        ],
        command: "cal {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ]
      ),
      CommandTemplate(
        id: "list_users",
        intents: [
          "list users", "show all users", "who are the users",
          "all users on system", "list system users",
          "show user accounts",
        ],
        command: "cut -d: -f1 /etc/passwd | sort"
      ),
      CommandTemplate(
        id: "usermod_group",
        intents: [
          "add to group", "usermod group", "add user to group",
          "join group", "add myself to group",
          "add to docker group",
        ],
        command: "sudo usermod -aG {GROUP} {USER}",
        slots: [
          "GROUP": SlotDefinition(type: .string,
            extractPattern: #"(?:group)\s+(\S+)|(?:to)\s+(\S+)"#),
          "USER": SlotDefinition(type: .string, defaultValue: "$(whoami)",
            extractPattern: #"(?:user)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "echo_var",
        intents: [
          "echo variable", "show variable", "print variable",
          "value of variable", "show env var",
          "print environment variable", "echo env",
          "what is the value of",
        ],
        command: "echo ${VAR}",
        slots: [
          "VAR": SlotDefinition(type: .string,
            extractPattern: #"(?:variable|var|of)\s+(\w+)"#),
        ]
      ),
      CommandTemplate(
        id: "who_logged_in",
        intents: [
          "who is logged in", "who", "logged in users",
          "who else is on this machine", "show logged in users",
          "active users", "w command",
        ],
        command: "who"
      ),
      CommandTemplate(
        id: "nmap_scan",
        intents: [
          "nmap scan", "scan network", "scan local network",
          "discover devices on network", "port scan",
          "find devices on network", "network discovery",
        ],
        command: "nmap -sn {NETWORK}",
        slots: [
          "NETWORK": SlotDefinition(type: .string, defaultValue: "192.168.1.0/24",
            extractPattern: #"(\d+\.\d+\.\d+\.\d+/\d+)"#),
        ]
      ),
      CommandTemplate(
        id: "netstat_connections",
        intents: [
          "show network connections", "open connections",
          "all network connections", "active connections",
          "netstat", "show open sockets",
        ],
        command: "netstat -an | head -50"
      ),
    ]
  )

  // MARK: - Packages

  public static let packages = TemplateCategory(
    id: "packages",
    name: "Packages",
    description: "Package managers: brew install search list update, npm install list, pip install, cargo add, gem install",
    templates: [
      CommandTemplate(
        id: "brew_install",
        intents: [
          "brew install", "install with homebrew", "homebrew install",
          "install package on mac", "brew add",
          "install formula",
          "install tool", "install utility", "install program",
          "install package", "install software",
          "install command line tool", "install a package",
        ],
        command: "brew install {PACKAGE}",
        slots: [
          "PACKAGE": SlotDefinition(type: .string,
            extractPattern: #"(?:install)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "brew_search",
        intents: [
          "brew search", "search homebrew", "find brew package",
          "homebrew search", "is it on homebrew",
          "search for formula", "search for package on homebrew",
          "look for brew formula", "brew find",
        ],
        command: "brew search {QUERY}",
        slots: [
          "QUERY": SlotDefinition(type: .string,
            extractPattern: #"(?:search|find|for)\s+(\S+)"#),
        ],
        discriminators: ["search", "find", "look"]
      ),
      CommandTemplate(
        id: "brew_list",
        intents: [
          "brew list", "list installed packages", "homebrew list",
          "what's installed with brew", "show brew packages",
          "list homebrew formulae",
        ],
        command: "brew list"
      ),
      CommandTemplate(
        id: "brew_update",
        intents: [
          "brew update", "update homebrew", "brew upgrade",
          "update all packages", "upgrade homebrew packages",
          "update brew formulae",
          "update all brew packages", "upgrade all brew packages",
          "update everything with brew", "brew update and upgrade",
          "upgrade all installed packages", "update all formulae",
        ],
        command: "brew update && brew upgrade"
      ),
      CommandTemplate(
        id: "brew_info",
        intents: [
          "brew info", "homebrew info", "package info brew",
          "details about formula", "brew show",
        ],
        command: "brew info {PACKAGE}",
        slots: [
          "PACKAGE": SlotDefinition(type: .string,
            extractPattern: #"(?:info|about|details)\s+(?:for\s+)?(\S+)"#),
        ],
        discriminators: ["info", "details", "about", "show"]
      ),
      CommandTemplate(
        id: "npm_install",
        intents: [
          "npm install", "install npm package", "add npm dependency",
          "npm add", "install node module",
          "npm i package", "install from package.json",
          "install node dependencies", "install javascript dependencies",
          "install js package", "install node package",
        ],
        command: "npm install {PACKAGE}",
        slots: [
          "PACKAGE": SlotDefinition(type: .string,
            extractPattern: #"(?:install|add)\s+(\S+)"#),
        ],
        discriminators: ["install", "add"]
      ),
      CommandTemplate(
        id: "npm_list",
        intents: [
          "npm list", "list npm packages", "show node modules",
          "what npm packages are installed", "npm ls",
        ],
        command: "npm list --depth={DEPTH}",
        slots: [
          "DEPTH": SlotDefinition(type: .number, defaultValue: "0"),
        ]
      ),
      CommandTemplate(
        id: "pip_install",
        intents: [
          "pip install", "install python package", "pip3 install",
          "add python dependency", "install with pip",
          "python install package",
          "install python library", "install python module",
        ],
        command: "pip3 install {PACKAGE}",
        slots: [
          "PACKAGE": SlotDefinition(type: .string,
            extractPattern: #"(?:install)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "pip_list",
        intents: [
          "pip list", "list python packages", "installed pip packages",
          "show python packages", "pip3 list",
        ],
        command: "pip3 list"
      ),
      CommandTemplate(
        id: "pip_freeze",
        intents: [
          "pip freeze", "export requirements", "generate requirements.txt",
          "freeze python dependencies", "save pip packages",
        ],
        command: "pip3 freeze > requirements.txt"
      ),
      CommandTemplate(
        id: "cargo_add",
        intents: [
          "cargo add", "add rust dependency", "add crate",
          "install rust package", "cargo install",
        ],
        command: "cargo add {PACKAGE}",
        slots: [
          "PACKAGE": SlotDefinition(type: .string,
            extractPattern: #"(?:add|install)\s+(\S+)"#),
        ],
        discriminators: ["add", "install", "dependency", "crate"]
      ),
      CommandTemplate(
        id: "gem_install",
        intents: [
          "gem install", "install ruby gem", "add ruby gem",
          "install gem", "ruby gem install",
        ],
        command: "gem install {PACKAGE}",
        slots: [
          "PACKAGE": SlotDefinition(type: .string,
            extractPattern: #"(?:install)\s+(\S+)"#),
        ]
      ),
    ]
  )

  // MARK: - Compression

  public static let compression = TemplateCategory(
    id: "compression",
    name: "Compression",
    description: "Archive and compression: tar create extract, gzip, bzip2, zip unzip, xz, zstd",
    templates: [
      CommandTemplate(
        id: "tar_create",
        intents: [
          "create tar archive", "tar create", "make tarball",
          "compress directory into tar", "tar czf",
          "archive directory", "create tar.gz",
          "compress folder", "compress directory", "compress files",
          "compress all files", "compress log files",
          "archive and compress", "tar gz this folder",
          "archive folder", "archive files", "make archive",
          "pack directory", "bundle files into archive",
        ],
        command: "tar -czf {ARCHIVE} {PATH}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path, defaultValue: "archive.tar.gz",
            extractPattern: #"(?:as|to|into|named?)\s+(\S+\.tar(?:\.\w+)?)"#),
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:of|archive|compress)\s+(?:the\s+)?(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "tar_extract",
        intents: [
          "extract tar", "untar", "tar extract",
          "uncompress tarball", "tar xzf", "extract archive",
          "unpack tar.gz", "extract tar.gz",
        ],
        command: "tar -xzf {ARCHIVE} {FLAGS}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:extract|untar|unpack)\s+(\S+)"#),
          "FLAGS": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:to|into)\s+-C\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "tar_list",
        intents: [
          "list tar contents", "tar list", "what's in this tar",
          "show archive contents", "tar tf",
          "peek inside tarball",
        ],
        command: "tar -tzf {ARCHIVE}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:of|in|contents)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "tar_bz2_create",
        intents: [
          "create bzip2 tar", "tar bz2 compress",
          "create tar.bz2", "bzip2 archive",
          "compress with bzip2",
        ],
        command: "tar -cjf {ARCHIVE} {PATH}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:as|to|named?)\s+(\S+)"#),
          "PATH": SlotDefinition(type: .path,
            extractPattern: #"(?:compress|archive)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "gzip_file",
        intents: [
          "gzip file", "compress with gzip", "gzip compress",
          "make gz file", "gzip",
        ],
        command: "gzip {FLAGS} {FILE}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:gzip|compress)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "gunzip_file",
        intents: [
          "gunzip file", "decompress gz", "ungzip",
          "extract gz file", "gunzip",
        ],
        command: "gunzip {FILE}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:gunzip|decompress|extract)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "zip_create",
        intents: [
          "create zip", "zip files", "compress to zip",
          "make zip archive", "zip directory",
          "zip folder", "create zip file",
        ],
        command: "zip -r {ARCHIVE} {PATH}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:as|to|into|named?)\s+(\S+\.zip)"#),
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:zip|compress)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "unzip_extract",
        intents: [
          "unzip", "extract zip", "uncompress zip",
          "unzip file", "extract zip archive",
          "unpack zip",
        ],
        command: "unzip {ARCHIVE} {FLAGS}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:unzip|extract)\s+(\S+)"#),
          "FLAGS": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:to|into)\s+-d\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "xz_compress",
        intents: [
          "xz compress", "compress with xz", "create xz file",
          "xz file", "lzma compress",
        ],
        command: "xz {FLAGS} {FILE}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:compress|xz)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "xz_decompress",
        intents: [
          "xz decompress", "unxz", "extract xz file",
          "decompress xz", "uncompress xz",
        ],
        command: "xz -d {FILE}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:decompress|extract|unxz)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "zstd_compress",
        intents: [
          "zstd compress", "compress with zstd", "zstandard compress",
          "create zst file", "zstd",
        ],
        command: "zstd {FLAGS} {FILE}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:compress|zstd)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "zstd_decompress",
        intents: [
          "zstd decompress", "unzstd", "decompress zst",
          "extract zstd file", "zstd extract",
        ],
        command: "zstd -d {FILE}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:decompress|extract)\s+(\S+)"#),
        ]
      ),
      // --- Wave 1: tar deep coverage (incant) ---
      CommandTemplate(
        id: "tar_create_xz",
        intents: [
          "create tar.xz", "tar xz archive", "compress directory with xz tar",
          "make tar.xz archive", "tar with xz compression",
        ],
        command: "tar -cJf {ARCHIVE} {PATH}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path, defaultValue: "archive.tar.xz",
            extractPattern: #"(?:as|to|into|named?)\s+(\S+\.tar\.xz)"#),
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:of|archive|compress)\s+(?:the\s+)?(\S+)"#),
        ],
        discriminators: ["xz", "tar.xz", "lzma"]
      ),
      CommandTemplate(
        id: "tar_create_zst",
        intents: [
          "create tar.zst", "create tar.zst archive",
          "compress directory with zstd tar", "compress with zstandard tar",
          "compress directory with zstandard tar", "compress folder with zstandard tar",
          "make tar.zst archive", "tar with zstd compression",
          "tar.zst of folder",
        ],
        command: "tar -cf {ARCHIVE} {TAR_ZSTD_FLAG} {PATH}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path, defaultValue: "archive.tar.zst",
            extractPattern: #"(?:as|to|into|named?)\s+(\S+\.tar\.zst)"#),
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:of|archive|compress)\s+(?:the\s+)?(\S+)"#),
        ],
        negativeKeywords: ["database", "file.sql", "single file"],
        discriminators: ["tar.zst", "zstandard", "zstd"],
        requires: ["capability:tar.zstd"]
      ),
      CommandTemplate(
        id: "tar_extract_xz",
        intents: [
          "extract tar.xz", "untar xz archive", "decompress tar.xz",
          "unpack tar.xz", "extract xz tarball",
        ],
        command: "tar -xJf {ARCHIVE}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:extract|untar|unpack)\s+(\S+\.tar\.xz)"#),
        ],
        discriminators: ["xz", "tar.xz"]
      ),
      CommandTemplate(
        id: "tar_extract_zst",
        intents: [
          "extract tar.zst", "extract bundle.tar.zst", "untar zst archive",
          "decompress tar.zst", "decompress source.tar.zst",
          "unpack tar.zst", "extract zstd tarball",
          "extract zst tarball", "untar tar.zst",
        ],
        command: "tar -xf {ARCHIVE} {TAR_ZSTD_FLAG}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:extract|untar|unpack|decompress)\s+(\S+\.tar\.zst)"#),
        ],
        discriminators: ["tar.zst", "tar zst"],
        requires: ["capability:tar.zstd"]
      ),
      CommandTemplate(
        id: "tar_extract_to_dir",
        intents: [
          "tar extract -C destination",
          "tar -xzf -C destination",
          "extract tarball into directory",
          "untar into specific directory",
          "extract archive into named output folder",
        ],
        command: "tar -xzf {ARCHIVE} -C {DEST}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:extract|untar|unpack)\s+(\S+\.tar(?:\.\w+)?)"#),
          "DEST": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:to|into)\s+(\S+)"#),
        ],
        negativeKeywords: ["strip", "removing", "remove top", "extract single"],
        discriminators: ["into", "-C", "destination", "specific directory"]
      ),
      CommandTemplate(
        id: "tar_extract_strip",
        intents: [
          "extract tar strip components", "untar strip leading directory",
          "tar extract --strip-components", "remove top-level directory from tarball",
          "extract tar without top folder", "untar removing top folder",
          "extract tar.gz removing top folder", "strip top directory from archive",
          "untar release.tar.gz removing top folder",
          "extract tarball strip components",
        ],
        command: "tar -xzf {ARCHIVE} --strip-components={N}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:extract|untar|unpack)\s+(\S+\.tar(?:\.\w+)?)"#),
          "N": SlotDefinition(type: .number, defaultValue: "1",
            extractPattern: #"strip[\s-]+(\d+)|--strip-components[= ](\d+)"#),
        ],
        negativeKeywords: ["create", "mkdir", "src/", "make", "new"],
        discriminators: ["strip", "components", "leading", "removing top", "remove top"]
      ),
      CommandTemplate(
        id: "tar_list_verbose",
        intents: [
          "tar list verbose", "list tar contents with sizes",
          "show tar archive contents detailed", "tar -tvzf",
          "verbose tar listing",
        ],
        command: "tar -tvzf {ARCHIVE}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:of|in|contents)\s+(\S+)"#),
        ],
        discriminators: ["verbose", "detailed", "sizes", "with sizes"]
      ),
      CommandTemplate(
        id: "tar_append",
        intents: [
          "append to tar", "add file to tar archive",
          "tar append --append",
          "add to existing tarball",
        ],
        command: "tar -rf {ARCHIVE} {PATH}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:to|into)\s+(\S+\.tar)"#),
          "PATH": SlotDefinition(type: .path,
            extractPattern: #"(?:append|add)\s+(\S+)"#),
        ],
        discriminators: ["append", "add to"]
      ),
      CommandTemplate(
        id: "tar_exclude",
        intents: [
          "tar with exclude pattern", "create tar excluding files",
          "tar archive but skip pattern", "tar --exclude",
          "compress directory but exclude node_modules",
        ],
        command: "tar -czf {ARCHIVE} --exclude='{PATTERN}' {PATH}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path, defaultValue: "archive.tar.gz",
            extractPattern: #"(?:as|to|into|named?)\s+(\S+\.tar(?:\.\w+)?)"#),
          "PATTERN": SlotDefinition(type: .pattern, defaultValue: "*.log",
            extractPattern: #"(?:exclud(?:e|ing))\s+(\S+)"#),
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:of|compress|archive)\s+(?:the\s+)?(\S+?)\s+(?:exclud|but|skip)"#),
        ],
        discriminators: ["exclude", "excluding", "skip", "without"]
      ),
      CommandTemplate(
        id: "tar_extract_single",
        intents: [
          "extract single file from tar", "extract one file from tarball",
          "tar extract one file", "extract specific file from tar",
          "untar just one file", "extract one entry from archive",
          "extract a specific file from archive", "get one file out of tarball",
          "extract one file from tar.gz",
          "extract a single entry from a tar archive",
          "get a file from inside a tarball",
          "extract FILE from archive.tar.gz",
          "extract FILENAME from tar.gz",
          "extract FILE from tarball",
          "get FILE out of tar.gz",
        ],
        command: "tar -xzf {ARCHIVE} {FILE}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:from|out of)\s+(\S+\.tar(?:\.\w+)?)"#),
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:extract|get)\s+(\S+\.\w+)\s+(?:from|out)"#),
        ],
        negativeKeywords: ["pull request", "git pull", " and ", "all files"],
        discriminators: ["single", "specific", "one file", "just one", "tarball", "from archive", "from tar"]
      ),
      CommandTemplate(
        id: "tar_compare",
        intents: [
          "tar compare", "tar diff archive against filesystem",
          "verify tar matches files", "tar --diff",
          "check tar against directory",
        ],
        command: "tar -dzf {ARCHIVE} {PATH}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:compare|diff|verify)\s+(\S+\.tar(?:\.\w+)?)"#),
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:against|with)\s+(\S+)"#),
        ],
        discriminators: ["compare", "diff", "against", "matches"]
      ),
      CommandTemplate(
        id: "tar_preserve_perms",
        intents: [
          "tar preserve permissions", "tar with permissions",
          "create tar keeping ownership", "tar -p preserve perms",
          "archive with original permissions",
        ],
        command: "tar -cpzf {ARCHIVE} {PATH}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path, defaultValue: "archive.tar.gz",
            extractPattern: #"(?:as|to|into|named?)\s+(\S+\.tar(?:\.\w+)?)"#),
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:of|archive|compress)\s+(?:the\s+)?(\S+)"#),
        ],
        discriminators: ["preserve", "permissions", "perms", "keep ownership"]
      ),
      CommandTemplate(
        id: "tar_dereference",
        intents: [
          "tar follow symlinks", "tar dereference",
          "tar -h follow links", "archive with symlink targets",
          "tar resolve symbolic links",
        ],
        command: "tar -czhf {ARCHIVE} {PATH}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path, defaultValue: "archive.tar.gz",
            extractPattern: #"(?:as|to|into|named?)\s+(\S+\.tar(?:\.\w+)?)"#),
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:of|archive|follow)\s+(?:the\s+)?(\S+)"#),
        ],
        discriminators: ["dereference", "follow", "symlink", "symbolic"]
      ),
      CommandTemplate(
        id: "tar_create_no_compress",
        intents: [
          "create plain tar", "tar without compression",
          "tar uncompressed", "make .tar archive only",
          "raw tar no gzip",
        ],
        command: "tar -cf {ARCHIVE} {PATH}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path, defaultValue: "archive.tar",
            extractPattern: #"(?:as|to|into|named?)\s+(\S+\.tar)"#),
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:of|archive|tar)\s+(?:the\s+)?(\S+)"#),
        ],
        discriminators: ["plain", "uncompressed", "no compression", "raw"]
      ),
    ]
  )

  // MARK: - Cloud

  public static let cloud = TemplateCategory(
    id: "cloud",
    name: "Cloud",
    description: "Cloud CLI tools: aws s3 ec2 lambda iam logs, kubectl, wrangler cloudflare workers, sam serverless deploy invoke logs",
    templates: [
      CommandTemplate(
        id: "aws_s3_ls",
        intents: [
          "list s3 bucket", "aws s3 ls", "show s3 contents",
          "what's in s3 bucket", "browse s3",
          "list s3 objects",
        ],
        command: "aws s3 ls {BUCKET}",
        slots: [
          "BUCKET": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(s3://\S+)"#),
        ],
        negativeKeywords: ["directory", "folder", "here", "files", "local"]
      ),
      CommandTemplate(
        id: "aws_s3_cp",
        intents: [
          "copy to s3", "aws s3 cp", "upload to s3",
          "download from s3", "s3 copy",
          "transfer file to s3",
        ],
        command: "aws s3 cp {SOURCE} {DEST}",
        slots: [
          "SOURCE": SlotDefinition(type: .path,
            extractPattern: #"(?:cp|copy|upload)\s+(\S+)"#),
          "DEST": SlotDefinition(type: .string,
            extractPattern: #"(?:to)\s+(\S+)"#),
        ],
        negativeKeywords: ["curl", "wget", "http", "https", "url", "server"]
      ),
      CommandTemplate(
        id: "aws_s3_sync",
        intents: [
          "sync to s3", "aws s3 sync", "mirror to s3",
          "s3 sync directory", "sync folder with s3",
          "s3 upload directory",
        ],
        command: "aws s3 sync {SOURCE} {DEST} {FLAGS}",
        slots: [
          "SOURCE": SlotDefinition(type: .path,
            extractPattern: #"(?:sync)\s+(\S+)"#),
          "DEST": SlotDefinition(type: .string,
            extractPattern: #"(?:to|with)\s+(\S+)"#),
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        negativeKeywords: ["nuke", "delete", "trash", "remove", "build"]
      ),
      CommandTemplate(
        id: "aws_ec2_describe",
        intents: [
          "list ec2 instances", "describe ec2", "aws ec2 describe",
          "show running instances", "ec2 instances",
          "what instances are running",
        ],
        command: "aws ec2 describe-instances {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: "--query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType]' --output table"),
        ],
        negativeKeywords: ["process", "nginx", "apache", "docker", "container", "pid", "kill"]
      ),
      CommandTemplate(
        id: "aws_lambda_invoke",
        intents: [
          "invoke lambda", "aws lambda invoke", "run lambda function",
          "call lambda", "trigger lambda",
          "execute lambda function",
        ],
        command: "aws lambda invoke --function-name {FUNCTION} --payload '{PAYLOAD}' {OUTPUT}",
        slots: [
          "FUNCTION": SlotDefinition(type: .string,
            extractPattern: #"(?:function|lambda)\s+(\S+)"#),
          "PAYLOAD": SlotDefinition(type: .string, defaultValue: "{}"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "/dev/stdout"),
        ]
      ),
      CommandTemplate(
        id: "aws_lambda_list",
        intents: [
          "list lambda functions", "aws lambda list", "show lambdas",
          "what lambda functions exist", "all lambda functions",
        ],
        command: "aws lambda list-functions --query 'Functions[*].[FunctionName,Runtime,LastModified]' --output table"
      ),
      CommandTemplate(
        id: "aws_iam_whoami",
        intents: [
          "aws whoami", "aws identity", "sts get caller identity",
          "who am i in aws", "current aws account",
          "check aws credentials",
        ],
        command: "aws sts get-caller-identity"
      ),
      CommandTemplate(
        id: "aws_logs_tail",
        intents: [
          "tail cloudwatch logs", "aws logs tail", "stream logs",
          "follow cloudwatch log group", "watch aws logs",
          "read cloudwatch logs",
        ],
        command: "aws logs tail '{LOG_GROUP}' --follow",
        slots: [
          "LOG_GROUP": SlotDefinition(type: .string,
            extractPattern: #"(?:group|logs?)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "kubectl_get_all",
        intents: [
          "kubectl get all", "show all k8s resources",
          "kubernetes all resources", "list all kubernetes objects",
          "what's running in k8s",
        ],
        command: "kubectl get all {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ]
      ),
      CommandTemplate(
        id: "kubectl_describe",
        intents: [
          "kubectl describe", "describe pod", "k8s pod details",
          "describe kubernetes resource", "pod info",
          "show pod details",
        ],
        command: "kubectl describe {RESOURCE} {NAME}",
        slots: [
          "RESOURCE": SlotDefinition(type: .string, defaultValue: "pod",
            extractPattern: #"(?:describe)\s+(\w+)"#),
          "NAME": SlotDefinition(type: .string,
            extractPattern: #"(?:describe\s+\w+)\s+(\S+)"#),
        ],
        discriminators: ["describe", "details", "info"]
      ),
      CommandTemplate(
        id: "kubectl_logs",
        intents: [
          "kubectl logs", "pod logs", "show pod logs",
          "container logs", "read k8s logs",
          "stream pod logs",
        ],
        command: "kubectl logs {FLAGS} {POD}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(-f|--follow|--tail=\d+)"#),
          "POD": SlotDefinition(type: .string,
            extractPattern: #"(?:logs?|pod)\s+(\S+)"#),
        ],
        discriminators: ["logs", "log"]
      ),
      CommandTemplate(
        id: "kubectl_apply",
        intents: [
          "kubectl apply manifest", "apply k8s manifest file", "deploy to kubernetes",
          "apply kubernetes yaml manifest", "kubectl deploy manifest",
          "apply kubernetes configuration manifest",
        ],
        command: "kubectl apply -f {FILE}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:apply|deploy)\s+(\S+)"#),
        ],
        discriminators: ["apply", "deploy", "manifest"]
      ),

      // MARK: Wrangler (Cloudflare Workers)

      CommandTemplate(
        id: "wrangler_dev",
        intents: [
          "wrangler dev", "cloudflare worker dev", "start worker locally",
          "run worker dev server", "local cloudflare worker",
          "test worker locally", "wrangler local dev",
        ],
        command: "wrangler dev {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        discriminators: ["dev", "local", "locally", "test"]
      ),
      CommandTemplate(
        id: "wrangler_deploy",
        intents: [
          "wrangler deploy", "deploy cloudflare worker", "publish worker",
          "wrangler publish", "push worker to cloudflare",
          "deploy to cloudflare", "ship worker",
          "deploy worker to production",
        ],
        command: "wrangler deploy {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        discriminators: ["deploy", "publish", "ship", "production"]
      ),
      CommandTemplate(
        id: "wrangler_tail",
        intents: [
          "wrangler tail", "tail cloudflare worker logs",
          "stream worker logs", "cloudflare worker logs",
          "watch worker logs", "follow worker output",
        ],
        command: "wrangler tail {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        discriminators: ["tail", "logs", "stream", "watch", "follow"]
      ),
      CommandTemplate(
        id: "wrangler_secret",
        intents: [
          "wrangler secret", "set cloudflare worker secret",
          "add worker secret", "wrangler secret put",
          "set worker environment variable", "cloudflare secret",
        ],
        command: "wrangler secret put {NAME}",
        slots: [
          "NAME": SlotDefinition(type: .string,
            extractPattern: #"(?:secret|variable|put)\s+(\S+)"#),
        ],
        discriminators: ["secret", "variable", "env"]
      ),
      CommandTemplate(
        id: "wrangler_init",
        intents: [
          "wrangler init", "create cloudflare worker",
          "new cloudflare worker project", "init worker project",
          "scaffold cloudflare worker", "wrangler generate",
        ],
        command: "wrangler init {NAME}",
        slots: [
          "NAME": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:init|create|named?)\s+(\S+)"#),
        ],
        discriminators: ["init", "create", "new", "scaffold", "generate"]
      ),

      // MARK: AWS SAM

      CommandTemplate(
        id: "sam_build",
        intents: [
          "sam build", "build sam application", "build serverless app with sam",
          "aws sam build", "compile sam project",
        ],
        command: "sam build {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        negativeKeywords: ["trash", "artifacts", "remove", "delete", "clean", "docker",
                           "swift", "rust", "cargo", "go", "golang", "flutter", "react",
                           "node", "npm", "nuke", "test", "production", "release",
                           "project", "this"],
        discriminators: ["sam", "serverless"]
      ),
      CommandTemplate(
        id: "sam_deploy",
        intents: [
          "sam deploy", "deploy sam application", "deploy with sam",
          "aws sam deploy", "sam deploy guided",
          "push sam stack to aws", "deploy sam to production",
        ],
        command: "sam deploy {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: "--guided"),
        ],
        negativeKeywords: ["kubernetes", "docker", "cloudflare", "worker", "serverless framework"],
        discriminators: ["sam", "guided"]
      ),
      CommandTemplate(
        id: "sam_local_invoke",
        intents: [
          "sam local invoke", "invoke sam function locally",
          "test sam function", "run lambda locally with sam",
          "sam invoke local", "local sam test",
        ],
        command: "sam local invoke {FUNCTION} {FLAGS}",
        slots: [
          "FUNCTION": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:invoke|function)\s+(\S+)"#),
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        discriminators: ["invoke", "local", "locally", "test"]
      ),
      CommandTemplate(
        id: "sam_local_api",
        intents: [
          "sam local start-api", "start local api with sam",
          "sam local api gateway", "run sam api locally",
          "sam start local server", "local sam api",
        ],
        command: "sam local start-api {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        discriminators: ["api", "start-api", "server", "gateway"]
      ),
      CommandTemplate(
        id: "sam_logs",
        intents: [
          "sam logs", "fetch sam logs", "aws sam logs",
          "view sam function logs", "sam tail logs",
          "stream sam lambda logs",
        ],
        command: "sam logs -n {FUNCTION} --tail {FLAGS}",
        slots: [
          "FUNCTION": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:logs?|function)\s+(\S+)"#),
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        discriminators: ["logs", "tail", "stream", "view"]
      ),
      CommandTemplate(
        id: "sam_init",
        intents: [
          "sam init", "create sam project", "new sam application",
          "aws sam init", "scaffold sam app",
          "initialize sam project",
        ],
        command: "sam init {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        discriminators: ["init", "create", "new", "scaffold", "initialize"]
      ),

      // MARK: Serverless Framework

      CommandTemplate(
        id: "serverless_deploy",
        intents: [
          "serverless deploy", "sls deploy", "deploy serverless app",
          "deploy with serverless framework", "serverless push",
          "sls deploy to production", "deploy serverless stack",
        ],
        command: "serverless deploy {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        negativeKeywords: ["kubernetes", "docker", "cloudflare", "worker", "sam", "ansible"],
        discriminators: ["serverless", "sls"]
      ),
      CommandTemplate(
        id: "serverless_invoke",
        intents: [
          "serverless invoke", "sls invoke", "invoke serverless function",
          "call serverless function", "test serverless function",
          "sls invoke local",
        ],
        command: "serverless invoke {FLAGS} -f {FUNCTION}",
        slots: [
          "FUNCTION": SlotDefinition(type: .string,
            extractPattern: #"(?:invoke|function)\s+(\S+)"#),
          "FLAGS": SlotDefinition(type: .string, defaultValue: "--local"),
        ],
        discriminators: ["invoke", "call", "test"]
      ),
      CommandTemplate(
        id: "serverless_logs",
        intents: [
          "serverless logs", "sls logs", "view serverless logs",
          "tail serverless function logs", "serverless log output",
          "stream serverless logs",
        ],
        command: "serverless logs -f {FUNCTION} --tail {FLAGS}",
        slots: [
          "FUNCTION": SlotDefinition(type: .string,
            extractPattern: #"(?:logs?|function)\s+(\S+)"#),
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        discriminators: ["logs", "tail", "stream", "output"]
      ),
      CommandTemplate(
        id: "serverless_remove",
        intents: [
          "serverless remove", "sls remove", "tear down serverless stack",
          "delete serverless deployment", "remove serverless service",
          "serverless destroy",
        ],
        command: "serverless remove {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        negativeKeywords: ["file", "files", "log", "directory", "folder", "old"],
        discriminators: ["serverless", "sls", "stack", "deployment"]
      ),
      CommandTemplate(
        id: "serverless_info",
        intents: [
          "serverless info", "sls info", "serverless service info",
          "show serverless deployment info", "serverless status",
          "what's deployed serverless",
        ],
        command: "serverless info {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        discriminators: ["info", "status", "deployed"]
      ),
      CommandTemplate(
        id: "serverless_offline",
        intents: [
          "serverless offline", "sls offline", "run serverless locally",
          "start serverless offline", "local serverless dev",
          "serverless local development",
        ],
        command: "serverless offline {FLAGS}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
        ],
        discriminators: ["offline", "local", "locally", "development"]
      ),
    ]
  )

  // MARK: - Media

  public static let media = TemplateCategory(
    id: "media",
    name: "Media",
    description: "Media processing: ffmpeg convert extract audio resize video, imagemagick convert resize identify, sips resize",
    templates: [
      CommandTemplate(
        id: "ffmpeg_convert",
        intents: [
          "convert video", "ffmpeg convert", "transcode video",
          "change video format", "convert video format",
          "convert mp4", "encode video",
        ],
        command: "ffmpeg -i {INPUT} {FLAGS} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:convert)\s+(\S+)"#),
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
          "OUTPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:to|as|output)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "ffmpeg_extract_audio",
        intents: [
          "extract audio from video", "ffmpeg extract audio",
          "rip audio from video", "get audio track",
          "video to audio", "extract sound from video",
        ],
        command: "ffmpeg -i {INPUT} -vn -acodec {CODEC} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:from)\s+(\S+)"#),
          "CODEC": SlotDefinition(type: .string, defaultValue: "libmp3lame"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "audio.mp3",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "ffmpeg_resize_video",
        intents: [
          "resize video", "scale video", "change video resolution",
          "downscale video", "ffmpeg resize",
          "shrink video dimensions",
        ],
        command: "ffmpeg -i {INPUT} -vf scale={WIDTH}:{HEIGHT} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:resize|scale)\s+(\S+)"#),
          "WIDTH": SlotDefinition(type: .number, defaultValue: "1280",
            extractPattern: #"(\d+)x\d+"#),
          "HEIGHT": SlotDefinition(type: .number, defaultValue: "-1",
            extractPattern: #"\d+x(\d+)"#),
          "OUTPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:to|as|output)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "ffmpeg_trim",
        intents: [
          "trim video", "cut video clip", "extract video segment",
          "ffmpeg trim", "clip video from to",
          "shorten video",
        ],
        command: "ffmpeg -i {INPUT} -ss {START} -t {DURATION} -c copy {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:trim|cut|clip)\s+(\S+)"#),
          "START": SlotDefinition(type: .string, defaultValue: "00:00:00",
            extractPattern: #"(?:from|start|at)\s+(\d[\d:\.]+)"#),
          "DURATION": SlotDefinition(type: .string, defaultValue: "00:00:30",
            extractPattern: #"(?:duration|for|length)\s+(\d[\d:\.]+)"#),
          "OUTPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:to|as|output)\s+(\S+)"#),
        ],
        discriminators: ["trim", "cut", "clip", "shorten", "segment"]
      ),
      CommandTemplate(
        id: "ffmpeg_gif",
        intents: [
          "video to gif", "make gif from video", "ffmpeg gif",
          "convert to animated gif", "create gif from video",
        ],
        command: "ffmpeg -i {INPUT} -vf 'fps={FPS},scale={WIDTH}:-1:flags=lanczos' {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:from)\s+(\S+)"#),
          "FPS": SlotDefinition(type: .number, defaultValue: "10"),
          "WIDTH": SlotDefinition(type: .number, defaultValue: "480"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "output.gif",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "ffmpeg_info",
        intents: [
          "video info", "ffprobe", "media file info",
          "get video metadata", "show video details",
          "video duration and format",
        ],
        command: "ffprobe -v quiet -print_format json -show_format -show_streams {INPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:info|details|metadata)\s+(?:of|for|about)?\s*(\S+)"#),
        ],
        discriminators: ["info", "metadata", "details", "duration", "format", "ffprobe"]
      ),
      // --- Wave 4: ffmpeg deep coverage (incant) ---
      CommandTemplate(
        id: "ffmpeg_h264",
        intents: [
          "encode video to h264", "transcode video to h.264",
          "convert video using libx264", "ffmpeg encode h264",
          "convert video to mp4 h264",
        ],
        command: "ffmpeg -i {INPUT} -c:v libx264 -preset {PRESET} -crf {CRF} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:encode|transcode|convert)\s+(\S+\.\w+)"#),
          "PRESET": SlotDefinition(type: .string, defaultValue: "medium",
            extractPattern: #"(?:preset)\s+(\w+)"#),
          "CRF": SlotDefinition(type: .number, defaultValue: "23",
            extractPattern: #"(?:crf|quality)\s+(\d+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "out.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["h264", "h.264", "libx264", "x264"]
      ),
      CommandTemplate(
        id: "ffmpeg_hevc_x265",
        intents: [
          "encode video to hevc software", "transcode to h.265 with x265",
          "convert video using libx265 software encoder",
          "ffmpeg hevc software encode",
        ],
        command: "ffmpeg -i {INPUT} -c:v libx265 -preset {PRESET} -crf {CRF} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:encode|transcode|convert)\s+(\S+\.\w+)"#),
          "PRESET": SlotDefinition(type: .string, defaultValue: "medium"),
          "CRF": SlotDefinition(type: .number, defaultValue: "28",
            extractPattern: #"(?:crf|quality)\s+(\d+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "out.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["x265", "libx265", "hevc software", "software hevc"]
      ),
      CommandTemplate(
        id: "ffmpeg_hevc_videotoolbox",
        intents: [
          "encode video to hevc using hardware",
          "transcode to h.265 with videotoolbox",
          "ffmpeg hevc hardware accelerated",
          "macos hardware accelerated hevc",
        ],
        command: "ffmpeg -i {INPUT} -c:v hevc_videotoolbox -b:v {BITRATE} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:encode|transcode|convert)\s+(\S+\.\w+)"#),
          "BITRATE": SlotDefinition(type: .string, defaultValue: "5M",
            extractPattern: #"(\d+[Mk])"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "out.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["hardware", "videotoolbox", "hevc hardware"],
        requires: ["flavor:ffmpeg=ffmpeg"]
      ),
      CommandTemplate(
        id: "ffmpeg_av1_svt",
        intents: [
          "encode to av1 with svt",
          "transcode to AV1 using libsvtav1",
          "ffmpeg av1 svt-av1 fast encode",
        ],
        command: "ffmpeg -i {INPUT} -c:v libsvtav1 -crf {CRF} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:encode|transcode|convert)\s+(\S+\.\w+)"#),
          "CRF": SlotDefinition(type: .number, defaultValue: "30"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "out.mkv",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["svt", "svt-av1", "libsvtav1"]
      ),
      CommandTemplate(
        id: "ffmpeg_av1_aom",
        intents: [
          "encode to av1 with aom",
          "transcode to AV1 using libaom-av1",
          "ffmpeg av1 aom encode",
        ],
        command: "ffmpeg -i {INPUT} -c:v libaom-av1 -crf {CRF} -b:v 0 {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:encode|transcode|convert)\s+(\S+\.\w+)"#),
          "CRF": SlotDefinition(type: .number, defaultValue: "30"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "out.mkv",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["aom", "libaom-av1", "aom av1"]
      ),
      CommandTemplate(
        id: "ffmpeg_crop",
        intents: [
          "crop video", "ffmpeg crop region",
          "trim sides off video", "cut a region from a video",
        ],
        command: "ffmpeg -i {INPUT} -filter:v 'crop={W}:{H}:{X}:{Y}' {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:crop)\s+(\S+\.\w+)"#),
          "W": SlotDefinition(type: .number, defaultValue: "1280"),
          "H": SlotDefinition(type: .number, defaultValue: "720"),
          "X": SlotDefinition(type: .number, defaultValue: "0"),
          "Y": SlotDefinition(type: .number, defaultValue: "0"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "cropped.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["crop video", "cut region", "crop=", "video crop"]
      ),
      CommandTemplate(
        id: "ffmpeg_pad",
        intents: [
          "pad video to aspect", "letterbox video",
          "add black bars to video",
          "ffmpeg pad video",
        ],
        command: "ffmpeg -i {INPUT} -vf 'pad={W}:{H}:(ow-iw)/2:(oh-ih)/2:black' {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:pad|letterbox)\s+(\S+\.\w+)"#),
          "W": SlotDefinition(type: .number, defaultValue: "1920"),
          "H": SlotDefinition(type: .number, defaultValue: "1080"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "padded.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["letterbox", "pad video", "black bars"]
      ),
      CommandTemplate(
        id: "ffmpeg_concat",
        intents: [
          "concatenate videos", "join multiple videos",
          "merge clips into one", "ffmpeg concat list",
        ],
        command: "ffmpeg -f concat -safe 0 -i {LIST} -c copy {OUTPUT}",
        slots: [
          "LIST": SlotDefinition(type: .path, defaultValue: "list.txt",
            extractPattern: #"(?:list)\s+(\S+\.txt)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "merged.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["concat", "concatenate", "merge clips", "join videos"]
      ),
      CommandTemplate(
        id: "ffmpeg_loop",
        intents: [
          "loop video N times", "ffmpeg stream_loop repeat video",
          "make video repeat N times",
        ],
        command: "ffmpeg -stream_loop {N} -i {INPUT} -c copy {OUTPUT}",
        slots: [
          "N": SlotDefinition(type: .number, defaultValue: "2",
            extractPattern: #"(\d+)\s*(?:times|x)"#),
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:loop|repeat)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "looped.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        negativeKeywords: ["from 1", "1 to", "for", "for loop", "for i", "seq"],
        discriminators: ["loop video", "stream_loop", "repeat video"]
      ),
      CommandTemplate(
        id: "ffmpeg_webp",
        intents: [
          "video to animated webp", "convert video to webp animation",
          "ffmpeg webp output animation",
        ],
        command: "ffmpeg -i {INPUT} -vf 'fps={FPS},scale={WIDTH}:-1' -loop 0 {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:webp|animation)\s+(\S+\.\w+)"#),
          "FPS": SlotDefinition(type: .number, defaultValue: "15"),
          "WIDTH": SlotDefinition(type: .number, defaultValue: "480"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "out.webp",
            extractPattern: #"(?:to|as|save)\s+(\S+\.webp)"#),
        ],
        discriminators: ["webp", "animated webp", "webp animation"]
      ),
      CommandTemplate(
        id: "ffmpeg_watermark",
        intents: [
          "add watermark to video", "overlay logo on video",
          "ffmpeg watermark image overlay",
        ],
        command: "ffmpeg -i {INPUT} -i {LOGO} -filter_complex 'overlay=10:10' {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:watermark)\s+(\S+\.\w+)"#),
          "LOGO": SlotDefinition(type: .path, defaultValue: "logo.png",
            extractPattern: #"(?:logo|watermark)\s+(\S+\.png)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "watermarked.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["watermark", "overlay logo", "video overlay"]
      ),
      CommandTemplate(
        id: "ffmpeg_burn_subs",
        intents: [
          "burn subtitles into video", "hardsub video file",
          "ffmpeg burn srt subtitles into video",
        ],
        command: "ffmpeg -i {INPUT} -vf 'subtitles={SUBS}' {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:burn|hardsub)\s+(\S+\.\w+)"#),
          "SUBS": SlotDefinition(type: .path, defaultValue: "subs.srt",
            extractPattern: #"(\S+\.srt)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "subbed.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["burn", "hardsub", "burn subtitles", "subtitles burned"]
      ),
      CommandTemplate(
        id: "ffmpeg_audio_mix",
        intents: [
          "mix two audio tracks", "ffmpeg amix combine audios",
          "blend music with narration",
        ],
        command: "ffmpeg -i {A} -i {B} -filter_complex 'amix=inputs=2:duration=longest' {OUTPUT}",
        slots: [
          "A": SlotDefinition(type: .path, extractPattern: #"(?:mix|combine)\s+(\S+\.\w+)"#),
          "B": SlotDefinition(type: .path, extractPattern: #"(?:with|and)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "mixed.m4a",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["amix", "mix audio", "combine audio", "blend audio"]
      ),
      CommandTemplate(
        id: "ffmpeg_normalize_audio",
        intents: [
          "normalize audio loudness", "ffmpeg loudnorm",
          "loudnorm broadcast standard",
        ],
        command: "ffmpeg -i {INPUT} -filter:a loudnorm {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:normalize|loudnorm)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "normalized.m4a",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["loudnorm", "normalize audio", "audio normalize"]
      ),
      CommandTemplate(
        id: "ffmpeg_frames",
        intents: [
          "extract video frames as images", "ffmpeg frames to png",
          "save video frames as png sequence",
        ],
        command: "ffmpeg -i {INPUT} -vf fps={FPS} {OUTPATTERN}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:frames|extract)\s+(\S+\.\w+)"#),
          "FPS": SlotDefinition(type: .number, defaultValue: "1",
            extractPattern: #"(\d+)\s*fps"#),
          "OUTPATTERN": SlotDefinition(type: .string, defaultValue: "frame_%04d.png"),
        ],
        discriminators: ["frames", "frame_", "frames as png"]
      ),
      CommandTemplate(
        id: "ffmpeg_thumbnail",
        intents: [
          "generate single thumbnail from video",
          "ffmpeg one thumbnail at time offset",
          "create poster image from video",
        ],
        command: "ffmpeg -ss {TIME} -i {INPUT} -vframes 1 {OUTPUT}",
        slots: [
          "TIME": SlotDefinition(type: .string, defaultValue: "00:00:01",
            extractPattern: #"(?:at)\s+(\d+(?::\d+)*)"#),
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:thumbnail|poster)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "poster.jpg",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["poster", "thumbnail at", "single thumbnail"]
      ),
      CommandTemplate(
        id: "ffmpeg_thumbnails_grid",
        intents: [
          "thumbnail grid from video", "ffmpeg tile thumbnails",
          "contact sheet from video",
        ],
        command: "ffmpeg -i {INPUT} -vf 'fps=1/{INTERVAL},scale=320:-1,tile={TILE}' {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:grid|tile)\s+(\S+\.\w+)"#),
          "INTERVAL": SlotDefinition(type: .number, defaultValue: "10"),
          "TILE": SlotDefinition(type: .string, defaultValue: "4x3"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "grid.jpg",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["thumbnail grid", "tile thumbnails", "contact sheet"]
      ),
      CommandTemplate(
        id: "ffmpeg_screen_record",
        intents: [
          "record screen to video", "ffmpeg screen recording avfoundation",
          "capture desktop to mp4",
        ],
        command: "ffmpeg -f avfoundation -framerate 30 -i 1 {OUTPUT}",
        slots: [
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "screen.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        negativeKeywords: ["TXT", "DNS", "dig", "MX", "lookup", "domain", "record for"],
        discriminators: ["screen record", "screen recording", "capture desktop", "avfoundation"]
      ),
      CommandTemplate(
        id: "ffmpeg_duration",
        intents: [
          "show video duration only", "ffprobe print duration",
          "get video length in seconds",
        ],
        command: "ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 {INPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:duration|length)\s+(?:of|for)?\s*(\S+)"#),
        ],
        discriminators: ["duration only", "length seconds", "video length", "show duration"]
      ),
      CommandTemplate(
        id: "ffmpeg_mute",
        intents: [
          "remove audio from video", "mute video track",
          "ffmpeg drop audio strip sound",
        ],
        command: "ffmpeg -i {INPUT} -an -c:v copy {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:mute|silence|remove)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "muted.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["mute", "remove audio", "silence video", "drop audio"]
      ),
      CommandTemplate(
        id: "ffmpeg_speed",
        intents: [
          "speed up video", "slow down video",
          "ffmpeg setpts speed change",
        ],
        command: "ffmpeg -i {INPUT} -filter:v 'setpts={PTS}*PTS' {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:speed|slow)\s+(\S+\.\w+)"#),
          "PTS": SlotDefinition(type: .string, defaultValue: "0.5",
            extractPattern: #"(?:by)\s+(\d+(?:\.\d+)?)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "speed.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["speed up", "slow down", "setpts", "speed change"]
      ),
      CommandTemplate(
        id: "ffmpeg_rotate_video",
        intents: [
          "rotate video", "ffmpeg transpose rotate video",
          "turn video 90 degrees",
        ],
        command: "ffmpeg -i {INPUT} -vf 'transpose={N}' {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:rotate|turn)\s+(\S+\.\w+)"#),
          "N": SlotDefinition(type: .number, defaultValue: "1",
            extractPattern: #"(?:transpose)\s+(\d)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "rotated.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["rotate video", "transpose", "video transpose"]
      ),
      CommandTemplate(
        id: "ffmpeg_hls_segment",
        intents: [
          "segment video for hls streaming",
          "ffmpeg hls m3u8 output",
          "create hls playlist from video",
        ],
        command: "ffmpeg -i {INPUT} -codec: copy -hls_time {SEG} -hls_playlist_type vod {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:hls|segment)\s+(\S+\.\w+)"#),
          "SEG": SlotDefinition(type: .number, defaultValue: "10"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "playlist.m3u8",
            extractPattern: #"(?:to|as|save)\s+(\S+\.m3u8)"#),
        ],
        discriminators: ["hls", "m3u8", "playlist", "hls streaming"]
      ),
      CommandTemplate(
        id: "ffmpeg_dash_segment",
        intents: [
          "segment video for dash streaming",
          "ffmpeg mpd dash output",
          "create dash manifest from video",
        ],
        command: "ffmpeg -i {INPUT} -map 0 -codec:v libx264 -codec:a aac -f dash {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:dash|segment)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "manifest.mpd",
            extractPattern: #"(?:to|as|save)\s+(\S+\.mpd)"#),
        ],
        discriminators: ["dash", "mpd", "dash manifest"]
      ),
      CommandTemplate(
        id: "ffmpeg_change_resolution",
        intents: [
          "change video resolution preserving aspect",
          "ffmpeg -2 keep aspect ratio scale",
          "scale video preserving aspect",
        ],
        command: "ffmpeg -i {INPUT} -vf 'scale={W}:-2' {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:scale|resize)\s+(\S+\.\w+)"#),
          "W": SlotDefinition(type: .number, defaultValue: "1280"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "scaled.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["preserving aspect", "preserve aspect", "scale -2", "keep aspect"]
      ),
      CommandTemplate(
        id: "ffmpeg_extract_subs",
        intents: [
          "extract subtitles from video",
          "ffmpeg dump srt from mkv",
          "rip subtitle track from container",
        ],
        command: "ffmpeg -i {INPUT} -map 0:s:0 {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:extract|dump|rip)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "subs.srt",
            extractPattern: #"(?:to|as|save)\s+(\S+\.srt)"#),
        ],
        discriminators: ["extract subtitles", "dump srt", "rip subtitle"]
      ),
      CommandTemplate(
        id: "ffmpeg_remux",
        intents: [
          "remux video container without re-encode",
          "ffmpeg copy streams change container",
          "switch container without transcoding",
        ],
        command: "ffmpeg -i {INPUT} -c copy {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:remux)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "out.mkv",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["remux", "copy streams", "switch container", "without transcoding"]
      ),
      CommandTemplate(
        id: "ffmpeg_concat_demuxer",
        intents: [
          "concat videos via concat protocol",
          "ffmpeg concat:protocol join mpegts",
        ],
        command: "ffmpeg -i 'concat:{LIST}' -c copy {OUTPUT}",
        slots: [
          "LIST": SlotDefinition(type: .string, defaultValue: "a.ts|b.ts"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "joined.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["concat protocol", "concat:", "mpegts join"]
      ),
      CommandTemplate(
        id: "ffmpeg_audio_only",
        intents: [
          "extract audio only stream copy",
          "ffmpeg -vn -acodec copy audio rip",
          "save just the audio track without re-encode",
        ],
        command: "ffmpeg -i {INPUT} -vn -acodec copy {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:rip|extract)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "audio.m4a",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["audio copy", "stream copy", "audio only", "without re-encode"]
      ),
      CommandTemplate(
        id: "ffmpeg_volume",
        intents: [
          "change video volume level", "ffmpeg volume gain",
          "boost or lower audio volume",
        ],
        command: "ffmpeg -i {INPUT} -filter:a 'volume={GAIN}' {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:volume|gain)\s+(\S+\.\w+)"#),
          "GAIN": SlotDefinition(type: .string, defaultValue: "1.5",
            extractPattern: #"(?:to|by)\s+(\d+(?:\.\d+)?|\d+dB)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "voladj.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["volume gain", "audio volume", "boost volume", "lower volume"]
      ),
      CommandTemplate(
        id: "ffmpeg_two_pass",
        intents: [
          "two pass encode video", "ffmpeg 2-pass libx264 fixed bitrate",
          "encode video with bitrate constraint two passes",
        ],
        command: "ffmpeg -y -i {INPUT} -c:v libx264 -b:v {BITRATE} -pass 1 -an -f mp4 /dev/null && ffmpeg -i {INPUT} -c:v libx264 -b:v {BITRATE} -pass 2 {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:encode|2-pass|two pass)\s+(\S+\.\w+)"#),
          "BITRATE": SlotDefinition(type: .string, defaultValue: "2M"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "out.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        negativeKeywords: ["ln", "-s", "symlink", "source target"],
        discriminators: ["two pass", "2-pass", "pass 1", "pass 2", "fixed bitrate"]
      ),
      CommandTemplate(
        id: "ffmpeg_fade_in",
        intents: [
          "add fade in to video",
          "ffmpeg fade=in fade in effect",
        ],
        command: "ffmpeg -i {INPUT} -vf 'fade=t=in:st=0:d={D}' {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:fade|fade-in)\s+(\S+\.\w+)"#),
          "D": SlotDefinition(type: .number, defaultValue: "1"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "fade.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["fade in", "fade=t=in", "fade-in"]
      ),
      CommandTemplate(
        id: "ffmpeg_concat_filter",
        intents: [
          "concatenate clips using concat filter",
          "ffmpeg concat filtergraph",
        ],
        command: "ffmpeg -i {A} -i {B} -filter_complex '[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[v][a]' -map '[v]' -map '[a]' {OUTPUT}",
        slots: [
          "A": SlotDefinition(type: .path, extractPattern: #"(?:concat|merge)\s+(\S+\.\w+)"#),
          "B": SlotDefinition(type: .path, extractPattern: #"(?:and|with)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "joined.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["concat filter", "filtergraph concat"]
      ),
      CommandTemplate(
        id: "ffmpeg_replace_audio",
        intents: [
          "replace audio track of video",
          "ffmpeg swap audio in video",
          "replace soundtrack with new audio",
        ],
        command: "ffmpeg -i {VIDEO} -i {AUDIO} -c:v copy -map 0:v:0 -map 1:a:0 -shortest {OUTPUT}",
        slots: [
          "VIDEO": SlotDefinition(type: .path, extractPattern: #"(?:replace|swap)\s+(\S+\.\w+)"#),
          "AUDIO": SlotDefinition(type: .path, extractPattern: #"(?:with)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "newaudio.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["replace audio", "swap audio", "soundtrack", "new audio"]
      ),
      CommandTemplate(
        id: "ffmpeg_extract_clip",
        intents: [
          "extract a clip between two timestamps",
          "ffmpeg cut clip from start to end",
          "snip a portion between times",
        ],
        command: "ffmpeg -ss {START} -to {END} -i {INPUT} -c copy {OUTPUT}",
        slots: [
          "START": SlotDefinition(type: .string, defaultValue: "00:00:00",
            extractPattern: #"(?:from|start)\s+(\d[\d:.]+)"#),
          "END": SlotDefinition(type: .string, defaultValue: "00:00:30",
            extractPattern: #"(?:to|end)\s+(\d[\d:.]+)"#),
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:clip|snip|cut)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "clip.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["timestamps", "snip", "between two times", "from start to end"]
      ),
      CommandTemplate(
        id: "ffmpeg_low_bitrate",
        intents: [
          "encode low bitrate video for messaging",
          "ffmpeg compress video small file",
          "make video tiny for sharing",
        ],
        command: "ffmpeg -i {INPUT} -c:v libx264 -crf 35 -preset slow -c:a aac -b:a 64k {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:compress|tiny)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "small.mp4",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["low bitrate", "small file", "tiny for sharing", "for messaging"]
      ),
      CommandTemplate(
        id: "magick_convert",
        intents: [
          "convert image format", "imagemagick convert",
          "change image format", "convert png to jpg",
          "convert jpg to png", "image format conversion",
        ],
        command: "{IM_CMD} {INPUT} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:convert)\s+(\S+)"#),
          "OUTPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:to|as|into)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "magick_resize",
        intents: [
          "resize image", "scale image", "shrink image",
          "imagemagick resize", "change image size",
          "make image smaller", "enlarge image",
        ],
        command: "{IM_CMD} {INPUT} -resize {SIZE} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:resize|scale|shrink)\s+(\S+)"#),
          "SIZE": SlotDefinition(type: .string, defaultValue: "50%",
            extractPattern: #"(?:to)\s+(\d+x\d+|\d+%)"#),
          "OUTPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:as|save|output)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "magick_identify",
        intents: [
          "image info", "identify image", "image dimensions",
          "imagemagick identify", "image metadata",
          "what size is this image",
        ],
        command: "{IM_CMD} identify -verbose {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path,
            extractPattern: #"(?:identify|info|details)\s+(?:of|for|about)?\s*(\S+)"#),
        ]
      ),
      // --- Wave 3: imagemagick deep coverage (incant) ---
      CommandTemplate(
        id: "magick_crop",
        intents: [
          "crop image", "crop a region from image", "imagemagick crop",
          "cut out a section of image", "trim image to box",
          "magick -crop region",
        ],
        command: "{IM_CMD} {INPUT} -crop {GEOMETRY} +repage {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:crop|cut)\s+(\S+\.\w+)"#),
          "GEOMETRY": SlotDefinition(type: .string, defaultValue: "800x600+0+0",
            extractPattern: #"(\d+x\d+(?:[+-]\d+)?(?:[+-]\d+)?)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "cropped.png",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["crop", "region", "section", "cut out"]
      ),
      CommandTemplate(
        id: "magick_rotate",
        intents: [
          "rotate image", "rotate image by degrees", "imagemagick rotate",
          "turn image 90 degrees", "rotate by N degrees",
        ],
        command: "{IM_CMD} {INPUT} -rotate {DEGREES} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:rotate)\s+(\S+\.\w+)"#),
          "DEGREES": SlotDefinition(type: .number, defaultValue: "90",
            extractPattern: #"(\d+)\s*(?:deg|degree)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "rotated.png",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["rotate", "degrees", "turn"]
      ),
      CommandTemplate(
        id: "magick_flip",
        intents: [
          "flip image vertically", "mirror image vertically",
          "imagemagick flip", "flip top bottom",
        ],
        command: "{IM_CMD} {INPUT} -flip {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:flip|mirror)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "flipped.png",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["flip", "vertical", "vertically", "top to bottom"]
      ),
      CommandTemplate(
        id: "magick_flop",
        intents: [
          "flop image horizontally", "mirror image horizontally",
          "imagemagick flop", "flip left right",
        ],
        command: "{IM_CMD} {INPUT} -flop {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:flop|mirror)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "flopped.png",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["flop", "horizontal", "horizontally", "left to right"]
      ),
      CommandTemplate(
        id: "magick_quality",
        intents: [
          "change image quality", "imagemagick quality compression",
          "set jpeg quality", "compress image quality 85",
        ],
        command: "{IM_CMD} {INPUT} -quality {Q} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:compress|quality)\s+(\S+\.\w+)"#),
          "Q": SlotDefinition(type: .number, defaultValue: "85",
            extractPattern: #"(?:quality)\s+(\d+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "compressed.jpg",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["quality", "jpeg quality", "compression level"]
      ),
      CommandTemplate(
        id: "magick_strip",
        intents: [
          "strip image metadata", "remove exif data",
          "imagemagick strip metadata", "clean image metadata",
          "drop image metadata",
        ],
        command: "{IM_CMD} {INPUT} -strip {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:strip|metadata)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "stripped.jpg",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["strip metadata", "remove metadata", "exif", "clean metadata"]
      ),
      CommandTemplate(
        id: "magick_compose",
        intents: [
          "composite two images", "imagemagick composite",
          "overlay image on another",
          "overlay X on Y",
          "overlay logo on cover",
          "overlay watermark on photo",
          "combine two pictures",
          "place one image on top of another",
        ],
        command: "{IM_CMD} composite {OVERLAY} {BASE} {OUTPUT}",
        slots: [
          "OVERLAY": SlotDefinition(type: .path,
            extractPattern: #"(?:overlay|on top)\s+(\S+\.\w+)"#),
          "BASE": SlotDefinition(type: .path,
            extractPattern: #"(?:on|onto|over)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "composite.png",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["composite", "overlay on", "on top of", "combine images"]
      ),
      CommandTemplate(
        id: "magick_montage",
        intents: [
          "montage of images", "imagemagick montage grid",
          "tile multiple images into grid",
          "combine images into contact sheet",
        ],
        command: "{IM_CMD} montage {PATTERN} -tile {TILE} -geometry {GEOMETRY} {OUTPUT}",
        slots: [
          "PATTERN": SlotDefinition(type: .glob, defaultValue: "*.jpg",
            extractPattern: #"(\*\.\w+)"#),
          "TILE": SlotDefinition(type: .string, defaultValue: "4x",
            extractPattern: #"(\d+x\d*)"#),
          "GEOMETRY": SlotDefinition(type: .string, defaultValue: "200x200+5+5"),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "montage.jpg",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["montage", "grid of", "contact sheet", "tile images"]
      ),
      CommandTemplate(
        id: "magick_annotate",
        intents: [
          "annotate image with text", "add caption to image",
          "imagemagick add text overlay",
          "label image with caption",
        ],
        command: "{IM_CMD} {INPUT} -gravity south -pointsize 36 -annotate +0+10 '{TEXT}' {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:annotate|caption|label)\s+(\S+\.\w+)"#),
          "TEXT": SlotDefinition(type: .string, defaultValue: "TEXT",
            extractPattern: #"(?:text|caption|label)\s+['\"]([^'\"]+)['\"]"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "annotated.jpg",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["annotate", "caption", "label", "text overlay"]
      ),
      CommandTemplate(
        id: "magick_blur",
        intents: [
          "blur image", "imagemagick blur",
          "apply blur to image", "gaussian blur image",
        ],
        command: "{IM_CMD} {INPUT} -blur {SIGMA} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:blur)\s+(\S+\.\w+)"#),
          "SIGMA": SlotDefinition(type: .string, defaultValue: "0x8",
            extractPattern: #"(?:blur)\s+(\d+x\d+|\d+\.\d+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "blurred.png",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["blur", "gaussian", "soften"]
      ),
      CommandTemplate(
        id: "magick_sharpen",
        intents: [
          "sharpen image", "imagemagick sharpen",
          "enhance image sharpness", "unsharp mask image",
        ],
        command: "{IM_CMD} {INPUT} -sharpen {SIGMA} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:sharpen|enhance)\s+(\S+\.\w+)"#),
          "SIGMA": SlotDefinition(type: .string, defaultValue: "0x4",
            extractPattern: #"(\d+x\d+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "sharpened.png",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["sharpen", "unsharp", "enhance sharpness"]
      ),
      CommandTemplate(
        id: "magick_grayscale",
        intents: [
          "convert image to grayscale", "imagemagick grayscale",
          "make image black and white", "desaturate image",
        ],
        command: "{IM_CMD} {INPUT} -colorspace Gray {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:grayscale|gray|desaturate)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "gray.png",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["grayscale", "gray", "black and white", "desaturate"]
      ),
      CommandTemplate(
        id: "magick_sepia",
        intents: [
          "apply sepia to image", "imagemagick sepia tone",
          "make image sepia", "vintage sepia effect",
        ],
        command: "{IM_CMD} {INPUT} -sepia-tone {PCT} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:sepia|vintage)\s+(\S+\.\w+)"#),
          "PCT": SlotDefinition(type: .string, defaultValue: "80%",
            extractPattern: #"(\d+%)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "sepia.jpg",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["sepia", "vintage tone", "sepia effect"]
      ),
      CommandTemplate(
        id: "magick_brightness",
        intents: [
          "change image brightness", "imagemagick brightness contrast",
          "adjust image brightness",
        ],
        command: "{IM_CMD} {INPUT} -brightness-contrast {LEVELS} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:brighten|brightness|adjust)\s+(\S+\.\w+)"#),
          "LEVELS": SlotDefinition(type: .string, defaultValue: "20x10",
            extractPattern: #"([+-]?\d+x[+-]?\d+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "bright.jpg",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["brightness", "brightness contrast", "brighten"]
      ),
      CommandTemplate(
        id: "magick_contrast",
        intents: [
          "increase image contrast", "imagemagick contrast",
          "boost image contrast",
        ],
        command: "{IM_CMD} {INPUT} -contrast {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:contrast|boost)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "contrast.jpg",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["contrast", "boost contrast"]
      ),
      CommandTemplate(
        id: "magick_border",
        intents: [
          "add border to image", "imagemagick border",
          "frame image with border",
        ],
        command: "{IM_CMD} {INPUT} -bordercolor {COLOR} -border {SIZE} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:border|frame)\s+(\S+\.\w+)"#),
          "COLOR": SlotDefinition(type: .string, defaultValue: "white",
            extractPattern: #"(?:color)\s+(\w+|#[0-9a-fA-F]{6})"#),
          "SIZE": SlotDefinition(type: .string, defaultValue: "10x10",
            extractPattern: #"(\d+x\d+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "bordered.jpg",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["border", "frame", "add border"]
      ),
      CommandTemplate(
        id: "magick_trim",
        intents: [
          "trim whitespace around image", "imagemagick trim",
          "auto-crop empty borders",
        ],
        command: "{IM_CMD} {INPUT} -trim +repage {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:trim|auto-crop)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "trimmed.png",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["trim whitespace", "auto-crop", "trim empty"]
      ),
      CommandTemplate(
        id: "magick_optimize",
        intents: [
          "optimize image for web", "imagemagick optimize",
          "shrink image for web",
        ],
        command: "{IM_CMD} {INPUT} -strip -interlace Plane -gaussian-blur 0.05 -quality 85% {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:optimize)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "optimized.jpg",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["optimize", "for web", "shrink for web"]
      ),
      CommandTemplate(
        id: "magick_exif",
        intents: [
          "show exif data", "imagemagick exif",
          "read photo metadata", "image exif info",
          "display exif tags", "view photo exif",
        ],
        command: "{IM_CMD} identify -format '%[EXIF:*]' {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path,
            extractPattern: #"(?:exif|metadata|of|for)\s+(\S+)"#),
        ],
        negativeKeywords: ["remove", "strip", "drop", "clean"],
        discriminators: ["show exif", "view exif", "display exif", "read metadata"]
      ),
      CommandTemplate(
        id: "magick_batch_resize",
        intents: [
          "batch resize images", "imagemagick mogrify resize all",
          "resize all images in a directory",
          "shrink every jpg in folder",
        ],
        command: "mogrify -resize {SIZE} {PATTERN}",
        slots: [
          "SIZE": SlotDefinition(type: .string, defaultValue: "50%",
            extractPattern: #"(\d+x\d+|\d+%)"#),
          "PATTERN": SlotDefinition(type: .glob, defaultValue: "*.jpg",
            extractPattern: #"(\*\.\w+)"#),
        ],
        discriminators: ["batch resize", "mogrify", "resize all"]
      ),
      CommandTemplate(
        id: "magick_invert",
        intents: [
          "invert image colors", "imagemagick negate",
          "make negative of image",
        ],
        command: "{IM_CMD} {INPUT} -negate {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:invert|negate|negative)\s+(\S+\.\w+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "inverted.png",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["invert colors", "negate", "negative image"]
      ),
      CommandTemplate(
        id: "magick_thumbnail",
        intents: [
          "create thumbnail of image", "imagemagick thumbnail",
          "generate small preview of image",
        ],
        command: "{IM_CMD} {INPUT} -thumbnail {SIZE} {OUTPUT}",
        slots: [
          "INPUT": SlotDefinition(type: .path, extractPattern: #"(?:thumbnail|preview)\s+(\S+\.\w+)"#),
          "SIZE": SlotDefinition(type: .string, defaultValue: "200x200",
            extractPattern: #"(\d+x\d+)"#),
          "OUTPUT": SlotDefinition(type: .path, defaultValue: "thumb.jpg",
            extractPattern: #"(?:to|as|save)\s+(\S+)"#),
        ],
        discriminators: ["thumbnail", "thumb", "small preview"]
      ),
      CommandTemplate(
        id: "sips_convert",
        intents: [
          "sips convert", "convert image with sips",
          "sips format change", "sips png to jpeg",
          "macOS image convert",
        ],
        command: "sips -s format {FORMAT} {INPUT} --out {OUTPUT}",
        slots: [
          "FORMAT": SlotDefinition(type: .string, defaultValue: "jpeg",
            extractPattern: #"(?:to|format)\s+(\w+)"#),
          "INPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:convert)\s+(\S+)"#),
          "OUTPUT": SlotDefinition(type: .path,
            extractPattern: #"(?:as|out|save)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "sips_getprop",
        intents: [
          "sips image properties", "image width height sips",
          "sips get property", "check image dimensions sips",
          "sips pixel size",
        ],
        command: "sips -g pixelWidth -g pixelHeight {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path,
            extractPattern: #"(?:of|for|check)\s+(\S+)"#),
        ]
      ),
    ]
  )

  // MARK: - Shell Scripting

  public static let shellScripting = TemplateCategory(
    id: "shell_scripting",
    name: "Shell Scripting",
    description: "Shell scripting patterns: for loops, while loops, if then, subshells, process substitution, command substitution, here documents",
    templates: [
      CommandTemplate(
        id: "for_files",
        intents: [
          "for loop over files", "iterate files", "loop through files",
          "for each file", "run command on each file",
          "process each file in directory",
        ],
        command: "for f in {PATTERN}; do {COMMAND} \"$f\"; done",
        slots: [
          "PATTERN": SlotDefinition(type: .glob, defaultValue: "*",
            extractPattern: #"(?:in|over|matching)\s+(\S+)"#),
          "COMMAND": SlotDefinition(type: .command, defaultValue: "echo",
            extractPattern: #"(?:do|run|execute)\s+(.+?)(?:\s+(?:on|for))"#),
        ]
      ),
      CommandTemplate(
        id: "for_range",
        intents: [
          "for loop range", "loop n times", "repeat command",
          "for i in sequence", "count loop",
          "run command n times",
        ],
        command: "for i in $(seq 1 {END}); do {COMMAND}; done",
        slots: [
          "END": SlotDefinition(type: .number, defaultValue: "10",
            extractPattern: #"(\d+)\s+times?"#),
          "COMMAND": SlotDefinition(type: .command, defaultValue: "echo $i"),
        ]
      ),
      CommandTemplate(
        id: "for_lines",
        intents: [
          "loop over lines in file", "read file line by line",
          "for each line", "iterate lines in file",
          "process file line by line",
        ],
        command: "while IFS= read -r line; do {COMMAND} \"$line\"; done < {FILE}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:in|of|from)\s+(\S+)"#),
          "COMMAND": SlotDefinition(type: .command, defaultValue: "echo"),
        ]
      ),
      CommandTemplate(
        id: "while_true",
        intents: [
          "infinite loop", "while true", "loop forever",
          "repeat until stopped", "continuous loop",
          "keep running command",
        ],
        command: "while true; do {COMMAND}; sleep {INTERVAL}; done",
        slots: [
          "COMMAND": SlotDefinition(type: .command,
            extractPattern: #"(?:run|do|execute)\s+(.+?)(?:\s+every)"#),
          "INTERVAL": SlotDefinition(type: .number, defaultValue: "1",
            extractPattern: #"(?:every|each)\s+(\d+)"#),
        ]
      ),
      CommandTemplate(
        id: "if_file_exists",
        intents: [
          "if file exists", "check if file exists", "test file existence",
          "does file exist", "conditional on file",
          "run if file present",
        ],
        command: "if [ -f {FILE} ]; then {COMMAND}; fi",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:file|exists)\s+(\S+)"#),
          "COMMAND": SlotDefinition(type: .command, defaultValue: "echo 'exists'"),
        ]
      ),
      CommandTemplate(
        id: "if_dir_exists",
        intents: [
          "if directory exists", "check if directory exists",
          "test directory existence", "does directory exist",
          "conditional on directory",
        ],
        command: "if [ -d {DIR} ]; then {COMMAND}; fi",
        slots: [
          "DIR": SlotDefinition(type: .path,
            extractPattern: #"(?:directory|dir|folder)\s+(\S+)"#),
          "COMMAND": SlotDefinition(type: .command, defaultValue: "echo 'exists'"),
        ]
      ),
      CommandTemplate(
        id: "if_command_succeeds",
        intents: [
          "if command succeeds", "run if successful",
          "conditional on command", "check exit code then run",
          "if then else",
        ],
        command: "if {TEST}; then {COMMAND}; else {FALLBACK}; fi",
        slots: [
          "TEST": SlotDefinition(type: .command,
            extractPattern: #"(?:if)\s+(.+?)(?:\s+then)"#),
          "COMMAND": SlotDefinition(type: .command,
            extractPattern: #"(?:then|run)\s+(.+?)(?:\s+else)"#),
          "FALLBACK": SlotDefinition(type: .command, defaultValue: "echo 'failed'"),
        ]
      ),
      CommandTemplate(
        id: "subshell",
        intents: [
          "run in subshell", "subshell command", "isolated command",
          "run without affecting environment", "parenthesized command",
        ],
        command: "({COMMAND})",
        slots: [
          "COMMAND": SlotDefinition(type: .command,
            extractPattern: #"(?:run|execute)\s+(.+?)(?:\s+in\s+subshell)"#),
        ]
      ),
      CommandTemplate(
        id: "command_substitution",
        intents: [
          "command substitution", "capture output", "store output in variable",
          "save command output", "assign output to variable",
          "backtick command",
        ],
        command: "{VAR}=$({COMMAND})",
        slots: [
          "VAR": SlotDefinition(type: .string, defaultValue: "result",
            extractPattern: #"(?:variable|var|as)\s+(\w+)"#),
          "COMMAND": SlotDefinition(type: .command,
            extractPattern: #"(?:output\s+of|capture|run)\s+(.+)"#),
        ]
      ),
      CommandTemplate(
        id: "process_substitution",
        intents: [
          "process substitution", "diff two commands",
          "compare output of two commands", "feed command as file",
          "treat output as file",
        ],
        command: "diff <({CMD1}) <({CMD2})",
        slots: [
          "CMD1": SlotDefinition(type: .command,
            extractPattern: #"(?:compare|diff)\s+(.+?)(?:\s+(?:and|with|vs))"#),
          "CMD2": SlotDefinition(type: .command,
            extractPattern: #"(?:and|with|vs)\s+(.+)"#),
        ]
      ),
      CommandTemplate(
        id: "here_document",
        intents: [
          "here document", "heredoc", "multiline input",
          "pass multiline string", "cat heredoc",
          "write multiline to file",
        ],
        command: "cat << 'EOF' > {FILE}\n{CONTENT}\nEOF",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:to|into|file)\s+(\S+)"#),
          "CONTENT": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(?:content|text|write)\s+(.+)"#),
        ]
      ),
      CommandTemplate(
        id: "watch_command",
        intents: [
          "watch command output", "repeat command periodically",
          "monitor command", "watch changes",
          "run every n seconds and show",
          "run command every seconds", "watch every seconds",
          "run periodically", "execute every interval",
        ],
        command: "while true; do clear; {COMMAND}; sleep {INTERVAL}; done",
        slots: [
          "COMMAND": SlotDefinition(type: .command,
            extractPattern: #"(?:watch|monitor|run)\s+(.+?)(?:\s+every)"#),
          "INTERVAL": SlotDefinition(type: .number, defaultValue: "2",
            extractPattern: #"(?:every)\s+(\d+)"#),
        ],
        negativeKeywords: ["git", "diff", "staged", "status", "commit", "branch"],
        discriminators: ["every", "seconds", "periodically", "repeat", "interval"]
      ),
    ]
  )

  // MARK: - Crypto (Wave 5: openssl deep coverage / incant)
  // Templates use {OPENSSL_CMD} so macOS LibreSSL users transparently
  // pick up Homebrew's OpenSSL 3 when installed. Templates that depend on
  // OpenSSL 3-specific flags or LibreSSL-incompatible flags use
  // requires:["capability:openssl.v3"] / requires:["flavor:openssl=openssl"]
  // for soft demotion on incompatible profiles.

  public static let crypto = TemplateCategory(
    id: "crypto",
    name: "Crypto",
    description: "Cryptography and certificates: openssl x509 certificate, csr, private key, public key, hash, base64 encode decode, AES encryption, password generation, TLS connection inspection",
    templates: [
      CommandTemplate(
        id: "random_password",
        intents: [
          "generate password", "random password", "create password",
          "generate random string", "random token",
          "generate secret", "secure password",
        ],
        command: "{OPENSSL_CMD} rand -base64 {LENGTH}",
        slots: [
          "LENGTH": SlotDefinition(type: .number, defaultValue: "32",
            extractPattern: #"(\d+)\s*(?:char|byte|length)"#),
        ]
      ),
      CommandTemplate(
        id: "openssl_check",
        intents: [
          "check ssl certificate", "test ssl handshake",
          "ssl handshake info", "check https endpoint",
          "openssl s_client connect", "inspect ssl handshake",
        ],
        command: "{OPENSSL_CMD} s_client -connect {HOST}:443 -brief <<< ''",
        slots: [
          "HOST": SlotDefinition(type: .string,
            extractPattern: #"(?:for|of|on)\s+(\S+)"#),
        ],
        discriminators: ["s_client", "handshake", "connect", "ssl handshake"]
      ),
      CommandTemplate(
        id: "openssl_x509_text",
        intents: [
          "view certificate details", "openssl x509 -text",
          "show full cert info", "decode pem certificate",
          "print certificate fields",
        ],
        command: "{OPENSSL_CMD} x509 -in {CERT} -text -noout",
        slots: [
          "CERT": SlotDefinition(type: .path, defaultValue: "cert.pem",
            extractPattern: #"(?:cert|in|file)\s+(\S+\.(?:pem|crt|cer))"#),
        ],
        discriminators: ["x509", "-text", "view cert", "decode pem"]
      ),
      CommandTemplate(
        id: "openssl_x509_dates",
        intents: [
          "show certificate validity dates",
          "openssl x509 -dates",
          "cert valid from to",
          "show notBefore notAfter",
        ],
        command: "{OPENSSL_CMD} x509 -in {CERT} -noout -dates",
        slots: [
          "CERT": SlotDefinition(type: .path, defaultValue: "cert.pem",
            extractPattern: #"(?:cert|in|file)\s+(\S+\.(?:pem|crt|cer))"#),
        ],
        discriminators: ["validity dates", "notBefore", "notAfter", "expires", "-dates"]
      ),
      CommandTemplate(
        id: "openssl_x509_subject",
        intents: [
          "show certificate subject",
          "openssl x509 -subject",
          "print cert subject",
        ],
        command: "{OPENSSL_CMD} x509 -in {CERT} -noout -subject",
        slots: [
          "CERT": SlotDefinition(type: .path, defaultValue: "cert.pem",
            extractPattern: #"(?:cert|in|file)\s+(\S+\.(?:pem|crt|cer))"#),
        ],
        discriminators: ["subject", "-subject", "cert subject"]
      ),
      CommandTemplate(
        id: "openssl_x509_issuer",
        intents: [
          "show certificate issuer",
          "openssl x509 -issuer",
          "print cert issuer",
        ],
        command: "{OPENSSL_CMD} x509 -in {CERT} -noout -issuer",
        slots: [
          "CERT": SlotDefinition(type: .path, defaultValue: "cert.pem",
            extractPattern: #"(?:cert|in|file)\s+(\S+\.(?:pem|crt|cer))"#),
        ],
        discriminators: ["issuer", "-issuer", "ca that signed"]
      ),
      CommandTemplate(
        id: "openssl_x509_fingerprint",
        intents: [
          "show certificate fingerprint",
          "openssl x509 -fingerprint",
          "sha256 fingerprint of cert",
        ],
        command: "{OPENSSL_CMD} x509 -in {CERT} -noout -fingerprint -sha256",
        slots: [
          "CERT": SlotDefinition(type: .path, defaultValue: "cert.pem",
            extractPattern: #"(?:cert|in|file)\s+(\S+\.(?:pem|crt|cer))"#),
        ],
        discriminators: ["fingerprint", "-fingerprint", "sha256 of cert"]
      ),
      CommandTemplate(
        id: "openssl_verify_chain",
        intents: [
          "verify certificate chain",
          "openssl verify cert against ca",
          "validate cert chain",
        ],
        command: "{OPENSSL_CMD} verify -CAfile {CA} {CERT}",
        slots: [
          "CA": SlotDefinition(type: .path, defaultValue: "ca.pem",
            extractPattern: #"(?:against|ca|CAfile)\s+(\S+\.(?:pem|crt))"#),
          "CERT": SlotDefinition(type: .path, defaultValue: "cert.pem",
            extractPattern: #"(?:cert)\s+(\S+\.(?:pem|crt|cer))"#),
        ],
        discriminators: ["verify", "validate chain", "CAfile", "verify chain"]
      ),
      CommandTemplate(
        id: "openssl_genrsa",
        intents: [
          "generate rsa private key",
          "openssl genrsa 4096",
          "create rsa key pair",
        ],
        command: "{OPENSSL_CMD} genrsa -out {KEY} {BITS}",
        slots: [
          "KEY": SlotDefinition(type: .path, defaultValue: "private.key",
            extractPattern: #"(?:out|to|as)\s+(\S+\.key)"#),
          "BITS": SlotDefinition(type: .number, defaultValue: "4096",
            extractPattern: #"(\d{4})"#),
        ],
        discriminators: ["genrsa", "rsa private", "rsa key"]
      ),
      CommandTemplate(
        id: "openssl_genec",
        intents: [
          "generate ec private key",
          "openssl ecparam ec key",
          "create elliptic curve key",
        ],
        command: "{OPENSSL_CMD} ecparam -name {CURVE} -genkey -noout -out {KEY}",
        slots: [
          "CURVE": SlotDefinition(type: .string, defaultValue: "prime256v1",
            extractPattern: #"(?:curve|name)\s+(\S+)"#),
          "KEY": SlotDefinition(type: .path, defaultValue: "ec.key",
            extractPattern: #"(?:out|to|as)\s+(\S+\.key)"#),
        ],
        discriminators: ["ec key", "ecparam", "elliptic curve", "ecdsa"]
      ),
      CommandTemplate(
        id: "openssl_gened25519",
        intents: [
          "generate ed25519 private key",
          "openssl genpkey ed25519",
          "create ed25519 key",
        ],
        command: "{OPENSSL_CMD} genpkey -algorithm ed25519 -out {KEY}",
        slots: [
          "KEY": SlotDefinition(type: .path, defaultValue: "ed25519.key",
            extractPattern: #"(?:out|to|as)\s+(\S+\.key)"#),
        ],
        discriminators: ["ed25519", "edwards"],
        requires: ["capability:openssl.v3"]
      ),
      CommandTemplate(
        id: "openssl_pubkey",
        intents: [
          "extract public key from private key",
          "openssl rsa -pubout",
          "derive public from private",
        ],
        command: "{OPENSSL_CMD} pkey -in {KEY} -pubout -out {PUB}",
        slots: [
          "KEY": SlotDefinition(type: .path, defaultValue: "private.key",
            extractPattern: #"(?:from|in)\s+(\S+\.key)"#),
          "PUB": SlotDefinition(type: .path, defaultValue: "public.pem",
            extractPattern: #"(?:out|to|as)\s+(\S+\.pem)"#),
        ],
        discriminators: ["public key", "pubout", "derive public", "extract pubkey"]
      ),
      CommandTemplate(
        id: "openssl_csr_new",
        intents: [
          "create CSR certificate signing request",
          "openssl req -new",
          "generate csr from key",
        ],
        command: "{OPENSSL_CMD} req -new -key {KEY} -out {CSR} -subj '{SUBJ}'",
        slots: [
          "KEY": SlotDefinition(type: .path, defaultValue: "private.key",
            extractPattern: #"(?:key)\s+(\S+\.key)"#),
          "CSR": SlotDefinition(type: .path, defaultValue: "request.csr",
            extractPattern: #"(?:out|as)\s+(\S+\.csr)"#),
          "SUBJ": SlotDefinition(type: .string, defaultValue: "/CN=example.com",
            extractPattern: #"(?:subj|subject)\s+(/[A-Z]+=[^\s]+(?:/[A-Z]+=[^\s]+)*)"#),
        ],
        discriminators: ["csr", "signing request", "req -new"]
      ),
      CommandTemplate(
        id: "openssl_csr_view",
        intents: [
          "view csr details",
          "openssl req -in -text",
          "decode csr",
        ],
        command: "{OPENSSL_CMD} req -in {CSR} -noout -text",
        slots: [
          "CSR": SlotDefinition(type: .path, defaultValue: "request.csr",
            extractPattern: #"(?:csr|in|file)\s+(\S+\.csr)"#),
        ],
        discriminators: ["view csr", "decode csr", "csr details"]
      ),
      CommandTemplate(
        id: "openssl_self_signed",
        intents: [
          "create self-signed certificate",
          "openssl req -x509",
          "generate self signed cert",
        ],
        command: "{OPENSSL_CMD} req -x509 -newkey rsa:{BITS} -keyout {KEY} -out {CERT} -days {DAYS} -nodes -subj '{SUBJ}'",
        slots: [
          "BITS": SlotDefinition(type: .number, defaultValue: "4096"),
          "KEY": SlotDefinition(type: .path, defaultValue: "key.pem"),
          "CERT": SlotDefinition(type: .path, defaultValue: "cert.pem",
            extractPattern: #"(?:out|cert)\s+(\S+\.(?:pem|crt))"#),
          "DAYS": SlotDefinition(type: .number, defaultValue: "365",
            extractPattern: #"(\d+)\s+days?"#),
          "SUBJ": SlotDefinition(type: .string, defaultValue: "/CN=example.com",
            extractPattern: #"(?:subj|subject)\s+(/[A-Z]+=[^\s]+(?:/[A-Z]+=[^\s]+)*)"#),
        ],
        discriminators: ["self-signed", "self signed", "req -x509"]
      ),
      CommandTemplate(
        id: "openssl_p12_export",
        intents: [
          "export pkcs12 bundle",
          "openssl pkcs12 -export",
          "create p12 from cert and key",
        ],
        command: "{OPENSSL_CMD} pkcs12 -export -inkey {KEY} -in {CERT} -out {OUT}",
        slots: [
          "KEY": SlotDefinition(type: .path, defaultValue: "private.key",
            extractPattern: #"(?:key)\s+(\S+\.key)"#),
          "CERT": SlotDefinition(type: .path, defaultValue: "cert.pem",
            extractPattern: #"(?:cert|in)\s+(\S+\.(?:pem|crt))"#),
          "OUT": SlotDefinition(type: .path, defaultValue: "bundle.p12",
            extractPattern: #"(?:out|as)\s+(\S+\.p12)"#),
        ],
        discriminators: ["pkcs12", "p12", "export bundle"]
      ),
      CommandTemplate(
        id: "openssl_p12_import",
        intents: [
          "extract cert and key from pkcs12",
          "openssl pkcs12 -in",
          "import p12 contents",
        ],
        command: "{OPENSSL_CMD} pkcs12 -in {P12} -nodes -out {OUT}",
        slots: [
          "P12": SlotDefinition(type: .path, defaultValue: "bundle.p12",
            extractPattern: #"(?:in|from)\s+(\S+\.p12)"#),
          "OUT": SlotDefinition(type: .path, defaultValue: "out.pem",
            extractPattern: #"(?:out|to)\s+(\S+\.pem)"#),
        ],
        discriminators: ["pkcs12 import", "p12 import", "extract from p12"]
      ),
      CommandTemplate(
        id: "openssl_pem_to_der",
        intents: [
          "convert pem certificate to der",
          "openssl x509 outform DER",
          "pem to der",
        ],
        command: "{OPENSSL_CMD} x509 -in {PEM} -outform DER -out {DER}",
        slots: [
          "PEM": SlotDefinition(type: .path, defaultValue: "cert.pem",
            extractPattern: #"(?:in|from)\s+(\S+\.pem)"#),
          "DER": SlotDefinition(type: .path, defaultValue: "cert.der",
            extractPattern: #"(?:out|to|as)\s+(\S+\.der)"#),
        ],
        discriminators: ["pem to der", "outform DER", "convert to der"]
      ),
      CommandTemplate(
        id: "openssl_der_to_pem",
        intents: [
          "convert der certificate to pem",
          "openssl x509 inform DER",
          "der to pem",
        ],
        command: "{OPENSSL_CMD} x509 -inform DER -in {DER} -out {PEM}",
        slots: [
          "DER": SlotDefinition(type: .path, defaultValue: "cert.der",
            extractPattern: #"(?:in|from)\s+(\S+\.der)"#),
          "PEM": SlotDefinition(type: .path, defaultValue: "cert.pem",
            extractPattern: #"(?:out|to|as)\s+(\S+\.pem)"#),
        ],
        discriminators: ["der to pem", "inform DER", "convert from der"]
      ),
      CommandTemplate(
        id: "openssl_pkcs8",
        intents: [
          "convert key to pkcs8 format",
          "openssl pkcs8 -topk8",
          "convert rsa key to pkcs8",
        ],
        command: "{OPENSSL_CMD} pkcs8 -topk8 -in {KEY} -out {OUT} -nocrypt",
        slots: [
          "KEY": SlotDefinition(type: .path, defaultValue: "private.key",
            extractPattern: #"(?:in|from)\s+(\S+\.(?:key|pem))"#),
          "OUT": SlotDefinition(type: .path, defaultValue: "key.p8",
            extractPattern: #"(?:out|as)\s+(\S+\.(?:p8|pem))"#),
        ],
        discriminators: ["pkcs8", "topk8", "p8 format"]
      ),
      CommandTemplate(
        id: "openssl_sha256",
        intents: [
          "sha256 sum a file using openssl",
          "openssl dgst -sha256",
          "compute sha256 hash with openssl",
        ],
        command: "{OPENSSL_CMD} dgst -sha256 {FILE}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:hash|sum|of|file)\s+(\S+)"#),
        ],
        discriminators: ["sha256", "dgst -sha256", "openssl sha256"]
      ),
      CommandTemplate(
        id: "openssl_sha512",
        intents: [
          "sha512 sum a file using openssl",
          "openssl dgst -sha512",
          "compute sha512 hash with openssl",
        ],
        command: "{OPENSSL_CMD} dgst -sha512 {FILE}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:hash|sum|of|file)\s+(\S+)"#),
        ],
        discriminators: ["sha512", "dgst -sha512"]
      ),
      CommandTemplate(
        id: "openssl_hmac",
        intents: [
          "compute hmac of file",
          "openssl dgst -hmac",
          "hmac sha256 with secret",
        ],
        command: "{OPENSSL_CMD} dgst -sha256 -hmac '{SECRET}' {FILE}",
        slots: [
          "SECRET": SlotDefinition(type: .string, defaultValue: "SECRET",
            extractPattern: #"(?:secret|key)\s+['\"]?(\w+)['\"]?"#),
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:hmac|of|file)\s+(\S+)"#),
        ],
        discriminators: ["hmac", "-hmac", "hmac sha256"]
      ),
      CommandTemplate(
        id: "openssl_base64_encode",
        intents: [
          "base64 encode file with openssl",
          "openssl enc -base64",
          "encode binary to base64",
        ],
        command: "{OPENSSL_CMD} base64 -in {FILE} -out {OUT}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:encode|in|of)\s+(\S+)"#),
          "OUT": SlotDefinition(type: .path, defaultValue: "encoded.b64",
            extractPattern: #"(?:out|to|as)\s+(\S+)"#),
        ],
        discriminators: ["base64 encode", "enc -base64", "to base64"]
      ),
      CommandTemplate(
        id: "openssl_base64_decode",
        intents: [
          "base64 decode file with openssl",
          "openssl base64 -d",
          "decode base64 back to binary",
        ],
        command: "{OPENSSL_CMD} base64 -d -in {FILE} -out {OUT}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:decode|in|from)\s+(\S+\.b64|\S+\.txt)"#),
          "OUT": SlotDefinition(type: .path, defaultValue: "decoded.bin",
            extractPattern: #"(?:out|to|as)\s+(\S+)"#),
        ],
        discriminators: ["base64 decode", "decode base64", "-base64 -d"]
      ),
      CommandTemplate(
        id: "openssl_aes_encrypt",
        intents: [
          "aes encrypt file",
          "openssl enc aes-256-cbc",
          "encrypt file with aes",
        ],
        command: "{OPENSSL_CMD} enc -aes-256-cbc -salt -pbkdf2 -in {FILE} -out {OUT}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:encrypt|in|of)\s+(\S+)"#),
          "OUT": SlotDefinition(type: .path, defaultValue: "encrypted.enc",
            extractPattern: #"(?:out|to|as)\s+(\S+)"#),
        ],
        discriminators: ["aes encrypt", "aes-256-cbc", "encrypt file"]
      ),
      CommandTemplate(
        id: "openssl_aes_decrypt",
        intents: [
          "aes decrypt file",
          "openssl enc -d aes-256-cbc",
          "decrypt aes file",
        ],
        command: "{OPENSSL_CMD} enc -d -aes-256-cbc -pbkdf2 -in {FILE} -out {OUT}",
        slots: [
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:decrypt|in|from)\s+(\S+)"#),
          "OUT": SlotDefinition(type: .path, defaultValue: "decrypted.bin",
            extractPattern: #"(?:out|to|as)\s+(\S+)"#),
        ],
        discriminators: ["aes decrypt", "decrypt file", "enc -d"]
      ),
      CommandTemplate(
        id: "openssl_dhparam",
        intents: [
          "generate dh params for tls",
          "openssl dhparam 2048",
          "create diffie hellman params",
        ],
        command: "{OPENSSL_CMD} dhparam -out {OUT} {BITS}",
        slots: [
          "OUT": SlotDefinition(type: .path, defaultValue: "dhparam.pem",
            extractPattern: #"(?:out|as)\s+(\S+\.pem)"#),
          "BITS": SlotDefinition(type: .number, defaultValue: "2048",
            extractPattern: #"(\d{4})"#),
        ],
        discriminators: ["dhparam", "diffie hellman", "dh params"]
      ),
      CommandTemplate(
        id: "openssl_rand_hex",
        intents: [
          "generate random hex string",
          "openssl rand -hex N",
          "random hex token",
        ],
        command: "{OPENSSL_CMD} rand -hex {LENGTH}",
        slots: [
          "LENGTH": SlotDefinition(type: .number, defaultValue: "16",
            extractPattern: #"(\d+)\s*(?:hex|bytes?)?"#),
        ],
        discriminators: ["random hex", "rand -hex", "hex token"]
      ),
      CommandTemplate(
        id: "openssl_match_key",
        intents: [
          "verify key matches certificate",
          "openssl modulus check key matches cert",
          "match key to cert",
        ],
        command: "diff <({OPENSSL_CMD} x509 -in {CERT} -noout -modulus | md5) <({OPENSSL_CMD} rsa -in {KEY} -noout -modulus | md5)",
        slots: [
          "CERT": SlotDefinition(type: .path, defaultValue: "cert.pem",
            extractPattern: #"(?:cert)\s+(\S+\.(?:pem|crt))"#),
          "KEY": SlotDefinition(type: .path, defaultValue: "private.key",
            extractPattern: #"(?:key)\s+(\S+\.key)"#),
        ],
        discriminators: ["modulus", "key matches", "match key", "matches cert"]
      ),
      CommandTemplate(
        id: "openssl_pem_extract_chain",
        intents: [
          "split pem bundle into individual certs",
          "openssl extract chain certs",
          "separate concatenated certificates",
        ],
        command: "csplit -z -f cert- -b '%02d.pem' {BUNDLE} '/-----BEGIN CERTIFICATE-----/' '{*}'",
        slots: [
          "BUNDLE": SlotDefinition(type: .path, defaultValue: "chain.pem",
            extractPattern: #"(?:bundle|chain|from|in)\s+(\S+\.pem)"#),
        ],
        discriminators: ["split bundle", "split pem", "separate certs", "extract chain"]
      ),
    ]
  )
}

// swiftlint:enable function_body_length file_length
