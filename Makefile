# HeyNav — common tasks. Run `make` to list them.

PROJECT  := HeyNav.xcodeproj
SCHEME   := HeyNav
DEST     := platform=macOS
APP      := $(shell xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $$2}' | head -1)/HeyNav.app

.DEFAULT_GOAL := help
.PHONY: help build run test release dmg clean

help: ## Show this help
	@grep -E '^[a-z]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "} {printf "  \033[1m%-9s\033[0m %s\n", $$1, $$2}'

build: ## Build (Debug)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination '$(DEST)' build

test: ## Run the test suite
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' test

run: ## Build and launch the app
	@pkill -x HeyNav 2>/dev/null || true
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination '$(DEST)' build | tail -1
	@open "$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $$2}' | head -1)/HeyNav.app"
	@echo "HeyNav launched — look in the menu bar."

release: ## Build Release and zip it into dist/
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination '$(DEST)' build
	@mkdir -p dist
	@rm -f dist/HeyNav.zip
	@ditto -c -k --sequesterRsrc --keepParent "$(APP)" dist/HeyNav.zip
	@echo "→ dist/HeyNav.zip  ($$(du -h dist/HeyNav.zip | cut -f1))"
	@echo "  Attach this to a GitHub Release."

dmg: release ## Build a drag-to-Applications disk image
	@rm -rf dist/stage dist/HeyNav.dmg
	@mkdir -p dist/stage
	@ditto -x -k dist/HeyNav.zip dist/stage
	@ln -s /Applications dist/stage/Applications
	@hdiutil create -volname HeyNav -srcfolder dist/stage -ov -format UDZO -quiet dist/HeyNav.dmg
	@rm -rf dist/stage
	@echo "→ dist/HeyNav.dmg  ($$(du -h dist/HeyNav.dmg | cut -f1))"

clean: ## Remove build output and dist/
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	@rm -rf dist
