# Mullion developer commands. See docs/SETUP.md.
.DEFAULT_GOAL := build
.PHONY: bootstrap build test test-core test-app run lint format clean

PROJECT      := Mullion.xcodeproj
SCHEME       := Mullion
CORE_PKG     := Packages/MullionCore
DERIVED_DATA := build/DerivedData
DESTINATION  := platform=macOS
DEBUG_APP    := $(DERIVED_DATA)/Build/Products/Debug/Mullion-Debug.app

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' \
	-derivedDataPath $(DERIVED_DATA)

# With only the Command Line Tools selected (no Xcode), SwiftPM does not find Swift Testing on its
# own. Point it at the copy that ships with the CLT. With Xcode selected this is a no-op.
CLT_DEV := /Library/Developer/CommandLineTools/Library/Developer
ifeq ($(shell xcode-select -p 2>/dev/null),/Library/Developer/CommandLineTools)
SWIFT_TEST_FLAGS := -Xswiftc -F -Xswiftc $(CLT_DEV)/Frameworks \
	-Xlinker -F -Xlinker $(CLT_DEV)/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT_DEV)/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT_DEV)/usr/lib
endif

bootstrap: ## Generate Mullion.xcodeproj from project.yml
	@command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen"; exit 1; }
	xcodegen generate

build: bootstrap ## Debug build of the app
	$(XCODEBUILD) -configuration Debug build

test: test-core test-app ## Core + app tests

test-core: ## Fast: swift test on MullionCore
	swift test --package-path $(CORE_PKG) $(SWIFT_TEST_FLAGS)

test-app: bootstrap ## App tests (Swift Testing, hosted in the app)
	$(XCODEBUILD) -configuration Debug test

run: build ## Build and launch Mullion-Debug.app
	open "$(DEBUG_APP)"

lint: ## SwiftLint + SwiftFormat check (CI fails on any warning)
	@command -v swiftlint >/dev/null || { echo "swiftlint not found: brew install swiftlint"; exit 1; }
	@command -v swiftformat >/dev/null || { echo "swiftformat not found: brew install swiftformat"; exit 1; }
	swiftlint lint --strict --quiet
	swiftformat --lint .

format: ## Apply SwiftFormat
	@command -v swiftformat >/dev/null || { echo "swiftformat not found: brew install swiftformat"; exit 1; }
	swiftformat .

clean: ## Remove build products and the generated project
	rm -rf build $(PROJECT) $(CORE_PKG)/.build
