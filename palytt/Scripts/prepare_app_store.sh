#!/bin/bash

# Palytt App Store Preparation Script
# This script prepares the app for App Store submission

set -e # Exit on any error

echo "🚀 Palytt App Store Preparation Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    print_error "Please run this script from the palytt project root directory"
    exit 1
fi

print_info "Starting App Store preparation process..."

# Step 1: Check prerequisites
echo ""
echo "Step 1: Checking Prerequisites"
echo "-----------------------------"

# Check if Fastlane is installed
if command -v fastlane &> /dev/null; then
    print_status "Fastlane is installed"
else
    print_error "Fastlane is not installed. Please install it first: gem install fastlane"
    exit 1
fi

# Check if Xcode command line tools are available
if command -v xcodebuild &> /dev/null; then
    print_status "Xcode command line tools available"
else
    print_error "Xcode command line tools not found"
    exit 1
fi

# Step 2: Clean environment
echo ""
echo "Step 2: Cleaning Environment"
echo "---------------------------"
print_info "Cleaning derived data and build artifacts..."
fastlane clean
print_status "Environment cleaned"

# Step 3: Run App Store requirements check
echo ""
echo "Step 3: Checking App Store Requirements"
echo "-------------------------------------"
fastlane check_app_store_requirements

# Step 4: Check for common issues
echo ""
echo "Step 4: Pre-submission Validation"
echo "--------------------------------"

# Check for simulator builds
if grep -r "iphonesimulator" build/ 2>/dev/null; then
    print_warning "Found simulator artifacts in build directory"
fi

# Check bundle identifier
BUNDLE_ID=$(grep -A1 "PRODUCT_BUNDLE_IDENTIFIER" Palytt.xcodeproj/project.pbxproj | grep "buildSettings" -A 20 | grep "PRODUCT_BUNDLE_IDENTIFIER" | head -1 | cut -d'"' -f2)
if [ -z "$BUNDLE_ID" ]; then
    print_warning "Could not determine bundle identifier"
else
    print_status "Bundle ID: $BUNDLE_ID"
fi

# Step 5: Backend health check
echo ""
echo "Step 5: Backend Health Check"
echo "---------------------------"
print_info "Checking backend connectivity..."

# Check if backend is running
cd ../palytt-backend
if pnpm run health-check 2>/dev/null; then
    print_status "Backend is healthy"
else
    print_warning "Backend health check failed - ensure production backend is ready"
fi
cd ../palytt

# Step 6: Run tests
echo ""
echo "Step 6: Running Test Suite"
echo "-------------------------"
print_info "Running comprehensive tests..."

if fastlane test_all; then
    print_status "All tests passed"
else
    print_error "Some tests failed. Please fix before proceeding with App Store submission."
    exit 1
fi

# Step 7: Build preparation
echo ""
echo "Step 7: Preparing Release Build"
echo "------------------------------"

# Ask for version information
echo ""
read -p "Enter version number (or press Enter to keep current): " VERSION
read -p "Enter build number (or press Enter for auto-increment): " BUILD_NUMBER

if [ ! -z "$VERSION" ]; then
    export VERSION=$VERSION
fi

if [ ! -z "$BUILD_NUMBER" ]; then
    export BUILD_NUMBER=$BUILD_NUMBER
fi

# Setup release configuration
fastlane setup_release

# Step 8: Create App Store build
echo ""
echo "Step 8: Creating App Store Build"
echo "-------------------------------"
print_info "Building for App Store distribution..."

if fastlane prepare_app_store; then
    print_status "App Store build created successfully"
else
    print_error "Failed to create App Store build"
    exit 1
fi

# Step 9: Final validation
echo ""
echo "Step 9: Final Validation"
echo "----------------------"

IPA_PATH="./build/Palytt.ipa"
if [ -f "$IPA_PATH" ]; then
    IPA_SIZE=$(du -h "$IPA_PATH" | cut -f1)
    print_status "IPA created: $IPA_PATH ($IPA_SIZE)"
else
    print_error "IPA file not found at expected location"
    exit 1
fi

# Step 10: Summary and next steps
echo ""
echo "🎉 App Store Preparation Complete!"
echo "================================="
echo ""
echo "Your Palytt app is ready for App Store submission!"
echo ""
echo "📦 Build Location: $IPA_PATH"
echo "📱 Size: $IPA_SIZE"
echo ""
echo "Next Steps:"
echo "----------"
echo "1. 📋 Review the preparation guide: docs/APP_STORE_SUBMISSION_PREPARATION.md"
echo "2. 🖼️  Create screenshots using the App Store guidelines"
echo "3. 📝 Prepare App Store Connect metadata"
echo "4. 🧪 Upload to TestFlight for internal testing:"
echo "   fastlane deploy_testflight"
echo "5. 🚀 When ready, submit to App Store:"
echo "   fastlane deploy_app_store"
echo ""
echo "⚠️  Important Reminders:"
echo "• Ensure privacy policy is ready and accessible"
echo "• Test on multiple devices and iOS versions"
echo "• Remove any development/debug configurations"
echo "• Verify all app permissions are justified"
echo ""
echo "Good luck with your App Store submission! 🚀"
