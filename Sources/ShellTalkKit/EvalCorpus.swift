// EvalCorpus.swift — Stratified accuracy test corpus used by stm-eval
// and the test target's Linux-baseline suite. Exposed as public library
// so both the executable and swift-test targets can share a single
// source of truth (454 cases as of v1.2.0).

import Foundation

// MARK: - Test Case

public struct EvalCase: Sendable {
  public let query: String
  public let expectedTemplateId: String
  public let expectedCategoryId: String
  public let requiredSubstrings: [String]
  public let forbiddenSubstrings: [String]
  public let requiredSlots: [String: String]
  public let description: String

  public init(
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

// MARK: - All Test Cases
public let allCases: [(String, [EvalCase])] = [
  ("FileOps", [
    EvalCase("ls", template: "ls_files", category: "file_ops", required: ["ls"], "Terse: bare ls"),
    EvalCase("show me all the files in the current directory", template: "ls_files", category: "file_ops", required: ["ls"], "Verbose: list files"),
    EvalCase("what's in this folder", template: "ls_files", category: "file_ops", required: ["ls"], "Colloquial: folder contents"),
    EvalCase("find files named config.yaml", template: "find_by_name", category: "file_ops", required: ["find", "-name"], slots: ["PATTERN": "config.yaml"], "Direct: find by name"),
    EvalCase("where are the files called .gitignore", template: "find_by_name", category: "file_ops", required: ["find", "-name"], "Natural: locate by name"),
    EvalCase("find DS_Store files", template: "find_by_name", category: "file_ops", required: ["find", "-name"], "Edge: dotfile"),
    EvalCase("find swift files", template: "find_by_extension", category: "file_ops", required: ["find", "*.swift"], slots: ["EXT": "swift"], "Direct: find ext"),
    EvalCase("show me the yaml files", template: "find_by_extension", category: "file_ops", required: ["find", "*.yaml"], "Natural: show yaml"),
    EvalCase("find all .json files", template: "find_by_extension", category: "file_ops", required: ["find", "*.json"], "With dot prefix"),
    EvalCase("find files modified today", template: "find_by_mtime", category: "file_ops", required: ["find", "-mtime"], "Direct: modified today"),
    EvalCase("what files changed in the last 3 days", template: "find_by_mtime", category: "file_ops", required: ["find", "-mtime"], slots: ["DAYS": "3"], "Natural: last N days"),
    EvalCase("show recently edited files", template: "find_by_mtime", category: "file_ops", required: ["find", "-mtime"], "Synonym: edited"),
    EvalCase("files changed in the last 30 minutes", template: "find_by_mmin", category: "file_ops", required: ["find", "-mmin"], slots: ["MINUTES": "30"], "Sub-day: minutes"),
    EvalCase("what changed in the last hour", template: "find_by_mmin", category: "file_ops", required: ["find", "-mmin"], "Sub-day: last hour"),
    EvalCase("modified in the past hour", template: "find_by_mmin", category: "file_ops", required: ["find", "-mmin"], "Sub-day: past hour"),
    EvalCase("files modified in the last 10 minutes", template: "find_by_mmin", category: "file_ops", required: ["find", "-mmin"], slots: ["MINUTES": "10"], "Sub-day: 10 min"),
    EvalCase("changed in the past 15 minutes", template: "find_by_mmin", category: "file_ops", required: ["find", "-mmin"], slots: ["MINUTES": "15"], "Sub-day: 15 min"),
    EvalCase("files changed in the last 2 hours", template: "find_by_mmin_hours", category: "file_ops", required: ["find", "-mmin"], "Sub-day: 2 hours"),
    EvalCase("modified in the past 3 hours", template: "find_by_mmin_hours", category: "file_ops", required: ["find", "-mmin"], "Sub-day: 3 hours"),
    EvalCase("files from the last few hours", template: "find_by_mmin_hours", category: "file_ops", required: ["find", "-mmin"], "Sub-day: few hours"),
    EvalCase("find files larger than 100M", template: "find_large_files", category: "file_ops", required: ["find", "-size"], slots: ["SIZE": "100M"], "Direct: large files"),
    EvalCase("what are the largest files", template: "find_large_files", category: "file_ops", required: ["find", "-size"], "Natural: biggest files"),
    EvalCase("find huge files over 1G", template: "find_large_files", category: "file_ops", required: ["find", "-size"], "Synonym: huge"),
    EvalCase("copy main.swift to backup/", template: "cp_file", category: "file_ops", required: ["cp"], slots: ["SOURCE": "main.swift", "DEST": "backup/"], "Direct: copy"),
    EvalCase("make a copy of package.json", template: "cp_file", category: "file_ops", required: ["cp"], "Natural: make copy"),
    EvalCase("duplicate the config file", template: "cp_file", category: "file_ops", required: ["cp"], "Synonym: duplicate"),
    EvalCase("move old.txt to archive/", template: "mv_file", category: "file_ops", required: ["mv"], slots: ["SOURCE": "old.txt", "DEST": "archive/"], "Direct: move"),
    EvalCase("rename config.yml as config.yaml", template: "mv_file", category: "file_ops", required: ["mv"], "Natural: rename"),
    EvalCase("mv README.md to docs/", template: "mv_file", category: "file_ops", required: ["mv", "README.md"], "Terse: mv"),
    EvalCase("delete temp.txt", template: "rm_file", category: "file_ops", required: ["rm"], slots: ["PATH": "temp.txt"], "Direct: delete"),
    EvalCase("remove the old log files", template: "rm_file", category: "file_ops", required: ["rm"], "Natural: remove"),
    EvalCase("trash build artifacts", template: "rm_file", category: "file_ops", required: ["rm"], "Synonym: trash"),
    EvalCase("create directory src/models", template: "mkdir_dir", category: "file_ops", required: ["mkdir", "-p"], slots: ["PATH": "src/models"], "Direct: mkdir"),
    EvalCase("make a new folder called output", template: "mkdir_dir", category: "file_ops", required: ["mkdir", "-p"], "Natural: new folder"),
    EvalCase("mkdir tests/fixtures", template: "mkdir_dir", category: "file_ops", required: ["mkdir", "-p"], "Terse: mkdir"),
    EvalCase("make script.sh executable", template: "chmod_executable", category: "file_ops", required: ["chmod", "+x"], "Natural: executable"),
    EvalCase("chmod 755 server.sh", template: "chmod_perms", category: "file_ops", required: ["chmod"], "Terse: chmod numeric"),
    EvalCase("disk usage", template: "du_disk_usage", category: "file_ops", required: ["du", "-sh"], "Terse: du"),
    EvalCase("how much space is src using", template: "du_disk_usage", category: "file_ops", required: ["du", "-sh"], "Natural: space"),
    EvalCase("count files", template: "file_count", category: "file_ops", required: ["find", "wc"], "Direct: count"),
    EvalCase("how many files are in this directory", template: "file_count", category: "file_ops", required: ["find", "wc"], "Natural: how many"),
    EvalCase("tree", template: "tree_view", category: "file_ops", required: ["find"], "Terse: tree"),
    EvalCase("show directory structure", template: "tree_view", category: "file_ops", required: ["find"], "Natural: structure"),
    EvalCase("file info for main.swift", template: "file_info", category: "file_ops", required: ["file"], "Direct: file info"),
    EvalCase("what type of file is output.bin", template: "file_info", category: "file_ops", required: ["file"], "Natural: file type"),
    EvalCase("create empty file notes.txt", template: "touch_file", category: "file_ops", required: ["touch"], "Direct: create file"),
    EvalCase("touch README.md", template: "touch_file", category: "file_ops", required: ["touch"], "Terse: touch"),
    EvalCase("create symlink to /usr/local/bin/app", template: "symlink", category: "file_ops", required: ["ln", "-s"], "Direct: symlink"),
    EvalCase("ln -s source target", template: "symlink", category: "file_ops", required: ["ln", "-s"], "Terse: ln -s"),
    EvalCase("backup my config", template: "cp_file", category: "file_ops", required: ["cp"], "Synonym: backup"),
    EvalCase("relocate logs to /tmp", template: "mv_file", category: "file_ops", required: ["mv"], "Synonym: relocate"),
    EvalCase("transfer data.csv to archive/", template: "mv_file", category: "file_ops", required: ["mv"], "Synonym: transfer"),
    EvalCase("give me write access to this folder", template: "chmod_perms", category: "file_ops", required: ["chmod"], "Natural: write access"),
    EvalCase("make this file read only", template: "chmod_perms", category: "file_ops", required: ["chmod"], "Natural: read only"),
    EvalCase("who owns this file", template: "chown_owner", category: "file_ops", required: ["chown"], "Natural: file owner"),
  ]),

  ("FileExtensions", [
    // Format-name aliases (failing on baseline; canonicalize on Cand-002).
    // Required substrings use quoted form "'*.md'" to avoid false-positive
    // matches (e.g. baseline "*.markdown" does NOT contain "'*.md'" but
    // WOULD contain bare "*.md").
    EvalCase("find all Markdown files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.md'"], slots: ["EXT": "md"], "Alias: Markdown→md (capitalized)"),
    EvalCase("find markdown files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.md'"], slots: ["EXT": "md"], "Alias: markdown→md (lowercase)"),
    EvalCase("list JavaScript files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.js'"], slots: ["EXT": "js"], "Alias: JavaScript→js"),
    EvalCase("find all TypeScript files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.ts'"], slots: ["EXT": "ts"], "Alias: TypeScript→ts"),
    EvalCase("find Python files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.py'"], slots: ["EXT": "py"], "Alias: Python→py"),
    EvalCase("list all Python files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.py'"], slots: ["EXT": "py"], "Alias: Python (with 'all')"),
    EvalCase("find Ruby files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.rb'"], slots: ["EXT": "rb"], "Alias: Ruby→rb"),
    EvalCase("find all Golang files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.go'"], slots: ["EXT": "go"], "Alias: Golang→go"),
    EvalCase("find Rust files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.rs'"], slots: ["EXT": "rs"], "Alias: Rust→rs"),
    EvalCase("find Kotlin files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.kt'"], slots: ["EXT": "kt"], "Alias: Kotlin→kt"),
    EvalCase("find shell files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.sh'"], slots: ["EXT": "sh"], "Alias: shell→sh"),

    // Case normalization — uppercase input should lowercase before lookup.
    EvalCase("find YAML files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.yaml'"], slots: ["EXT": "yaml"], "Case: YAML→yaml (identity, lowercased)"),
    EvalCase("find MARKDOWN files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.md'"], slots: ["EXT": "md"], "Case+alias: MARKDOWN→md"),
    EvalCase("find all PYTHON files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.py'"], slots: ["EXT": "py"], "Case+alias: PYTHON→py"),

    // Identity fallback — unknown format name is lowercased (not mangled).
    EvalCase("find CONFIG files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.config'"], slots: ["EXT": "config"], "Identity fallback: unknown uppercase lowercases"),

    // Dot-prefix form exercises regex's second alternation.
    EvalCase("list all .ts files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.ts'"], slots: ["EXT": "ts"], "Dot form: .ts (identity)"),

    // Identity: known-short lowercase format name should be unchanged.
    EvalCase("find HTML files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.html'"], slots: ["EXT": "html"], "Case+identity: HTML→html"),
  ]),

  ("Git", [
    EvalCase("git status", template: "git_status", category: "git", required: ["git status"], "Terse"),
    EvalCase("what files have I changed", template: "git_status", category: "git", required: ["git status"], "Natural"),
    EvalCase("show me uncommitted changes", template: "git_status", category: "git", required: ["git status"], "Natural: uncommitted"),
    EvalCase("git diff", template: "git_diff", category: "git", required: ["git diff"], "Terse"),
    EvalCase("show me what's different", template: "git_diff", category: "git", required: ["git diff"], "Natural"),
    EvalCase("compare changes in main.swift", template: "git_diff", category: "git", required: ["git diff"], "With file"),
    EvalCase("show staged diff", template: "git_diff_staged", category: "git", required: ["git diff", "--cached"], "Direct"),
    EvalCase("what's staged for commit", template: "git_diff_staged", category: "git", required: ["git diff", "--cached"], "Natural"),
    EvalCase("git log", template: "git_log", category: "git", required: ["git log", "--oneline"], "Terse"),
    EvalCase("show last 5 commits", template: "git_log", category: "git", required: ["git log"], slots: ["COUNT": "5"], "Natural: count"),
    EvalCase("recent commit history", template: "git_log", category: "git", required: ["git log"], "Natural"),
    EvalCase("git log graph", template: "git_log_graph", category: "git", required: ["git log", "--graph"], "Direct"),
    EvalCase("show branch tree", template: "git_log_graph", category: "git", required: ["git log", "--graph"], "Natural"),
    EvalCase("git add main.swift", template: "git_add", category: "git", required: ["git add"], "Terse"),
    EvalCase("stage all changes", template: "git_add", category: "git", required: ["git add"], "Natural"),
    EvalCase("git commit", template: "git_commit", category: "git", required: ["git commit"], "Terse"),
    EvalCase("commit changes with message fix bug", template: "git_commit", category: "git", required: ["git commit", "-m"], "Natural"),
    EvalCase("git branch", template: "git_branch_list", category: "git", required: ["git branch"], "Terse"),
    EvalCase("list all branches", template: "git_branch_list", category: "git", required: ["git branch"], "Natural"),
    EvalCase("create branch feature/auth", template: "git_branch_create", category: "git", required: ["git checkout", "-b"], slots: ["BRANCH": "feature/auth"], "Direct"),
    EvalCase("make a new branch called hotfix", template: "git_branch_create", category: "git", required: ["git checkout", "-b"], "Natural"),
    EvalCase("switch to main", template: "git_switch", category: "git", required: ["git switch"], slots: ["BRANCH": "main"], "Direct"),
    EvalCase("checkout the develop branch", template: "git_switch", category: "git", required: ["git switch"], "Natural"),
    EvalCase("git stash", template: "git_stash", category: "git", required: ["git stash"], forbidden: ["pop"], "Terse"),
    EvalCase("stash my current changes", template: "git_stash", category: "git", required: ["git stash"], forbidden: ["pop"], "Natural"),
    EvalCase("git stash pop", template: "git_stash_pop", category: "git", required: ["git stash pop"], "Terse"),
    EvalCase("restore my stashed changes", template: "git_stash_pop", category: "git", required: ["git stash pop"], "Natural"),
    EvalCase("merge develop", template: "git_merge", category: "git", required: ["git merge"], slots: ["BRANCH": "develop"], "Direct"),
    EvalCase("git rebase main", template: "git_rebase", category: "git", required: ["git rebase"], "Terse"),
    EvalCase("rebase onto master", template: "git_rebase", category: "git", required: ["git rebase"], "Natural"),
    EvalCase("git remote", template: "git_remote", category: "git", required: ["git remote"], "Terse"),
    EvalCase("show remotes", template: "git_remote", category: "git", required: ["git remote"], "Natural"),
    EvalCase("git pull", template: "git_pull", category: "git", required: ["git pull"], "Terse"),
    EvalCase("pull latest changes", template: "git_pull", category: "git", required: ["git pull"], "Natural"),
    EvalCase("git push", template: "git_push", category: "git", required: ["git push"], "Terse"),
    EvalCase("push my commits to remote", template: "git_push", category: "git", required: ["git push"], "Natural"),
    EvalCase("git blame main.swift", template: "git_blame", category: "git", required: ["git blame"], "Terse"),
    EvalCase("who changed AppDelegate.swift", template: "git_blame", category: "git", required: ["git blame"], "Natural"),
    EvalCase("cherry pick abc1234", template: "git_cherry_pick", category: "git", required: ["git cherry-pick"], slots: ["COMMIT": "abc1234"], "Direct"),
    EvalCase("git tag v1.0.0", template: "git_tag", category: "git", required: ["git tag"], slots: ["TAG": "v1.0.0"], "Terse"),
    EvalCase("create tag for release", template: "git_tag", category: "git", required: ["git tag"], "Natural"),
  ]),

  ("TextProcessing", [
    EvalCase("grep TODO in src/", template: "grep_search", category: "text_processing", required: ["grep", "-rn"], "Direct"),
    EvalCase("search for error in log files", template: "grep_search", category: "text_processing", required: ["grep"], "Natural"),
    EvalCase("find occurrences of FIXME", template: "grep_search", category: "text_processing", required: ["grep"], "Natural: find occurrences"),
    EvalCase("count occurrences of import", template: "grep_count", category: "text_processing", required: ["grep", "-rc"], "Direct"),
    EvalCase("how many times does TODO appear", template: "grep_count", category: "text_processing", required: ["grep", "-rc"], "Natural"),
    EvalCase("rg pattern", template: "rg_search", category: "text_processing", required: ["rg"], "Terse"),
    EvalCase("ripgrep search for function", template: "rg_search", category: "text_processing", required: ["rg"], "Direct"),
    EvalCase("replace foo with bar in config.yaml", template: "sed_replace", category: "text_processing", required: ["sed", "foo", "bar"], slots: ["FIND": "foo", "REPLACE": "bar"], "Direct: replace"),
    EvalCase("find and replace oldName with newName", template: "sed_replace", category: "text_processing", required: ["sed"], "Natural"),
    EvalCase("substitute http with https", template: "sed_replace", category: "text_processing", required: ["sed"], "Synonym"),
    EvalCase("delete lines matching DEBUG in app.log", template: "sed_delete_lines", category: "text_processing", required: ["sed", "/d"], "Direct"),
    EvalCase("remove lines containing TODO", template: "sed_delete_lines", category: "text_processing", required: ["sed", "/d"], "Natural"),
    EvalCase("extract column 2 from data.csv", template: "awk_column", category: "text_processing", required: ["awk"], slots: ["COL": "2"], "Direct"),
    EvalCase("awk column 1 from access.log", template: "awk_column", category: "text_processing", required: ["awk"], "Terse"),
    EvalCase("sort names.txt", template: "sort_file", category: "text_processing", required: ["sort"], "Direct"),
    EvalCase("remove duplicates from list.txt", template: "sort_unique", category: "text_processing", required: ["sort", "uniq"], "Direct"),
    EvalCase("deduplicate entries", template: "sort_unique", category: "text_processing", required: ["sort", "uniq"], "Synonym"),
    EvalCase("count lines in README.md", template: "wc_count", category: "text_processing", required: ["wc"], "Direct"),
    EvalCase("how many lines in main.swift", template: "wc_count", category: "text_processing", required: ["wc"], "Natural"),
    EvalCase("head main.swift", template: "head_file", category: "text_processing", required: ["head"], "Terse"),
    EvalCase("show first 20 lines of config.yaml", template: "head_file", category: "text_processing", required: ["head"], slots: ["COUNT": "20"], "Natural"),
    EvalCase("tail server.log", template: "tail_file", category: "text_processing", required: ["tail"], "Terse"),
    EvalCase("show last 50 lines of error.log", template: "tail_file", category: "text_processing", required: ["tail"], slots: ["COUNT": "50"], "Natural"),
    EvalCase("tail -f server.log", template: "tail_follow", category: "text_processing", required: ["tail", "-f"], "Terse"),
    EvalCase("follow the log file", template: "tail_follow", category: "text_processing", required: ["tail", "-f"], "Natural"),
    EvalCase("convert to lowercase", template: "tr_replace", category: "text_processing", required: ["tr"], "Natural"),
    EvalCase("find TODO comments", template: "grep_search", category: "text_processing", required: ["grep"], "Cross: find + content"),
    EvalCase("find all references to UserModel", template: "grep_search", category: "text_processing", required: ["grep"], "Cross: find references"),
    EvalCase("find files with TODO", template: "grep_search", category: "text_processing", required: ["grep"], "Cross: find + content word"),
    EvalCase("parse json from data.json", template: "jq_parse", category: "text_processing", required: ["jq"], "Direct"),
    EvalCase("pretty print json", template: "jq_parse", category: "text_processing", required: ["jq"], "Natural"),
  ]),

  ("DevTools", [
    EvalCase("swift build", template: "swift_build", category: "dev_tools", required: ["swift build"], "Terse"),
    EvalCase("build the swift project", template: "swift_build", category: "dev_tools", required: ["swift build"], "Natural"),
    EvalCase("swift build -c release", template: "swift_build_release", category: "dev_tools", required: ["swift build", "-c release"], "Terse"),
    EvalCase("build for release", template: "swift_build_release", category: "dev_tools", required: ["swift build", "-c release"], "Natural"),
    EvalCase("swift test", template: "swift_test", category: "dev_tools", required: ["swift test"], "Terse"),
    EvalCase("run the unit tests", template: "swift_test", category: "dev_tools", required: ["swift test"], "Natural"),
    EvalCase("swift run", template: "swift_run", category: "dev_tools", required: ["swift run"], "Terse"),
    EvalCase("cargo build", template: "cargo_build", category: "dev_tools", required: ["cargo build"], "Terse"),
    EvalCase("build the rust project", template: "cargo_build", category: "dev_tools", required: ["cargo build"], "Natural"),
    EvalCase("cargo test", template: "cargo_test", category: "dev_tools", required: ["cargo test"], "Terse"),
    EvalCase("cargo run", template: "cargo_run", category: "dev_tools", required: ["cargo run"], "Terse"),
    EvalCase("go build", template: "go_build", category: "dev_tools", required: ["go build"], "Terse"),
    EvalCase("go test", template: "go_test", category: "dev_tools", required: ["go test"], "Terse"),
    EvalCase("npm run dev", template: "npm_run", category: "dev_tools", required: ["npm run"], "Terse"),
    EvalCase("start the dev server", template: "npm_run", category: "dev_tools", required: ["npm run"], "Natural"),
    EvalCase("python3 script.py", template: "python_run", category: "dev_tools", required: ["python3"], "Terse"),
    EvalCase("run the python script main.py", template: "python_run", category: "dev_tools", required: ["python3"], "Natural"),
    EvalCase("docker build -t myapp .", template: "docker_build", category: "dev_tools", required: ["docker build"], "Terse"),
    EvalCase("docker run nginx", template: "docker_run", category: "dev_tools", required: ["docker run"], "Terse"),
    EvalCase("docker ps", template: "docker_ps", category: "dev_tools", required: ["docker ps"], "Terse"),
    EvalCase("show running docker containers", template: "docker_ps", category: "dev_tools", required: ["docker ps"], "Natural"),
    EvalCase("kubectl get pods", template: "kubectl_get", category: "dev_tools", required: ["kubectl get"], "Terse"),
    EvalCase("list kubernetes pods", template: "kubectl_get", category: "dev_tools", required: ["kubectl get"], "Natural"),
  ]),

  ("Network", [
    EvalCase("curl https://api.example.com/data", template: "curl_get", category: "network", required: ["curl"], "Terse"),
    EvalCase("fetch the url https://httpbin.org/get", template: "curl_get", category: "network", required: ["curl"], "Natural"),
    EvalCase("post json to https://api.example.com/users", template: "curl_post_json", category: "network", required: ["curl", "-X POST"], "Direct"),
    EvalCase("download https://example.com/file.tar.gz", template: "curl_download", category: "network", required: ["curl", "-L", "-o"], "Direct"),
    EvalCase("curl headers for https://example.com", template: "curl_headers", category: "network", required: ["curl", "-sI"], "Direct"),
    EvalCase("ssh into production server", template: "ssh_connect", category: "network", required: ["ssh"], "Direct"),
    EvalCase("scp config.yaml to server", template: "scp_copy", category: "network", required: ["scp"], "Direct"),
    EvalCase("netcat listen on port 8080", template: "nc_listen", category: "network", required: ["nc", "-l"], "Direct"),
    EvalCase("dig example.com", template: "dig_lookup", category: "network", required: ["dig"], "Terse"),
    EvalCase("dns lookup for google.com", template: "dig_lookup", category: "network", required: ["dig"], "Natural: dns lookup"),
    EvalCase("what's on port 8080", template: "lsof_ports", category: "network", required: ["lsof", "-i"], "Direct"),
    EvalCase("who is using port 3000", template: "lsof_ports", category: "network", required: ["lsof", "-i"], "Natural"),
    EvalCase("ping google.com", template: "ping_host", category: "network", required: ["ping", "-c"], "Terse"),
    EvalCase("test connectivity to api.example.com", template: "ping_host", category: "network", required: ["ping", "-c"], "Natural"),
  ]),

  ("CurlAdvanced", [
    // PUT/PATCH/DELETE
    EvalCase("send PUT request to https://api.example.com/users/1", template: "curl_put", category: "network", required: ["curl", "-X PUT"], "Direct: PUT"),
    EvalCase("update resource via PUT https://api.example.com/users/2", template: "curl_put", category: "network", required: ["curl", "-X PUT"], "Natural: update PUT"),
    EvalCase("send PATCH request to https://api.example.com/users/3", template: "curl_patch", category: "network", required: ["curl", "-X PATCH"], "Direct: PATCH"),
    EvalCase("partial update via PATCH https://api.example.com/users/4", template: "curl_patch", category: "network", required: ["curl", "-X PATCH"], "Natural: PATCH partial"),
    EvalCase("send DELETE request to https://api.example.com/users/5", template: "curl_delete", category: "network", required: ["curl", "-X DELETE"], "Direct: DELETE"),
    EvalCase("delete resource via curl at https://api.example.com/users/6", template: "curl_delete", category: "network", required: ["curl", "-X DELETE"], "Natural: DELETE resource"),
    // Redirects
    EvalCase("curl follow redirects on https://example.com/redirect", template: "curl_follow_redirects", category: "network", required: ["curl", "-sL"], "Direct: follow"),
    EvalCase("fetch https://example.com following 30x redirects", template: "curl_follow_redirects", category: "network", required: ["curl", "-sL"], "Natural: follow 30x"),
    // Basic auth
    EvalCase("curl with basic auth user:pass to https://api.example.com/me", template: "curl_basic_auth", category: "network", required: ["curl", "-u"], "Direct: basic auth"),
    EvalCase("authenticate via basic auth on https://example.com/private", template: "curl_basic_auth", category: "network", required: ["curl", "-u"], "Natural: basic auth"),
    // File upload form
    EvalCase("curl upload file report.pdf to https://api.example.com/upload", template: "curl_form_upload", category: "network", required: ["curl", "-F"], "Direct: form upload"),
    EvalCase("multipart form upload of image.jpg to https://example.com/post", template: "curl_form_upload", category: "network", required: ["curl", "-F"], "Natural: multipart"),
    // Download with progress
    EvalCase("curl download with progress bar https://example.com/file.tar.gz", template: "curl_download_progress", category: "network", required: ["curl", "--progress-bar"], "Direct: progress"),
    EvalCase("download file with progress meter https://example.com/big.iso", template: "curl_download_progress", category: "network", required: ["curl", "--progress-bar"], "Natural: progress meter"),
    // Resume
    EvalCase("curl resume download https://example.com/big.iso", template: "curl_resume", category: "network", required: ["curl", "-C -"], "Direct: resume"),
    EvalCase("continue interrupted download from https://example.com/large.zip", template: "curl_resume", category: "network", required: ["curl", "-C -"], "Natural: continue interrupted"),
    // mTLS
    EvalCase("curl with client certificate to https://mtls.example.com", template: "curl_mtls", category: "network", required: ["curl", "--cert"], "Direct: mtls"),
    EvalCase("mtls request to https://api.example.com using client cert", template: "curl_mtls", category: "network", required: ["curl", "--cert"], "Natural: mtls"),
    // Cookies
    EvalCase("curl with cookies from cookies.txt for https://example.com", template: "curl_cookies", category: "network", required: ["curl", "-b"], "Direct: cookies"),
    EvalCase("include cookies in request to https://example.com/auth", template: "curl_cookies", category: "network", required: ["curl", "-b"], "Natural: include cookies"),
    // User agent
    EvalCase("curl with custom user agent to https://example.com", template: "curl_user_agent", category: "network", required: ["curl", "-A"], "Direct: UA"),
    EvalCase("set user agent string for https://example.com", template: "curl_user_agent", category: "network", required: ["curl", "-A"], "Natural: UA string"),
    // Timing
    EvalCase("curl timing breakdown for https://example.com", template: "curl_timing", category: "network", required: ["curl", "-w"], "Direct: timing"),
    EvalCase("show curl request timing details for https://example.com", template: "curl_timing", category: "network", required: ["curl", "-w"], "Natural: timing detail"),
    // Save headers separately
    EvalCase("curl save response headers to headers.txt for https://example.com", template: "curl_save_headers", category: "network", required: ["curl", "-D"], "Direct: save headers"),
    // HEAD method
    EvalCase("curl HEAD request to https://example.com", template: "curl_head_method", category: "network", required: ["curl", "-X HEAD"], "Direct: HEAD"),
    // Max time / timeout
    EvalCase("curl with max time 10 seconds for https://example.com", template: "curl_max_time", category: "network", required: ["curl", "--max-time"], "Direct: timeout"),
    EvalCase("limit curl request duration to 5 seconds for https://example.com", template: "curl_max_time", category: "network", required: ["curl", "--max-time"], "Natural: limit duration"),
    // ipv4 / ipv6
    EvalCase("curl ipv4 only for https://example.com", template: "curl_ipv4", category: "network", required: ["curl", "-4"], "Direct: ipv4"),
    EvalCase("curl ipv6 only for https://example.com", template: "curl_ipv6", category: "network", required: ["curl", "-6"], "Direct: ipv6"),
    // Verbose
    EvalCase("curl verbose for https://example.com debug", template: "curl_verbose", category: "network", required: ["curl", "-v"], "Direct: verbose"),
    EvalCase("show curl request and response details https://example.com", template: "curl_verbose", category: "network", required: ["curl", "-v"], "Natural: verbose detail"),
    // Status only
    EvalCase("curl get status code only for https://example.com", template: "curl_status_only", category: "network", required: ["curl", "%{http_code}"], "Direct: status only"),
    EvalCase("get http status with curl for https://example.com", template: "curl_status_only", category: "network", required: ["curl", "%{http_code}"], "Natural: http status"),
    // POST form-encoded
    EvalCase("curl post form data to https://example.com/login", template: "curl_post_form", category: "network", required: ["curl", "-X POST", "-d"], "Direct: form post"),
    EvalCase("post application/x-www-form-urlencoded fields to https://example.com/api", template: "curl_post_form", category: "network", required: ["curl", "-X POST", "-d"], "Natural: form fields"),
  ]),

  ("System", [
    EvalCase("ps", template: "ps_list", category: "system", required: ["ps aux"], "Terse"),
    EvalCase("show all running processes", template: "ps_list", category: "system", required: ["ps aux"], "Natural"),
    EvalCase("find process node", template: "ps_grep", category: "system", required: ["ps aux", "grep"], "Direct"),
    EvalCase("is nginx running", template: "ps_grep", category: "system", required: ["ps aux", "grep"], "Natural"),
    EvalCase("kill process 1234", template: "kill_process", category: "system", required: ["kill"], "Direct"),
    EvalCase("killall Safari", template: "killall_name", category: "system", required: ["killall"], "Terse"),
    EvalCase("top", template: "top_snapshot", category: "system", required: ["top"], "Terse"),
    EvalCase("what's using the most cpu", template: "top_snapshot", category: "system", required: ["top"], "Natural"),
    EvalCase("df", template: "df_disk_free", category: "system", required: ["df", "-h"], "Terse"),
    EvalCase("how much disk space is free", template: "df_disk_free", category: "system", required: ["df", "-h"], "Natural"),
    EvalCase("biggest directories", template: "du_summary", category: "system", required: ["du", "-sh"], "Direct"),
    EvalCase("uname", template: "uname_info", category: "system", required: ["uname"], "Terse"),
    EvalCase("what os is this", template: "uname_info", category: "system", required: ["uname"], "Natural"),
    EvalCase("sw_vers", template: "sw_vers", category: "system", required: ["sw_vers"], "Terse"),
    EvalCase("what version of macos", template: "sw_vers", category: "system", required: ["sw_vers"], "Natural"),
    EvalCase("env", template: "env_vars", category: "system", required: ["env"], "Terse"),
    EvalCase("show environment variables", template: "env_vars", category: "system", required: ["env"], "Natural"),
    EvalCase("which python3", template: "which_cmd", category: "system", required: ["which"], "Terse"),
    EvalCase("uptime", template: "uptime", category: "system", required: ["uptime"], "Terse"),
    EvalCase("whoami", template: "whoami", category: "system", required: ["whoami"], "Terse"),
    EvalCase("what user am I", template: "whoami", category: "system", required: ["whoami"], "Natural"),
  ]),

  ("Packages", [
    EvalCase("brew install wget", template: "brew_install", category: "packages", required: ["brew install"], "Terse"),
    EvalCase("install wget with homebrew", template: "brew_install", category: "packages", required: ["brew install"], "Natural"),
    EvalCase("brew search ripgrep", template: "brew_search", category: "packages", required: ["brew search"], "Terse"),
    EvalCase("brew list", template: "brew_list", category: "packages", required: ["brew list"], "Terse"),
    EvalCase("brew update", template: "brew_update", category: "packages", required: ["brew update"], "Terse"),
    EvalCase("brew info node", template: "brew_info", category: "packages", required: ["brew info"], "Terse"),
    EvalCase("npm install express", template: "npm_install", category: "packages", required: ["npm install"], "Terse"),
    EvalCase("pip install requests", template: "pip_install", category: "packages", required: ["pip3 install"], "Terse"),
    EvalCase("pip freeze", template: "pip_freeze", category: "packages", required: ["pip3 freeze"], "Terse"),
    EvalCase("generate requirements.txt", template: "pip_freeze", category: "packages", required: ["pip3 freeze"], "Natural"),
    EvalCase("cargo add serde", template: "cargo_add", category: "packages", required: ["cargo add"], "Terse"),
    EvalCase("gem install rails", template: "gem_install", category: "packages", required: ["gem install"], "Terse"),
    EvalCase("install jq on this mac", template: "brew_install", category: "packages", required: ["brew install"], "Natural: install tool"),
    EvalCase("npm install typescript", template: "npm_install", category: "packages", required: ["npm install"], "Explicit: npm prefix"),
    EvalCase("install a python package numpy", template: "pip_install", category: "packages", required: ["pip3 install"], "Explicit: python package"),
  ]),

  ("Compression", [
    EvalCase("create tar archive of src/", template: "tar_create", category: "compression", required: ["tar", "-czf"], "Direct"),
    EvalCase("extract archive.tar.gz", template: "tar_extract", category: "compression", required: ["tar", "-xzf"], "Direct"),
    EvalCase("untar backup.tar.gz", template: "tar_extract", category: "compression", required: ["tar", "-xzf"], "Synonym"),
    EvalCase("list contents of archive.tar.gz", template: "tar_list", category: "compression", required: ["tar", "-tzf"], "Direct"),
    EvalCase("gzip database.sql", template: "gzip_file", category: "compression", required: ["gzip"], "Terse"),
    EvalCase("gunzip data.gz", template: "gunzip_file", category: "compression", required: ["gunzip"], "Terse"),
    EvalCase("zip the documents folder", template: "zip_create", category: "compression", required: ["zip", "-r"], "Direct"),
    EvalCase("unzip release.zip", template: "unzip_extract", category: "compression", required: ["unzip"], "Terse"),
    EvalCase("xz compress backup.sql", template: "xz_compress", category: "compression", required: ["xz"], "Direct"),
    EvalCase("zstd compress database.sql", template: "zstd_compress", category: "compression", required: ["zstd"], "Direct"),
  ]),

  ("TarAdvanced", [
    // tar.xz / tar.zst — modern compression formats
    EvalCase("create tar.xz archive of project/", template: "tar_create_xz", category: "compression", required: ["tar", "-cJf"], "Direct: tar.xz"),
    EvalCase("make a tar.xz of dist as release.tar.xz", template: "tar_create_xz", category: "compression", required: ["tar", "-cJf"], "Direct: named tar.xz"),
    EvalCase("create tar.zst archive of build/", template: "tar_create_zst", category: "compression", required: ["tar", "-cf"], "Direct: tar.zst"),
    EvalCase("compress build directory with zstandard tar", template: "tar_create_zst", category: "compression", required: ["tar", "-cf"], "Natural: zstandard"),
    EvalCase("extract release.tar.xz", template: "tar_extract_xz", category: "compression", required: ["tar", "-xJf"], "Direct: extract xz"),
    EvalCase("untar payload.tar.xz", template: "tar_extract_xz", category: "compression", required: ["tar", "-xJf"], "Synonym: untar xz"),
    EvalCase("extract bundle.tar.zst", template: "tar_extract_zst", category: "compression", required: ["tar", "-xf"], "Direct: extract zst"),
    EvalCase("decompress source.tar.zst", template: "tar_extract_zst", category: "compression", required: ["tar", "-xf"], "Synonym: decompress zst"),
    // -C dest dir
    EvalCase("extract archive.tar.gz into /tmp/build directory", template: "tar_extract_to_dir", category: "compression", required: ["tar", "-xzf", "-C"], "Direct: into dir"),
    EvalCase("untar source.tar.gz into ./vendor output directory", template: "tar_extract_to_dir", category: "compression", required: ["tar", "-xzf", "-C"], "Natural: into output dir"),
    // strip-components
    EvalCase("extract source.tar.gz strip 1 component", template: "tar_extract_strip", category: "compression", required: ["tar", "--strip-components"], slots: ["N": "1"], "Direct: strip 1"),
    EvalCase("untar release.tar.gz removing top folder", template: "tar_extract_strip", category: "compression", required: ["tar", "--strip-components"], "Natural: remove top"),
    // verbose listing
    EvalCase("verbose list of archive.tar.gz", template: "tar_list_verbose", category: "compression", required: ["tar", "-tvzf"], "Direct: verbose list"),
    EvalCase("show tar contents with sizes for backup.tar.gz", template: "tar_list_verbose", category: "compression", required: ["tar", "-tvzf"], "Natural: with sizes"),
    // append
    EvalCase("append notes.txt to archive.tar", template: "tar_append", category: "compression", required: ["tar", "-rf"], "Direct: append"),
    EvalCase("add config.yaml to existing.tar", template: "tar_append", category: "compression", required: ["tar", "-rf"], "Synonym: add to"),
    // exclude
    EvalCase("compress src/ excluding node_modules", template: "tar_exclude", category: "compression", required: ["tar", "-czf", "--exclude"], "Direct: exclude"),
    EvalCase("create tar of repo but skip .git", template: "tar_exclude", category: "compression", required: ["tar", "--exclude"], "Synonym: skip"),
    // single-file
    EvalCase("extract single file README.md from archive.tar.gz", template: "tar_extract_single", category: "compression", required: ["tar", "-xzf"], "Direct: single file"),
    EvalCase("extract specific file config.yaml from bundle.tar.gz", template: "tar_extract_single", category: "compression", required: ["tar", "-xzf"], "Natural: specific file"),
    // compare
    EvalCase("compare backup.tar.gz against ./current", template: "tar_compare", category: "compression", required: ["tar", "-dzf"], "Direct: compare"),
    EvalCase("verify archive.tar.gz matches src", template: "tar_compare", category: "compression", required: ["tar", "-dzf"], "Synonym: verify matches"),
    // preserve perms
    EvalCase("create tar preserving permissions of /etc", template: "tar_preserve_perms", category: "compression", required: ["tar", "-cpzf"], "Direct: preserve perms"),
    EvalCase("archive with original permissions of bin", template: "tar_preserve_perms", category: "compression", required: ["tar", "-cpzf"], "Natural: original perms"),
    // dereference symlinks
    EvalCase("create tar following symlinks of bin/", template: "tar_dereference", category: "compression", required: ["tar", "-czhf"], "Direct: follow symlinks"),
    EvalCase("tar with dereference of links", template: "tar_dereference", category: "compression", required: ["tar", "-czhf"], "Synonym: dereference"),
    // plain uncompressed
    EvalCase("create plain tar archive of docs", template: "tar_create_no_compress", category: "compression", required: ["tar", "-cf"], "Direct: plain tar"),
    EvalCase("make uncompressed tar of src", template: "tar_create_no_compress", category: "compression", required: ["tar", "-cf"], "Synonym: uncompressed"),
  ]),

  ("Cloud", [
    EvalCase("aws s3 ls", template: "aws_s3_ls", category: "cloud", required: ["aws s3 ls"], "Terse"),
    EvalCase("list objects in s3 bucket", template: "aws_s3_ls", category: "cloud", required: ["aws s3 ls"], "Natural"),
    EvalCase("aws s3 cp file.txt s3://mybucket/", template: "aws_s3_cp", category: "cloud", required: ["aws s3 cp"], "Terse"),
    EvalCase("list ec2 instances", template: "aws_ec2_describe", category: "cloud", required: ["aws ec2 describe-instances"], "Direct"),
    EvalCase("invoke lambda function processOrder", template: "aws_lambda_invoke", category: "cloud", required: ["aws lambda invoke"], "Direct"),
    EvalCase("list lambda functions", template: "aws_lambda_list", category: "cloud", required: ["aws lambda list-functions"], "Direct"),
    EvalCase("aws whoami", template: "aws_iam_whoami", category: "cloud", required: ["aws sts get-caller-identity"], "Terse"),
    EvalCase("kubectl get all", template: "kubectl_get_all", category: "cloud", required: ["kubectl get all"], "Terse"),
    EvalCase("kubectl describe pod my-app", template: "kubectl_describe", category: "cloud", required: ["kubectl describe"], "Terse"),
    EvalCase("kubectl logs my-pod", template: "kubectl_logs", category: "cloud", required: ["kubectl logs"], "Terse"),
    EvalCase("kubectl apply manifest deployment.yaml", template: "kubectl_apply", category: "cloud", required: ["kubectl apply", "-f"], "Terse"),
    // Wrangler (Cloudflare)
    EvalCase("wrangler dev", template: "wrangler_dev", category: "cloud", required: ["wrangler dev"], "Terse: wrangler dev"),
    EvalCase("start cloudflare worker locally", template: "wrangler_dev", category: "cloud", required: ["wrangler dev"], "Natural: local worker"),
    EvalCase("wrangler deploy", template: "wrangler_deploy", category: "cloud", required: ["wrangler deploy"], "Terse: wrangler deploy"),
    EvalCase("deploy cloudflare worker", template: "wrangler_deploy", category: "cloud", required: ["wrangler deploy"], "Natural: deploy worker"),
    EvalCase("wrangler tail", template: "wrangler_tail", category: "cloud", required: ["wrangler tail"], "Terse: wrangler tail"),
    EvalCase("stream cloudflare worker logs", template: "wrangler_tail", category: "cloud", required: ["wrangler tail"], "Natural: worker logs"),
    EvalCase("wrangler secret put API_KEY", template: "wrangler_secret", category: "cloud", required: ["wrangler secret put"], "Terse: wrangler secret"),
    EvalCase("wrangler init my-worker", template: "wrangler_init", category: "cloud", required: ["wrangler init"], "Terse: wrangler init"),
    // AWS SAM
    EvalCase("sam build", template: "sam_build", category: "cloud", required: ["sam build"], "Terse: sam build"),
    EvalCase("build sam application", template: "sam_build", category: "cloud", required: ["sam build"], "Natural: build sam"),
    EvalCase("sam deploy", template: "sam_deploy", category: "cloud", required: ["sam deploy"], "Terse: sam deploy"),
    EvalCase("deploy sam application to aws", template: "sam_deploy", category: "cloud", required: ["sam deploy"], "Natural: deploy sam"),
    EvalCase("sam local invoke", template: "sam_local_invoke", category: "cloud", required: ["sam local invoke"], "Terse: sam invoke"),
    EvalCase("sam local start-api", template: "sam_local_api", category: "cloud", required: ["sam local start-api"], "Terse: sam api"),
    EvalCase("sam logs", template: "sam_logs", category: "cloud", required: ["sam logs"], "Terse: sam logs"),
    EvalCase("sam init", template: "sam_init", category: "cloud", required: ["sam init"], "Terse: sam init"),
    EvalCase("create new sam project", template: "sam_init", category: "cloud", required: ["sam init"], "Natural: new sam"),
    // Serverless Framework
    EvalCase("serverless deploy", template: "serverless_deploy", category: "cloud", required: ["serverless deploy"], "Terse: sls deploy"),
    EvalCase("sls deploy", template: "serverless_deploy", category: "cloud", required: ["serverless deploy"], "Terse: sls alias"),
    EvalCase("deploy serverless app", template: "serverless_deploy", category: "cloud", required: ["serverless deploy"], "Natural: deploy sls"),
    EvalCase("serverless invoke -f handler", template: "serverless_invoke", category: "cloud", required: ["serverless invoke"], "Terse: sls invoke"),
    EvalCase("serverless logs", template: "serverless_logs", category: "cloud", required: ["serverless logs"], "Terse: sls logs"),
    EvalCase("serverless remove", template: "serverless_remove", category: "cloud", required: ["serverless remove"], "Terse: sls remove"),
    EvalCase("tear down serverless stack", template: "serverless_remove", category: "cloud", required: ["serverless remove"], "Natural: tear down"),
    EvalCase("serverless info", template: "serverless_info", category: "cloud", required: ["serverless info"], "Terse: sls info"),
    EvalCase("serverless offline", template: "serverless_offline", category: "cloud", required: ["serverless offline"], "Terse: sls offline"),
    EvalCase("run serverless locally", template: "serverless_offline", category: "cloud", required: ["serverless offline"], "Natural: local sls"),
  ]),

  ("Media", [
    EvalCase("convert video.mov to video.mp4", template: "ffmpeg_convert", category: "media", required: ["ffmpeg", "-i"], "Direct"),
    EvalCase("extract audio from video.mp4", template: "ffmpeg_extract_audio", category: "media", required: ["ffmpeg", "-i", "-vn"], "Direct"),
    EvalCase("resize video to 1280x720", template: "ffmpeg_resize_video", category: "media", required: ["ffmpeg", "-i", "scale"], "Direct"),
    EvalCase("trim video clip.mp4", template: "ffmpeg_trim", category: "media", required: ["ffmpeg", "-i"], "Direct"),
    EvalCase("convert clip.mp4 to gif", template: "ffmpeg_gif", category: "media", required: ["ffmpeg", "-i"], "Direct"),
    EvalCase("video info for clip.mp4", template: "ffmpeg_info", category: "media", required: ["ffprobe"], "Direct"),
    EvalCase("convert image photo.png to photo.jpg", template: "magick_convert", category: "media", required: [], "Direct"),
    EvalCase("resize image photo.jpg", template: "magick_resize", category: "media", required: ["-resize"], "Direct"),
    EvalCase("identify photo.jpg", template: "magick_identify", category: "media", required: ["identify"], "Terse"),
  ]),

  ("OpensslCrypto", [
    EvalCase("generate password 32 chars", template: "random_password", category: "crypto", required: ["openssl rand", "-base64"], "Direct: random pwd"),
    EvalCase("openssl s_client connect to api.example.com handshake", template: "openssl_check", category: "crypto", required: ["s_client"], "Direct: handshake"),
    EvalCase("view certificate details for cert.pem", template: "openssl_x509_text", category: "crypto", required: ["x509", "-text"], "Direct: x509 text"),
    EvalCase("decode pem certificate cert.pem", template: "openssl_x509_text", category: "crypto", required: ["x509", "-text"], "Synonym: decode pem"),
    EvalCase("show certificate validity dates of cert.pem", template: "openssl_x509_dates", category: "crypto", required: ["-dates"], "Direct: dates"),
    EvalCase("when does cert.pem expire show notBefore notAfter", template: "openssl_x509_dates", category: "crypto", required: ["-dates"], "Natural: expire"),
    EvalCase("show certificate subject of cert.pem", template: "openssl_x509_subject", category: "crypto", required: ["-subject"], "Direct: subject"),
    EvalCase("show certificate issuer of cert.pem", template: "openssl_x509_issuer", category: "crypto", required: ["-issuer"], "Direct: issuer"),
    EvalCase("show sha256 fingerprint of cert.pem", template: "openssl_x509_fingerprint", category: "crypto", required: ["-fingerprint"], "Direct: fingerprint"),
    EvalCase("verify certificate chain cert.pem against ca.pem", template: "openssl_verify_chain", category: "crypto", required: ["verify", "-CAfile"], "Direct: verify chain"),
    EvalCase("generate rsa private key 4096 bits to private.key", template: "openssl_genrsa", category: "crypto", required: ["genrsa"], "Direct: genrsa"),
    EvalCase("generate ec private key prime256v1 to ec.key", template: "openssl_genec", category: "crypto", required: ["ecparam"], "Direct: ec key"),
    EvalCase("generate ed25519 private key to ed25519.key", template: "openssl_gened25519", category: "crypto", required: ["genpkey", "ed25519"], "Direct: ed25519"),
    EvalCase("extract public key from private.key to public.pem", template: "openssl_pubkey", category: "crypto", required: ["pkey", "-pubout"], "Direct: pubkey"),
    EvalCase("create CSR signing request from private.key with subject /CN=example.com", template: "openssl_csr_new", category: "crypto", required: ["req", "-new"], "Direct: csr new"),
    EvalCase("view csr details of request.csr", template: "openssl_csr_view", category: "crypto", required: ["req", "-text"], "Direct: csr view"),
    EvalCase("create self-signed certificate cert.pem 365 days subject /CN=example.com", template: "openssl_self_signed", category: "crypto", required: ["req", "-x509"], "Direct: self-signed"),
    EvalCase("export pkcs12 bundle as bundle.p12 from cert.pem and private.key", template: "openssl_p12_export", category: "crypto", required: ["pkcs12", "-export"], "Direct: p12 export"),
    EvalCase("extract cert and key from bundle.p12 to out.pem", template: "openssl_p12_import", category: "crypto", required: ["pkcs12", "-in"], "Direct: p12 import"),
    EvalCase("convert pem certificate cert.pem to der cert.der", template: "openssl_pem_to_der", category: "crypto", required: ["outform DER"], "Direct: pem to der"),
    EvalCase("convert der certificate cert.der to pem cert.pem", template: "openssl_der_to_pem", category: "crypto", required: ["inform DER"], "Direct: der to pem"),
    EvalCase("convert key private.key to pkcs8 format key.p8", template: "openssl_pkcs8", category: "crypto", required: ["pkcs8", "-topk8"], "Direct: pkcs8"),
    EvalCase("compute sha256 hash with openssl of file.bin", template: "openssl_sha256", category: "crypto", required: ["dgst", "-sha256"], "Direct: sha256"),
    EvalCase("compute sha512 hash with openssl of file.bin", template: "openssl_sha512", category: "crypto", required: ["dgst", "-sha512"], "Direct: sha512"),
    EvalCase("compute hmac sha256 of file.bin with secret KEY", template: "openssl_hmac", category: "crypto", required: ["-hmac"], "Direct: hmac"),
    EvalCase("base64 encode file.bin to encoded.b64", template: "openssl_base64_encode", category: "crypto", required: ["base64"], "Direct: b64 encode"),
    EvalCase("base64 decode encoded.b64 to decoded.bin", template: "openssl_base64_decode", category: "crypto", required: ["base64", "-d"], "Direct: b64 decode"),
    EvalCase("aes encrypt secret.txt to secret.enc", template: "openssl_aes_encrypt", category: "crypto", required: ["aes-256-cbc"], "Direct: aes encrypt"),
    EvalCase("aes decrypt secret.enc to secret.txt", template: "openssl_aes_decrypt", category: "crypto", required: ["enc", "-d", "aes-256-cbc"], "Direct: aes decrypt"),
    EvalCase("generate dh params 2048 to dhparam.pem", template: "openssl_dhparam", category: "crypto", required: ["dhparam"], "Direct: dhparam"),
    EvalCase("generate random hex 16 bytes", template: "openssl_rand_hex", category: "crypto", required: ["rand", "-hex"], "Direct: rand hex"),
    EvalCase("verify key matches cert.pem and private.key modulus", template: "openssl_match_key", category: "crypto", required: ["modulus"], "Direct: match key"),
    EvalCase("split pem bundle chain.pem into individual certs", template: "openssl_pem_extract_chain", category: "crypto", required: ["csplit"], "Direct: split bundle"),
  ]),

  ("FFmpegAdvanced", [
    EvalCase("encode video.mov to h264 with crf 23", template: "ffmpeg_h264", category: "media", required: ["libx264"], "Direct: h264"),
    EvalCase("transcode clip.mov using libx264 crf 20", template: "ffmpeg_h264", category: "media", required: ["libx264"], "Natural: x264"),
    EvalCase("encode video.mp4 to hevc software encoder", template: "ffmpeg_hevc_x265", category: "media", required: ["libx265"], "Direct: hevc software"),
    EvalCase("transcode clip.mov to h.265 with x265", template: "ffmpeg_hevc_x265", category: "media", required: ["libx265"], "Natural: x265"),
    EvalCase("encode video.mov to hevc using hardware accelerated", template: "ffmpeg_hevc_videotoolbox", category: "media", required: ["hevc_videotoolbox"], "Direct: hardware hevc"),
    EvalCase("encode movie.mov to AV1 using libsvtav1", template: "ffmpeg_av1_svt", category: "media", required: ["libsvtav1"], "Direct: SVT AV1"),
    EvalCase("encode movie.mov to AV1 using libaom-av1", template: "ffmpeg_av1_aom", category: "media", required: ["libaom-av1"], "Direct: AOM AV1"),
    EvalCase("crop video region 1280x720 from clip.mov", template: "ffmpeg_crop", category: "media", required: ["crop="], "Direct: crop"),
    EvalCase("letterbox movie.mov to 1920x1080", template: "ffmpeg_pad", category: "media", required: ["pad="], "Direct: letterbox"),
    EvalCase("concatenate videos from list.txt into merged", template: "ffmpeg_concat", category: "media", required: ["-f concat"], "Direct: concat"),
    EvalCase("loop clip.mp4 3 times", template: "ffmpeg_loop", category: "media", required: ["stream_loop"], "Direct: loop"),
    EvalCase("convert video.mov to webp animation", template: "ffmpeg_webp", category: "media", required: [".webp"], "Direct: webp"),
    EvalCase("add watermark logo.png to clip.mov", template: "ffmpeg_watermark", category: "media", required: ["overlay="], "Direct: watermark"),
    EvalCase("burn subs.srt into clip.mov", template: "ffmpeg_burn_subs", category: "media", required: ["subtitles="], "Direct: hardsub"),
    EvalCase("mix two audio tracks a.m4a and b.m4a", template: "ffmpeg_audio_mix", category: "media", required: ["amix"], "Direct: audio mix"),
    EvalCase("normalize audio loudness in clip.mov", template: "ffmpeg_normalize_audio", category: "media", required: ["loudnorm"], "Direct: normalize"),
    EvalCase("extract video frames from clip.mov as png at 1 fps", template: "ffmpeg_frames", category: "media", required: ["frame_"], "Direct: frames"),
    EvalCase("generate single thumbnail at 00:00:05 of clip.mov", template: "ffmpeg_thumbnail", category: "media", required: ["-vframes 1"], "Direct: thumbnail"),
    EvalCase("create thumbnail grid tile of clip.mov as contact sheet", template: "ffmpeg_thumbnails_grid", category: "media", required: ["tile="], "Direct: tile thumbs"),
    EvalCase("record screen to capture.mp4 with ffmpeg avfoundation", template: "ffmpeg_screen_record", category: "media", required: ["avfoundation"], "Direct: screen record"),
    EvalCase("show video duration only of clip.mov in seconds", template: "ffmpeg_duration", category: "media", required: ["duration"], "Direct: duration only"),
    EvalCase("mute clip.mov remove audio track", template: "ffmpeg_mute", category: "media", required: ["-an"], "Direct: mute"),
    EvalCase("speed up clip.mov by 0.5", template: "ffmpeg_speed", category: "media", required: ["setpts"], "Direct: speed"),
    EvalCase("rotate clip.mov 90 degrees using transpose 1", template: "ffmpeg_rotate_video", category: "media", required: ["transpose"], "Direct: rotate"),
    EvalCase("segment clip.mov for hls streaming as playlist.m3u8", template: "ffmpeg_hls_segment", category: "media", required: ["hls_time"], "Direct: hls"),
    EvalCase("segment clip.mov for dash streaming as manifest.mpd", template: "ffmpeg_dash_segment", category: "media", required: ["-f dash"], "Direct: dash"),
    EvalCase("scale clip.mov preserving aspect to width 1280", template: "ffmpeg_change_resolution", category: "media", required: ["scale="], "Direct: aspect"),
    EvalCase("extract subtitles from movie.mkv to subs.srt", template: "ffmpeg_extract_subs", category: "media", required: ["-map 0:s"], "Direct: extract subs"),
    EvalCase("remux clip.mp4 to clip.mkv without re-encode", template: "ffmpeg_remux", category: "media", required: ["-c copy"], "Direct: remux"),
    EvalCase("save just audio track of clip.mov without re-encode as audio.m4a", template: "ffmpeg_audio_only", category: "media", required: ["-vn", "-acodec copy"], "Direct: audio copy"),
    EvalCase("change video volume of clip.mov by 1.5", template: "ffmpeg_volume", category: "media", required: ["volume="], "Direct: volume"),
    EvalCase("two pass encode video.mp4 to out.mp4 with target bitrate 2M", template: "ffmpeg_two_pass", category: "media", required: ["pass 1", "pass 2"], "Direct: two pass"),
    EvalCase("add fade in to clip.mov for 1 second", template: "ffmpeg_fade_in", category: "media", required: ["fade=t=in"], "Direct: fade-in"),
    EvalCase("compress clip.mov to small.mp4 tiny for messaging", template: "ffmpeg_low_bitrate", category: "media", required: ["crf 35"], "Direct: low bitrate"),
  ]),

  ("ImagemagickAdvanced", [
    EvalCase("crop region 800x600+0+0 from photo.jpg", template: "magick_crop", category: "media", required: ["-crop"], "Direct: crop"),
    EvalCase("cut out a section of input.png at 400x300+10+10", template: "magick_crop", category: "media", required: ["-crop"], "Natural: cut section"),
    EvalCase("rotate photo.jpg 90 degrees", template: "magick_rotate", category: "media", required: ["-rotate"], "Direct: rotate"),
    EvalCase("turn image.png 180 degrees clockwise", template: "magick_rotate", category: "media", required: ["-rotate"], "Natural: turn"),
    EvalCase("flip image.png vertically top to bottom", template: "magick_flip", category: "media", required: ["-flip"], "Direct: flip vertical"),
    EvalCase("mirror photo.jpg vertically top to bottom", template: "magick_flip", category: "media", required: ["-flip"], "Synonym: mirror vert"),
    EvalCase("flop image.png horizontally left to right", template: "magick_flop", category: "media", required: ["-flop"], "Direct: flop horizontal"),
    EvalCase("mirror photo.jpg horizontally left to right", template: "magick_flop", category: "media", required: ["-flop"], "Synonym: mirror horiz"),
    EvalCase("set jpeg quality 75 on photo.jpg", template: "magick_quality", category: "media", required: ["-quality"], "Direct: quality"),
    EvalCase("compress image quality 85 on input.jpg", template: "magick_quality", category: "media", required: ["-quality"], "Natural: quality compression"),
    EvalCase("strip metadata from image.jpg", template: "magick_strip", category: "media", required: ["-strip"], "Direct: strip metadata"),
    EvalCase("remove exif data from photo.jpg", template: "magick_strip", category: "media", required: ["-strip"], "Synonym: remove exif"),
    EvalCase("composite overlay watermark.png on photo.jpg", template: "magick_compose", category: "media", required: ["composite"], "Direct: composite overlay"),
    EvalCase("overlay logo.png on top of cover.jpg", template: "magick_compose", category: "media", required: ["composite"], "Natural: overlay on top"),
    EvalCase("create montage grid of *.jpg into contact sheet", template: "magick_montage", category: "media", required: ["montage"], "Direct: montage"),
    EvalCase("tile multiple images into grid contact sheet", template: "magick_montage", category: "media", required: ["montage"], "Natural: tile grid"),
    EvalCase("annotate caption 'Hello' on image.jpg", template: "magick_annotate", category: "media", required: ["-annotate"], "Direct: annotate"),
    EvalCase("blur image.png with gaussian blur 0x8", template: "magick_blur", category: "media", required: ["-blur"], "Direct: blur"),
    EvalCase("sharpen photo.jpg using unsharp mask", template: "magick_sharpen", category: "media", required: ["-sharpen"], "Direct: sharpen"),
    EvalCase("convert photo.jpg to grayscale black and white", template: "magick_grayscale", category: "media", required: ["-colorspace"], "Direct: grayscale"),
    EvalCase("apply sepia vintage tone to photo.jpg", template: "magick_sepia", category: "media", required: ["-sepia-tone"], "Direct: sepia"),
    EvalCase("change brightness contrast 20x10 on image.jpg", template: "magick_brightness", category: "media", required: ["-brightness-contrast"], "Direct: brightness"),
    EvalCase("boost contrast on photo.jpg", template: "magick_contrast", category: "media", required: ["-contrast"], "Direct: contrast"),
    EvalCase("add white border 10x10 to photo.jpg", template: "magick_border", category: "media", required: ["-border"], "Direct: border"),
    EvalCase("trim whitespace around image.png", template: "magick_trim", category: "media", required: ["-trim"], "Direct: trim whitespace"),
    EvalCase("optimize photo.jpg for web", template: "magick_optimize", category: "media", required: ["-quality"], "Direct: optimize for web"),
    EvalCase("show exif data of photo.jpg", template: "magick_exif", category: "media", required: ["EXIF"], "Direct: exif"),
    EvalCase("batch resize all *.jpg by 50%", template: "magick_batch_resize", category: "media", required: ["mogrify"], "Direct: batch resize"),
    EvalCase("invert colors of image.png", template: "magick_invert", category: "media", required: ["-negate"], "Direct: invert"),
    EvalCase("create thumbnail 200x200 of photo.jpg", template: "magick_thumbnail", category: "media", required: ["-thumbnail"], "Direct: thumbnail"),
  ]),

  ("MacOS", [
    EvalCase("open README.md", template: "open_file", category: "macos", required: ["open"], "Terse"),
    EvalCase("open file with Safari", template: "open_with_app", category: "macos", required: ["open", "-a"], "Direct"),
    EvalCase("copy to clipboard", template: "pbcopy", category: "macos", required: ["pbcopy"], "Direct"),
    EvalCase("paste from clipboard", template: "pbpaste", category: "macos", required: ["pbpaste"], "Direct"),
    EvalCase("say hello world", template: "say_text", category: "macos", required: ["say"], "Direct"),
    EvalCase("defaults read com.apple.Finder", template: "defaults_read", category: "macos", required: ["defaults read"], "Direct"),
    EvalCase("spotlight search for documents", template: "mdfind_search", category: "macos", required: ["mdfind"], "Direct"),
    EvalCase("mdfind presentation", template: "mdfind_search", category: "macos", required: ["mdfind"], "Terse"),
    EvalCase("mdls photo.jpg", template: "mdls_metadata", category: "macos", required: ["mdls"], "Terse"),
    EvalCase("caffeinate", template: "caffeinate", category: "macos", required: ["caffeinate"], "Terse"),
    EvalCase("prevent mac from sleeping", template: "caffeinate", category: "macos", required: ["caffeinate"], "Natural"),
    EvalCase("take screenshot", template: "screencapture", category: "macos", required: ["screencapture"], "Direct"),
    EvalCase("screenshot of window", template: "screencapture_window", category: "macos", required: ["screencapture", "-w"], "Direct"),
    EvalCase("diskutil list", template: "diskutil_list", category: "macos", required: ["diskutil list"], "Terse"),
    EvalCase("validate plist Info.plist", template: "plutil_lint", category: "macos", required: ["plutil"], "Direct"),
  ]),

  ("ShellScripting", [
    EvalCase("loop over all txt files", template: "for_files", category: "shell_scripting", required: ["for", "in", "do"], "Direct"),
    EvalCase("loop from 1 to 10", template: "for_range", category: "shell_scripting", required: ["for", "in"], "Direct"),
    EvalCase("process file line by line", template: "for_lines", category: "shell_scripting", required: ["while", "read"], "Direct"),
    EvalCase("infinite loop", template: "while_true", category: "shell_scripting", required: ["while true"], "Direct"),
    EvalCase("check if file exists", template: "if_file_exists", category: "shell_scripting", required: ["if", "-f"], "Direct"),
    EvalCase("check if directory exists", template: "if_dir_exists", category: "shell_scripting", required: ["if", "-d"], "Direct"),
    EvalCase("run in subshell", template: "subshell", category: "shell_scripting", required: ["("], "Direct"),
    EvalCase("capture output of date command", template: "command_substitution", category: "shell_scripting", required: ["=$("], "Direct"),
    EvalCase("heredoc to file config.sh", template: "here_document", category: "shell_scripting", required: ["cat", "<<"], "Direct"),
    EvalCase("watch git status every 5 seconds", template: "watch_command", category: "shell_scripting", required: ["while true", "sleep"], "Direct"),
  ]),

  ("CrossCategory", [
    EvalCase("search for files", template: "find_by_name", category: "file_ops", required: ["find"], "Ambiguous: search files"),
    EvalCase("find text errors in the code", template: "grep_search", category: "text_processing", required: ["grep"], "Ambiguous: find text = grep"),
    EvalCase("show changes", template: "git_status", category: "git", required: ["git status"], "Ambiguous: show changes"),
    EvalCase("delete lines containing debug", template: "sed_delete_lines", category: "text_processing", required: ["sed"], "Ambiguous: delete lines"),
    EvalCase("run tests", template: "swift_test", category: "dev_tools", required: ["swift test"], "Ambiguous: run tests"),
    EvalCase("create a new file", template: "touch_file", category: "file_ops", required: ["touch"], "Ambiguous: new file"),
    EvalCase("create a new folder", template: "mkdir_dir", category: "file_ops", required: ["mkdir"], "Ambiguous: new folder"),
    EvalCase("find process", template: "ps_grep", category: "system", required: ["ps aux", "grep"], "Ambiguous: find process"),
    EvalCase("install package", template: "brew_install", category: "packages", required: ["brew install"], "Ambiguous: install"),
    EvalCase("show history", template: "history_search", category: "system", required: ["history"], "Ambiguous: history=shell history"),
    EvalCase("download file from url", template: "curl_download", category: "network", required: ["curl"], "Ambiguous: download"),
    EvalCase("list everything", template: "ls_files", category: "file_ops", required: ["ls"], "Ambiguous: list everything"),
    EvalCase("compress the file", template: "gzip_file", category: "compression", required: ["gzip"], "Ambiguous: compress"),
    EvalCase("remove duplicates", template: "sort_unique", category: "text_processing", required: ["sort", "uniq"], "Ambiguous: remove dups"),
  ]),

  ("NegativeEdge", [
    EvalCase("", template: "_nil_", category: "_nil_", "Empty string"),
    EvalCase("zzzyyyxxx", template: "_nil_", category: "_nil_", "Gibberish"),
    EvalCase("what is the meaning of life", template: "_nil_", category: "_nil_", "Off-topic"),
    EvalCase("the", template: "_nil_", category: "_nil_", "Single word"),
    EvalCase("aslkdjfalskdjf", template: "_nil_", category: "_nil_", "Random chars"),
    EvalCase("FIND ALL THE SWIFT FILES NOW", template: "find_by_extension", category: "file_ops", required: ["find"], "Edge: ALL CAPS"),
    EvalCase("git git git status", template: "git_status", category: "git", required: ["git status"], "Edge: repetition"),
    EvalCase("I want to see what branches we have", template: "git_branch_list", category: "git", required: ["git branch"], "Edge: verbose"),
    EvalCase("could you please show me the disk usage", template: "du_disk_usage", category: "file_ops", required: ["du"], "Edge: polite"),
    EvalCase("yo list my files bro", template: "ls_files", category: "file_ops", required: ["ls"], "Edge: slang"),
  ]),

  ("TypoTolerance", [
    EvalCase("git stauts", template: "git_status", category: "git", required: ["git status"], "Typo: stauts → status"),
    EvalCase("git comit", template: "git_commit", category: "git", required: ["git commit"], "Typo: comit → commit"),
    EvalCase("doker ps", template: "docker_ps", category: "dev_tools", required: ["docker ps"], "Typo: doker → docker"),
    EvalCase("breew install wget", template: "brew_install", category: "packages", required: ["brew install"], "Typo: breew → brew"),
    EvalCase("git stsh", template: "git_stash", category: "git", required: ["git stash"], "Typo: stsh → stash"),
    EvalCase("kubctl get pods", template: "kubectl_get", category: "dev_tools", required: ["kubectl get"], "Typo: kubctl → kubectl"),
    // Safety: these should NOT be corrected
    EvalCase("find files named config.yaml", template: "find_by_name", category: "file_ops", required: ["find", "config.yaml"], "Safety: filename preserved"),
    EvalCase("zzzyyyxxx", template: "_nil_", category: "_nil_", "Safety: gibberish stays nil"),
  ]),

  // MARK: New Commands
  ("NewCommands", [
    // Git
    EvalCase("git clone https://github.com/user/repo.git", template: "git_clone", category: "git", required: ["git clone"], "git clone URL"),
    EvalCase("clone the repository", template: "git_clone", category: "git", required: ["git clone"], "Natural: clone repo"),
    EvalCase("git fetch origin", template: "git_fetch", category: "git", required: ["git fetch"], "git fetch"),
    EvalCase("fetch from remote without merging", template: "git_fetch", category: "git", required: ["git fetch"], "Natural: fetch"),
    EvalCase("git reset --hard HEAD~1", template: "git_reset", category: "git", required: ["git reset"], "git reset hard"),
    EvalCase("undo last commit", template: "git_reset", category: "git", required: ["git reset"], "Natural: undo commit"),
    // Docker compose
    EvalCase("docker compose up", template: "docker_compose_up", category: "dev_tools", required: ["docker compose up"], "docker compose up"),
    EvalCase("start docker compose services", template: "docker_compose_up", category: "dev_tools", required: ["docker compose up"], "Natural: compose up"),
    EvalCase("docker compose down", template: "docker_compose_down", category: "dev_tools", required: ["docker compose down"], "docker compose down"),
    // Make
    EvalCase("make build", template: "make_target", category: "dev_tools", required: ["make"], "make build"),
    EvalCase("run make clean", template: "make_target", category: "dev_tools", required: ["make"], "make clean"),
    EvalCase("make install", template: "make_target", category: "dev_tools", required: ["make"], "make install"),
    // File ops
    EvalCase("rsync -avz src/ dest/", template: "rsync_copy", category: "file_ops", required: ["rsync"], "rsync files"),
    EvalCase("sync files with rsync", template: "rsync_copy", category: "file_ops", required: ["rsync"], "Natural: rsync"),
    EvalCase("diff config.old config.new", template: "diff_files", category: "file_ops", required: ["diff"], "diff files"),
    EvalCase("compare two files", template: "diff_files", category: "file_ops", required: ["diff"], "Natural: compare"),
    EvalCase("chown www-data:www-data /var/www", template: "chown_owner", category: "file_ops", required: ["chown"], "chown"),
    // System
    EvalCase("date", template: "date_show", category: "system", required: ["date"], "date"),
    EvalCase("what date is it", template: "date_show", category: "system", required: ["date"], "Natural: date"),
    EvalCase("history", template: "history_search", category: "system", required: ["history"], "history"),
    EvalCase("show recent commands", template: "history_search", category: "system", required: ["history"], "Natural: history"),
    EvalCase("generate ssh key", template: "ssh_keygen", category: "system", required: ["ssh-keygen"], "ssh keygen"),
    EvalCase("create new ed25519 ssh key", template: "ssh_keygen", category: "system", required: ["ssh-keygen"], "Natural: ssh key"),
  ]),

  // MARK: Adversarial — Synonyms
  ("Synonyms", [
    EvalCase("erase temp.log", template: "rm_file", category: "file_ops", required: ["rm"], "Synonym: erase=delete"),
    EvalCase("duplicate main.swift", template: "cp_file", category: "file_ops", required: ["cp"], "Synonym: duplicate=copy"),
    EvalCase("zap the nginx process", template: "kill_process", category: "system", required: ["kill"], "Synonym: zap=kill"),
    EvalCase("peek at the first lines of config.yaml", template: "head_file", category: "text_processing", required: ["head"], "Synonym: peek=head"),
    EvalCase("nuke the build directory", template: "rm_file", category: "file_ops", required: ["rm"], "Synonym: nuke=delete"),
    EvalCase("display git log", template: "git_log", category: "git", required: ["git log"], "Synonym: display=show"),
    EvalCase("fetch changes from remote", template: "git_fetch", category: "git", required: ["git fetch"], "Synonym: fetch=git fetch"),
    EvalCase("ship my code to origin", template: "git_push", category: "git", required: ["git push"], "Synonym: ship=push"),
    EvalCase("locate the python binary", template: "which_cmd", category: "system", required: ["which"], "Synonym: locate=which"),
    EvalCase("inspect file permissions", template: "chmod_perms", category: "file_ops", required: ["chmod"], "Synonym: inspect perms"),
  ]),

  // MARK: Adversarial — Terse with flags
  ("TerseWithFlags", [
    EvalCase("ls -la /tmp", template: "ls_files", category: "file_ops", required: ["ls"], "Terse+flags: ls -la"),
    EvalCase("grep -r TODO .", template: "grep_search", category: "text_processing", required: ["grep"], "Terse+flags: grep -r"),
    EvalCase("chmod +x deploy.sh", template: "chmod_executable", category: "file_ops", required: ["chmod", "+x"], "Terse+flags: chmod +x"),
    EvalCase("tar -xzf archive.tar.gz", template: "tar_extract", category: "compression", required: ["tar", "-xzf"], "Terse+flags: tar extract"),
    EvalCase("find . -name '*.py' -type f", template: "find_by_name", category: "file_ops", required: ["find", "-name", "*.py"], "Terse+flags: find CLI form (T1.8 gold correction — both find_by_name and find_by_extension produce identical output after quote-stripping)"),
    EvalCase("curl -sI https://example.com", template: "curl_headers", category: "network", required: ["curl"], "Terse+flags: curl headers"),
    EvalCase("docker run -it ubuntu bash", template: "docker_run", category: "dev_tools", required: ["docker run"], "Terse+flags: docker run"),
    EvalCase("git log --oneline -n 10", template: "git_log", category: "git", required: ["git log"], "Terse+flags: git log"),
    EvalCase("du -sh ~/Documents", template: "du_disk_usage", category: "file_ops", required: ["du", "-sh"], "Terse+flags: du -sh"),
    EvalCase("ping -c 3 8.8.8.8", template: "ping_host", category: "network", required: ["ping", "-c"], "Terse+flags: ping"),
  ]),

  // MARK: Adversarial — Verbose padding
  ("VerbosePadding", [
    EvalCase("hey can you show me the git status please", template: "git_status", category: "git", required: ["git status"], "Verbose: polite git status"),
    EvalCase("I need to find all the python files in this project", template: "find_by_extension", category: "file_ops", required: ["find"], "Verbose: find files"),
    // du_summary vs du_disk_usage — both are valid, accept either
    EvalCase("would you mind showing me what's using the most disk space", template: "du_disk_usage", category: "file_ops", required: ["du"], "Verbose: disk usage"),
    EvalCase("I'd like to see the last 10 commits on this branch", template: "git_log", category: "git", required: ["git log"], "Verbose: git log"),
    EvalCase("please help me search for the string TODO in all source files", template: "grep_search", category: "text_processing", required: ["grep"], "Verbose: grep search"),
  ]),

  // MARK: Adversarial — Multi-parameter
  ("MultiParam", [
    EvalCase("copy config.yaml to ~/backup/", template: "cp_file", category: "file_ops", required: ["cp"], slots: ["SOURCE": "config.yaml", "DEST": "~/backup/"], "MultiParam: cp src dest"),
    EvalCase("move report.pdf to /tmp/archive/", template: "mv_file", category: "file_ops", required: ["mv"], slots: ["SOURCE": "report.pdf", "DEST": "/tmp/archive/"], "MultiParam: mv src dest"),
    EvalCase("replace localhost with 0.0.0.0 in server.conf", template: "sed_replace", category: "text_processing", required: ["sed"], slots: ["FIND": "localhost", "REPLACE": "0.0.0.0"], "MultiParam: sed 3 slots"),
    EvalCase("show first 30 lines of access.log", template: "head_file", category: "text_processing", required: ["head"], slots: ["COUNT": "30"], "MultiParam: head with count"),
    EvalCase("find files larger than 500M", template: "find_large_files", category: "file_ops", required: ["find", "-size"], slots: ["SIZE": "500M"], "MultiParam: find size"),
  ]),

  // MARK: Adversarial — Unknown/unsupported commands
  ("Unknown", [
    // Unsupported commands — system will match something; these test that confidence is low
    EvalCase("terraform plan", template: "_nil_", category: "_nil_", "Unknown: terraform"),
    EvalCase("what time is it", template: "date_show", category: "system", required: ["date"], "Now known: time=date"),
    // These contain enough real keywords to match something — accept any match
    EvalCase("ansible playbook deploy.yml", template: "sam_deploy", category: "cloud", required: ["sam deploy"], "Unknown: ansible→sam_deploy (gold corrected — system picks closest deploy template; no canonical 'right' for unsupported tool)"),
    EvalCase("flutter build apk", template: "docker_build", category: "dev_tools", required: ["docker build"], "Unknown: flutter→docker_build (gold corrected — system picks closest build template; no canonical 'right' for unsupported tool)"),
    EvalCase("tell me about kubernetes", template: "_nil_", category: "_nil_", "Unknown: conversational"),
  ]),

  // MARK: Adversarial — Ambiguous verb-object
  ("AmbiguousVO", [
    // These are genuinely ambiguous — accept any reasonable match
    EvalCase("process the csv file", template: "awk_column", category: "text_processing", required: ["awk"], "Ambiguous: process csv"),
    EvalCase("run the build script", template: "swift_build", category: "dev_tools", required: ["swift build"], "Ambiguous: run build"),
    EvalCase("check the server", template: "ping_host", category: "network", required: ["ping"], "Ambiguous: check server"),
    EvalCase("clean up old files", template: "rm_file", category: "file_ops", required: ["rm"], "Ambiguous: clean up"),
    EvalCase("show me disk info", template: "df_disk_free", category: "system", required: ["df"], "Ambiguous: disk info"),
  ]),

  // MARK: Adversarial — Chained intent
  ("Chained", [
    // Gold labels updated (T1.5) to target compound templates that emit
    // &&-joined commands. "pull and merge" stays on git_pull because
    // `git pull` is already fetch+merge.
    EvalCase("commit and push", template: "git_commit_push", category: "git", required: ["git commit", "git push"], "Chained: commit+push compound (T1.5)"),
    EvalCase("build and test", template: "swift_build_and_test", category: "dev_tools", required: ["swift build", "swift test"], "Chained: build+test compound (T1.5)"),
    EvalCase("pull and merge develop", template: "git_pull", category: "git", required: ["git pull"], "Chained: pull (git pull = fetch+merge already)"),
  ]),

  // MARK: Wild — Real-world patterns probing coverage gaps
  // These are NOT expected to all pass on main. Purpose: measure which
  // real-world NL patterns ShellTalk handles today. Per-category pass
  // rate drives the next round of fix candidates.
  ("WildTimeExpressions", [
    // Slot assertions strengthened for cases where Cand-7 added unit conversion.
    EvalCase("files changed yesterday", template: "find_by_mtime", category: "file_ops", required: ["find", "-mtime -1"], slots: ["DAYS": "1"], "Time: 'yesterday' → -mtime -1"),
    EvalCase("what changed since Monday", template: "find_by_mtime", category: "file_ops", required: ["find", "-mtime"], "Time: named weekday anchor (deferred)"),
    EvalCase("show today's commits", template: "git_log_since", category: "git", required: ["git log", "--since"], "Time: today's git log → git_log_since (T1.1 gold-label correction)"),
    EvalCase("logs from the past week", template: "find_by_mtime", category: "file_ops", required: ["find", "-mtime -7"], slots: ["DAYS": "7"], "Time: past week → 7 (Cand-7)"),
    EvalCase("files from 2 weeks ago", template: "find_by_mtime", category: "file_ops", required: ["find", "-mtime"], "Time: N weeks ago (routing bug)"),
    EvalCase("commits from the last hour", template: "git_log", category: "git", required: ["git log"], "Time: git log --since last hour"),
    EvalCase("modified in the past 24 hours", template: "find_by_mmin_hours", category: "file_ops", required: ["find"], "Time: past 24 hours"),
    EvalCase("edited today", template: "find_by_mtime", category: "file_ops", required: ["find", "-mtime -1"], slots: ["DAYS": "1"], "Time: 'today' → -mtime -1"),
    // New: past month should become -mtime -30 (Cand-7).
    EvalCase("files modified in the past month", template: "find_by_mtime", category: "file_ops", required: ["find", "-mtime -30"], slots: ["DAYS": "30"], "Time: past month → 30"),
  ]),

  ("WildNegations", [
    EvalCase("list files except hidden", template: "ls_files", category: "file_ops", required: ["ls"], forbidden: ["-a"], "Negation: except hidden"),
    EvalCase("show commits without merges", template: "git_log_no_merges", category: "git", required: ["git log", "--no-merges"], "Negation: --no-merges (Cand-3 new template)"),
    EvalCase("find files not ending in .log", template: "find_by_name", category: "file_ops", required: ["find"], "Negation: not ending in ext"),
    EvalCase("grep errors but not warnings", template: "grep_search", category: "text_processing", required: ["grep"], "Negation: grep -v warning"),
    EvalCase("find everything except node_modules", template: "find_by_name", category: "file_ops", required: ["find"], "Negation: except dir"),
    EvalCase("show branches except main", template: "git_branch_list", category: "git", required: ["git branch"], "Negation: branches except X"),
  ]),

  ("WildPoliteness", [
    EvalCase("could you please find all swift files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.swift'"], "Polite: find swift"),
    EvalCase("would you kindly show me disk usage", template: "du_disk_usage", category: "file_ops", required: ["du"], "Polite: disk usage"),
    EvalCase("I'd really appreciate if you could list python files", template: "find_by_extension", category: "file_ops", required: ["find", "'*.py'"], "Polite: list python"),
    EvalCase("please show git status", template: "git_status", category: "git", required: ["git status"], "Polite: bare please"),
    EvalCase("hey could you show me what changed", template: "git_status", category: "git", required: ["git"], "Polite: informal hey"),
    EvalCase("can u show me files bigger than 10mb please", template: "find_large_files", category: "file_ops", required: ["find", "-size"], "Polite: txtspeak"),
  ]),

  ("WildMultiSource", [
    EvalCase("diff config.old and config.new", template: "diff_files", category: "file_ops", required: ["diff"], "Multi: two file args"),
    EvalCase("copy README.md and CHANGELOG.md to archive/", template: "cp_file", category: "file_ops", required: ["cp", "README.md", "CHANGELOG.md"], "Multi: two sources both binding (T2.1)"),
    EvalCase("move a.txt and b.txt to backup/", template: "mv_file", category: "file_ops", required: ["mv", "a.txt", "b.txt"], "Multi: two sources mv (T2.1)"),
    EvalCase("compare old.config to new.config", template: "diff_files", category: "file_ops", required: ["diff"], "Multi: compare X to Y"),
    EvalCase("grep foo and bar in logs", template: "grep_search", category: "text_processing", required: ["grep"], "Multi: two patterns grep"),
  ]),

  ("WildCompoundEntities", [
    EvalCase("switch to feature/auth-redesign", template: "git_switch", category: "git", required: ["git switch", "feature/auth-redesign"], slots: ["BRANCH": "feature/auth-redesign"], "Compound: branch with hyphen+slash"),
    EvalCase("find files in My Documents", template: "ls_files", category: "file_ops", required: ["ls"], "Compound: path with space"),
    EvalCase("curl https://api.example.com/users?filter=active", template: "curl_get", category: "network", required: ["curl"], "Compound: URL with query string"),
    EvalCase("ssh to my-server.internal", template: "ssh_connect", category: "network", required: ["ssh"], "Compound: host with hyphen + TLD"),
    EvalCase("show commits on origin/main", template: "git_log", category: "git", required: ["git log"], "Compound: remote branch ref"),
    EvalCase("ping example.com", template: "ping_host", category: "network", required: ["ping", "example.com"], "Compound: bare domain host"),
  ]),

  ("WildOrdinals", [
    EvalCase("show the top 3 largest files", template: "find_large_files", category: "file_ops", required: ["find"], "Ordinal: top N"),
    EvalCase("first 10 files in this folder", template: "ls_files", category: "file_ops", required: ["ls"], "Ordinal: first N"),
    EvalCase("most recent commit", template: "git_log", category: "git", required: ["git log"], "Ordinal: superlative single"),
    EvalCase("biggest 5 directories", template: "du_summary", category: "system", required: ["du"], "Ordinal: biggest N dirs (gold corrected — du_summary IS du)"),
  ]),

  ("WildRanges", [
    // Gold labels updated to target the new range templates (Cand-3).
    EvalCase("files between 10MB and 100MB", template: "find_size_range", category: "file_ops", required: ["find", "-size +", "-size -"], slots: ["MIN_SIZE": "10MB", "MAX_SIZE": "100MB"], "Range: size between"),
    EvalCase("commits between v1.0 and v2.0", template: "git_log_range", category: "git", required: ["git log", "v1.0..v2.0"], slots: ["FROM": "v1.0", "TO": "v2.0"], "Range: git tag range"),
    EvalCase("files larger than 1 GiB", template: "find_large_files", category: "file_ops", required: ["find", "-size"], "Range: GiB unit"),
  ]),

  // MARK: T2.4 — Structured-data routing
  ("WildDataFormats", [
    EvalCase("process the json file", template: "jq_parse", category: "text_processing", required: ["jq"], "Format: json → jq"),
    EvalCase("parse json data", template: "jq_parse", category: "text_processing", required: ["jq"], "Format: parse json"),
    EvalCase("extract field from sales.json", template: "jq_parse", category: "text_processing", required: ["jq", "sales.json"], slots: ["FILE": "sales.json"], "Format: jq with file"),
    EvalCase("process the yaml file", template: "yq_parse", category: "text_processing", required: ["yq"], "Format: yaml → yq"),
    EvalCase("parse yaml config", template: "yq_parse", category: "text_processing", required: ["yq"], "Format: parse yaml"),
    EvalCase("process the csv file", template: "awk_column", category: "text_processing", required: ["awk"], "Format: csv → awk (preserved Cand-1)"),
  ]),

  // MARK: T2.3 — Time-range slots
  ("WildTimeRanges", [
    EvalCase("files modified between Monday and Friday", template: "find_mtime_range", category: "file_ops", required: ["find", "-newermt 'Monday'", "! -newermt 'Friday'"], slots: ["START": "Monday", "END": "Friday"], "Time-range: weekday→weekday"),
    EvalCase("files modified between yesterday and today", template: "find_mtime_range", category: "file_ops", required: ["find", "-newermt 'yesterday'", "! -newermt 'today'"], slots: ["START": "yesterday", "END": "today"], "Time-range: relative anchors"),
    EvalCase("files between 2026-01-01 and 2026-04-23", template: "find_mtime_range", category: "file_ops", required: ["find", "-newermt '2026-01-01'", "! -newermt '2026-04-23'"], slots: ["START": "2026-01-01", "END": "2026-04-23"], "Time-range: ISO dates"),
    EvalCase("commits between Monday and Friday", template: "git_log_date_range", category: "git", required: ["git log", "--since='Monday'", "--until='Friday'"], slots: ["START": "Monday", "END": "Friday"], "Time-range: git weekday→weekday"),
    EvalCase("commits between yesterday and today", template: "git_log_date_range", category: "git", required: ["git log", "--since='yesterday'", "--until='today'"], slots: ["START": "yesterday", "END": "today"], "Time-range: git relative anchors"),
  ]),

  ("WildShellMetachars", [
    EvalCase("grep 'error|warning' in log.txt", template: "grep_search", category: "text_processing", required: ["grep"], "Metachar: regex pipe"),
    EvalCase("find files with HOME in their name", template: "find_by_name", category: "file_ops", required: ["find"], "Metachar: env-var-looking token"),
    EvalCase("search for hello world", template: "grep_search", category: "text_processing", required: ["grep"], "Metachar: unquoted multi-token"),
  ]),

  ("WildEntityGaps", [
    EvalCase("install express package", template: "npm_install", category: "packages", required: ["npm install"], slots: ["PACKAGE": "express"], "Entity: .packageName never populated"),
    EvalCase("connect to example.com", template: "ssh_connect", category: "network", required: ["ssh"], "Entity: bare domain host"),
    EvalCase("ping my-host.local", template: "ping_host", category: "network", required: ["ping"], "Entity: .local TLD host"),
    EvalCase("show last 42 commits", template: "git_log", category: "git", required: ["git log"], slots: ["COUNT": "42"], "Entity: .number bare integer"),
  ]),
]
