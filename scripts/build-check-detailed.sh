#!/bin/bash

# Detailed build check script for KatahabaCamera
# This script performs comprehensive build verification with detailed output

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="KatahabaCamera"
PROJECT_FILE="KatahabaCamera.xcodeproj"
SCHEME="KatahabaCamera"

echo "🔨 Starting detailed build check for $PROJECT_NAME..."
echo "📱 iOS Deployment Target: 18.0"
echo ""

# Change to project directory
cd "$(dirname "$0")/.."

# Function to build for a specific destination
build_for_destination() {
    local destination="$1"
    local description="$2"
    
    echo -e "${BLUE}📱 Building for $description...${NC}"
    
    # Create temporary file for build output
    local BUILD_OUTPUT=$(mktemp)
    local BUILD_ERRORS=$(mktemp)
    
    # Clean
    xcodebuild clean \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -destination "$destination" \
        > /dev/null 2>&1
    
    # Build with detailed output
    if xcodebuild build \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -destination "$destination" \
        -configuration Debug \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        -quiet \
        2>&1 | tee "$BUILD_OUTPUT" | grep -E "(error:|warning:|note:)" > "$BUILD_ERRORS" || true; then
        
        # Check if there were any errors
        if grep -q "error:" "$BUILD_ERRORS"; then
            echo -e "${RED}❌ Build failed for $description${NC}"
            echo -e "${RED}Errors found:${NC}"
            grep "error:" "$BUILD_ERRORS" | head -10
            rm "$BUILD_OUTPUT" "$BUILD_ERRORS"
            return 1
        else
            # Check for warnings
            local warning_count=$(grep -c "warning:" "$BUILD_ERRORS" || echo "0")
            if [ "$warning_count" -gt 0 ]; then
                echo -e "${YELLOW}⚠️  Build succeeded with $warning_count warnings for $description${NC}"
            else
                echo -e "${GREEN}✅ Build succeeded for $description${NC}"
            fi
            rm "$BUILD_OUTPUT" "$BUILD_ERRORS"
            return 0
        fi
    else
        echo -e "${RED}❌ Build command failed for $description${NC}"
        if [ -f "$BUILD_ERRORS" ] && [ -s "$BUILD_ERRORS" ]; then
            echo -e "${RED}Errors:${NC}"
            cat "$BUILD_ERRORS" | head -20
        fi
        rm "$BUILD_OUTPUT" "$BUILD_ERRORS"
        return 1
    fi
}

# Test multiple destinations
echo "🧪 Testing builds for multiple devices..."
echo ""

DESTINATIONS=(
    "platform=iOS Simulator,name=iPhone 15 Pro,OS=18.0"
    "platform=iOS Simulator,name=iPhone 15,OS=18.0"
    "platform=iOS Simulator,name=iPad Pro (13-inch) (M4),OS=18.0"
)

DESCRIPTIONS=(
    "iPhone 15 Pro (iOS 18.0)"
    "iPhone 15 (iOS 18.0)"
    "iPad Pro 13-inch (iOS 18.0)"
)

BUILD_FAILED=0

# Build for each destination
for i in "${!DESTINATIONS[@]}"; do
    if ! build_for_destination "${DESTINATIONS[$i]}" "${DESCRIPTIONS[$i]}"; then
        BUILD_FAILED=1
    fi
    echo ""
done

# Summary
echo "📊 Build Summary:"
if [ $BUILD_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All builds succeeded!${NC}"
    
    # Additional checks
    echo ""
    echo "🔍 Additional checks:"
    
    # Check for required files
    echo -n "  - Info.plist: "
    if [ -f "KatahabaCamera/Info.plist" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
    
    # Check for camera usage description
    echo -n "  - Camera permission: "
    if grep -q "NSCameraUsageDescription" "KatahabaCamera/Info.plist"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
    
    # Check for photo library permission
    echo -n "  - Photo library permission: "
    if grep -q "NSPhotoLibraryUsageDescription" "KatahabaCamera/Info.plist"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
    
    exit 0
else
    echo -e "${RED}❌ Some builds failed!${NC}"
    echo -e "${YELLOW}Please check the errors above and fix them before proceeding.${NC}"
    exit 1
fi