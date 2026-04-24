# Dockerfile — Multi-stage Linux build & benchmark image for ShellTalk.
#
# Pinned to Swift 6.3-RELEASE on Ubuntu 24.04 LTS, matching the CI config.
# Install Swift by tarball (same pattern as .github/workflows/ci.yml) rather
# than using the `swiftlang/swift:6.3-jammy` floating tag — per CI comment,
# the 6.3 → 6.3.1 drift on that tag causes ABI mismatch with swift-wasm-6.3.
#
# Build for native Apple Silicon via `--platform=linux/arm64` so Docker Desktop
# on a Mac runs containers on the host CPU (no Rosetta emulation, no 2–5×
# perf distortion on benchmarks).
#
# Typical usage:
#   docker build --platform=linux/arm64 -t shelltalk:linux-perf .
#   docker run --rm shelltalk:linux-perf                      # runs stm-eval
#   docker run --rm shelltalk:linux-perf shelltalk "git status"
#
# Binaries land under /usr/local/bin in the runtime stage.

# ------------------------------------------------------------------------
# Stage 1 — builder
# ------------------------------------------------------------------------
FROM ubuntu:24.04 AS builder

ARG SWIFT_VERSION=6.3-RELEASE
ARG TARGETARCH

# Runtime libs Swift needs at compile time. Ubuntu 24.04 (noble) dropped
# libncurses5; Swift 6.3 works without it.
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
      binutils \
      ca-certificates \
      curl \
      git \
      libc6-dev \
      libcurl4-openssl-dev \
      libedit2 \
      libgcc-13-dev \
      libncurses6 \
      libpython3-dev \
      libsqlite3-0 \
      libstdc++-13-dev \
      libxml2-dev \
      libz3-dev \
      tzdata \
      zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

# Fetch Swift from download.swift.org. TARGETARCH matches Docker's naming
# (amd64/arm64). Swift.org ships ubuntu24.04 prebuilds for both archs. Avoid
# bash-only param substitution (`${var//./}`) since the default /bin/sh here
# is dash — hand-code the arch strings for the URL path vs. filename.
RUN set -eux; \
    case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
      arm64) SWIFT_ARCH_FILE="ubuntu24.04-aarch64"; SWIFT_ARCH_PATH="ubuntu2404-aarch64" ;; \
      amd64) SWIFT_ARCH_FILE="ubuntu24.04";          SWIFT_ARCH_PATH="ubuntu2404" ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    SWIFT_VERSION_PATH=$(echo "$SWIFT_VERSION" | cut -d- -f1); \
    curl -fsSL -o /tmp/swift.tar.gz \
      "https://download.swift.org/swift-${SWIFT_VERSION_PATH}-release/${SWIFT_ARCH_PATH}/swift-${SWIFT_VERSION}/swift-${SWIFT_VERSION}-${SWIFT_ARCH_FILE}.tar.gz"; \
    mkdir -p /opt/swift; \
    tar -xzf /tmp/swift.tar.gz -C /opt/swift --strip-components=1; \
    rm /tmp/swift.tar.gz
ENV PATH=/opt/swift/usr/bin:$PATH

WORKDIR /src

# Copy manifest first so `swift package resolve` caches across source edits.
COPY Package.swift Package.resolved ./
RUN swift package resolve

# Build the release binaries we care about for perf measurement.
COPY Sources/ Sources/
COPY Tests/ Tests/
# `swift build --product X --product Y` only builds the last one (SPM quirk);
# run two invocations so both binaries land in .build/release/.
RUN swift build -c release --product shelltalk -Xswiftc -Osize -Xswiftc -gnone \
 && swift build -c release --product stm-eval -Xswiftc -Osize -Xswiftc -gnone \
 && strip --strip-all .build/release/shelltalk \
 && strip --strip-all .build/release/stm-eval \
 && ls -lh .build/release/shelltalk .build/release/stm-eval

# ------------------------------------------------------------------------
# Stage 2 — runtime (perf measurement target)
# ------------------------------------------------------------------------
FROM ubuntu:24.04 AS runtime

# Minimal runtime dependencies. Swift dynamic libs come from the Swift runtime
# package in /opt/swift-runtime. For the smallest image we'd use musl + static
# stdlib; here we prioritize compatibility (glibc + dynamic Swift runtime).
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
      ca-certificates \
      libc6 \
      libcurl4 \
      libedit2 \
      libgcc-s1 \
      libncurses6 \
      libpython3.12 \
      libsqlite3-0 \
      libstdc++6 \
      libxml2 \
      tzdata \
      zlib1g \
      busybox \
      time \
 && rm -rf /var/lib/apt/lists/* \
 && ln -sf /usr/bin/busybox /usr/bin/strip 2>/dev/null || true

# Copy the Swift runtime libraries so dynamically-linked binaries find libswiftCore.
COPY --from=builder /opt/swift/usr/lib/swift/linux/ /usr/lib/swift/linux/
ENV LD_LIBRARY_PATH=/usr/lib/swift/linux

# Copy built binaries.
COPY --from=builder /src/.build/release/shelltalk /usr/local/bin/shelltalk
COPY --from=builder /src/.build/release/stm-eval  /usr/local/bin/stm-eval

# Default command: run the benchmark and write metrics to /tmp/metrics.json.
CMD ["/usr/local/bin/stm-eval", "--quiet", "--metrics-out", "/tmp/metrics.json"]
