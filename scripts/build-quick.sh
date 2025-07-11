#!/bin/bash

# Quick build syntax check for KatahabaCamera
# This script performs a fast compilation check without full build

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🔍 Quick build check for KatahabaCamera..."

# Change to project directory
cd "$(dirname "$0")/.."

# Perform syntax check only (faster than full build)
echo "📝 Checking code syntax..."

if xcodebuild \
    -project KatahabaCamera.xcodeproj \
    -scheme KatahabaCamera \
    -destination 'generic/platform=iOS Simulator' \
    -dry-run \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    > /dev/null 2>&1; then
    
    echo -e "${GREEN}✅ Syntax check passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Syntax check failed!${NC}"
    exit 1
fi