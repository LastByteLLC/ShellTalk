# Dockerfile — Build and test ShellTalk on Linux
FROM swiftlang/swift:nightly-6.1-jammy

WORKDIR /app

COPY Package.swift Package.resolved ./
RUN swift package resolve

COPY Sources/ Sources/
COPY Tests/ Tests/

RUN swift build 2>&1
RUN swift test 2>&1
RUN swift run shelltalk "find swift files" 2>&1
RUN swift run shelltalk --profile 2>&1
