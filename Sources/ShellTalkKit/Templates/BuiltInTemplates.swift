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
    compression, cloud, media, shellScripting,
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
          "EXT": SlotDefinition(type: .string,
            extractPattern: #"(?:find|list|show)\s+(?:all\s+)?\.?(\w+)\s+files|files?\s+(?:with\s+)?\.(\w+)"#),
        ]
      ),
      CommandTemplate(
        id: "find_by_mtime",
        intents: [
          "find files modified today", "recently modified files",
          "files changed in the last week", "find files modified recently",
          "find recent files", "what files changed today",
          "show recently edited files",
        ],
        command: "find {PATH} -type f -mtime -{DAYS}",
        slots: [
          "PATH": SlotDefinition(type: .path, defaultValue: "."),
          "DAYS": SlotDefinition(type: .number, defaultValue: "1",
            extractPattern: #"(?:last|past)\s+(\d+)\s+days?|(\d+)\s+days?\s+ago"#),
        ],
        negativeKeywords: ["who", "blame", "author", "wrote"]
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
          "SIZE": SlotDefinition(type: .string, defaultValue: "1M",
            extractPattern: #"(?:larger|bigger|over|above)\s+(?:than\s+)?(\d+[kKmMgG]?[bB]?)"#),
        ]
      ),
      CommandTemplate(
        id: "cp_file",
        intents: [
          "copy file", "copy files", "duplicate file",
          "make a copy of", "cp", "copy from to",
        ],
        command: "cp {FLAGS} {SOURCE} {DEST}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: ""),
          "SOURCE": SlotDefinition(type: .path, extractPattern: #"copy\s+(\S+)"#),
          "DEST": SlotDefinition(type: .path, extractPattern: #"(?:to|into)\s+(\S+)"#),
        ]
      ),
      CommandTemplate(
        id: "mv_file",
        intents: [
          "move file", "rename file", "mv", "move files",
          "rename files", "move from to",
        ],
        command: "mv {SOURCE} {DEST}",
        slots: [
          "SOURCE": SlotDefinition(type: .path, extractPattern: #"(?:move|rename)\s+(\S+)"#),
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
        ],
        command: "git reset {FLAGS} {REF}",
        slots: [
          "FLAGS": SlotDefinition(type: .string, defaultValue: "",
            extractPattern: #"(--hard|--soft|--mixed)"#),
          "REF": SlotDefinition(type: .string, defaultValue: "HEAD",
            extractPattern: #"(?:to|reset)\s+([a-f0-9]{6,40}|HEAD~?\d*)"#),
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
        ],
        command: "grep -rn '{PATTERN}' {PATH}",
        slots: [
          "PATTERN": SlotDefinition(type: .pattern,
            extractPattern: #"(?:search|grep|find|for|of)\s+['\"]?(\S+)['\"]?"#),
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
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:from|in|of)\s+(\S+)"#),
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
          "FILE": SlotDefinition(type: .path,
            extractPattern: #"(?:from|in)\s+(\S+)"#),
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
                           "request", "get", "post", "http", "url", "sure"]
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
        ]
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
        ]
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
        ]
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
            extractPattern: #"(?:to)\s+(https?://\S+)|(https?://\S+)"#),
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
        negativeKeywords: ["safari", "chrome", "finder", "app", "application", "xcode", "list", "directory", "folder"]
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
          "space usage by directory",
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
          "npm i package",
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
        ],
        command: "tar -czf {ARCHIVE} {PATH}",
        slots: [
          "ARCHIVE": SlotDefinition(type: .path,
            extractPattern: #"(?:as|to|into|named?)\s+(\S+\.tar(?:\.\w+)?)"#),
          "PATH": SlotDefinition(type: .path, defaultValue: ".",
            extractPattern: #"(?:archive|compress|tar)\s+(\S+)"#),
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
                           "node", "npm", "nuke", "test"],
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
      CommandTemplate(
        id: "magick_convert",
        intents: [
          "convert image format", "imagemagick convert",
          "change image format", "convert png to jpg",
          "convert jpg to png", "image format conversion",
        ],
        command: "magick {INPUT} {OUTPUT}",
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
        command: "magick {INPUT} -resize {SIZE} {OUTPUT}",
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
        command: "magick identify -verbose {PATH}",
        slots: [
          "PATH": SlotDefinition(type: .path,
            extractPattern: #"(?:identify|info|details)\s+(?:of|for|about)?\s*(\S+)"#),
        ]
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
}

// swiftlint:enable function_body_length file_length
