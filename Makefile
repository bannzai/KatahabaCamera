XCODEPROJ := KatahabaCamera.xcodeproj
SCHEME := KatahabaCamera
CONFIGURATION := Debug
DERIVED_DATA := tmp/DerivedData
APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)-iphonesimulator/KatahabaCamera.app
BUNDLE_ID := com.bannzai.KatahabaCamera
SIMULATOR_UDID ?= $(shell SCRIPT_QUIET=1 sim-boot | sed -n 's/^DEVICE_UDID=//p' | tail -n 1)

.PHONY: build-ios

# Simulator 向けビルド。generic destination なら simulator の起動なしでビルドできる
build-ios:
	xcodebuild -project $(XCODEPROJ) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

# 引数なしの make で ios を実行する (人が手で動作確認するための入口。検査・テストは CI が行う)
.DEFAULT_GOAL := ios

.PHONY: verify
verify:
	xcodebuild build -project KatahabaCamera.xcodeproj -scheme KatahabaCamera -destination "generic/platform=iOS Simulator" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO

.PHONY: ios
ios: build-ios
	@set -e; \
	simulator_udid="$(SIMULATOR_UDID)"; \
	[ -n "$$simulator_udid" ] || { echo "Error: sim-boot でSimulatorを解決できません (sim-bootがPATHにあるか確認するか、SIMULATOR_UDID=<UDID>を指定してください)" >&2; exit 1; }; \
	xcrun simctl install "$$simulator_udid" $(APP); \
	xcrun simctl launch "$$simulator_udid" $(BUNDLE_ID)
