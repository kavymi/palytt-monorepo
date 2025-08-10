#!/bin/bash

# App Icon Generator Script for Palytt
# This script generates all required app icon sizes from the source logo

set -e

echo "🎨 Generating App Icons for Palytt..."

# Source logo path
SOURCE_LOGO="Sources/PalyttApp/Resources/Assets.xcassets/palytt-logo.imageset/palytt-logo.png"
OUTPUT_DIR="Sources/PalyttApp/Resources/Assets.xcassets/AppIcon.appiconset"

# Check if source logo exists
if [ ! -f "$SOURCE_LOGO" ]; then
    echo "❌ Error: Source logo not found at $SOURCE_LOGO"
    exit 1
fi

echo "📁 Source logo: $SOURCE_LOGO"
echo "📁 Output directory: $OUTPUT_DIR"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to generate icon
generate_icon() {
    local size=$1
    local filename=$2
    echo "  → Generating ${filename} (${size}x${size})"
    sips -Z "$size" "$SOURCE_LOGO" --out "$OUTPUT_DIR/$filename" > /dev/null 2>&1
}

echo ""
echo "🔄 Generating iPhone Icons..."

# iPhone Icons
generate_icon 40 "app-icon-20x20@2x.png"        # 20pt @2x
generate_icon 60 "app-icon-20x20@3x.png"        # 20pt @3x
generate_icon 58 "app-icon-29x29@2x.png"        # 29pt @2x (Settings)
generate_icon 87 "app-icon-29x29@3x.png"        # 29pt @3x (Settings)
generate_icon 80 "app-icon-40x40@2x.png"        # 40pt @2x (Spotlight)
generate_icon 120 "app-icon-40x40@3x.png"       # 40pt @3x (Spotlight)
generate_icon 120 "app-icon-60x60@2x.png"       # 60pt @2x (App)
generate_icon 180 "app-icon-60x60@3x.png"       # 60pt @3x (App)

echo "🔄 Generating iPad Icons..."

# iPad Icons
generate_icon 20 "app-icon-20x20@1x.png"        # 20pt @1x
generate_icon 29 "app-icon-29x29@1x.png"        # 29pt @1x (Settings)
generate_icon 40 "app-icon-40x40@1x.png"        # 40pt @1x (Spotlight)
generate_icon 76 "app-icon-76x76@1x.png"        # 76pt @1x (App)
generate_icon 152 "app-icon-76x76@2x.png"       # 76pt @2x (App)
generate_icon 167 "app-icon-83.5x83.5@2x.png"   # 83.5pt @2x (App on iPad Pro)

echo "🔄 Generating App Store Icon..."

# App Store Marketing Icon
generate_icon 1024 "app-icon-1024x1024.png"     # 1024pt @1x (App Store)

echo ""
echo "✅ All app icons generated successfully!"
echo ""
echo "📋 Generated the following files:"
ls -la "$OUTPUT_DIR"/*.png 2>/dev/null | awk '{print "   " $9 " (" $5 " bytes)"}' || echo "   No PNG files found"

echo ""
echo "🎯 Next steps:"
echo "   1. Open Xcode and verify all icons appear correctly"
echo "   2. Build and test on device/simulator"
echo "   3. Check that icons display properly on home screen"
echo ""
echo "💡 Tips:"
echo "   • App icons should be square and without rounded corners"
echo "   • iOS will automatically apply the rounded corner mask"
echo "   • Test on both light and dark backgrounds"
echo "   • Ensure the icon is recognizable at small sizes" 