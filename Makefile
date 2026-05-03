.PHONY: build run clean install uninstall

APP_NAME = Claude Usage
BUNDLE_ID = com.claudeusage.app
BUILD_DIR = .build/release
APP_DIR = $(APP_NAME).app

build:
	swift build -c release

run: build
	$(BUILD_DIR)/ClaudeUsage

app: build
	@echo "Creating app bundle..."
	@rm -rf "$(APP_DIR)"
	@mkdir -p "$(APP_DIR)/Contents/MacOS"
	@mkdir -p "$(APP_DIR)/Contents/Resources"
	@cp $(BUILD_DIR)/ClaudeUsage "$(APP_DIR)/Contents/MacOS/"
	@cp Info.plist "$(APP_DIR)/Contents/"
	@echo "APPL????" > "$(APP_DIR)/Contents/PkgInfo"
	@echo "Built $(APP_DIR)"

install: app
	@cp -R "$(APP_DIR)" /Applications/
	@echo "Installed to /Applications/$(APP_DIR)"

uninstall:
	@rm -rf "/Applications/$(APP_DIR)"
	@rm -f "$(HOME)/Library/LaunchAgents/$(BUNDLE_ID).plist"
	@echo "Uninstalled $(APP_DIR) and removed LaunchAgent"

clean:
	swift package clean
	rm -rf "$(APP_DIR)"
	rm -rf .build
