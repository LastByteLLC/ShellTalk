import Foundation
import ShellTalkKit

// MARK: - Test Case

struct EvalCase {
  let query: String
  let expectedTemplateId: String
  let expectedCategoryId: String
  let requiredSubstrings: [String]
  let forbiddenSubstrings: [String]
  let requiredSlots: [String: String]
  let description: String

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

// MARK: - All Test Cases

let allCases: [(String, [EvalCase])] = [
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
    EvalCase("convert video to gif", template: "ffmpeg_gif", category: "media", required: ["ffmpeg", "-i"], "Direct"),
    EvalCase("video info for clip.mp4", template: "ffmpeg_info", category: "media", required: ["ffprobe"], "Direct"),
    EvalCase("convert image photo.png to photo.jpg", template: "magick_convert", category: "media", required: ["magick"], "Direct"),
    EvalCase("resize image photo.jpg", template: "magick_resize", category: "media", required: ["magick"], "Direct"),
    EvalCase("identify photo.jpg", template: "magick_identify", category: "media", required: ["magick identify"], "Terse"),
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
    EvalCase("ansible playbook deploy.yml", template: "kubectl_apply", category: "cloud", required: ["kubectl apply"], "Unknown: ansible→k8s deploy"),
    EvalCase("flutter build apk", template: "swift_build_release", category: "dev_tools", required: ["swift build"], "Unknown: flutter→build"),
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
    EvalCase("copy README.md and LICENSE to archive/", template: "cp_file", category: "file_ops", required: ["cp"], "Multi: two sources"),
    EvalCase("move a.txt and b.txt to backup/", template: "mv_file", category: "file_ops", required: ["mv"], "Multi: two sources mv"),
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
    EvalCase("biggest 5 directories", template: "du_disk_usage", category: "file_ops", required: ["du"], "Ordinal: biggest N dirs"),
  ]),

  ("WildRanges", [
    // Gold labels updated to target the new range templates (Cand-3).
    EvalCase("files between 10MB and 100MB", template: "find_size_range", category: "file_ops", required: ["find", "-size +", "-size -"], slots: ["MIN_SIZE": "10MB", "MAX_SIZE": "100MB"], "Range: size between"),
    EvalCase("commits between v1.0 and v2.0", template: "git_log_range", category: "git", required: ["git log", "v1.0..v2.0"], slots: ["FROM": "v1.0", "TO": "v2.0"], "Range: git tag range"),
    EvalCase("files larger than 1 GiB", template: "find_large_files", category: "file_ops", required: ["find", "-size"], "Range: GiB unit"),
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

// MARK: - CLI args

struct EvalArgs {
  var traceOut: String?
  var metricsOut: String?
  var overlayPath: String?
  var quiet: Bool = false

  static func parse() -> EvalArgs {
    var args = EvalArgs()
    var i = 1
    let argv = CommandLine.arguments
    while i < argv.count {
      switch argv[i] {
      case "--trace-out":
        i += 1
        if i < argv.count { args.traceOut = argv[i] }
      case "--metrics-out":
        i += 1
        if i < argv.count { args.metricsOut = argv[i] }
      case "--overlay":
        i += 1
        if i < argv.count { args.overlayPath = argv[i] }
      case "--quiet":
        args.quiet = true
      case "--help", "-h":
        print("""
        stm-eval — run ShellTalk accuracy evaluation

        Options:
          --overlay <path>       YAML overlay to mutate matcher config + templates
          --trace-out <path>     Emit JSONL trace (one record per case)
          --metrics-out <path>   Emit aggregate metrics.json
          --quiet                Suppress per-case stdout table
        """)
        exit(0)
      default:
        break
      }
      i += 1
    }
    return args
  }
}

// MARK: - Trace + Metrics schemas

struct TraceRecord: Encodable {
  let q: String
  let suite: String
  let gold_tpl: String
  let gold_cat: String
  let pred_tpl: String?
  let pred_cat: String?
  let ok_tpl: Bool
  let ok_cat: Bool
  let cat_score: Double?
  let tpl_score: Double?
  let conf: Double?
  let path: String
  let bm25_top5: [String]
  let entities: [String]
  let slots: [String: String]
  let miss_substr: [String]
  let safety: String
  let cmd: String?
  let ms: Double
}

struct PathBucket: Encodable {
  let n: Int
  let acc: Double
}

struct Metrics: Encodable {
  let n_cases: Int
  let tpl_acc: Double
  let cat_acc: Double
  let substr_acc: Double
  let slot_acc: Double
  let neg_acc: Double
  let p50_ms: Double
  let p95_ms: Double
  let p99_ms: Double
  let init_ms: Double
  let per_suite: [String: Double]
  let per_path: [String: PathBucket]
  let overlay_hash: String
  let overlay_path: String?
  let timestamp: String
}

// MARK: - Helpers

private func inferMatchPath(_ r: PipelineResult) -> String {
  // Heuristic from score patterns (see IntentMatcher fast-path scoring):
  // exact/meta: 1.0/1.0, phrase: 1.0/0.95, prefix: 1.0/0.9, else bm25.
  let cs = r.categoryScore, ts = r.templateScore
  if cs == 1.0 && ts == 1.0 { return "exact" }
  if cs == 1.0 && abs(ts - 0.95) < 1e-9 { return "phrase" }
  if cs == 1.0 && abs(ts - 0.9) < 1e-9 { return "prefix" }
  return "bm25"
}

private func percentile(_ sorted: [Double], _ p: Double) -> Double {
  guard !sorted.isEmpty else { return 0 }
  let idx = min(sorted.count - 1, Int((Double(sorted.count) * p).rounded(.down)))
  return sorted[idx]
}

private func iso8601Now() -> String {
  let f = ISO8601DateFormatter()
  f.formatOptions = [.withInternetDateTime]
  return f.string(from: Date())
}

// MARK: - Main

@main
struct STMEval {
  static func main() {
    let args = EvalArgs.parse()

    // Load overlay explicitly (if given). Build pipeline with overlay applied
    // on top of the shipped built-in refinements (TemplateRefinements.default).
    let overlay: PipelineOverlay? = args.overlayPath.flatMap { PipelineOverlay.load(path: $0) }
    let baseMatcherConfig = overlay?.apply(to: .default) ?? .default
    let includeDebug = (args.traceOut != nil)
    let pipelineConfig = PipelineConfig(
      matcherConfig: baseMatcherConfig,
      validateCommands: true,
      includeDebugInfo: includeDebug
    )
    // Base = built-in templates WITH shipped refinements. User overlay stacks on top.
    let refinedCategories = TemplateRefinements.defaultOverlay.apply(to: BuiltInTemplates.all)
    let overlaidCategories = overlay?.apply(to: refinedCategories) ?? refinedCategories
    let store = TemplateStore(categories: overlaidCategories)
    let pipe = STMPipeline(profile: nil, store: store, config: pipelineConfig)

    let totalCount = allCases.reduce(0) { $0 + $1.1.count }
    if !args.quiet {
      print("ShellTalk STM Accuracy Evaluation — \(totalCount) test cases")
      if let p = args.overlayPath { print("Overlay: \(p) (hash=\(overlay?.contentHash() ?? "n/a"))") }
      print(String(repeating: "=", count: 160))
    }

    var totalTests = 0
    var templateOk = 0
    var categoryOk = 0
    var substrOk = 0
    var substrTotal = 0
    var slotOk = 0
    var slotTotal = 0
    var negTotal = 0
    var negOk = 0
    var failures: [(String, String, String, String, String, String)] = []
    var catBreak: [String: (Int, Int, Int)] = [:]
    var latencies: [Double] = []
    var pathCounts: [String: (n: Int, ok: Int)] = [:]
    var traces: [TraceRecord] = []
    let wantTraces = args.traceOut != nil

    for (suite, cases) in allCases {
      var st = 0, stOk = 0, scOk = 0

      for tc in cases {
        totalTests += 1; st += 1

        let t0 = Date().timeIntervalSinceReferenceDate
        let r = pipe.process(tc.query)
        let ms = (Date().timeIntervalSinceReferenceDate - t0) * 1000
        latencies.append(ms)

        let isNeg = tc.expectedTemplateId == "_nil_"
        var tOk = false, cOk = false

        if isNeg {
          negTotal += 1
          tOk = r == nil || r!.confidence < 0.3
          cOk = tOk
          if tOk { negOk += 1 }
        } else {
          tOk = r?.templateId == tc.expectedTemplateId
          cOk = r?.categoryId == tc.expectedCategoryId
        }
        if tOk { templateOk += 1; stOk += 1 }
        if cOk { categoryOk += 1; scOk += 1 }

        var missSubstr: [String] = []
        for s in tc.requiredSubstrings {
          substrTotal += 1
          if r?.command.contains(s) == true {
            substrOk += 1
          } else {
            missSubstr.append(s)
          }
        }
        for (k, v) in tc.requiredSlots {
          slotTotal += 1
          if r?.extractedSlots[k] == v { slotOk += 1 }
        }

        let safety: String
        if let v = r?.validation {
          switch v.safetyLevel {
          case .safe: safety = "SAFE"
          case .caution: safety = "CAUTION"
          case .dangerous: safety = "DANGER"
          }
        } else { safety = "N/A" }

        let path: String = r.map(inferMatchPath) ?? "none"
        var bucket = pathCounts[path] ?? (0, 0)
        bucket.n += 1
        if tOk { bucket.ok += 1 }
        pathCounts[path] = bucket

        if !args.quiet {
          let mark = tOk ? "OK " : " X "
          let q = tc.query.isEmpty ? "(empty)" : tc.query
          let cmd = r?.command ?? "(nil)"
          let act = r?.templateId ?? "(nil)"
          print("\(mark) \(q.padding(toLength: 50, withPad: " ", startingAt: 0)) exp=\(tc.expectedTemplateId.padding(toLength: 20, withPad: " ", startingAt: 0)) act=\(act.padding(toLength: 20, withPad: " ", startingAt: 0)) \(safety.padding(toLength: 7, withPad: " ", startingAt: 0)) \(String(format: "%5.1f", ms))ms  \(cmd.prefix(60))")
        }

        if !tOk {
          failures.append((suite, tc.query.isEmpty ? "(empty)" : tc.query, tc.expectedTemplateId, r?.templateId ?? "(nil)", r?.categoryId ?? "(nil)", r?.command ?? "(nil)"))
        }

        if wantTraces {
          let topMatches: [String] = r?.debugInfo?.topMatches.prefix(5).map {
            "\($0.templateId):\(String(format: "%.2f", $0.templateScore))"
          } ?? []
          let entityStrs: [String] = r?.debugInfo?.entities.map {
            "\($0.type.rawValue):\($0.text)"
          } ?? []
          traces.append(TraceRecord(
            q: tc.query,
            suite: suite,
            gold_tpl: tc.expectedTemplateId,
            gold_cat: tc.expectedCategoryId,
            pred_tpl: r?.templateId,
            pred_cat: r?.categoryId,
            ok_tpl: tOk,
            ok_cat: cOk,
            cat_score: r?.categoryScore,
            tpl_score: r?.templateScore,
            conf: r?.confidence,
            path: path,
            bm25_top5: topMatches,
            entities: entityStrs,
            slots: r?.extractedSlots ?? [:],
            miss_substr: missSubstr,
            safety: safety,
            cmd: r?.command,
            ms: ms
          ))
        }
      }
      catBreak[suite] = (st, stOk, scOk)
    }

    if !args.quiet {
      print("\n" + String(repeating: "=", count: 160))
      print("SUMMARY")
      print(String(repeating: "=", count: 160))
    }

    let ta = Double(templateOk) / Double(totalTests) * 100
    let ca = Double(categoryOk) / Double(totalTests) * 100
    let sa = substrTotal > 0 ? Double(substrOk) / Double(substrTotal) * 100 : 100
    let sla = slotTotal > 0 ? Double(slotOk) / Double(slotTotal) * 100 : 100
    let neg = negTotal > 0 ? Double(negOk) / Double(negTotal) * 100 : 100

    if !args.quiet {
      print("Template accuracy:   \(templateOk) / \(totalTests) (\(String(format: "%.1f", ta))%)")
      print("Category accuracy:   \(categoryOk) / \(totalTests) (\(String(format: "%.1f", ca))%)")
      print("Substring checks:    \(substrOk) / \(substrTotal) (\(String(format: "%.1f", sa))%)")
      print("Slot extraction:     \(slotOk) / \(slotTotal) (\(String(format: "%.1f", sla))%)")
      print("Negative rejection:  \(negOk) / \(negTotal) (\(String(format: "%.1f", neg))%)")

      print("\nPER-CATEGORY:")
      for (n, s) in catBreak.sorted(by: { $0.key < $1.key }) {
        let tp = s.0 > 0 ? Double(s.1) / Double(s.0) * 100 : 0
        let cp = s.0 > 0 ? Double(s.2) / Double(s.0) * 100 : 0
        print("  \(n.padding(toLength: 18, withPad: " ", startingAt: 0)) \(s.0) tests  template=\(String(format: "%.0f", tp))%  category=\(String(format: "%.0f", cp))%")
      }

      if !failures.isEmpty {
        print("\nFAILURES (\(failures.count)):")
        for f in failures {
          print("  [\(f.0)] \"\(f.1)\"  expected=\(f.2)  got=\(f.3)  cat=\(f.4)")
          print("    cmd: \(f.5.prefix(100))")
        }
      }

      print("\nDone.")
    }

    // Emit JSONL traces
    if let tracePath = args.traceOut {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      var buf = ""
      for t in traces {
        if let data = try? encoder.encode(t), let s = String(data: data, encoding: .utf8) {
          buf.append(s); buf.append("\n")
        }
      }
      try? createDirectories(forFile: tracePath)
      try? buf.write(toFile: tracePath, atomically: true, encoding: .utf8)
    }

    // Emit metrics.json
    if let metricsPath = args.metricsOut {
      let sorted = latencies.sorted()
      let perSuite = catBreak.mapValues { s -> Double in
        s.0 > 0 ? Double(s.1) / Double(s.0) : 0
      }
      let perPath = pathCounts.mapValues { b -> PathBucket in
        PathBucket(n: b.n, acc: b.n > 0 ? Double(b.ok) / Double(b.n) : 0)
      }
      let metrics = Metrics(
        n_cases: totalTests,
        tpl_acc: Double(templateOk) / Double(totalTests),
        cat_acc: Double(categoryOk) / Double(totalTests),
        substr_acc: substrTotal > 0 ? Double(substrOk) / Double(substrTotal) : 1.0,
        slot_acc: slotTotal > 0 ? Double(slotOk) / Double(slotTotal) : 1.0,
        neg_acc: negTotal > 0 ? Double(negOk) / Double(negTotal) : 1.0,
        p50_ms: percentile(sorted, 0.50),
        p95_ms: percentile(sorted, 0.95),
        p99_ms: percentile(sorted, 0.99),
        init_ms: pipe.initMs,
        per_suite: perSuite,
        per_path: perPath,
        overlay_hash: overlay?.contentHash() ?? "none",
        overlay_path: args.overlayPath,
        timestamp: iso8601Now()
      )
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
      if let data = try? encoder.encode(metrics) {
        try? createDirectories(forFile: metricsPath)
        try? data.write(to: URL(fileURLWithPath: metricsPath))
      }
    }
  }
}

private func createDirectories(forFile path: String) throws {
  let url = URL(fileURLWithPath: path)
  let dir = url.deletingLastPathComponent()
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
}
