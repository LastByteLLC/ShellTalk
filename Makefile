# Makefile — Build and install ShellTalk

PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin

# Linux perf benchmarking (requires Docker; uses linux/arm64 on Apple Silicon
# so the container runs natively, not via Rosetta).
LINUX_IMAGE ?= shelltalk:linux-perf
DOCKER_PLATFORM ?= linux/arm64

.PHONY: build test install uninstall clean release wasm wasm-compressed wasm-demo eval \
        bench-linux bench-linux-size bench-wasm-size bench-all

build:
	swift build -c release

test:
	swift test

install: build
	install -d $(BINDIR)
	install .build/release/shelltalk $(BINDIR)/shelltalk

uninstall:
	rm -f $(BINDIR)/shelltalk

clean:
	swift package clean
	rm -rf .build

release:
	swift build -c release --arch arm64
	@echo "Binary: .build/release/shelltalk"
	@ls -lh .build/release/shelltalk

eval:
	swift run stm-eval

wasm:
	swift build --swift-sdk swift-6.3-RELEASE_wasm --product shelltalk-wasm -c release \
	  -Xswiftc -Osize \
	  -Xswiftc -gnone \
	  -Xswiftc -Xfrontend -Xswiftc -disable-reflection-metadata \
	  -Xswiftc -Xfrontend -Xswiftc -disable-availability-checking
	wasm-opt -Oz \
	  --strip-debug --strip-producers --strip-eh --strip-target-features \
	  --vacuum --dae-optimizing --converge \
	  .build/wasm32-unknown-wasip1/release/shelltalk-wasm.wasm \
	  -o Web/shelltalk.wasm
	@command -v wasm-strip >/dev/null 2>&1 && wasm-strip Web/shelltalk.wasm || echo "(skip: wasm-strip not installed)"
	@echo "WASM binary: Web/shelltalk.wasm"
	@ls -lh Web/shelltalk.wasm

# Emit Brotli + gzip variants for the web demo. Brotli typically hits ~25–35%
# of raw WASM; gzip is the fallback for browsers/servers without .br support.
wasm-compressed: wasm
	@command -v brotli >/dev/null 2>&1 || (echo "brotli not installed — brew install brotli"; exit 1)
	brotli --force -q 11 -o Web/shelltalk.wasm.br Web/shelltalk.wasm
	gzip  --force -9 -k  Web/shelltalk.wasm
	@mv Web/shelltalk.wasm.gz Web/shelltalk.wasm.gz 2>/dev/null; true
	@echo ""
	@echo "WASM wire sizes:"
	@ls -lh Web/shelltalk.wasm Web/shelltalk.wasm.br Web/shelltalk.wasm.gz

wasm-demo: wasm
	@echo "Starting web server at http://localhost:8090"
	cd Web && python3 -m http.server 8090

# ---------------------------------------------------------------------------
# Benchmarking targets
#
# bench-linux       — build the multi-stage Dockerfile and run stm-eval inside
# bench-linux-size  — report stripped Linux binary size (runs bench-linux first)
# bench-wasm-size   — report Web/shelltalk.wasm size + wasm-objdump section breakdown
# bench-all         — rebuild + rerun everything, emit a side-by-side table
# ---------------------------------------------------------------------------

bench-linux:
	@echo "==> Building Linux perf image ($(DOCKER_PLATFORM))"
	docker build --platform=$(DOCKER_PLATFORM) -t $(LINUX_IMAGE) .
	@echo "==> Running stm-eval inside container (3 runs, extracting metrics)"
	@mkdir -p /tmp/shelltalk-bench
	@for i in 1 2 3; do \
	  echo "--- run $$i ---"; \
	  docker run --rm --platform=$(DOCKER_PLATFORM) \
	    -v /tmp/shelltalk-bench:/out $(LINUX_IMAGE) \
	    sh -c '/usr/bin/time -v stm-eval --quiet --metrics-out /out/linux-run-'$$i'.json 2> /out/linux-run-'$$i'.time'; \
	done
	@echo "==> Linux run summary"
	@python3 -c 'import json,glob; \
	rs=[json.load(open(f)) for f in sorted(glob.glob("/tmp/shelltalk-bench/linux-run-*.json"))]; \
	k=["tpl_acc","cat_acc","mean_ms","p50_ms","p90_ms","p99_ms","max_ms","wall_ms","init_ms"]; \
	print("| metric |", " | ".join(f"run{i+1}" for i in range(len(rs))), "|"); \
	print("|---|", "|".join("---:" for _ in rs), "|"); \
	[print(f"| {m} |", " | ".join(f"{r[m]:.3f}" if m.endswith("_acc") else f"{r[m]:.1f}" for r in rs), "|") for m in k]'
	@echo ""
	@echo "==> Per-path accuracy (run 1)"
	@python3 -c 'import json; d=json.load(open("/tmp/shelltalk-bench/linux-run-1.json")); \
	print("| path | n | acc |"); print("|---|---:|---:|"); \
	[print(f"| {k} | {v[\"n\"]} | {v[\"acc\"]:.3f} |") for k,v in sorted(d["per_path"].items())]'

bench-linux-size:
	@echo "==> Linux binary sizes (inside $(LINUX_IMAGE))"
	@docker image inspect $(LINUX_IMAGE) > /dev/null 2>&1 || $(MAKE) bench-linux
	@docker run --rm --platform=$(DOCKER_PLATFORM) $(LINUX_IMAGE) \
	  sh -c 'ls -lh /usr/local/bin/shelltalk /usr/local/bin/stm-eval; echo; echo "Total Swift runtime libs:"; du -sh /usr/lib/swift/linux'

bench-wasm-size:
	@echo "==> WASM binary size and section breakdown"
	@test -f Web/shelltalk.wasm || (echo "Web/shelltalk.wasm not found — run 'make wasm' first"; exit 1)
	@ls -lh Web/shelltalk.wasm
	@echo ""
	@echo "==> Section sizes (wasm-objdump -h, sorted by size)"
	@command -v wasm-objdump >/dev/null 2>&1 || (echo "wasm-objdump not installed — brew install wabt"; exit 1)
	@wasm-objdump -h Web/shelltalk.wasm | awk '/size:/ {print}' | sort -t= -k2 -h -r | head -15 || wasm-objdump -h Web/shelltalk.wasm | head -30

bench-all: bench-linux bench-linux-size bench-wasm-size
	@echo ""
	@echo "==> Side-by-side vs macOS baseline (if /tmp/bench-binaries/stm-eval.v111 exists)"
	@test -x /tmp/bench-binaries/stm-eval.v111 && \
	  (echo "Running macOS stm-eval (v1.1.1 baseline) for comparison..." && \
	   /tmp/bench-binaries/stm-eval.v111 --quiet --metrics-out /tmp/shelltalk-bench/macos-baseline.json && \
	   python3 -c 'import json; \
	m=json.load(open("/tmp/shelltalk-bench/macos-baseline.json")); \
	l=json.load(open("/tmp/shelltalk-bench/linux-run-1.json")); \
	print("| metric | macOS | Linux | delta |"); print("|---|---:|---:|---:|"); \
	[print(f"| {k} | {m[k]:.3f} | {l[k]:.3f} | {l[k]-m[k]:+.3f} |" if k.endswith("_acc") \
	       else f"| {k} | {m[k]:.1f} | {l[k]:.1f} | {l[k]-m[k]:+.1f} |") \
	 for k in ["tpl_acc","cat_acc","mean_ms","p50_ms","p90_ms","p99_ms","wall_ms","init_ms"]]') \
	|| echo "(skip: /tmp/bench-binaries/stm-eval.v111 not present)"
