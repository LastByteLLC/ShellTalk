#!/usr/bin/env swift
// generate_intent_data.swift — Generate 12K labeled intent→template training samples
//
// Each sample maps a natural language query to a template ID.
// Uses template substitution, variation generators, and adversarial examples.
//
// Output: JSON array of {"text": "...", "label": "template_id"}
// Run: swift Training/generate_intent_data.swift > Training/intent_data.json
//
// Quality notes:
// - Templates provide the structural backbone, but real human intent phrasing varies greatly.
// - This generator uses template slot substitution and variation generators (case, verbosity,
//   terse, typo) but may NOT capture the full diversity of natural language.
// - Consider augmenting with synthetic data generation (e.g., LLM paraphrasing) for:
//   * More natural phrasing variations
//   * Error recovery samples (need real stderr examples)
//   * Ambiguous queries that span multiple templates

import Foundation

struct Example: Codable {
  let text: String
  let label: String
}

var examples: [Example] = []
var rng = SystemRandomNumberGenerator()

// MARK: - Slot Values for Substitution

let files = [
  "main.swift", "Package.swift", "config.yaml", "README.md", "app.py",
  "index.ts", "Cargo.toml", "go.mod", "Dockerfile", "docker-compose.yml",
  "server.go", "lib.rs", "test_auth.py", "routes.swift", "schema.json",
  "Makefile", ".env", "setup.cfg", "requirements.txt", "package.json",
]

let paths = [
  ".", "src/", "Sources/", "Tests/", "~/Documents/project",
  "./build/", "lib/", "cmd/", "internal/", "public/",
]

let extensions = [
  "swift", "py", "ts", "js", "go", "rs", "json", "yaml", "md", "txt",
  "toml", "css", "html", "sql", "sh", "rb", "java", "kt", "c", "cpp",
]

let branches = [
  "main", "master", "develop", "feature/auth", "feature/api",
  "fix/crash-123", "release/2.0", "hotfix/login", "staging",
]

let patterns = [
  "TODO", "FIXME", "HACK", "import", "func", "struct", "class",
  "protocol", "enum", "let", "var", "return", "async", "await",
  "deprecated", "error", "warning", "public", "private",
]

let ports = ["3000", "8080", "5432", "6379", "443", "80", "9090", "27017"]

let packages = [
  "express", "flask", "django", "vapor", "tokio", "react", "vue",
  "swift-argument-parser", "alamofire", "numpy", "pandas", "tensorflow",
]

let urls = [
  "https://api.example.com/data", "https://cdn.example.com/file.tar.gz",
  "https://raw.githubusercontent.com/user/repo/main/file.txt",
  "https://httpbin.org/post", "https://example.com/api/v1/users",
]

let processes = [
  "node", "python3", "swift", "docker", "nginx", "postgres",
  "redis-server", "ollama", "hugo", "cargo",
]

let findReplaceSource = [
  ("foo", "bar"), ("old", "new"), ("http", "https"), ("v1", "v2"),
  ("debug", "release"), ("test", "prod"), ("localhost", "example.com"),
  ("TODO", "DONE"), ("error", "warning"), ("private", "public"),
]

let dockerImages = [
  "nginx", "postgres", "redis", "node:20", "python:3.12",
  "swift:6.0", "ubuntu:24.04", "alpine",
]

let jsonQueries = [
  ".name", ".data[]", ".results[0]", ".status", ".config.port",
  ".users | length", ".[].id", ".response.body",
]

// MARK: - Template-Based Generation

// Maps template IDs to arrays of (template, slot_filler) pairs
// Each template string has {SLOT} placeholders filled by the filler function

typealias Filler = () -> String

struct IntentTemplate {
  let templateId: String
  let phrases: [String]  // Natural language with {SLOT} placeholders
  let fillers: [String: Filler]  // Slot name -> random value generator
}

func randomElement<T>(_ arr: [T]) -> T {
  arr[Int.random(in: 0..<arr.count)]
}

func fillTemplate(_ template: String, fillers: [String: Filler]) -> String {
  var result = template
  for (slot, filler) in fillers {
    result = result.replacingOccurrences(of: "{\(slot)}", with: filler())
  }
  return result
}

// MARK: - Intent Templates per Category

let intentTemplates: [IntentTemplate] = [
  // --- File Operations ---
  IntentTemplate(templateId: "ls_files", phrases: [
    "list files in {PATH}", "show files in {PATH}", "what's in {PATH}",
    "ls {PATH}", "directory listing of {PATH}", "contents of {PATH}",
    "show me the files", "what files are here",
  ], fillers: ["PATH": { randomElement(paths) }]),

  IntentTemplate(templateId: "find_by_name", phrases: [
    "find files named {PATTERN}", "search for {PATTERN}", "locate {PATTERN}",
    "where is {PATTERN}", "find {PATTERN}", "look for files called {PATTERN}",
  ], fillers: ["PATTERN": { randomElement(files) }]),

  IntentTemplate(templateId: "find_by_extension", phrases: [
    "find {EXT} files", "find all .{EXT} files", "list {EXT} files",
    "show me all {EXT} files", "find all files with extension {EXT}",
    "where are the {EXT} files", "search for {EXT} source files",
  ], fillers: ["EXT": { randomElement(extensions) }]),

  IntentTemplate(templateId: "find_by_mtime", phrases: [
    "find files modified today", "recently changed files", "files edited today",
    "what changed recently", "modified files in the last {N} days",
    "find recent files", "recently modified files in {PATH}",
  ], fillers: ["N": { String(Int.random(in: 1...30)) }, "PATH": { randomElement(paths) }]),

  IntentTemplate(templateId: "find_large_files", phrases: [
    "find large files", "biggest files in the project", "files larger than {SIZE}",
    "what's taking up space", "find files over {SIZE}", "largest files",
  ], fillers: ["SIZE": { "\(Int.random(in: 1...100))M" }]),

  IntentTemplate(templateId: "cp_file", phrases: [
    "copy {FILE} to {PATH}", "duplicate {FILE}", "cp {FILE} {PATH}",
    "make a copy of {FILE}", "back up {FILE}",
  ], fillers: ["FILE": { randomElement(files) }, "PATH": { randomElement(paths) }]),

  IntentTemplate(templateId: "mv_file", phrases: [
    "move {FILE} to {PATH}", "rename {FILE}", "mv {FILE} to {PATH}",
    "move {FILE}", "rename {FILE} to something",
  ], fillers: ["FILE": { randomElement(files) }, "PATH": { randomElement(paths) }]),

  IntentTemplate(templateId: "rm_file", phrases: [
    "delete {FILE}", "remove {FILE}", "rm {FILE}", "trash {FILE}",
    "get rid of {FILE}", "delete the {FILE} file",
  ], fillers: ["FILE": { randomElement(files) }]),

  IntentTemplate(templateId: "mkdir_dir", phrases: [
    "create directory {PATH}", "make folder {PATH}", "mkdir {PATH}",
    "new directory called {PATH}", "create {PATH} folder",
  ], fillers: ["PATH": { "new_\(randomElement(["src", "lib", "build", "test", "docs"]))" }]),

  IntentTemplate(templateId: "du_disk_usage", phrases: [
    "disk usage", "how much space is {PATH} using", "folder sizes",
    "directory size of {PATH}", "what's using disk space", "du {PATH}",
  ], fillers: ["PATH": { randomElement(paths) }]),

  IntentTemplate(templateId: "tree_view", phrases: [
    "show directory tree", "project structure", "folder hierarchy",
    "tree view", "directory structure", "show the file tree",
  ], fillers: [:]),

  // --- Git ---
  IntentTemplate(templateId: "git_status", phrases: [
    "git status", "what changed", "show changes", "modified files",
    "uncommitted changes", "working tree status", "what's different",
  ], fillers: [:]),

  IntentTemplate(templateId: "git_diff", phrases: [
    "git diff", "show diff", "what's changed in {FILE}", "compare changes",
    "diff of {FILE}", "show modifications", "code changes",
  ], fillers: ["FILE": { randomElement(files) }]),

  IntentTemplate(templateId: "git_log", phrases: [
    "git log", "show commit history", "recent {N} commits",
    "last {N} commits", "commit log", "git history",
    "what was committed recently", "show the log",
  ], fillers: ["N": { String(Int.random(in: 5...50)) }]),

  IntentTemplate(templateId: "git_branch_list", phrases: [
    "list branches", "show branches", "what branches exist",
    "all branches", "git branch", "available branches",
  ], fillers: [:]),

  IntentTemplate(templateId: "git_branch_create", phrases: [
    "create branch {BRANCH}", "new branch {BRANCH}", "checkout -b {BRANCH}",
    "make branch {BRANCH}", "branch off as {BRANCH}",
  ], fillers: ["BRANCH": { randomElement(branches) }]),

  IntentTemplate(templateId: "git_switch", phrases: [
    "switch to {BRANCH}", "checkout {BRANCH}", "go to branch {BRANCH}",
    "change to {BRANCH}", "git switch {BRANCH}",
  ], fillers: ["BRANCH": { randomElement(branches) }]),

  IntentTemplate(templateId: "git_commit", phrases: [
    "commit changes", "git commit", "commit with message",
    "save changes to git", "make a commit", "commit the staged files",
  ], fillers: [:]),

  IntentTemplate(templateId: "git_stash", phrases: [
    "stash changes", "git stash", "save work temporarily",
    "stash current changes", "shelve my changes",
  ], fillers: [:]),

  IntentTemplate(templateId: "git_pull", phrases: [
    "pull changes", "git pull", "update from remote",
    "fetch latest", "pull latest changes",
  ], fillers: [:]),

  IntentTemplate(templateId: "git_push", phrases: [
    "push changes", "git push", "push to remote",
    "upload commits", "push to origin",
  ], fillers: [:]),

  IntentTemplate(templateId: "git_merge", phrases: [
    "merge {BRANCH}", "git merge {BRANCH}", "merge branch {BRANCH}",
    "combine {BRANCH} into current", "merge from {BRANCH}",
  ], fillers: ["BRANCH": { randomElement(branches) }]),

  IntentTemplate(templateId: "git_blame", phrases: [
    "blame {FILE}", "who changed {FILE}", "git blame {FILE}",
    "who wrote {FILE}", "line history of {FILE}",
  ], fillers: ["FILE": { randomElement(files) }]),

  // --- Text Processing ---
  IntentTemplate(templateId: "grep_search", phrases: [
    "search for {PATTERN}", "grep {PATTERN}", "find {PATTERN} in files",
    "search code for {PATTERN}", "grep for {PATTERN} in {PATH}",
    "find occurrences of {PATTERN}", "look for {PATTERN}",
  ], fillers: ["PATTERN": { randomElement(patterns) }, "PATH": { randomElement(paths) }]),

  IntentTemplate(templateId: "sed_replace", phrases: [
    "replace {FROM} with {TO} in {FILE}", "sed substitute {FROM} to {TO}",
    "find and replace {FROM} with {TO}", "change {FROM} to {TO} in {FILE}",
    "sed replace {FROM} with {TO}", "swap {FROM} for {TO} in {FILE}",
  ], fillers: [
    "FROM": { randomElement(findReplaceSource).0 },
    "TO": { randomElement(findReplaceSource).1 },
    "FILE": { randomElement(files) },
  ]),

  IntentTemplate(templateId: "wc_count", phrases: [
    "count lines in {FILE}", "how many lines in {FILE}", "wc {FILE}",
    "line count of {FILE}", "word count {FILE}",
  ], fillers: ["FILE": { randomElement(files) }]),

  IntentTemplate(templateId: "head_file", phrases: [
    "first {N} lines of {FILE}", "head {FILE}", "top of {FILE}",
    "preview {FILE}", "beginning of {FILE}", "show first {N} lines",
  ], fillers: ["N": { String(Int.random(in: 5...50)) }, "FILE": { randomElement(files) }]),

  IntentTemplate(templateId: "tail_file", phrases: [
    "last {N} lines of {FILE}", "tail {FILE}", "end of {FILE}",
    "bottom of {FILE}", "show last {N} lines of {FILE}",
  ], fillers: ["N": { String(Int.random(in: 5...50)) }, "FILE": { randomElement(files) }]),

  IntentTemplate(templateId: "tail_follow", phrases: [
    "follow {FILE}", "tail -f {FILE}", "watch {FILE} for changes",
    "stream {FILE}", "monitor {FILE} live", "live log {FILE}",
  ], fillers: ["FILE": { randomElement(["app.log", "server.log", "output.log", "debug.log"]) }]),

  IntentTemplate(templateId: "sort_unique", phrases: [
    "unique lines in {FILE}", "remove duplicates from {FILE}",
    "deduplicate {FILE}", "sort and unique {FILE}",
  ], fillers: ["FILE": { randomElement(files) }]),

  IntentTemplate(templateId: "jq_parse", phrases: [
    "parse json with jq {QUERY}", "jq {QUERY} {FILE}", "extract {QUERY} from json",
    "query json field {QUERY}", "pretty print json {FILE}", "format json",
  ], fillers: ["QUERY": { randomElement(jsonQueries) }, "FILE": { randomElement(["data.json", "response.json", "config.json"]) }]),

  // --- Dev Tools ---
  IntentTemplate(templateId: "swift_build", phrases: [
    "build the swift package", "swift build", "compile the project",
    "build in release mode", "swift build -c release",
  ], fillers: [:]),

  IntentTemplate(templateId: "swift_test", phrases: [
    "run swift tests", "swift test", "run the tests",
    "execute test suite", "run unit tests",
  ], fillers: [:]),

  IntentTemplate(templateId: "docker_run", phrases: [
    "run docker container {IMAGE}", "docker run {IMAGE}",
    "start {IMAGE} container", "launch docker {IMAGE}",
    "run {IMAGE} in docker on port {PORT}",
  ], fillers: ["IMAGE": { randomElement(dockerImages) }, "PORT": { randomElement(ports) }]),

  IntentTemplate(templateId: "docker_ps", phrases: [
    "running docker containers", "docker ps", "list containers",
    "show running containers", "active docker containers",
  ], fillers: [:]),

  IntentTemplate(templateId: "npm_install", phrases: [
    "npm install {PKG}", "install npm package {PKG}",
    "add {PKG} dependency", "npm add {PKG}",
  ], fillers: ["PKG": { randomElement(packages) }]),

  // --- Network ---
  IntentTemplate(templateId: "curl_get", phrases: [
    "curl {URL}", "fetch {URL}", "GET request to {URL}",
    "download {URL}", "http get {URL}", "make a request to {URL}",
  ], fillers: ["URL": { randomElement(urls) }]),

  IntentTemplate(templateId: "curl_post", phrases: [
    "POST to {URL}", "send data to {URL}", "curl POST {URL}",
    "post json to {URL}", "make a POST request to {URL}",
  ], fillers: ["URL": { randomElement(urls) }]),

  IntentTemplate(templateId: "ssh_connect", phrases: [
    "ssh to server", "connect via ssh", "ssh user@host",
    "remote login", "ssh into the server",
  ], fillers: [:]),

  IntentTemplate(templateId: "ping_host", phrases: [
    "ping google.com", "check if server is up", "ping {HOST}",
    "test connectivity to {HOST}", "is {HOST} reachable",
  ], fillers: ["HOST": { randomElement(["google.com", "8.8.8.8", "localhost", "api.example.com"]) }]),

  // --- System ---
  IntentTemplate(templateId: "ps_list", phrases: [
    "show running processes", "ps aux", "process list",
    "what's running", "list all processes",
  ], fillers: [:]),

  IntentTemplate(templateId: "kill_process", phrases: [
    "kill process {PROC}", "stop {PROC}", "kill {PROC}",
    "terminate {PROC} process", "end {PROC}",
  ], fillers: ["PROC": { randomElement(processes) }]),

  IntentTemplate(templateId: "df_disk", phrases: [
    "disk space", "free disk space", "df", "how much disk is left",
    "filesystem usage", "check disk space",
  ], fillers: [:]),

  IntentTemplate(templateId: "env_vars", phrases: [
    "show environment variables", "env", "print environment",
    "list env vars", "what's in the environment",
  ], fillers: [:]),

  IntentTemplate(templateId: "which_cmd", phrases: [
    "where is {CMD}", "which {CMD}", "find {CMD} path",
    "locate {CMD} binary", "path to {CMD}",
  ], fillers: ["CMD": { randomElement(["python3", "node", "swift", "git", "docker"]) }]),

  // --- macOS ---
  IntentTemplate(templateId: "open_file", phrases: [
    "open {FILE}", "open {FILE} in default app", "launch {FILE}",
    "open file {FILE}", "view {FILE}",
  ], fillers: ["FILE": { randomElement(files) }]),

  IntentTemplate(templateId: "pbcopy", phrases: [
    "copy to clipboard", "pipe to clipboard", "clipboard copy",
    "pbcopy", "copy output to clipboard",
  ], fillers: [:]),

  IntentTemplate(templateId: "mdfind_search", phrases: [
    "spotlight search for {PATTERN}", "mdfind {PATTERN}", "find {PATTERN} with spotlight",
    "search mac for {PATTERN}", "spotlight {PATTERN}",
  ], fillers: ["PATTERN": { randomElement(patterns) }]),

  IntentTemplate(templateId: "say_text", phrases: [
    "speak text", "say hello", "text to speech",
    "say something", "read aloud",
  ], fillers: [:]),

  IntentTemplate(templateId: "caffeinate_cmd", phrases: [
    "prevent sleep", "keep mac awake", "caffeinate",
    "don't let the mac sleep", "prevent display sleep",
  ], fillers: [:]),

  IntentTemplate(templateId: "screencapture", phrases: [
    "take screenshot", "screen capture", "screencapture",
    "capture the screen", "take a screen shot",
  ], fillers: [:]),

  // --- Packages ---
  IntentTemplate(templateId: "brew_install", phrases: [
    "brew install {PKG}", "install {PKG} with homebrew",
    "homebrew install {PKG}", "get {PKG} via brew",
  ], fillers: ["PKG": { randomElement(["jq", "ripgrep", "fd", "bat", "fzf", "httpie", "tree"]) }]),

  IntentTemplate(templateId: "brew_search", phrases: [
    "brew search {PKG}", "search homebrew for {PKG}",
    "is {PKG} available on brew", "find {PKG} in brew",
  ], fillers: ["PKG": { randomElement(packages) }]),

  // --- Compression ---
  IntentTemplate(templateId: "tar_create", phrases: [
    "create tar archive of {PATH}", "tar {PATH}", "compress {PATH}",
    "archive {PATH}", "make a tarball of {PATH}",
  ], fillers: ["PATH": { randomElement(paths) }]),

  IntentTemplate(templateId: "tar_extract", phrases: [
    "extract tar archive", "untar {FILE}", "decompress {FILE}",
    "extract {FILE}", "unpack {FILE}",
  ], fillers: ["FILE": { randomElement(["archive.tar.gz", "backup.tgz", "data.tar.xz"]) }]),

  IntentTemplate(templateId: "zip_compress", phrases: [
    "zip {PATH}", "compress to zip", "create zip of {PATH}",
    "zip archive {PATH}", "make a zip file",
  ], fillers: ["PATH": { randomElement(paths) }]),

  // --- Cloud ---
  IntentTemplate(templateId: "aws_s3_ls", phrases: [
    "list s3 bucket", "aws s3 ls", "show s3 contents",
    "what's in the s3 bucket", "list files in s3",
  ], fillers: [:]),

  IntentTemplate(templateId: "kubectl_get_pods", phrases: [
    "list kubernetes pods", "kubectl get pods", "show pods",
    "running k8s pods", "pod status",
  ], fillers: [:]),
]

// MARK: - Generation

// Generate base examples from templates
for template in intentTemplates {
  let targetPerTemplate = 11000 / intentTemplates.count + 1  // ~170 each
  for _ in 0..<targetPerTemplate {
    let phrase = randomElement(template.phrases)
    let filled = fillTemplate(phrase, fillers: template.fillers)
    examples.append(Example(text: filled, label: template.templateId))
  }
}

// MARK: - Variation Generators

// 1. ALL CAPS variations (500 samples)
for _ in 0..<500 {
  let template = randomElement(intentTemplates)
  let phrase = randomElement(template.phrases)
  let filled = fillTemplate(phrase, fillers: template.fillers)
  examples.append(Example(text: filled.uppercased(), label: template.templateId))
}

// 2. Lowercase variations (500 samples)
for _ in 0..<500 {
  let template = randomElement(intentTemplates)
  let phrase = randomElement(template.phrases)
  let filled = fillTemplate(phrase, fillers: template.fillers)
  examples.append(Example(text: filled.lowercased(), label: template.templateId))
}

// 3. Terse/shorthand (500 samples)
let terseTemplates: [(String, String)] = [
  ("git status", "git_status"), ("git diff", "git_diff"), ("git log", "git_log"),
  ("git push", "git_push"), ("git pull", "git_pull"), ("git stash", "git_stash"),
  ("ls", "ls_files"), ("ps", "ps_list"), ("df", "df_disk"),
  ("env", "env_vars"), ("top", "ps_list"),
  ("grep TODO", "grep_search"), ("find *.swift", "find_by_extension"),
  ("wc -l", "wc_count"), ("head", "head_file"), ("tail", "tail_file"),
  ("docker ps", "docker_ps"), ("brew install", "brew_install"),
  ("tar xf", "tar_extract"), ("unzip", "tar_extract"),
  ("curl", "curl_get"), ("ssh", "ssh_connect"), ("ping", "ping_host"),
  ("screenshot", "screencapture"), ("clipboard", "pbcopy"),
]
for _ in 0..<500 {
  let (text, label) = randomElement(terseTemplates)
  examples.append(Example(text: text, label: label))
}

// 4. Typos / misspellings (300 samples)
func addTypo(_ text: String) -> String {
  guard text.count > 3 else { return text }
  var chars = Array(text)
  let idx = Int.random(in: 1..<chars.count - 1)
  // Swap adjacent characters
  chars.swapAt(idx, idx - 1)
  return String(chars)
}

for _ in 0..<300 {
  let template = randomElement(intentTemplates)
  let phrase = randomElement(template.phrases)
  let filled = fillTemplate(phrase, fillers: template.fillers)
  examples.append(Example(text: addTypo(filled), label: template.templateId))
}

// 5. Prefix/suffix noise (200 samples)
let prefixes = ["please ", "can you ", "I want to ", "help me ", "quickly ", "just "]
let suffixes = [" please", " thanks", " now", " quickly", " asap", " for me"]
for _ in 0..<200 {
  let template = randomElement(intentTemplates)
  let phrase = randomElement(template.phrases)
  let filled = fillTemplate(phrase, fillers: template.fillers)
  let prefix = Bool.random() ? randomElement(prefixes) : ""
  let suffix = Bool.random() ? randomElement(suffixes) : ""
  examples.append(Example(text: prefix + filled + suffix, label: template.templateId))
}

// MARK: - Quality Notes

// NOTE: The following areas may benefit from SYNTHETIC data generation (LLM paraphrasing)
// rather than template-based generation:
//
// 1. NATURAL LANGUAGE INTENTS: Real humans phrase requests in highly varied ways.
//    Templates capture ~60% of phrasing diversity. LLM paraphrasing can reach ~90%.
//    Example: "find swift files" could also be phrased as:
//    - "I need to see all the Swift source in this project"
//    - "where are my .swift files?"
//    - "show me anything ending in .swift"
//    - "can you locate the swift sources?"
//
// 2. ERROR RECOVERY SAMPLES: Real stderr output is messy and varied.
//    Template-based error messages are too clean. Real errors include:
//    - Stack traces, line numbers, file paths
//    - Partial output mixed with errors
//    - Non-English locale messages
//    Need: ~800 real stderr samples from actual command failures
//
// 3. AMBIGUOUS QUERIES: Queries that could match multiple templates.
//    Need: ~400 carefully crafted ambiguous examples with correct labels.
//    Example: "find config" → file search, not kubectl apply
//
// 4. MULTI-STEP PIPELINES: Complex piped commands are hard to template.
//    Need: ~500 natural descriptions of piped workflows.
//    Example: "count how many unique IPs hit the server today"
//    → "grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' access.log | sort -u | wc -l"

// MARK: - Output

// Shuffle
examples.shuffle()

// Print stats to stderr
let labelCounts = Dictionary(grouping: examples, by: \.label)
  .mapValues(\.count)
  .sorted(by: { $0.value > $1.value })

fputs("Generated \(examples.count) examples across \(labelCounts.count) labels\n", stderr)
fputs("Top labels:\n", stderr)
for (label, count) in labelCounts.prefix(20) {
  fputs("  \(label): \(count)\n", stderr)
}

// Output JSON
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(examples)
print(String(data: data, encoding: .utf8)!)
