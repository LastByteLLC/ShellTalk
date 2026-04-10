# Makefile — Build and install ShellTalk

PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin

.PHONY: build test install uninstall clean release wasm wasm-demo eval

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
	swift build --swift-sdk swift-6.3-RELEASE_wasm --product shelltalk-wasm -c release -Xswiftc -Osize
	wasm-opt -Oz --strip-debug --strip-producers .build/wasm32-unknown-wasip1/release/shelltalk-wasm.wasm -o Web/shelltalk.wasm
	@echo "WASM binary: Web/shelltalk.wasm"
	@ls -lh Web/shelltalk.wasm

wasm-demo: wasm
	@echo "Starting web server at http://localhost:8090"
	cd Web && python3 -m http.server 8090
