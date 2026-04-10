// STMAccuracyTests.swift — Comprehensive accuracy evaluation for ShellTalk STM pipeline
//
// ~540 test cases across all 168 templates (3 variations each) plus cross-category
// ambiguity tests and negative/edge cases.
//
// Run: swift test --filter STMAccuracy
// Report: swift test --filter "AccuracyReport" 2>&1 | grep -A9999 "ACCURACY REPORT"

import Testing
@testable import ShellTalkKit
import Foundation

// MARK: - Test Case Definition

struct EvalCase: Sendable, CustomTestStringConvertible {
  let query: String
  let expectedTemplateId: String
  let expectedCategoryId: String
  let requiredSubstrings: [String]
  let forbiddenSubstrings: [String]
  let requiredSlots: [String: String]
  let description: String

  var testDescription: String { description }

  init(
    _ query: String,
    template: String,
    category: String,
    required: [String] = [],
    forbidden: [String] = [],
    slots: [String: String] = [:],
    _ description: String
  ) {
    self.query = query
    self.expectedTemplateId = template
    self.expectedCategoryId = category
    self.requiredSubstrings = required
    self.forbiddenSubstrings = forbidden
    self.requiredSlots = slots
    self.description = description
  }
}

// MARK: - Shared Pipeline

private let pipeline = STMPipeline()

// MARK: - Assertion Helper

private func assertAccuracy(_ tc: EvalCase) {
  let result = pipeline.process(tc.query)
  #expect(result != nil, "Nil result for: \(tc.query)")
  guard let result else { return }

  #expect(result.templateId == tc.expectedTemplateId,
    "Template: expected \(tc.expectedTemplateId), got \(result.templateId) for: \(tc.query)")
  #expect(result.categoryId == tc.expectedCategoryId,
    "Category: expected \(tc.expectedCategoryId), got \(result.categoryId) for: \(tc.query)")

  for substr in tc.requiredSubstrings {
    #expect(result.command.contains(substr),
      "Command '\(result.command)' missing '\(substr)' for: \(tc.query)")
  }
  for substr in tc.forbiddenSubstrings {
    #expect(!result.command.contains(substr),
      "Command '\(result.command)' has forbidden '\(substr)' for: \(tc.query)")
  }
  for (slot, expected) in tc.requiredSlots {
    #expect(result.extractedSlots[slot] == expected,
      "Slot \(slot): expected '\(expected)', got '\(result.extractedSlots[slot] ?? "nil")' for: \(tc.query)")
  }
}

// MARK: - File Operations (51 tests)

@Suite("STMAccuracy")
struct STMAccuracyTests {

  @Suite("FileOps")
  struct FileOpsAccuracy {
    static let cases: [EvalCase] = [
      // ls_files
      EvalCase("ls", template: "ls_files", category: "file_ops", required: ["ls"], "Terse: bare ls"),
      EvalCase("show me all the files in the current directory with details", template: "ls_files", category: "file_ops", required: ["ls"], "Verbose: list files naturally"),
      EvalCase("what's in this folder", template: "ls_files", category: "file_ops", required: ["ls"], "Colloquial: folder contents"),

      // find_by_name
      EvalCase("find files named config.yaml", template: "find_by_name", category: "file_ops", required: ["find", "-name", "config.yaml"], slots: ["PATTERN": "config.yaml"], "Direct: find by name"),
      EvalCase("where are the files called .gitignore", template: "find_by_name", category: "file_ops", required: ["find", "-name"], "Natural: locate by name"),
      EvalCase("find DS_Store files", template: "find_by_name", category: "file_ops", required: ["find", "-name"], "Edge: dotfile pattern"),

      // find_by_extension
      EvalCase("find swift files", template: "find_by_extension", category: "file_ops", required: ["find", "*.swift"], slots: ["EXT": "swift"], "Direct: find by extension"),
      EvalCase("show me the yaml files in ~/Projects", template: "find_by_extension", category: "file_ops", required: ["find", "*.yaml"], "Natural: with path"),
      EvalCase("find all .json files", template: "find_by_extension", category: "file_ops", required: ["find", "*.json"], "With dot prefix on ext"),

      // find_by_mtime
      EvalCase("find files modified today", template: "find_by_mtime", category: "file_ops", required: ["find", "-mtime"], "Direct: recently modified"),
      EvalCase("what files changed in the last 3 days", template: "find_by_mtime", category: "file_ops", required: ["find", "-mtime"], slots: ["DAYS": "3"], "Natural: with day count"),
      EvalCase("show recently edited files", template: "find_by_mtime", category: "file_ops", required: ["find", "-mtime"], "Synonym: edited for modified"),

      // find_large_files
      EvalCase("find files larger than 100M", template: "find_large_files", category: "file_ops", required: ["find", "-size"], slots: ["SIZE": "100M"], "Direct: with size"),
      EvalCase("what are the largest files in this directory", template: "find_large_files", category: "file_ops", required: ["find", "-size"], "Natural: biggest files"),
      EvalCase("find huge files over 1G", template: "find_large_files", category: "file_ops", required: ["find", "-size"], "Synonym: huge with GB"),

      // cp_file
      EvalCase("copy main.swift to backup/", template: "cp_file", category: "file_ops", required: ["cp"], slots: ["SOURCE": "main.swift", "DEST": "backup/"], "Direct: copy with src/dest"),
      EvalCase("make a copy of package.json to /tmp", template: "cp_file", category: "file_ops", required: ["cp"], "Natural: duplicate phrasing"),
      EvalCase("duplicate the config file", template: "cp_file", category: "file_ops", required: ["cp"], "Synonym: duplicate"),

      // mv_file
      EvalCase("move old.txt to archive/", template: "mv_file", category: "file_ops", required: ["mv"], slots: ["SOURCE": "old.txt", "DEST": "archive/"], "Direct: move with paths"),
      EvalCase("rename config.yml as config.yaml", template: "mv_file", category: "file_ops", required: ["mv"], "Natural: rename synonym"),
      EvalCase("mv README.md to docs/", template: "mv_file", category: "file_ops", required: ["mv", "README.md", "docs/"], "Terse: bare mv"),

      // rm_file
      EvalCase("delete temp.txt", template: "rm_file", category: "file_ops", required: ["rm"], slots: ["PATH": "temp.txt"], "Direct: delete file"),
      EvalCase("remove the old log files", template: "rm_file", category: "file_ops", required: ["rm"], "Natural: remove phrasing"),
      EvalCase("trash build artifacts", template: "rm_file", category: "file_ops", required: ["rm"], "Synonym: trash"),

      // mkdir_dir
      EvalCase("create directory src/models", template: "mkdir_dir", category: "file_ops", required: ["mkdir", "-p"], slots: ["PATH": "src/models"], "Direct: create directory"),
      EvalCase("make a new folder called output", template: "mkdir_dir", category: "file_ops", required: ["mkdir", "-p"], "Natural: new folder"),
      EvalCase("mkdir tests/fixtures", template: "mkdir_dir", category: "file_ops", required: ["mkdir", "-p", "tests/fixtures"], "Terse: bare mkdir"),

      // chmod_perms
      EvalCase("make script.sh executable", template: "chmod_perms", category: "file_ops", required: ["chmod"], "Natural: make executable"),
      EvalCase("change permissions on deploy.sh", template: "chmod_perms", category: "file_ops", required: ["chmod"], "Direct: change permissions"),
      EvalCase("chmod 755 server.sh", template: "chmod_perms", category: "file_ops", required: ["chmod"], "Terse: with numeric mode"),

      // du_disk_usage
      EvalCase("disk usage", template: "du_disk_usage", category: "file_ops", required: ["du", "-sh"], "Terse: disk usage"),
      EvalCase("how much space is the src directory using", template: "du_disk_usage", category: "file_ops", required: ["du", "-sh"], "Natural: space question"),
      EvalCase("size of directory node_modules", template: "du_disk_usage", category: "file_ops", required: ["du", "-sh"], "Natural: size of dir"),

      // file_count
      EvalCase("count files", template: "file_count", category: "file_ops", required: ["find", "wc", "-l"], "Direct: count files"),
      EvalCase("how many files are in this directory", template: "file_count", category: "file_ops", required: ["find", "wc"], "Natural: how many files"),
      EvalCase("how many swift files are there", template: "file_count", category: "file_ops", required: ["find", "wc"], "With file type filter"),

      // tree_view
      EvalCase("tree", template: "tree_view", category: "file_ops", required: ["find"], "Terse: tree command"),
      EvalCase("show directory structure", template: "tree_view", category: "file_ops", required: ["find"], "Natural: directory structure"),
      EvalCase("project structure 2 levels deep", template: "tree_view", category: "file_ops", required: ["find"], "With depth parameter"),

      // file_info
      EvalCase("file info for main.swift", template: "file_info", category: "file_ops", required: ["file"], "Direct: file info"),
      EvalCase("what type of file is output.bin", template: "file_info", category: "file_ops", required: ["file"], "Natural: file type question"),
      EvalCase("stat file README.md", template: "file_info", category: "file_ops", required: ["stat"], "Terse: stat command"),

      // touch_file
      EvalCase("create empty file notes.txt", template: "touch_file", category: "file_ops", required: ["touch"], "Direct: create empty file"),
      EvalCase("touch README.md", template: "touch_file", category: "file_ops", required: ["touch", "README.md"], "Terse: touch command"),
      EvalCase("make new file todo.txt", template: "touch_file", category: "file_ops", required: ["touch"], "Natural: make new file"),

      // symlink
      EvalCase("create symlink to /usr/local/bin/app", template: "symlink", category: "file_ops", required: ["ln", "-s"], "Direct: create symlink"),
      EvalCase("make a symbolic link to config.yaml", template: "symlink", category: "file_ops", required: ["ln", "-s"], "Natural: symbolic link"),
      EvalCase("ln -s source target", template: "symlink", category: "file_ops", required: ["ln", "-s"], "Terse: bare ln -s"),
    ]

    @Test("File operations accuracy", arguments: FileOpsAccuracy.cases)
    func verify(_ tc: EvalCase) { assertAccuracy(tc) }
  }

  // MARK: - Git (60 tests)

  @Suite("Git")
  struct GitAccuracy {
    static let cases: [EvalCase] = [
      // git_status
      EvalCase("git status", template: "git_status", category: "git", required: ["git status"], "Terse: exact command"),
      EvalCase("what files have I changed", template: "git_status", category: "git", required: ["git status"], "Natural: what changed"),
      EvalCase("show me uncommitted changes", template: "git_status", category: "git", required: ["git status"], "Natural: uncommitted"),

      // git_diff
      EvalCase("git diff", template: "git_diff", category: "git", required: ["git diff"], "Terse: exact command"),
      EvalCase("show me what's different", template: "git_diff", category: "git", required: ["git diff"], "Natural: what's different"),
      EvalCase("compare changes in main.swift", template: "git_diff", category: "git", required: ["git diff"], "With specific file"),

      // git_diff_staged
      EvalCase("show staged diff", template: "git_diff_staged", category: "git", required: ["git diff", "--cached"], "Direct: staged diff"),
      EvalCase("what's staged for commit", template: "git_diff_staged", category: "git", required: ["git diff", "--cached"], "Natural: what's staged"),
      EvalCase("show what will be committed", template: "git_diff_staged", category: "git", required: ["git diff", "--cached"], "Natural: will be committed"),

      // git_log
      EvalCase("git log", template: "git_log", category: "git", required: ["git log", "--oneline"], "Terse: git log"),
      EvalCase("show last 5 commits", template: "git_log", category: "git", required: ["git log", "--oneline"], slots: ["COUNT": "5"], "Natural: with count"),
      EvalCase("recent commit history", template: "git_log", category: "git", required: ["git log"], "Natural: recent history"),

      // git_log_graph
      EvalCase("git log graph", template: "git_log_graph", category: "git", required: ["git log", "--graph", "--all"], "Direct: log graph"),
      EvalCase("show branch tree", template: "git_log_graph", category: "git", required: ["git log", "--graph"], "Natural: branch tree"),
      EvalCase("visual git history", template: "git_log_graph", category: "git", required: ["git log", "--graph"], "Natural: visual log"),

      // git_add
      EvalCase("git add main.swift", template: "git_add", category: "git", required: ["git add"], "Terse: git add with file"),
      EvalCase("stage all changes", template: "git_add", category: "git", required: ["git add"], "Natural: stage changes"),
      EvalCase("add files to staging area", template: "git_add", category: "git", required: ["git add"], "Natural: add to staging"),

      // git_commit
      EvalCase("git commit", template: "git_commit", category: "git", required: ["git commit", "-m"], "Terse: git commit"),
      EvalCase("commit changes with message fix login bug", template: "git_commit", category: "git", required: ["git commit", "-m"], "Natural: with message"),
      EvalCase("save changes to git", template: "git_commit", category: "git", required: ["git commit"], "Natural: save changes"),

      // git_branch_list
      EvalCase("git branch", template: "git_branch_list", category: "git", required: ["git branch"], "Terse: git branch"),
      EvalCase("list all branches", template: "git_branch_list", category: "git", required: ["git branch"], "Natural: list branches"),
      EvalCase("what branches exist", template: "git_branch_list", category: "git", required: ["git branch"], "Natural: what branches"),

      // git_branch_create
      EvalCase("create branch feature/auth", template: "git_branch_create", category: "git", required: ["git checkout", "-b"], slots: ["BRANCH": "feature/auth"], "Direct: create named branch"),
      EvalCase("make a new branch called hotfix", template: "git_branch_create", category: "git", required: ["git checkout", "-b"], "Natural: new branch"),
      EvalCase("git checkout -b develop", template: "git_branch_create", category: "git", required: ["git checkout", "-b"], "Terse: exact command"),

      // git_switch
      EvalCase("switch to main", template: "git_switch", category: "git", required: ["git switch"], slots: ["BRANCH": "main"], "Direct: switch branch"),
      EvalCase("checkout the develop branch", template: "git_switch", category: "git", required: ["git switch"], "Natural: checkout branch"),
      EvalCase("go to branch feature/login", template: "git_switch", category: "git", required: ["git switch"], "Natural: go to branch"),

      // git_stash
      EvalCase("git stash", template: "git_stash", category: "git", required: ["git stash"], forbidden: ["pop"], "Terse: git stash"),
      EvalCase("stash my current changes", template: "git_stash", category: "git", required: ["git stash"], forbidden: ["pop"], "Natural: stash changes"),
      EvalCase("put aside my work temporarily", template: "git_stash", category: "git", required: ["git stash"], "Natural: put aside"),

      // git_stash_pop
      EvalCase("git stash pop", template: "git_stash_pop", category: "git", required: ["git stash pop"], "Terse: stash pop"),
      EvalCase("restore my stashed changes", template: "git_stash_pop", category: "git", required: ["git stash pop"], "Natural: restore stash"),
      EvalCase("get back stashed changes", template: "git_stash_pop", category: "git", required: ["git stash pop"], "Natural: get back stash"),

      // git_merge
      EvalCase("merge develop", template: "git_merge", category: "git", required: ["git merge"], slots: ["BRANCH": "develop"], "Direct: merge branch"),
      EvalCase("combine the feature branch into current", template: "git_merge", category: "git", required: ["git merge"], "Natural: combine branches"),
      EvalCase("git merge hotfix/payment", template: "git_merge", category: "git", required: ["git merge"], "Terse: with branch path"),

      // git_rebase
      EvalCase("git rebase main", template: "git_rebase", category: "git", required: ["git rebase"], "Terse: rebase on main"),
      EvalCase("rebase onto master", template: "git_rebase", category: "git", required: ["git rebase"], "Natural: rebase onto"),
      EvalCase("rebase my branch on develop", template: "git_rebase", category: "git", required: ["git rebase"], "Natural: rebase on branch"),

      // git_remote
      EvalCase("git remote", template: "git_remote", category: "git", required: ["git remote", "-v"], "Terse: git remote"),
      EvalCase("show remotes", template: "git_remote", category: "git", required: ["git remote"], "Natural: show remotes"),
      EvalCase("what is the origin url", template: "git_remote", category: "git", required: ["git remote"], "Natural: origin url"),

      // git_pull
      EvalCase("git pull", template: "git_pull", category: "git", required: ["git pull"], "Terse: git pull"),
      EvalCase("pull latest changes from remote", template: "git_pull", category: "git", required: ["git pull"], "Natural: pull latest"),
      EvalCase("update from remote", template: "git_pull", category: "git", required: ["git pull"], "Natural: update from remote"),

      // git_push
      EvalCase("git push", template: "git_push", category: "git", required: ["git push"], "Terse: git push"),
      EvalCase("push my commits to the remote", template: "git_push", category: "git", required: ["git push"], "Natural: push commits"),
      EvalCase("upload changes to origin", template: "git_push", category: "git", required: ["git push"], "Natural: upload changes"),

      // git_blame
      EvalCase("git blame main.swift", template: "git_blame", category: "git", required: ["git blame"], "Terse: git blame"),
      EvalCase("who changed AppDelegate.swift", template: "git_blame", category: "git", required: ["git blame"], "Natural: who changed"),
      EvalCase("show line authors for Package.swift", template: "git_blame", category: "git", required: ["git blame"], "Natural: line authors"),

      // git_cherry_pick
      EvalCase("cherry pick abc1234", template: "git_cherry_pick", category: "git", required: ["git cherry-pick", "abc1234"], slots: ["COMMIT": "abc1234"], "Direct: with SHA"),
      EvalCase("git cherry-pick deadbeef", template: "git_cherry_pick", category: "git", required: ["git cherry-pick", "deadbeef"], "Terse: with SHA"),
      EvalCase("apply specific commit a1b2c3d", template: "git_cherry_pick", category: "git", required: ["git cherry-pick"], "Natural: apply commit"),

      // git_tag
      EvalCase("git tag v1.0.0", template: "git_tag", category: "git", required: ["git tag", "v1.0.0"], slots: ["TAG": "v1.0.0"], "Terse: git tag"),
      EvalCase("create tag for release 2.1", template: "git_tag", category: "git", required: ["git tag"], "Natural: create tag"),
      EvalCase("tag this as v3.0", template: "git_tag", category: "git", required: ["git tag"], "Natural: tag version"),
    ]

    @Test("Git accuracy", arguments: GitAccuracy.cases)
    func verify(_ tc: EvalCase) { assertAccuracy(tc) }
  }

  // MARK: - Text Processing (48 tests)

  @Suite("TextProcessing")
  struct TextProcessingAccuracy {
    static let cases: [EvalCase] = [
      // grep_search
      EvalCase("grep TODO in src/", template: "grep_search", category: "text_processing", required: ["grep", "-rn", "TODO"], "Direct: grep with pattern"),
      EvalCase("search for error in all log files", template: "grep_search", category: "text_processing", required: ["grep", "-rn"], "Natural: search for text"),
      EvalCase("find occurrences of FIXME in the codebase", template: "grep_search", category: "text_processing", required: ["grep"], "Natural: find occurrences"),

      // grep_count
      EvalCase("count occurrences of import", template: "grep_count", category: "text_processing", required: ["grep", "-rc"], "Direct: count matches"),
      EvalCase("how many times does TODO appear", template: "grep_count", category: "text_processing", required: ["grep", "-rc"], "Natural: how many times"),
      EvalCase("grep count of errors in logs", template: "grep_count", category: "text_processing", required: ["grep", "-rc"], "Direct: grep count"),

      // rg_search
      EvalCase("rg pattern", template: "rg_search", category: "text_processing", required: ["rg"], "Terse: rg command"),
      EvalCase("ripgrep search for function", template: "rg_search", category: "text_processing", required: ["rg"], "Direct: ripgrep"),
      EvalCase("fast search for className", template: "rg_search", category: "text_processing", required: ["rg"], "Natural: fast search"),

      // sed_replace
      EvalCase("replace foo with bar in config.yaml", template: "sed_replace", category: "text_processing", required: ["sed", "foo", "bar", "config.yaml"], slots: ["FIND": "foo", "REPLACE": "bar"], "Direct: replace with slots"),
      EvalCase("find and replace oldName with newName in main.swift", template: "sed_replace", category: "text_processing", required: ["sed", "oldName", "newName"], "Natural: find and replace"),
      EvalCase("substitute http with https in urls.txt", template: "sed_replace", category: "text_processing", required: ["sed"], "Synonym: substitute"),

      // sed_delete_lines
      EvalCase("delete lines matching DEBUG in app.log", template: "sed_delete_lines", category: "text_processing", required: ["sed", "DEBUG", "/d"], "Direct: delete matching lines"),
      EvalCase("remove lines containing TODO from notes.txt", template: "sed_delete_lines", category: "text_processing", required: ["sed", "/d"], "Natural: remove lines"),
      EvalCase("strip lines with WARNING in output.log", template: "sed_delete_lines", category: "text_processing", required: ["sed", "/d"], "Synonym: strip lines"),

      // awk_column
      EvalCase("extract column 2 from data.csv", template: "awk_column", category: "text_processing", required: ["awk"], slots: ["COL": "2"], "Direct: extract column"),
      EvalCase("get the third field from output.tsv", template: "awk_column", category: "text_processing", required: ["awk"], "Natural: get field"),
      EvalCase("awk column 1 from access.log", template: "awk_column", category: "text_processing", required: ["awk"], "Terse: awk column"),

      // sort_file
      EvalCase("sort names.txt", template: "sort_file", category: "text_processing", required: ["sort"], "Direct: sort file"),
      EvalCase("sort the lines alphabetically in words.txt", template: "sort_file", category: "text_processing", required: ["sort"], "Natural: sort alphabetically"),
      EvalCase("sort output numerically", template: "sort_file", category: "text_processing", required: ["sort"], "Natural: sort numerically"),

      // sort_unique
      EvalCase("remove duplicates from list.txt", template: "sort_unique", category: "text_processing", required: ["sort", "uniq"], "Direct: remove duplicates"),
      EvalCase("unique lines in names.txt", template: "sort_unique", category: "text_processing", required: ["sort", "uniq"], "Natural: unique lines"),
      EvalCase("deduplicate entries in data.csv", template: "sort_unique", category: "text_processing", required: ["sort", "uniq"], "Synonym: deduplicate"),

      // wc_count
      EvalCase("count lines in README.md", template: "wc_count", category: "text_processing", required: ["wc", "README.md"], "Direct: count lines"),
      EvalCase("how many lines in main.swift", template: "wc_count", category: "text_processing", required: ["wc"], "Natural: how many lines"),
      EvalCase("word count of essay.txt", template: "wc_count", category: "text_processing", required: ["wc"], "Natural: word count"),

      // head_file
      EvalCase("head main.swift", template: "head_file", category: "text_processing", required: ["head"], "Terse: head command"),
      EvalCase("show first 20 lines of config.yaml", template: "head_file", category: "text_processing", required: ["head", "-n"], slots: ["COUNT": "20"], "Natural: first N lines"),
      EvalCase("preview the top of output.log", template: "head_file", category: "text_processing", required: ["head"], "Natural: preview top"),

      // tail_file
      EvalCase("tail server.log", template: "tail_file", category: "text_processing", required: ["tail"], "Terse: tail command"),
      EvalCase("show last 50 lines of error.log", template: "tail_file", category: "text_processing", required: ["tail", "-n"], slots: ["COUNT": "50"], "Natural: last N lines"),
      EvalCase("end of file output.txt", template: "tail_file", category: "text_processing", required: ["tail"], "Natural: end of file"),

      // tail_follow
      EvalCase("tail -f server.log", template: "tail_follow", category: "text_processing", required: ["tail", "-f"], "Terse: tail -f"),
      EvalCase("follow the log file app.log", template: "tail_follow", category: "text_processing", required: ["tail", "-f"], "Natural: follow log"),
      EvalCase("watch log file in real time", template: "tail_follow", category: "text_processing", required: ["tail", "-f"], "Natural: watch log"),

      // cut_columns
      EvalCase("cut columns from data.csv", template: "cut_columns", category: "text_processing", required: ["cut", "-d", "-f"], "Direct: cut columns"),
      EvalCase("extract columns by delimiter", template: "cut_columns", category: "text_processing", required: ["cut"], "Natural: extract by delimiter"),
      EvalCase("csv column extraction", template: "cut_columns", category: "text_processing", required: ["cut"], "Natural: csv column"),

      // tr_replace
      EvalCase("convert to lowercase", template: "tr_replace", category: "text_processing", required: ["tr"], "Natural: to lowercase"),
      EvalCase("translate characters from upper to lower", template: "tr_replace", category: "text_processing", required: ["tr"], "Natural: translate chars"),
      EvalCase("uppercase text", template: "tr_replace", category: "text_processing", required: ["tr"], "Natural: uppercase"),

      // jq_parse
      EvalCase("parse json from data.json", template: "jq_parse", category: "text_processing", required: ["jq"], "Direct: parse json"),
      EvalCase("pretty print json output", template: "jq_parse", category: "text_processing", required: ["jq"], "Natural: pretty print"),
      EvalCase("extract field name from config.json", template: "jq_parse", category: "text_processing", required: ["jq"], "Natural: extract field"),

      // xargs_pipe
      EvalCase("xargs echo", template: "xargs_pipe", category: "text_processing", required: ["xargs"], "Terse: xargs"),
      EvalCase("pipe to xargs for batch processing", template: "xargs_pipe", category: "text_processing", required: ["xargs"], "Natural: pipe to xargs"),
      EvalCase("apply command to each line", template: "xargs_pipe", category: "text_processing", required: ["xargs"], "Natural: apply to each"),
    ]

    @Test("Text processing accuracy", arguments: TextProcessingAccuracy.cases)
    func verify(_ tc: EvalCase) { assertAccuracy(tc) }
  }

  // MARK: - Dev Tools (48 tests)

  @Suite("DevTools")
  struct DevToolsAccuracy {
    static let cases: [EvalCase] = [
      // swift_build
      EvalCase("swift build", template: "swift_build", category: "dev_tools", required: ["swift build"], "Terse: swift build"),
      EvalCase("build the swift project", template: "swift_build", category: "dev_tools", required: ["swift build"], "Natural: build project"),
      EvalCase("compile this package", template: "swift_build", category: "dev_tools", required: ["swift build"], "Natural: compile package"),

      // swift_build_release
      EvalCase("swift build -c release", template: "swift_build_release", category: "dev_tools", required: ["swift build", "-c release"], "Terse: release flag"),
      EvalCase("build for release", template: "swift_build_release", category: "dev_tools", required: ["swift build", "-c release"], "Natural: build release"),
      EvalCase("compile optimized production build", template: "swift_build_release", category: "dev_tools", required: ["swift build", "-c release"], "Natural: optimized"),

      // swift_test
      EvalCase("swift test", template: "swift_test", category: "dev_tools", required: ["swift test"], "Terse: swift test"),
      EvalCase("run the unit tests", template: "swift_test", category: "dev_tools", required: ["swift test"], "Natural: run tests"),
      EvalCase("execute tests for this project", template: "swift_test", category: "dev_tools", required: ["swift test"], "Natural: execute tests"),

      // swift_run
      EvalCase("swift run", template: "swift_run", category: "dev_tools", required: ["swift run"], "Terse: swift run"),
      EvalCase("run the swift executable", template: "swift_run", category: "dev_tools", required: ["swift run"], "Natural: run executable"),
      EvalCase("execute the tool", template: "swift_run", category: "dev_tools", required: ["swift run"], "Natural: execute tool"),

      // cargo_build
      EvalCase("cargo build", template: "cargo_build", category: "dev_tools", required: ["cargo build"], "Terse: cargo build"),
      EvalCase("build the rust project", template: "cargo_build", category: "dev_tools", required: ["cargo build"], "Natural: build rust"),
      EvalCase("compile rust code", template: "cargo_build", category: "dev_tools", required: ["cargo build"], "Natural: compile rust"),

      // cargo_test
      EvalCase("cargo test", template: "cargo_test", category: "dev_tools", required: ["cargo test"], "Terse: cargo test"),
      EvalCase("run rust tests", template: "cargo_test", category: "dev_tools", required: ["cargo test"], "Natural: rust tests"),
      EvalCase("test the rust project", template: "cargo_test", category: "dev_tools", required: ["cargo test"], "Natural: test rust"),

      // cargo_run
      EvalCase("cargo run", template: "cargo_run", category: "dev_tools", required: ["cargo run"], "Terse: cargo run"),
      EvalCase("run the rust program", template: "cargo_run", category: "dev_tools", required: ["cargo run"], "Natural: run rust"),
      EvalCase("execute rust binary", template: "cargo_run", category: "dev_tools", required: ["cargo run"], "Natural: execute rust"),

      // go_build
      EvalCase("go build", template: "go_build", category: "dev_tools", required: ["go build"], "Terse: go build"),
      EvalCase("build the go project", template: "go_build", category: "dev_tools", required: ["go build"], "Natural: build go"),
      EvalCase("compile golang binary", template: "go_build", category: "dev_tools", required: ["go build"], "Natural: compile golang"),

      // go_test
      EvalCase("go test", template: "go_test", category: "dev_tools", required: ["go test"], "Terse: go test"),
      EvalCase("run go tests", template: "go_test", category: "dev_tools", required: ["go test"], "Natural: go tests"),
      EvalCase("test golang project", template: "go_test", category: "dev_tools", required: ["go test"], "Natural: test golang"),

      // npm_run
      EvalCase("npm run dev", template: "npm_run", category: "dev_tools", required: ["npm run"], "Terse: npm run"),
      EvalCase("start the dev server", template: "npm_run", category: "dev_tools", required: ["npm run"], "Natural: start dev server"),
      EvalCase("run npm script build", template: "npm_run", category: "dev_tools", required: ["npm run"], "Natural: run script"),

      // python_run
      EvalCase("python3 script.py", template: "python_run", category: "dev_tools", required: ["python3"], "Terse: python3"),
      EvalCase("run the python script main.py", template: "python_run", category: "dev_tools", required: ["python3"], "Natural: run python"),
      EvalCase("execute python script analyzer.py", template: "python_run", category: "dev_tools", required: ["python3"], "Natural: execute python"),

      // docker_build
      EvalCase("docker build -t myapp .", template: "docker_build", category: "dev_tools", required: ["docker build", "-t"], "Terse: docker build"),
      EvalCase("build a docker image called webapp", template: "docker_build", category: "dev_tools", required: ["docker build", "-t"], "Natural: build docker"),
      EvalCase("create docker image from Dockerfile", template: "docker_build", category: "dev_tools", required: ["docker build"], "Natural: create image"),

      // docker_run
      EvalCase("docker run nginx", template: "docker_run", category: "dev_tools", required: ["docker run"], "Terse: docker run"),
      EvalCase("run docker container from ubuntu image", template: "docker_run", category: "dev_tools", required: ["docker run"], "Natural: run container"),
      EvalCase("launch a container with redis", template: "docker_run", category: "dev_tools", required: ["docker run"], "Natural: launch container"),

      // docker_ps
      EvalCase("docker ps", template: "docker_ps", category: "dev_tools", required: ["docker ps"], "Terse: docker ps"),
      EvalCase("show running docker containers", template: "docker_ps", category: "dev_tools", required: ["docker ps"], "Natural: running containers"),
      EvalCase("what containers are running", template: "docker_ps", category: "dev_tools", required: ["docker ps"], "Natural: what containers"),

      // kubectl_get
      EvalCase("kubectl get pods", template: "kubectl_get", category: "dev_tools", required: ["kubectl get"], "Terse: kubectl get"),
      EvalCase("list kubernetes pods", template: "kubectl_get", category: "dev_tools", required: ["kubectl get"], "Natural: list pods"),
      EvalCase("show k8s resources", template: "kubectl_get", category: "dev_tools", required: ["kubectl get"], "Natural: show resources"),
    ]

    @Test("Dev tools accuracy", arguments: DevToolsAccuracy.cases)
    func verify(_ tc: EvalCase) { assertAccuracy(tc) }
  }

  // MARK: - macOS (48 tests)

  @Suite("MacOS")
  struct MacOSAccuracy {
    static let cases: [EvalCase] = [
      // open_file
      EvalCase("open README.md", template: "open_file", category: "macos", required: ["open"], "Terse: open file"),
      EvalCase("launch this file in the default app", template: "open_file", category: "macos", required: ["open"], "Natural: launch file"),
      EvalCase("reveal in Finder", template: "open_file", category: "macos", required: ["open"], "Natural: Finder reveal"),

      // open_with_app
      EvalCase("open file with Safari", template: "open_with_app", category: "macos", required: ["open", "-a"], "Direct: open with app"),
      EvalCase("open index.html in Chrome", template: "open_with_app", category: "macos", required: ["open", "-a"], "Natural: open in app"),
      EvalCase("launch with Xcode", template: "open_with_app", category: "macos", required: ["open", "-a"], "Natural: launch with"),

      // pbcopy
      EvalCase("copy to clipboard", template: "pbcopy", category: "macos", required: ["pbcopy"], "Direct: copy to clipboard"),
      EvalCase("put output in clipboard", template: "pbcopy", category: "macos", required: ["pbcopy"], "Natural: put in clipboard"),
      EvalCase("pbcopy", template: "pbcopy", category: "macos", required: ["pbcopy"], "Terse: bare pbcopy"),

      // pbpaste
      EvalCase("paste from clipboard", template: "pbpaste", category: "macos", required: ["pbpaste"], "Direct: paste clipboard"),
      EvalCase("show clipboard contents", template: "pbpaste", category: "macos", required: ["pbpaste"], "Natural: show clipboard"),
      EvalCase("what's in clipboard", template: "pbpaste", category: "macos", required: ["pbpaste"], "Natural: what's in clipboard"),

      // say_text
      EvalCase("say hello world", template: "say_text", category: "macos", required: ["say"], "Direct: say text"),
      EvalCase("read this text aloud", template: "say_text", category: "macos", required: ["say"], "Natural: read aloud"),
      EvalCase("text to speech testing", template: "say_text", category: "macos", required: ["say"], "Natural: text to speech"),

      // defaults_read
      EvalCase("defaults read com.apple.Finder", template: "defaults_read", category: "macos", required: ["defaults read"], "Direct: defaults read"),
      EvalCase("read macOS setting for dock", template: "defaults_read", category: "macos", required: ["defaults read"], "Natural: read setting"),
      EvalCase("check plist preference", template: "defaults_read", category: "macos", required: ["defaults read"], "Natural: check preference"),

      // defaults_write
      EvalCase("defaults write com.apple.dock autohide -bool true", template: "defaults_write", category: "macos", required: ["defaults write"], "Direct: defaults write"),
      EvalCase("set macOS preference for dock", template: "defaults_write", category: "macos", required: ["defaults write"], "Natural: set preference"),
      EvalCase("change default setting", template: "defaults_write", category: "macos", required: ["defaults write"], "Natural: change setting"),

      // mdfind_search
      EvalCase("spotlight search for budget spreadsheet", template: "mdfind_search", category: "macos", required: ["mdfind"], "Direct: spotlight search"),
      EvalCase("mdfind presentation", template: "mdfind_search", category: "macos", required: ["mdfind"], "Terse: mdfind"),
      EvalCase("search mac for project files", template: "mdfind_search", category: "macos", required: ["mdfind"], "Natural: search mac"),

      // mdls_metadata
      EvalCase("mdls photo.jpg", template: "mdls_metadata", category: "macos", required: ["mdls"], "Terse: mdls"),
      EvalCase("show spotlight metadata for document.pdf", template: "mdls_metadata", category: "macos", required: ["mdls"], "Natural: spotlight metadata"),
      EvalCase("get file metadata attributes", template: "mdls_metadata", category: "macos", required: ["mdls"], "Natural: file metadata"),

      // osascript_run
      EvalCase("run applescript to quit Safari", template: "osascript_run", category: "macos", required: ["osascript", "-e"], "Direct: run applescript"),
      EvalCase("osascript display dialog hello", template: "osascript_run", category: "macos", required: ["osascript", "-e"], "Terse: osascript"),
      EvalCase("execute applescript command", template: "osascript_run", category: "macos", required: ["osascript"], "Natural: execute applescript"),

      // sips_resize
      EvalCase("sips resize image to 800px", template: "sips_resize", category: "macos", required: ["sips", "-Z"], "Direct: sips resize"),
      EvalCase("resize image macOS photo.png", template: "sips_resize", category: "macos", required: ["sips", "-Z"], "Natural: resize macOS"),
      EvalCase("scale image with sips to 1024", template: "sips_resize", category: "macos", required: ["sips", "-Z"], "Natural: scale with sips"),

      // caffeinate
      EvalCase("caffeinate", template: "caffeinate", category: "macos", required: ["caffeinate"], "Terse: caffeinate"),
      EvalCase("prevent mac from sleeping", template: "caffeinate", category: "macos", required: ["caffeinate"], "Natural: prevent sleep"),
      EvalCase("keep display on during download", template: "caffeinate", category: "macos", required: ["caffeinate"], "Natural: keep display on"),

      // screencapture
      EvalCase("take screenshot", template: "screencapture", category: "macos", required: ["screencapture"], "Direct: take screenshot"),
      EvalCase("capture the screen to desktop.png", template: "screencapture", category: "macos", required: ["screencapture"], "Natural: capture screen"),
      EvalCase("screen grab", template: "screencapture", category: "macos", required: ["screencapture"], "Natural: screen grab"),

      // screencapture_window
      EvalCase("screenshot of window", template: "screencapture_window", category: "macos", required: ["screencapture", "-w"], "Direct: window screenshot"),
      EvalCase("capture specific window", template: "screencapture_window", category: "macos", required: ["screencapture", "-w"], "Natural: capture window"),
      EvalCase("take a screenshot of the active app", template: "screencapture_window", category: "macos", required: ["screencapture", "-w"], "Natural: screenshot of app"),

      // diskutil_list
      EvalCase("diskutil list", template: "diskutil_list", category: "macos", required: ["diskutil list"], "Terse: diskutil"),
      EvalCase("show disk partitions", template: "diskutil_list", category: "macos", required: ["diskutil list"], "Natural: disk partitions"),
      EvalCase("what disks are mounted", template: "diskutil_list", category: "macos", required: ["diskutil list"], "Natural: disks mounted"),

      // plutil_lint
      EvalCase("validate plist Info.plist", template: "plutil_lint", category: "macos", required: ["plutil", "-lint"], "Direct: validate plist"),
      EvalCase("check plist syntax for config.plist", template: "plutil_lint", category: "macos", required: ["plutil", "-lint"], "Natural: check syntax"),
      EvalCase("lint plist file", template: "plutil_lint", category: "macos", required: ["plutil", "-lint"], "Natural: lint plist"),
    ]

    @Test("macOS accuracy", arguments: MacOSAccuracy.cases)
    func verify(_ tc: EvalCase) { assertAccuracy(tc) }
  }

  // MARK: - Network (36 tests)

  @Suite("Network")
  struct NetworkAccuracy {
    static let cases: [EvalCase] = [
      // curl_get
      EvalCase("curl https://api.example.com/data", template: "curl_get", category: "network", required: ["curl", "https://api.example.com/data"], "Terse: curl with URL"),
      EvalCase("fetch the url https://httpbin.org/get", template: "curl_get", category: "network", required: ["curl", "https://httpbin.org/get"], "Natural: fetch URL"),
      EvalCase("make a get request to https://api.github.com", template: "curl_get", category: "network", required: ["curl", "https://api.github.com"], "Natural: get request"),

      // curl_post_json
      EvalCase("post json to https://api.example.com/users", template: "curl_post_json", category: "network", required: ["curl", "-X POST", "Content-Type: application/json"], "Direct: post json"),
      EvalCase("send json data to https://httpbin.org/post", template: "curl_post_json", category: "network", required: ["curl", "-X POST"], "Natural: send json"),
      EvalCase("http post request with body to https://api.test.com", template: "curl_post_json", category: "network", required: ["curl", "-X POST"], "Natural: http post"),

      // curl_download
      EvalCase("download https://example.com/file.tar.gz", template: "curl_download", category: "network", required: ["curl", "-L", "-o", "https://example.com/file.tar.gz"], "Direct: download URL"),
      EvalCase("save url https://example.com/data.zip to file", template: "curl_download", category: "network", required: ["curl", "-L", "-o"], "Natural: save URL"),
      EvalCase("fetch and save https://releases.com/v2.tar.gz", template: "curl_download", category: "network", required: ["curl", "-L", "-o"], "Natural: fetch and save"),

      // curl_headers
      EvalCase("curl headers for https://example.com", template: "curl_headers", category: "network", required: ["curl", "-sI"], "Direct: curl headers"),
      EvalCase("show response headers from https://api.github.com", template: "curl_headers", category: "network", required: ["curl", "-sI"], "Natural: show headers"),
      EvalCase("check headers of https://httpbin.org/get", template: "curl_headers", category: "network", required: ["curl", "-sI"], "Natural: check headers"),

      // curl_auth
      EvalCase("curl with bearer token abc123 to https://api.secure.com", template: "curl_auth", category: "network", required: ["curl", "Authorization: Bearer"], "Direct: curl with auth"),
      EvalCase("authenticated request to https://api.private.com with token mytoken", template: "curl_auth", category: "network", required: ["curl", "Authorization: Bearer"], "Natural: authenticated request"),
      EvalCase("api request with token secret123 to https://api.example.com", template: "curl_auth", category: "network", required: ["curl", "Authorization: Bearer"], "Natural: api with token"),

      // ssh_connect
      EvalCase("ssh into production server", template: "ssh_connect", category: "network", required: ["ssh"], "Direct: ssh into"),
      EvalCase("connect to remote machine via ssh", template: "ssh_connect", category: "network", required: ["ssh"], "Natural: connect remote"),
      EvalCase("log into remote server", template: "ssh_connect", category: "network", required: ["ssh"], "Natural: log into"),

      // scp_copy
      EvalCase("scp config.yaml to server", template: "scp_copy", category: "network", required: ["scp"], "Direct: scp file"),
      EvalCase("copy file to remote server", template: "scp_copy", category: "network", required: ["scp"], "Natural: copy to server"),
      EvalCase("upload deploy.sh to production", template: "scp_copy", category: "network", required: ["scp"], "Natural: upload to server"),

      // nc_listen
      EvalCase("netcat listen on port 8080", template: "nc_listen", category: "network", required: ["nc", "-l"], "Direct: netcat listen"),
      EvalCase("open a port listener on 3000", template: "nc_listen", category: "network", required: ["nc", "-l"], "Natural: open listener"),
      EvalCase("nc listen 9090", template: "nc_listen", category: "network", required: ["nc", "-l"], "Terse: nc listen"),

      // dig_lookup
      EvalCase("dig example.com", template: "dig_lookup", category: "network", required: ["dig"], "Terse: dig domain"),
      EvalCase("dns lookup for google.com", template: "dig_lookup", category: "network", required: ["dig"], "Natural: dns lookup"),
      EvalCase("resolve dns records for api.stripe.com", template: "dig_lookup", category: "network", required: ["dig"], "Natural: resolve dns"),

      // host_lookup
      EvalCase("host github.com", template: "host_lookup", category: "network", required: ["host"], "Terse: host command"),
      EvalCase("find ip of domain example.org", template: "host_lookup", category: "network", required: ["host"], "Natural: find ip"),
      EvalCase("reverse dns lookup", template: "host_lookup", category: "network", required: ["host"], "Natural: reverse dns"),

      // lsof_ports
      EvalCase("what's on port 8080", template: "lsof_ports", category: "network", required: ["lsof", "-i"], "Direct: what's on port"),
      EvalCase("who is using port 3000", template: "lsof_ports", category: "network", required: ["lsof", "-i"], "Natural: who is using"),
      EvalCase("check if port 443 is in use", template: "lsof_ports", category: "network", required: ["lsof", "-i"], "Natural: port in use"),

      // ping_host
      EvalCase("ping google.com", template: "ping_host", category: "network", required: ["ping", "-c"], "Terse: ping host"),
      EvalCase("check if server 10.0.0.1 is up", template: "ping_host", category: "network", required: ["ping", "-c"], "Natural: server up"),
      EvalCase("test connectivity to api.example.com", template: "ping_host", category: "network", required: ["ping", "-c"], "Natural: test connectivity"),
    ]

    @Test("Network accuracy", arguments: NetworkAccuracy.cases)
    func verify(_ tc: EvalCase) { assertAccuracy(tc) }
  }

  // MARK: - System (42 tests)

  @Suite("System")
  struct SystemAccuracy {
    static let cases: [EvalCase] = [
      // ps_list
      EvalCase("ps", template: "ps_list", category: "system", required: ["ps aux"], "Terse: ps"),
      EvalCase("show all running processes", template: "ps_list", category: "system", required: ["ps aux"], "Natural: running processes"),
      EvalCase("what processes are running", template: "ps_list", category: "system", required: ["ps aux"], "Natural: what processes"),

      // ps_grep
      EvalCase("find process node", template: "ps_grep", category: "system", required: ["ps aux", "grep"], "Direct: find process"),
      EvalCase("is nginx running", template: "ps_grep", category: "system", required: ["ps aux", "grep"], "Natural: is running"),
      EvalCase("search for python process", template: "ps_grep", category: "system", required: ["ps aux", "grep"], "Natural: search process"),

      // kill_process
      EvalCase("kill process 1234", template: "kill_process", category: "system", required: ["kill"], "Direct: kill PID"),
      EvalCase("terminate process 5678", template: "kill_process", category: "system", required: ["kill"], "Natural: terminate process"),
      EvalCase("stop process with pid 9999", template: "kill_process", category: "system", required: ["kill"], "Natural: stop process"),

      // killall_name
      EvalCase("killall Safari", template: "killall_name", category: "system", required: ["killall"], "Terse: killall"),
      EvalCase("kill all processes named node", template: "killall_name", category: "system", required: ["killall"], "Natural: kill all named"),
      EvalCase("terminate all instances of python3", template: "killall_name", category: "system", required: ["killall"], "Natural: terminate all"),

      // top_snapshot
      EvalCase("top", template: "top_snapshot", category: "system", required: ["top"], "Terse: top"),
      EvalCase("what's using the most cpu", template: "top_snapshot", category: "system", required: ["top"], "Natural: cpu usage"),
      EvalCase("show system resource usage", template: "top_snapshot", category: "system", required: ["top"], "Natural: resource usage"),

      // lsof_open_files
      EvalCase("lsof", template: "lsof_open_files", category: "system", required: ["lsof"], "Terse: lsof"),
      EvalCase("what files are open by processes", template: "lsof_open_files", category: "system", required: ["lsof"], "Natural: open files"),
      EvalCase("show open file descriptors", template: "lsof_open_files", category: "system", required: ["lsof"], "Natural: file descriptors"),

      // df_disk_free
      EvalCase("df", template: "df_disk_free", category: "system", required: ["df", "-h"], "Terse: df"),
      EvalCase("how much disk space is free", template: "df_disk_free", category: "system", required: ["df", "-h"], "Natural: disk space"),
      EvalCase("check available disk space", template: "df_disk_free", category: "system", required: ["df", "-h"], "Natural: available space"),

      // du_summary
      EvalCase("biggest directories", template: "du_summary", category: "system", required: ["du", "-sh", "sort"], "Direct: biggest dirs"),
      EvalCase("what's using the most disk space", template: "du_summary", category: "system", required: ["du", "-sh"], "Natural: most space"),
      EvalCase("largest directories sorted by size", template: "du_summary", category: "system", required: ["du", "-sh", "sort"], "Natural: largest sorted"),

      // uname_info
      EvalCase("uname", template: "uname_info", category: "system", required: ["uname", "-a"], "Terse: uname"),
      EvalCase("what os is this", template: "uname_info", category: "system", required: ["uname"], "Natural: what os"),
      EvalCase("show system info", template: "uname_info", category: "system", required: ["uname"], "Natural: system info"),

      // sw_vers
      EvalCase("sw_vers", template: "sw_vers", category: "system", required: ["sw_vers"], "Terse: sw_vers"),
      EvalCase("what version of macos am I running", template: "sw_vers", category: "system", required: ["sw_vers"], "Natural: macos version"),
      EvalCase("check macOS version number", template: "sw_vers", category: "system", required: ["sw_vers"], "Natural: check version"),

      // env_vars
      EvalCase("env", template: "env_vars", category: "system", required: ["env"], "Terse: env"),
      EvalCase("show all environment variables", template: "env_vars", category: "system", required: ["env"], "Natural: show env vars"),
      EvalCase("list env vars", template: "env_vars", category: "system", required: ["env"], "Natural: list env"),

      // which_cmd
      EvalCase("which python3", template: "which_cmd", category: "system", required: ["which"], "Terse: which"),
      EvalCase("where is the git binary", template: "which_cmd", category: "system", required: ["which"], "Natural: where is binary"),
      EvalCase("find path to executable node", template: "which_cmd", category: "system", required: ["which"], "Natural: find executable"),

      // uptime
      EvalCase("uptime", template: "uptime", category: "system", required: ["uptime"], "Terse: uptime"),
      EvalCase("how long has the system been running", template: "uptime", category: "system", required: ["uptime"], "Natural: how long running"),
      EvalCase("check system uptime", template: "uptime", category: "system", required: ["uptime"], "Natural: check uptime"),

      // whoami
      EvalCase("whoami", template: "whoami", category: "system", required: ["whoami"], "Terse: whoami"),
      EvalCase("what user am I logged in as", template: "whoami", category: "system", required: ["whoami"], "Natural: what user"),
      EvalCase("show my username", template: "whoami", category: "system", required: ["whoami"], "Natural: my username"),
    ]

    @Test("System accuracy", arguments: SystemAccuracy.cases)
    func verify(_ tc: EvalCase) { assertAccuracy(tc) }
  }

  // MARK: - Packages (36 tests)

  @Suite("Packages")
  struct PackagesAccuracy {
    static let cases: [EvalCase] = [
      // brew_install
      EvalCase("brew install wget", template: "brew_install", category: "packages", required: ["brew install"], "Terse: brew install"),
      EvalCase("install wget with homebrew", template: "brew_install", category: "packages", required: ["brew install"], "Natural: install with homebrew"),
      EvalCase("homebrew install ffmpeg", template: "brew_install", category: "packages", required: ["brew install"], "Natural: homebrew install"),

      // brew_search
      EvalCase("brew search ripgrep", template: "brew_search", category: "packages", required: ["brew search"], "Terse: brew search"),
      EvalCase("find brew package for image editing", template: "brew_search", category: "packages", required: ["brew search"], "Natural: find package"),
      EvalCase("is it on homebrew", template: "brew_search", category: "packages", required: ["brew search"], "Natural: is it on homebrew"),

      // brew_list
      EvalCase("brew list", template: "brew_list", category: "packages", required: ["brew list"], "Terse: brew list"),
      EvalCase("what's installed with homebrew", template: "brew_list", category: "packages", required: ["brew list"], "Natural: what's installed"),
      EvalCase("list all installed brew packages", template: "brew_list", category: "packages", required: ["brew list"], "Natural: list installed"),

      // brew_update
      EvalCase("brew update", template: "brew_update", category: "packages", required: ["brew update"], "Terse: brew update"),
      EvalCase("update all homebrew packages", template: "brew_update", category: "packages", required: ["brew"], "Natural: update all"),
      EvalCase("upgrade homebrew formulae", template: "brew_update", category: "packages", required: ["brew"], "Natural: upgrade formulae"),

      // brew_info
      EvalCase("brew info node", template: "brew_info", category: "packages", required: ["brew info"], "Terse: brew info"),
      EvalCase("details about homebrew formula git", template: "brew_info", category: "packages", required: ["brew info"], "Natural: details about"),
      EvalCase("show info for package python", template: "brew_info", category: "packages", required: ["brew info"], "Natural: show info"),

      // npm_install
      EvalCase("npm install express", template: "npm_install", category: "packages", required: ["npm install"], "Terse: npm install"),
      EvalCase("add npm dependency lodash", template: "npm_install", category: "packages", required: ["npm install"], "Natural: add dependency"),
      EvalCase("install node module react", template: "npm_install", category: "packages", required: ["npm install"], "Natural: install module"),

      // npm_list
      EvalCase("npm list", template: "npm_list", category: "packages", required: ["npm list"], "Terse: npm list"),
      EvalCase("show installed npm packages", template: "npm_list", category: "packages", required: ["npm list"], "Natural: show installed"),
      EvalCase("what npm packages are installed", template: "npm_list", category: "packages", required: ["npm list"], "Natural: what's installed"),

      // pip_install
      EvalCase("pip install requests", template: "pip_install", category: "packages", required: ["pip3 install"], "Terse: pip install"),
      EvalCase("install python package numpy", template: "pip_install", category: "packages", required: ["pip3 install"], "Natural: install python pkg"),
      EvalCase("add python dependency pandas", template: "pip_install", category: "packages", required: ["pip3 install"], "Natural: add dependency"),

      // pip_list
      EvalCase("pip list", template: "pip_list", category: "packages", required: ["pip3 list"], "Terse: pip list"),
      EvalCase("show installed python packages", template: "pip_list", category: "packages", required: ["pip3 list"], "Natural: show installed"),
      EvalCase("list python packages", template: "pip_list", category: "packages", required: ["pip3 list"], "Natural: list packages"),

      // pip_freeze
      EvalCase("pip freeze", template: "pip_freeze", category: "packages", required: ["pip3 freeze"], "Terse: pip freeze"),
      EvalCase("export python requirements", template: "pip_freeze", category: "packages", required: ["pip3 freeze"], "Natural: export requirements"),
      EvalCase("generate requirements.txt", template: "pip_freeze", category: "packages", required: ["pip3 freeze"], "Natural: generate requirements"),

      // cargo_add
      EvalCase("cargo add serde", template: "cargo_add", category: "packages", required: ["cargo add"], "Terse: cargo add"),
      EvalCase("add rust dependency tokio", template: "cargo_add", category: "packages", required: ["cargo add"], "Natural: add rust dep"),
      EvalCase("install rust package clap", template: "cargo_add", category: "packages", required: ["cargo add"], "Natural: install rust pkg"),

      // gem_install
      EvalCase("gem install rails", template: "gem_install", category: "packages", required: ["gem install"], "Terse: gem install"),
      EvalCase("install ruby gem bundler", template: "gem_install", category: "packages", required: ["gem install"], "Natural: install gem"),
      EvalCase("add ruby gem puma", template: "gem_install", category: "packages", required: ["gem install"], "Natural: add gem"),
    ]

    @Test("Packages accuracy", arguments: PackagesAccuracy.cases)
    func verify(_ tc: EvalCase) { assertAccuracy(tc) }
  }

  // MARK: - Compression (36 tests)

  @Suite("Compression")
  struct CompressionAccuracy {
    static let cases: [EvalCase] = [
      // tar_create
      EvalCase("create tar archive of src/", template: "tar_create", category: "compression", required: ["tar", "-czf"], "Direct: create tar"),
      EvalCase("make a tarball of the project", template: "tar_create", category: "compression", required: ["tar", "-czf"], "Natural: make tarball"),
      EvalCase("tar czf backup.tar.gz documents/", template: "tar_create", category: "compression", required: ["tar", "-czf"], "Terse: tar czf"),

      // tar_extract
      EvalCase("extract archive.tar.gz", template: "tar_extract", category: "compression", required: ["tar", "-xzf"], "Direct: extract tar"),
      EvalCase("untar backup.tar.gz", template: "tar_extract", category: "compression", required: ["tar", "-xzf"], "Synonym: untar"),
      EvalCase("unpack the tarball release.tar.gz", template: "tar_extract", category: "compression", required: ["tar", "-xzf"], "Natural: unpack"),

      // tar_list
      EvalCase("list contents of archive.tar.gz", template: "tar_list", category: "compression", required: ["tar", "-tzf"], "Direct: list contents"),
      EvalCase("what's in this tar file", template: "tar_list", category: "compression", required: ["tar", "-tzf"], "Natural: what's in tar"),
      EvalCase("peek inside backup.tar.gz", template: "tar_list", category: "compression", required: ["tar", "-tzf"], "Natural: peek inside"),

      // tar_bz2_create
      EvalCase("create bzip2 tar archive", template: "tar_bz2_create", category: "compression", required: ["tar", "-cjf"], "Direct: bzip2 tar"),
      EvalCase("compress with bzip2 the logs directory", template: "tar_bz2_create", category: "compression", required: ["tar", "-cjf"], "Natural: compress bzip2"),
      EvalCase("create tar.bz2 of data/", template: "tar_bz2_create", category: "compression", required: ["tar", "-cjf"], "Direct: tar.bz2"),

      // gzip_file
      EvalCase("gzip database.sql", template: "gzip_file", category: "compression", required: ["gzip"], "Terse: gzip"),
      EvalCase("compress with gzip the log file", template: "gzip_file", category: "compression", required: ["gzip"], "Natural: compress gzip"),
      EvalCase("make gz file from backup.sql", template: "gzip_file", category: "compression", required: ["gzip"], "Natural: make gz"),

      // gunzip_file
      EvalCase("gunzip data.gz", template: "gunzip_file", category: "compression", required: ["gunzip"], "Terse: gunzip"),
      EvalCase("decompress the gz file backup.sql.gz", template: "gunzip_file", category: "compression", required: ["gunzip"], "Natural: decompress gz"),
      EvalCase("extract gz file archive.gz", template: "gunzip_file", category: "compression", required: ["gunzip"], "Natural: extract gz"),

      // zip_create
      EvalCase("zip the documents folder", template: "zip_create", category: "compression", required: ["zip", "-r"], "Direct: zip folder"),
      EvalCase("create a zip file from src/", template: "zip_create", category: "compression", required: ["zip", "-r"], "Natural: create zip"),
      EvalCase("compress directory to zip archive", template: "zip_create", category: "compression", required: ["zip", "-r"], "Natural: compress to zip"),

      // unzip_extract
      EvalCase("unzip release.zip", template: "unzip_extract", category: "compression", required: ["unzip"], "Terse: unzip"),
      EvalCase("extract the zip file archive.zip", template: "unzip_extract", category: "compression", required: ["unzip"], "Natural: extract zip"),
      EvalCase("uncompress download.zip", template: "unzip_extract", category: "compression", required: ["unzip"], "Natural: uncompress"),

      // xz_compress
      EvalCase("xz compress backup.sql", template: "xz_compress", category: "compression", required: ["xz"], "Direct: xz compress"),
      EvalCase("compress file with xz", template: "xz_compress", category: "compression", required: ["xz"], "Natural: compress xz"),
      EvalCase("create xz file from data.bin", template: "xz_compress", category: "compression", required: ["xz"], "Natural: create xz"),

      // xz_decompress
      EvalCase("xz decompress backup.xz", template: "xz_decompress", category: "compression", required: ["xz", "-d"], "Direct: xz decompress"),
      EvalCase("extract xz file data.xz", template: "xz_decompress", category: "compression", required: ["xz", "-d"], "Natural: extract xz"),
      EvalCase("uncompress the xz archive", template: "xz_decompress", category: "compression", required: ["xz", "-d"], "Natural: uncompress xz"),

      // zstd_compress
      EvalCase("zstd compress database.sql", template: "zstd_compress", category: "compression", required: ["zstd"], "Direct: zstd compress"),
      EvalCase("compress with zstandard", template: "zstd_compress", category: "compression", required: ["zstd"], "Natural: zstandard"),
      EvalCase("create zst file", template: "zstd_compress", category: "compression", required: ["zstd"], "Natural: create zst"),

      // zstd_decompress
      EvalCase("zstd decompress backup.zst", template: "zstd_decompress", category: "compression", required: ["zstd", "-d"], "Direct: zstd decompress"),
      EvalCase("extract zstd file archive.zst", template: "zstd_decompress", category: "compression", required: ["zstd", "-d"], "Natural: extract zstd"),
      EvalCase("decompress the zst archive", template: "zstd_decompress", category: "compression", required: ["zstd", "-d"], "Natural: decompress zst"),
    ]

    @Test("Compression accuracy", arguments: CompressionAccuracy.cases)
    func verify(_ tc: EvalCase) { assertAccuracy(tc) }
  }

  // MARK: - Cloud (36 tests)

  @Suite("Cloud")
  struct CloudAccuracy {
    static let cases: [EvalCase] = [
      // aws_s3_ls
      EvalCase("aws s3 ls", template: "aws_s3_ls", category: "cloud", required: ["aws s3 ls"], "Terse: aws s3 ls"),
      EvalCase("list objects in s3 bucket", template: "aws_s3_ls", category: "cloud", required: ["aws s3 ls"], "Natural: list s3"),
      EvalCase("show what's in the s3 bucket", template: "aws_s3_ls", category: "cloud", required: ["aws s3 ls"], "Natural: what's in s3"),

      // aws_s3_cp
      EvalCase("aws s3 cp file.txt s3://mybucket/", template: "aws_s3_cp", category: "cloud", required: ["aws s3 cp"], "Terse: aws s3 cp"),
      EvalCase("upload backup.sql to s3", template: "aws_s3_cp", category: "cloud", required: ["aws s3 cp"], "Natural: upload to s3"),
      EvalCase("copy file to s3 bucket", template: "aws_s3_cp", category: "cloud", required: ["aws s3 cp"], "Natural: copy to s3"),

      // aws_s3_sync
      EvalCase("aws s3 sync . s3://mybucket", template: "aws_s3_sync", category: "cloud", required: ["aws s3 sync"], "Terse: aws s3 sync"),
      EvalCase("sync directory with s3 bucket", template: "aws_s3_sync", category: "cloud", required: ["aws s3 sync"], "Natural: sync with s3"),
      EvalCase("mirror local folder to s3", template: "aws_s3_sync", category: "cloud", required: ["aws s3 sync"], "Natural: mirror to s3"),

      // aws_ec2_describe
      EvalCase("list ec2 instances", template: "aws_ec2_describe", category: "cloud", required: ["aws ec2 describe-instances"], "Direct: list ec2"),
      EvalCase("what ec2 instances are running", template: "aws_ec2_describe", category: "cloud", required: ["aws ec2 describe-instances"], "Natural: running instances"),
      EvalCase("show my aws instances", template: "aws_ec2_describe", category: "cloud", required: ["aws ec2 describe-instances"], "Natural: my instances"),

      // aws_lambda_invoke
      EvalCase("invoke lambda function processOrder", template: "aws_lambda_invoke", category: "cloud", required: ["aws lambda invoke"], "Direct: invoke lambda"),
      EvalCase("run lambda function dataProcessor", template: "aws_lambda_invoke", category: "cloud", required: ["aws lambda invoke"], "Natural: run lambda"),
      EvalCase("call aws lambda sendEmail", template: "aws_lambda_invoke", category: "cloud", required: ["aws lambda invoke"], "Natural: call lambda"),

      // aws_lambda_list
      EvalCase("list lambda functions", template: "aws_lambda_list", category: "cloud", required: ["aws lambda list-functions"], "Direct: list lambdas"),
      EvalCase("show all lambda functions", template: "aws_lambda_list", category: "cloud", required: ["aws lambda list-functions"], "Natural: show lambdas"),
      EvalCase("what lambda functions exist", template: "aws_lambda_list", category: "cloud", required: ["aws lambda list-functions"], "Natural: what lambdas"),

      // aws_iam_whoami
      EvalCase("aws whoami", template: "aws_iam_whoami", category: "cloud", required: ["aws sts get-caller-identity"], "Terse: aws whoami"),
      EvalCase("who am I in aws", template: "aws_iam_whoami", category: "cloud", required: ["aws sts get-caller-identity"], "Natural: who am i aws"),
      EvalCase("check aws credentials", template: "aws_iam_whoami", category: "cloud", required: ["aws sts get-caller-identity"], "Natural: check creds"),

      // aws_logs_tail
      EvalCase("tail cloudwatch logs for /aws/lambda/myFunc", template: "aws_logs_tail", category: "cloud", required: ["aws logs tail"], "Direct: tail logs"),
      EvalCase("stream cloudwatch logs", template: "aws_logs_tail", category: "cloud", required: ["aws logs tail"], "Natural: stream logs"),
      EvalCase("watch aws logs in real time", template: "aws_logs_tail", category: "cloud", required: ["aws logs tail"], "Natural: watch logs"),

      // kubectl_get_all
      EvalCase("kubectl get all", template: "kubectl_get_all", category: "cloud", required: ["kubectl get all"], "Terse: kubectl get all"),
      EvalCase("show all kubernetes resources", template: "kubectl_get_all", category: "cloud", required: ["kubectl get all"], "Natural: all k8s resources"),
      EvalCase("what's running in kubernetes", template: "kubectl_get_all", category: "cloud", required: ["kubectl get all"], "Natural: what's running"),

      // kubectl_describe
      EvalCase("kubectl describe pod my-app-pod", template: "kubectl_describe", category: "cloud", required: ["kubectl describe"], "Terse: kubectl describe"),
      EvalCase("show details of the failing pod", template: "kubectl_describe", category: "cloud", required: ["kubectl describe"], "Natural: pod details"),
      EvalCase("describe kubernetes pod", template: "kubectl_describe", category: "cloud", required: ["kubectl describe"], "Natural: describe pod"),

      // kubectl_logs
      EvalCase("kubectl logs my-pod", template: "kubectl_logs", category: "cloud", required: ["kubectl logs"], "Terse: kubectl logs"),
      EvalCase("show pod logs for api-server", template: "kubectl_logs", category: "cloud", required: ["kubectl logs"], "Natural: show pod logs"),
      EvalCase("read kubernetes container logs", template: "kubectl_logs", category: "cloud", required: ["kubectl logs"], "Natural: read k8s logs"),

      // kubectl_apply
      EvalCase("kubectl apply manifest deployment.yaml", template: "kubectl_apply", category: "cloud", required: ["kubectl apply", "-f"], "Terse: kubectl apply"),
      EvalCase("deploy kubernetes manifest service.yaml", template: "kubectl_apply", category: "cloud", required: ["kubectl apply", "-f"], "Natural: deploy manifest"),
      EvalCase("apply k8s configuration manifest", template: "kubectl_apply", category: "cloud", required: ["kubectl apply", "-f"], "Natural: apply config"),
    ]

    @Test("Cloud accuracy", arguments: CloudAccuracy.cases)
    func verify(_ tc: EvalCase) { assertAccuracy(tc) }
  }

  // MARK: - Media (33 tests)

  @Suite("Media")
  struct MediaAccuracy {
    static let cases: [EvalCase] = [
      // ffmpeg_convert
      EvalCase("convert video.mov to video.mp4", template: "ffmpeg_convert", category: "media", required: ["ffmpeg", "-i"], "Direct: convert video"),
      EvalCase("transcode the video to mp4 format", template: "ffmpeg_convert", category: "media", required: ["ffmpeg", "-i"], "Natural: transcode"),
      EvalCase("change video format from avi to mkv", template: "ffmpeg_convert", category: "media", required: ["ffmpeg", "-i"], "Natural: change format"),

      // ffmpeg_extract_audio
      EvalCase("extract audio from video.mp4", template: "ffmpeg_extract_audio", category: "media", required: ["ffmpeg", "-i", "-vn"], "Direct: extract audio"),
      EvalCase("rip audio from the video clip", template: "ffmpeg_extract_audio", category: "media", required: ["ffmpeg", "-i", "-vn"], "Natural: rip audio"),
      EvalCase("get audio track from movie.mkv", template: "ffmpeg_extract_audio", category: "media", required: ["ffmpeg", "-i", "-vn"], "Natural: get audio"),

      // ffmpeg_resize_video
      EvalCase("resize video to 1280x720", template: "ffmpeg_resize_video", category: "media", required: ["ffmpeg", "-i", "scale"], "Direct: resize video"),
      EvalCase("downscale the video to 640 width", template: "ffmpeg_resize_video", category: "media", required: ["ffmpeg", "-i", "scale"], "Natural: downscale"),
      EvalCase("shrink video dimensions", template: "ffmpeg_resize_video", category: "media", required: ["ffmpeg", "-i", "scale"], "Natural: shrink video"),

      // ffmpeg_trim
      EvalCase("trim video clip.mp4 from 00:01:00", template: "ffmpeg_trim", category: "media", required: ["ffmpeg", "-i", "-ss"], "Direct: trim video"),
      EvalCase("cut the first 30 seconds of video.mp4", template: "ffmpeg_trim", category: "media", required: ["ffmpeg", "-i"], "Natural: cut video"),
      EvalCase("extract a segment from movie.mkv", template: "ffmpeg_trim", category: "media", required: ["ffmpeg", "-i"], "Natural: extract segment"),

      // ffmpeg_gif
      EvalCase("convert video to gif", template: "ffmpeg_gif", category: "media", required: ["ffmpeg", "-i", "fps"], "Direct: video to gif"),
      EvalCase("make gif from clip.mp4", template: "ffmpeg_gif", category: "media", required: ["ffmpeg", "-i", "fps"], "Natural: make gif"),
      EvalCase("create animated gif from video", template: "ffmpeg_gif", category: "media", required: ["ffmpeg", "-i"], "Natural: create gif"),

      // ffmpeg_info
      EvalCase("video info for clip.mp4", template: "ffmpeg_info", category: "media", required: ["ffprobe"], "Direct: video info"),
      EvalCase("get video metadata for movie.mkv", template: "ffmpeg_info", category: "media", required: ["ffprobe"], "Natural: video metadata"),
      EvalCase("show details about the video file", template: "ffmpeg_info", category: "media", required: ["ffprobe"], "Natural: video details"),

      // magick_convert
      EvalCase("convert image photo.png to photo.jpg", template: "magick_convert", category: "media", required: ["magick"], "Direct: image convert"),
      EvalCase("change image format from png to jpeg", template: "magick_convert", category: "media", required: ["magick"], "Natural: change image format"),
      EvalCase("imagemagick convert screenshot.bmp to png", template: "magick_convert", category: "media", required: ["magick"], "Natural: imagemagick"),

      // magick_resize
      EvalCase("resize image photo.jpg to 800x600", template: "magick_resize", category: "media", required: ["magick"], "Direct: resize image"),
      EvalCase("scale down photo.png to thumbnail", template: "magick_resize", category: "media", required: ["magick"], "Natural: scale down"),
      EvalCase("make image smaller", template: "magick_resize", category: "media", required: ["magick"], "Natural: make smaller"),

      // magick_identify
      EvalCase("identify photo.jpg", template: "magick_identify", category: "media", required: ["magick identify"], "Terse: identify"),
      EvalCase("get image properties of banner.png", template: "magick_identify", category: "media", required: ["magick identify"], "Natural: image properties"),
      EvalCase("image analysis of screenshot.png", template: "magick_identify", category: "media", required: ["magick identify"], "Natural: image analysis"),

      // sips_convert
      EvalCase("sips convert photo.heic to jpg", template: "sips_convert", category: "media", required: ["sips"], "Direct: sips convert"),
      EvalCase("convert image using sips", template: "sips_convert", category: "media", required: ["sips"], "Natural: convert with sips"),
      EvalCase("sips change format of image", template: "sips_convert", category: "media", required: ["sips"], "Natural: sips change format"),

      // sips_getprop
      EvalCase("sips getprop for photo.jpg", template: "sips_getprop", category: "media", required: ["sips"], "Direct: sips getprop"),
      EvalCase("get image properties with sips", template: "sips_getprop", category: "media", required: ["sips"], "Natural: sips properties"),
      EvalCase("check image dimensions with sips", template: "sips_getprop", category: "media", required: ["sips"], "Natural: check dimensions"),
    ]

    @Test("Media accuracy", arguments: MediaAccuracy.cases)
    func verify(_ tc: EvalCase) { assertAccuracy(tc) }
  }

  // MARK: - Shell Scripting (36 tests)

  @Suite("ShellScripting")
  struct ShellScriptingAccuracy {
    static let cases: [EvalCase] = [
      // for_files
      EvalCase("loop over all txt files", template: "for_files", category: "shell_scripting", required: ["for", "in", "do", "done"], "Direct: for files loop"),
      EvalCase("iterate over each swift file", template: "for_files", category: "shell_scripting", required: ["for", "in", "do"], "Natural: iterate files"),
      EvalCase("for each file in directory run command", template: "for_files", category: "shell_scripting", required: ["for", "in", "do"], "Natural: for each file"),

      // for_range
      EvalCase("loop from 1 to 10", template: "for_range", category: "shell_scripting", required: ["for", "in"], "Direct: numeric range"),
      EvalCase("iterate numbers 1 through 100", template: "for_range", category: "shell_scripting", required: ["for", "in"], "Natural: iterate numbers"),
      EvalCase("for loop counter from 1 to 50", template: "for_range", category: "shell_scripting", required: ["for", "in"], "Natural: loop counter"),

      // for_lines
      EvalCase("process file line by line", template: "for_lines", category: "shell_scripting", required: ["while", "read"], "Direct: line by line"),
      EvalCase("read each line of input.txt", template: "for_lines", category: "shell_scripting", required: ["while", "read"], "Natural: read each line"),
      EvalCase("iterate over lines in data.csv", template: "for_lines", category: "shell_scripting", required: ["while", "read"], "Natural: iterate lines"),

      // while_true
      EvalCase("infinite loop", template: "while_true", category: "shell_scripting", required: ["while true", "do"], "Direct: infinite loop"),
      EvalCase("run forever until killed", template: "while_true", category: "shell_scripting", required: ["while true"], "Natural: run forever"),
      EvalCase("endless loop pattern", template: "while_true", category: "shell_scripting", required: ["while true"], "Natural: endless loop"),

      // if_file_exists
      EvalCase("check if file exists", template: "if_file_exists", category: "shell_scripting", required: ["if", "-f"], "Direct: file exists"),
      EvalCase("test if config.yaml is present", template: "if_file_exists", category: "shell_scripting", required: ["if", "-f"], "Natural: is present"),
      EvalCase("conditional on file existence", template: "if_file_exists", category: "shell_scripting", required: ["if", "-f"], "Natural: conditional file"),

      // if_dir_exists
      EvalCase("check if directory exists", template: "if_dir_exists", category: "shell_scripting", required: ["if", "-d"], "Direct: dir exists"),
      EvalCase("test if folder src/ is present", template: "if_dir_exists", category: "shell_scripting", required: ["if", "-d"], "Natural: folder present"),
      EvalCase("conditional on directory existence", template: "if_dir_exists", category: "shell_scripting", required: ["if", "-d"], "Natural: conditional dir"),

      // if_command_succeeds
      EvalCase("if command succeeds then", template: "if_command_succeeds", category: "shell_scripting", required: ["if", "then"], "Direct: if succeeds"),
      EvalCase("run command only if test passes", template: "if_command_succeeds", category: "shell_scripting", required: ["if"], "Natural: only if passes"),
      EvalCase("conditional on command exit code", template: "if_command_succeeds", category: "shell_scripting", required: ["if"], "Natural: exit code"),

      // subshell
      EvalCase("run in subshell", template: "subshell", category: "shell_scripting", required: ["("], "Direct: subshell"),
      EvalCase("execute in isolated subshell", template: "subshell", category: "shell_scripting", required: ["("], "Natural: isolated subshell"),
      EvalCase("run without affecting current shell", template: "subshell", category: "shell_scripting", required: ["("], "Natural: without affecting"),

      // command_substitution
      EvalCase("capture output of date command", template: "command_substitution", category: "shell_scripting", required: ["=$("], "Direct: capture output"),
      EvalCase("store the output of whoami in a variable", template: "command_substitution", category: "shell_scripting", required: ["=$("], "Natural: store output"),
      EvalCase("save command output to variable", template: "command_substitution", category: "shell_scripting", required: ["=$("], "Natural: save output"),

      // here_document
      EvalCase("heredoc to file config.sh", template: "here_document", category: "shell_scripting", required: ["cat", "<<", "EOF"], "Direct: heredoc"),
      EvalCase("write multiline text to script.sh", template: "here_document", category: "shell_scripting", required: ["cat", "<<"], "Natural: multiline text"),
      EvalCase("pass multiline input to a file", template: "here_document", category: "shell_scripting", required: ["cat", "<<"], "Natural: multiline input"),

      // watch_command
      EvalCase("watch git status every 5 seconds", template: "watch_command", category: "shell_scripting", required: ["while true", "sleep"], "Direct: watch command"),
      EvalCase("monitor disk usage every 10 seconds", template: "watch_command", category: "shell_scripting", required: ["while true", "sleep"], "Natural: monitor"),
      EvalCase("run df every 2 seconds and show output", template: "watch_command", category: "shell_scripting", required: ["while true", "sleep"], "Natural: run every N"),
    ]

    @Test("Shell scripting accuracy", arguments: ShellScriptingAccuracy.cases)
    func verify(_ tc: EvalCase) { assertAccuracy(tc) }
  }

  // MARK: - Cross-Category Ambiguity (18 tests)

  @Suite("CrossCategory")
  struct CrossCategoryAccuracy {
    static let cases: [EvalCase] = [
      EvalCase("search for files", template: "find_by_name", category: "file_ops", required: ["find"], "Ambiguous: search files = find not grep"),
      EvalCase("find text errors in the code", template: "grep_search", category: "text_processing", required: ["grep"], "Ambiguous: find text = grep not find"),
      EvalCase("show changes", template: "git_status", category: "git", required: ["git status"], "Ambiguous: show changes = status"),
      EvalCase("delete lines containing debug", template: "sed_delete_lines", category: "text_processing", required: ["sed", "/d"], "Ambiguous: delete lines = sed not rm"),
      EvalCase("list pods", template: "kubectl_get", category: "dev_tools", required: ["kubectl get"], "Ambiguous: list pods = kubectl"),
      EvalCase("run tests", template: "swift_test", category: "dev_tools", required: ["swift test"], "Ambiguous: run tests = swift test"),
      EvalCase("create a new file", template: "touch_file", category: "file_ops", required: ["touch"], "Ambiguous: new file = touch not mkdir"),
      EvalCase("create a new folder", template: "mkdir_dir", category: "file_ops", required: ["mkdir"], "Ambiguous: new folder = mkdir not touch"),
      EvalCase("find process", template: "ps_grep", category: "system", required: ["ps aux", "grep"], "Ambiguous: find process = ps grep"),
      EvalCase("install package", template: "brew_install", category: "packages", required: ["brew install"], "Ambiguous: install = brew on macOS"),
      EvalCase("show history", template: "git_log", category: "git", required: ["git log"], "Ambiguous: history = git log"),
      EvalCase("download file from url", template: "curl_download", category: "network", required: ["curl", "-L", "-o"], "Ambiguous: download = curl"),
      EvalCase("list everything", template: "ls_files", category: "file_ops", required: ["ls"], "Ambiguous: list everything = ls"),
      EvalCase("change permissions to 644", template: "chmod_perms", category: "file_ops", required: ["chmod"], "Ambiguous: change permissions = chmod"),
      EvalCase("check if server is up", template: "ping_host", category: "network", required: ["ping"], "Ambiguous: server up = ping"),
      EvalCase("compress the file", template: "gzip_file", category: "compression", required: ["gzip"], "Ambiguous: compress = gzip default"),
      EvalCase("show log", template: "git_log", category: "git", required: ["git log"], "Ambiguous: show log could be tail or git"),
      EvalCase("remove duplicates", template: "sort_unique", category: "text_processing", required: ["sort", "uniq"], "Ambiguous: remove duplicates = sort|uniq"),
    ]

    @Test("Cross-category ambiguity", arguments: CrossCategoryAccuracy.cases)
    func verify(_ tc: EvalCase) { assertAccuracy(tc) }
  }

  // MARK: - Negative / Edge Cases (15 tests)

  @Suite("NegativeEdge")
  struct NegativeEdgeAccuracy {
    static let cases: [EvalCase] = [
      EvalCase("", template: "_nil_", category: "_nil_", "Negative: empty string"),
      EvalCase("zzzyyyxxx", template: "_nil_", category: "_nil_", "Negative: pure gibberish"),
      EvalCase("what is the meaning of life", template: "_nil_", category: "_nil_", "Negative: off-topic"),
      EvalCase("tell me a joke about programming", template: "_nil_", category: "_nil_", "Negative: joke request"),
      EvalCase("the", template: "_nil_", category: "_nil_", "Negative: single common word"),
      EvalCase("aslkdjfalskdjf", template: "_nil_", category: "_nil_", "Negative: random chars"),
      EvalCase("please and thank you", template: "_nil_", category: "_nil_", "Negative: polite noise"),
      // Edge cases that SHOULD match despite unusual formatting
      EvalCase("FIND ALL THE SWIFT FILES NOW", template: "find_by_extension", category: "file_ops", required: ["find"], "Edge: ALL CAPS query"),
      EvalCase("git git git status", template: "git_status", category: "git", required: ["git status"], "Edge: word repetition"),
      EvalCase("show me the large files that are over 500mb sorted by size", template: "find_large_files", category: "file_ops", required: ["find", "-size"], "Edge: complex compound"),
      EvalCase("I want to see what branches we have", template: "git_branch_list", category: "git", required: ["git branch"], "Edge: verbose padding"),
      EvalCase("could you please show me the disk usage", template: "du_disk_usage", category: "file_ops", required: ["du", "-sh"], "Edge: polite wrapping"),
      EvalCase("yo list my files bro", template: "ls_files", category: "file_ops", required: ["ls"], "Edge: casual slang"),
      EvalCase("files list", template: "ls_files", category: "file_ops", required: ["ls"], "Edge: reversed word order"),
      EvalCase("commits recent show", template: "git_log", category: "git", required: ["git log"], "Edge: fully reversed order"),
    ]

    @Test("Negative and edge cases", arguments: NegativeEdgeAccuracy.cases)
    func verify(_ tc: EvalCase) {
      let result = pipeline.process(tc.query)

      if tc.expectedTemplateId == "_nil_" {
        // Expect nil or very low confidence
        if let result {
          #expect(result.confidence < 0.3,
            "Expected nil/low confidence for '\(tc.query)', got \(result.templateId) with confidence \(result.confidence)")
        }
        // nil is fine
      } else {
        assertAccuracy(tc)
      }
    }
  }

  // MARK: - Comprehensive Accuracy Report

  @Suite("AccuracyReport")
  struct AccuracyReport {

    @Test("Generate comprehensive accuracy report")
    func generateReport() {
      let allCases: [(String, [EvalCase])] = [
        ("FileOps", FileOpsAccuracy.cases),
        ("Git", GitAccuracy.cases),
        ("TextProcessing", TextProcessingAccuracy.cases),
        ("DevTools", DevToolsAccuracy.cases),
        ("MacOS", MacOSAccuracy.cases),
        ("Network", NetworkAccuracy.cases),
        ("System", SystemAccuracy.cases),
        ("Packages", PackagesAccuracy.cases),
        ("Compression", CompressionAccuracy.cases),
        ("Cloud", CloudAccuracy.cases),
        ("Media", MediaAccuracy.cases),
        ("ShellScripting", ShellScriptingAccuracy.cases),
        ("CrossCategory", CrossCategoryAccuracy.cases),
      ]

      let reportPipeline = STMPipeline(config: .debug)

      // Table header
      print("\n" + String(repeating: "=", count: 200))
      print("SHELLTALK ACCURACY REPORT")
      print(String(repeating: "=", count: 200))
      print(String(format: "%-60s | %-20s | %-20s | %-20s | %-20s | %-8s | %-6s | %s",
        "QUERY", "EXPECTED", "ACTUAL", "CATEGORY(exp)", "CATEGORY(act)", "SAFETY", "MS", "COMMAND"))
      print(String(repeating: "-", count: 200))

      var totalCases = 0
      var templateCorrect = 0
      var categoryCorrect = 0
      var substringPass = 0
      var slotPass = 0
      var totalSlotChecks = 0
      var totalSubstringChecks = 0
      var failures: [(query: String, expected: String, got: String, category: String)] = []
      var categoryBreakdown: [String: (total: Int, templateOk: Int, categoryOk: Int)] = [:]

      for (suiteName, cases) in allCases {
        var suiteTotal = 0
        var suiteTemplateOk = 0
        var suiteCategoryOk = 0

        for tc in cases {
          totalCases += 1
          suiteTotal += 1

          let start = CFAbsoluteTimeGetCurrent()
          let result = reportPipeline.process(tc.query)
          let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

          let templateMatch = result?.templateId == tc.expectedTemplateId
          let categoryMatch = result?.categoryId == tc.expectedCategoryId

          if templateMatch { templateCorrect += 1; suiteTemplateOk += 1 }
          if categoryMatch { categoryCorrect += 1; suiteCategoryOk += 1 }

          // Check substrings
          var allSubstringsOk = true
          for substr in tc.requiredSubstrings {
            totalSubstringChecks += 1
            if result?.command.contains(substr) == true {
              substringPass += 1
            } else {
              allSubstringsOk = false
            }
          }

          // Check slots
          var allSlotsOk = true
          for (slot, expected) in tc.requiredSlots {
            totalSlotChecks += 1
            if result?.extractedSlots[slot] == expected {
              slotPass += 1
            } else {
              allSlotsOk = false
            }
          }

          let safetyStr: String
          if let v = result?.validation {
            switch v.safetyLevel {
            case .safe: safetyStr = "SAFE"
            case .caution: safetyStr = "CAUTION"
            case .dangerous: safetyStr = "DANGER"
            }
          } else {
            safetyStr = "N/A"
          }

          let marker = templateMatch ? " " : "X"
          let truncQuery = String(tc.query.prefix(58))
          let truncCmd = String((result?.command ?? "nil").prefix(60))

          print(String(format: "%@ %-58s | %-20s | %-20s | %-20s | %-20s | %-8s | %5.1f | %s",
            marker,
            truncQuery,
            tc.expectedTemplateId,
            result?.templateId ?? "nil",
            tc.expectedCategoryId,
            result?.categoryId ?? "nil",
            safetyStr,
            elapsed,
            truncCmd))

          if !templateMatch {
            failures.append((tc.query, tc.expectedTemplateId, result?.templateId ?? "nil", result?.categoryId ?? "nil"))
          }
        }

        categoryBreakdown[suiteName] = (suiteTotal, suiteTemplateOk, suiteCategoryOk)
      }

      // Negative tests
      print(String(repeating: "-", count: 200))
      print("NEGATIVE / EDGE CASES:")
      print(String(repeating: "-", count: 200))

      var negativeCorrect = 0
      let negativeCases = NegativeEdgeAccuracy.cases

      for tc in negativeCases {
        totalCases += 1
        let start = CFAbsoluteTimeGetCurrent()
        let result = reportPipeline.process(tc.query)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        let isNegative = tc.expectedTemplateId == "_nil_"
        var pass: Bool

        if isNegative {
          pass = result == nil || result!.confidence < 0.3
        } else {
          pass = result?.templateId == tc.expectedTemplateId
          if pass { templateCorrect += 1 }
          if result?.categoryId == tc.expectedCategoryId { categoryCorrect += 1 }
        }
        if pass { negativeCorrect += 1 }

        let marker = pass ? " " : "X"
        let truncQuery = String(tc.query.prefix(58))

        print(String(format: "%@ %-58s | %-20s | %-20s | conf=%.3f | %5.1f | %s",
          marker,
          truncQuery,
          tc.expectedTemplateId,
          result?.templateId ?? "nil",
          result?.confidence ?? 0,
          elapsed,
          tc.description))
      }

      // Summary
      print("\n" + String(repeating: "=", count: 200))
      print("SUMMARY")
      print(String(repeating: "=", count: 200))

      let templateAcc = Double(templateCorrect) / Double(totalCases) * 100
      let categoryAcc = Double(categoryCorrect) / Double(totalCases) * 100
      let substrAcc = totalSubstringChecks > 0 ? Double(substringPass) / Double(totalSubstringChecks) * 100 : 100.0
      let slotAcc = totalSlotChecks > 0 ? Double(slotPass) / Double(totalSlotChecks) * 100 : 100.0

      print(String(format: "Template accuracy:  %d / %d (%.1f%%)", templateCorrect, totalCases, templateAcc))
      print(String(format: "Category accuracy:  %d / %d (%.1f%%)", categoryCorrect, totalCases, categoryAcc))
      print(String(format: "Substring checks:   %d / %d (%.1f%%)", substringPass, totalSubstringChecks, substrAcc))
      print(String(format: "Slot extraction:    %d / %d (%.1f%%)", slotPass, totalSlotChecks, slotAcc))
      print(String(format: "Negative/edge:      %d / %d (%.1f%%)", negativeCorrect, negativeCases.count,
        Double(negativeCorrect) / Double(negativeCases.count) * 100))

      print("\nPER-CATEGORY BREAKDOWN:")
      print(String(format: "%-20s | %8s | %12s | %12s", "Category", "Total", "Template%", "Category%"))
      print(String(repeating: "-", count: 60))
      for (name, stats) in categoryBreakdown.sorted(by: { $0.key < $1.key }) {
        let tPct = Double(stats.templateOk) / Double(stats.total) * 100
        let cPct = Double(stats.categoryOk) / Double(stats.total) * 100
        print(String(format: "%-20s | %8d | %10.1f%% | %10.1f%%", name, stats.total, tPct, cPct))
      }

      if !failures.isEmpty {
        print("\nFAILURES (\(failures.count) total):")
        print(String(format: "%-60s | %-20s | %-20s | %-15s", "QUERY", "EXPECTED", "ACTUAL", "ACT CATEGORY"))
        print(String(repeating: "-", count: 120))
        for f in failures {
          print(String(format: "%-60s | %-20s | %-20s | %-15s",
            String(f.query.prefix(58)), f.expected, f.got, f.category))
        }
      }

      print("\n" + String(repeating: "=", count: 200))

      // Minimum thresholds - soft assertion
      #expect(templateAcc >= 50.0, "Template accuracy \(String(format: "%.1f", templateAcc))% is below 50% minimum")
      #expect(categoryAcc >= 60.0, "Category accuracy \(String(format: "%.1f", categoryAcc))% is below 60% minimum")
    }
  }
}
