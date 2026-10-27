APP          := EMLViewer
BUNDLE       := dist/$(APP).app
INSTALL_PATH := /Applications/$(APP).app
RELEASE_ZIP  := dist/$(APP).app.zip
TEST_FILE    ?= test.eml
LSREG        := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
VERSION       = $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

.PHONY: all build release debug run run-debug bundle install uninstall clean check test test-xcode cli icon zip print-version lint lint-strict

all: bundle

# -----------------------------------------------------------------------------
# Build (Xcode → dist/)
# -----------------------------------------------------------------------------

# Debug build → dist/EMLViewer.app
debug:
	bash Scripts/build.sh debug

# Release build → dist/EMLViewer.app
release:
	bash Scripts/build.sh release

# Alias
build: release

# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------

# Build + restart (debug by default)
run:
	bash Scripts/build.sh debug --open

run-release:
	bash Scripts/build.sh release --open

# Run the CLI parser on a sample (SPM — emlcheck стоит отдельно от .app)
cli:
	swift build -c release --product emlcheck
	.build/release/emlcheck "$(TEST_FILE)"

# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------

test:
	swift test

# Full Xcode test run (runs the same XCTest suite through xcodebuild)
test-xcode:
	xcodebuild -project EMLViewer.xcodeproj -scheme EMLViewer -configuration Debug -destination 'platform=macOS,arch=arm64' test

# -----------------------------------------------------------------------------
# Lint
# -----------------------------------------------------------------------------

lint:
	@if ! command -v swiftlint >/dev/null; then \
	    echo "error: swiftlint not installed (brew install swiftlint)" >&2; exit 1; \
	fi
	swiftlint lint --quiet

# Strict mode: any violation (warning or error) fails the run
lint-strict:
	@if ! command -v swiftlint >/dev/null; then \
	    echo "error: swiftlint not installed (brew install swiftlint)" >&2; exit 1; \
	fi
	swiftlint lint --quiet --strict

# -----------------------------------------------------------------------------
# Icon
# -----------------------------------------------------------------------------

icon:
	bash Scripts/make-icon.sh

# -----------------------------------------------------------------------------
# Release packaging
# -----------------------------------------------------------------------------

bundle:
	bash Scripts/build.sh release --developer-id

dmg: bundle
	bash Scripts/distribute-developer-id.sh

zip: bundle
	rm -f "$(RELEASE_ZIP)"
	cd dist && zip -qry "$(APP).app.zip" "$(APP).app"
	@echo "Built: $(RELEASE_ZIP)"
	@shasum -a 256 "$(RELEASE_ZIP)"

preflight: test zip
	@echo ""
	@echo "==> Pre-flight complete for v$(VERSION)"
	@echo "    Asset:   $(RELEASE_ZIP)"
	@echo "    Next:    bash Scripts/distribute-developer-id.sh"

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
	rm -rf .build dist build
