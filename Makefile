APP          := EMLViewer
BUNDLE       := dist/$(APP).app
INSTALL_PATH := /Applications/$(APP).app
RELEASE_ZIP  := dist/$(APP).app.zip
TEST_FILE    ?= test.eml
LSREG        := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
VERSION       = $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

.PHONY: all build release debug run run-debug bundle install uninstall clean check test cli icon zip print-version

all: bundle

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

# Debug build (all products)
debug:
	swift build

# Release build (all products)
release: release-bin

release-bin:
	swift build -c release

# Alias for release build
build: release-bin

# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------

# Build + assemble .app + restart (debug by default)
run:
	bash Scripts/build.sh debug

run-release:
	bash Scripts/build.sh release

# Run the CLI parser on a sample
cli: release-bin
	.build/release/emlcheck "$(TEST_FILE)"

# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------

test:
	swift test

# -----------------------------------------------------------------------------
# Icon
# -----------------------------------------------------------------------------

icon:
	bash Scripts/make-icon.sh

# -----------------------------------------------------------------------------
# Release packaging
# -----------------------------------------------------------------------------

bundle:
	bash Scripts/make-app.sh release

zip: bundle
	rm -f "$(RELEASE_ZIP)"
	cd dist && zip -qry "$(APP).app.zip" "$(APP).app"
	@echo "Built: $(RELEASE_ZIP)"
	@shasum -a 256 "$(RELEASE_ZIP)"

preflight: test zip
	@echo ""
	@echo "==> Pre-flight complete for v$(VERSION)"
	@echo "    Asset:   $(RELEASE_ZIP)"
	@echo "    Next:    see CLAUDE.md → Releasing"

print-version:
	@echo $(VERSION)

# -----------------------------------------------------------------------------
# Install / uninstall
# -----------------------------------------------------------------------------

install: bundle
	rm -rf "$(INSTALL_PATH)"
	cp -R "$(BUNDLE)" "$(INSTALL_PATH)"
	touch "$(INSTALL_PATH)"
	@if [ -x "$(LSREG)" ]; then "$(LSREG)" -f "$(INSTALL_PATH)" >/dev/null 2>&1 || true; fi
	@echo "Installed: $(INSTALL_PATH)"

uninstall:
	rm -rf "$(INSTALL_PATH)"
	@echo "Removed: $(INSTALL_PATH)"

# -----------------------------------------------------------------------------
# Maintenance
# -----------------------------------------------------------------------------

check:
	swift build 2>&1

clean:
	swift package clean
	rm -rf .build dist
