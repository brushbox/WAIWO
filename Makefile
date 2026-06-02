SCHEME = WAIWO
APP = WAIWO.app
PROJECT = WAIWO.xcodeproj

RELEASE_DIR = $(shell xcodebuild -showBuildSettings -scheme $(SCHEME) -configuration Release 2>/dev/null | grep '^    CONFIGURATION_BUILD_DIR' | awk '{print $$NF}')
DEBUG_DIR   = $(shell xcodebuild -showBuildSettings -scheme $(SCHEME) -configuration Debug   2>/dev/null | grep '^    CONFIGURATION_BUILD_DIR' | awk '{print $$NF}')

.PHONY: all xcodegen build release clean install run test

all: release

xcodegen:
	xcodegen

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug

release:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean

test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug test

install: release
	cp -r "$(RELEASE_DIR)/$(APP)" /Applications/

run: build
	open "$(DEBUG_DIR)/$(APP)"