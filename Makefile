# Makefile — Build and install ShellTalk

PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin

.PHONY: build test install uninstall clean release

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
