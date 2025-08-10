# Logo Assets

Add your Palytt logo files to this directory with the following naming convention:

## Required Files
- `palytt-logo.png` (40x40 points)
- `palytt-logo@2x.png` (80x80 points) 
- `palytt-logo@3x.png` (120x120 points)

## Optional Variations
- `palytt-logo-light.png` (for dark backgrounds)
- `palytt-logo-dark.png` (for light backgrounds)
- `palytt-logo-icon.png` (simplified icon version)

## Format Requirements
- **File Format**: PNG with transparency
- **Color Mode**: RGBA
- **Background**: Transparent
- **Style**: Should work well on the app's rice background color (#fbf4e6)

## Usage in Code
Once added, reference the logo in SwiftUI views using:
```swift
Image("palytt-logo")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 120, height: 120)
```

## Current Usage Locations
- `AuthenticationView.swift` - Main branding logo
- Potential future locations: HomeView navigation, TabBar, Loading screens 