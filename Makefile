APP          := EMLViewer
BUNDLE       := dist/$(APP).app
INSTALL_PATH := /Applications/$(APP).app
LSREG        := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: all build bundle install uninstall clean

all: bundle

build:
	swift build -c release

bundle:
	bash Scripts/make-app.sh release

install: bundle
	rm -rf "$(INSTALL_PATH)"
	cp -R "$(BUNDLE)" "$(INSTALL_PATH)"
	touch "$(INSTALL_PATH)"
	@if [ -x "$(LSREG)" ]; then "$(LSREG)" -f "$(INSTALL_PATH)" >/dev/null 2>&1 || true; fi
	@echo "Installed: $(INSTALL_PATH)"

uninstall:
	rm -rf "$(INSTALL_PATH)"

clean:
	rm -rf .build dist
