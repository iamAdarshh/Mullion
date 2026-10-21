# Mullion developer commands. See docs/SETUP.md.
.DEFAULT_GOAL := build
.PHONY: bootstrap build test test-core test-app build-for-testing test-without-building run lint format clean archive dmg

PROJECT      := Mullion.xcodeproj
SCHEME       := Mullion
CORE_PKG     := Packages/MullionCore
DERIVED_DATA := build/DerivedData
DESTINATION  := platform=macOS
DEBUG_APP    := $(DERIVED_DATA)/Build/Products/Debug/Mullion-Debug.app

# Release artefacts (docs/RELEASING.md).
ARCHIVE      := build/Mullion.xcarchive
RELEASE_APP  := build/Mullion.app
DMG_STAGING  := build/dmg
MARKETING_VERSION := $(shell sed -n 's/^MARKETING_VERSION *= *//p' Config/Base.xcconfig)
# The DMG is named after the release tag, which may carry a -beta.N suffix that the bundle's
# CFBundleShortVersionString can't: make dmg RELEASE_VERSION=0.1.0-beta.1
RELEASE_VERSION ?= $(MARKETING_VERSION)
DMG          := build/Mullion-$(RELEASE_VERSION).dmg

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

build-for-testing: bootstrap ## Build the app tests to run on another Mac (CI: older macOS)
	$(XCODEBUILD) -configuration Debug build-for-testing

test-without-building: ## Run tests from build-for-testing: make test-without-building XCTESTRUN=path
	xcodebuild test-without-building -xctestrun '$(XCTESTRUN)' -destination '$(DESTINATION)'

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

archive: bootstrap ## Release build (universal, Hardened Runtime) at build/Mullion.app
	rm -rf $(ARCHIVE) $(RELEASE_APP)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'generic/platform=macOS' \
		-derivedDataPath $(DERIVED_DATA) -configuration Release archive -archivePath $(ARCHIVE)
	ditto $(ARCHIVE)/Products/Applications/Mullion.app $(RELEASE_APP)
	codesign --verify --strict --verbose=2 $(RELEASE_APP)

dmg: ## Disk image of build/Mullion.app with an Applications link; prints its SHA-256
	@test -d $(RELEASE_APP) || { echo "$(RELEASE_APP) not found: run make archive first"; exit 1; }
	rm -rf $(DMG_STAGING) $(DMG)
	mkdir -p $(DMG_STAGING)
	ditto $(RELEASE_APP) $(DMG_STAGING)/Mullion.app
	ln -s /Applications $(DMG_STAGING)/Applications
	hdiutil create -volname Mullion -srcfolder $(DMG_STAGING) -fs HFS+ -format UDZO -ov $(DMG)
	rm -rf $(DMG_STAGING)
	shasum -a 256 $(DMG)

clean: ## Remove build products and the generated project
	rm -rf build $(PROJECT) $(CORE_PKG)/.build
