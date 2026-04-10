# Dockerfile — Build and test ShellTalk on Linux
FROM swiftlang/swift:nightly-6.1-jammy

WORKDIR /app

# Copy package manifest first for dependency caching
COPY Package.swift Package.resolved ./
RUN swift package resolve

# Copy all source
COPY Sources/ Sources/
COPY Tests/ Tests/

# Single build + test pass (shares build cache within one RUN layer)
RUN swift test 2>&1 && \
    swift run shelltalk "find swift files" 2>&1 && \
    swift run stm-eval 2>&1 | tail -10
