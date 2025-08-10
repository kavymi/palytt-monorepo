#!/bin/bash

# 🛡️ Copyright Header Addition Script for Palytt
# This script adds copyright notices to all Swift files in the project

echo "🛡️ Adding copyright headers to all Swift files..."

# Copyright header template
COPYRIGHT_HEADER="//
//  FILENAME
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
"

# Counter for processed files
processed=0
skipped=0

# Function to add copyright header to a file
add_copyright_header() {
    local file="$1"
    local filename=$(basename "$file")
    
    # Check if file already has copyright header
    if head -5 "$file" | grep -q "Copyright © 2025 Palytt Inc"; then
        echo "   ⏭️  Skipping $filename (already has copyright header)"
        ((skipped++))
        return
    fi
    
    # Create header with actual filename
    local header=$(echo "$COPYRIGHT_HEADER" | sed "s/FILENAME/$filename/")
    
    # Create temporary file with header + original content
    local temp_file=$(mktemp)
    echo "$header" > "$temp_file"
    cat "$file" >> "$temp_file"
    
    # Replace original file
    mv "$temp_file" "$file"
    
    echo "   ✅ Added copyright header to $filename"
    ((processed++))
}

# Find and process all Swift files
echo "🔍 Finding Swift files in Sources directory..."

find "Sources" -name "*.swift" -type f | while read -r file; do
    add_copyright_header "$file"
done

echo ""
echo "📊 Summary:"
echo "   ✅ Processed: $processed files"
echo "   ⏭️  Skipped: $skipped files"
echo ""
echo "🛡️ Copyright headers have been added to all Swift files!"
echo ""
echo "📋 Next steps:"
echo "1. Review the changes with: git diff"
echo "2. Commit the copyright headers: git add . && git commit -m 'Add copyright headers for IP protection'"
echo "3. Build and test the app: xcodebuild -scheme Palytt build"
echo ""
echo "⚖️ IP Protection Status: Enhanced with comprehensive copyright notices" 