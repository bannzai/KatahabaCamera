#!/bin/bash

# Build check script for KatahabaCamera
# This script verifies that the project builds successfully

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "🔨 Starting build check for KatahabaCamera..."

# Change to project directory
cd "$(dirname "$0")/.."

# Clean build folder
echo "🧹 Cleaning build folder..."
xcodebuild clean \
    -project KatahabaCamera.xcodeproj \
    -scheme KatahabaCamera \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    > /dev/null 2>&1 || {
        echo -e "${RED}❌ Clean failed${NC}"
        exit 1
    }

echo "✨ Clean completed"

# Build project
echo "🏗️  Building project..."
BUILD_OUTPUT=$(mktemp)

if xcodebuild build \
    -project KatahabaCamera.xcodeproj \
    -scheme KatahabaCamera \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    -configuration Debug \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    2>&1 | tee "$BUILD_OUTPUT"; then
    
    echo -e "${GREEN}✅ Build succeeded!${NC}"
    rm "$BUILD_OUTPUT"
    exit 0
else
    echo -e "${RED}❌ Build failed!${NC}"
    echo -e "${YELLOW}Check the output above for error details.${NC}"
    rm "$BUILD_OUTPUT"
    exit 1
fi