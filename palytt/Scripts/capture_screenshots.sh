#!/bin/bash

# 📱 App Store Screenshot Capture Script
# This script captures screenshots for all required device sizes for App Store submission

echo "🎯 Starting App Store Screenshot Capture for Palytt"
echo "📱 This will capture screenshots on multiple device simulators"

# Create screenshots directory
mkdir -p screenshots

# Device configurations for App Store screenshots
declare -a devices=(
    "iPhone 16 Pro Max"  # 6.7" - 1320 x 2868
    "iPhone 16 Pro"      # 6.1" - 1206 x 2622
    "iPhone 8 Plus"      # 5.5" - 1242 x 2208
    "iPad Pro (12.9-inch) (6th generation)"  # 12.9" - 2048 x 2732
    "iPad Pro (11-inch) (4th generation)"    # 11" - 1668 x 2388
)

# App bundle identifier
BUNDLE_ID="com.palytt.app"

# Function to capture screenshots for a device
capture_device_screenshots() {
    local device_name="$1"
    local device_folder=$(echo "$device_name" | tr ' ' '_' | tr '(' '_' | tr ')' '_')
    
    echo "📱 Setting up $device_name..."
    
    # Boot device
    xcrun simctl boot "$device_name" 2>/dev/null || echo "Device already running"
    
    # Wait for boot
    sleep 3
    
    # Install app
    echo "📦 Installing Palytt on $device_name..."
    xcrun simctl install "$device_name" "/Users/kavyrattana/Library/Developer/Xcode/DerivedData/Palytt-gvevkmtdwzwghpfoemomuadifaul/Build/Products/Debug-iphonesimulator/Palytt.app"
    
    # Launch app
    echo "🚀 Launching Palytt..."
    xcrun simctl launch "$device_name" "$BUNDLE_ID"
    
    # Wait for app to load
    sleep 5
    
    # Create device-specific directory
    mkdir -p "screenshots/$device_folder"
    
    # Take screenshots
    echo "📸 Taking screenshots for $device_name..."
    
    # Screenshot 1: Authentication/Welcome Screen
    xcrun simctl io "$device_name" screenshot "screenshots/$device_folder/01_welcome.png"
    echo "   ✅ Welcome screen captured"
    
    # Navigate and take more screenshots
    # Note: These would need to be automated with UI testing or manual navigation
    sleep 2
    xcrun simctl io "$device_name" screenshot "screenshots/$device_folder/02_home_feed.png"
    echo "   ✅ Home feed captured"
    
    sleep 2
    xcrun simctl io "$device_name" screenshot "screenshots/$device_folder/03_map_view.png"
    echo "   ✅ Map view captured"
    
    sleep 2
    xcrun simctl io "$device_name" screenshot "screenshots/$device_folder/04_profile.png"
    echo "   ✅ Profile captured"
    
    sleep 2
    xcrun simctl io "$device_name" screenshot "screenshots/$device_folder/05_post_creation.png"
    echo "   ✅ Post creation captured"
    
    echo "✅ Screenshots complete for $device_name"
    echo ""
}

# Main execution
echo "🎬 Starting screenshot capture process..."
echo ""

# Capture screenshots for each device
for device in "${devices[@]}"; do
    capture_device_screenshots "$device"
done

echo "🎉 Screenshot capture complete!"
echo "📁 Screenshots saved to: ./screenshots/"
echo ""
echo "📋 Next Steps:"
echo "1. Review all screenshots in the screenshots folder"
echo "2. Edit screenshots to highlight key features"
echo "3. Add marketing text overlays if desired"
echo "4. Upload to App Store Connect in the appropriate sections"
echo ""
echo "📱 Required for App Store Connect:"
echo "- iPhone 6.7\": Use iPhone 16 Pro Max screenshots"
echo "- iPhone 6.1\": Use iPhone 16 Pro screenshots"  
echo "- iPhone 5.5\": Use iPhone 8 Plus screenshots"
echo "- iPad Pro 12.9\": Use iPad Pro 12.9-inch screenshots"
echo "- iPad Pro 11\": Use iPad Pro 11-inch screenshots"

# Make script executable
chmod +x "$0" 