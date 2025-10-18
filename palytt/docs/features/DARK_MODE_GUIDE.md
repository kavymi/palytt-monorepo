# Dark Mode & Theme System Guide

## Overview

Palytt now supports a comprehensive dark mode with a flexible theme system that allows users to choose between Light, Dark, and System themes. The implementation maintains the app's signature matcha green branding while providing excellent readability and visual appeal in all lighting conditions.

## Theme Management

### ThemeManager Class

The `ThemeManager` class handles all theme-related operations:

```swift
@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: Theme = .system
    
    enum Theme: String, CaseIterable {
        case light = "light"
        case dark = "dark" 
        case system = "system"
    }
}
```

### Features:
- **Persistent Storage**: Theme preferences are saved to UserDefaults
- **System Integration**: Automatically follows system appearance when set to system mode
- **Reactive Updates**: Uses `@Published` for automatic UI updates
- **Smooth Transitions**: Supports animated theme changes

## Color System

### Semantic Colors

The app uses semantic color names that automatically adapt to the current theme:

- `Color.primaryText` - Main text color
- `Color.secondaryText` - Secondary text color  
- `Color.tertiaryText` - Tertiary text color
- `Color.background` - Main background color
- `Color.cardBackground` - Card/surface background color
- `Color.divider` - Separator lines and borders
- `Color.surface` - Alternative surface color
- `Color.overlay` - Overlay effects

### Brand Colors (Consistent)

These colors remain consistent across themes:
- `Color.primaryBrand` - Light blue (#b2d7e8)
- `Color.matchaGreen` - Primary brand color (now light blue)
- `Color.milkTea` - Accent color (#e3c4a8)
- `Color.success` - Success green
- `Color.warning` - Warning orange
- `Color.error` - Error red

### Asset Catalog Integration

Colors are defined in the Asset Catalog with both light and dark variants:

```
Assets.xcassets/
├── Background.colorset/
├── CardBackground.colorset/
├── PrimaryText.colorset/
├── SecondaryText.colorset/
├── TertiaryText.colorset/
├── Divider.colorset/
├── Surface.colorset/
└── Overlay.colorset/
```

## Theme Components

### 1. ThemeSelectorGrid
Visual grid-based selector perfect for settings pages:
```swift
ThemeSelectorGrid(themeManager: themeManager)
```

### 2. InlineThemeToggle
Compact horizontal toggle for quick access:
```swift
InlineThemeToggle(themeManager: themeManager)
```

### 3. ToolbarThemeToggle
Simple button for navigation bars:
```swift
ToolbarThemeToggle(themeManager: appState.themeManager)
```

### 4. QuickThemeToggle
Animated floating button:
```swift
QuickThemeToggle(themeManager: themeManager)
```

### 5. ThemeStatusIndicator
Shows current theme status:
```swift
ThemeStatusIndicator(themeManager: themeManager)
```

## Implementation Details

### App Integration

1. **AppState Update**:
```swift
final class AppState: ObservableObject {
    let themeManager = ThemeManager()
    // ...
}
```

2. **Root View Setup**:
```swift
RootView()
    .environmentObject(appState)
    .environmentObject(appState.themeManager)
    .preferredColorScheme(appState.themeManager.colorScheme)
```

### Settings Integration

The Settings view includes multiple theme controls:
- Full theme selector grid in the Appearance section
- Quick theme status indicator and inline toggle
- Comprehensive preview of each theme option

### Quick Access

- **Home View**: Toolbar theme toggle button
- **Settings**: Multiple theme control options
- **Profile**: Theme status and controls

## Dark Mode Color Palette

### Dark Theme Colors:
- **Background**: `#1a1a1a` - Deep dark gray
- **Card Background**: `#2d2d2d` - Medium dark gray  
- **Surface**: `#333333` - Lighter dark gray
- **Primary Text**: `#ffffff` - Pure white
- **Secondary Text**: `#b3b3b3` - Light gray
- **Tertiary Text**: `#808080` - Medium gray
- **Divider**: `#404040` - Dark border gray
- **Overlay**: White with 5% opacity

### Light Theme Colors:
- **Background**: `#fbf4e6` - Rice background (warm cream)
- **Card Background**: `#ffffff` - Pure white
- **Surface**: `#ffffff` - Pure white
- **Primary Text**: `#3b2b2b` - Coffee dark
- **Secondary Text**: `#6B7280` - Medium gray
- **Tertiary Text**: `#9CA3AF` - Light gray
- **Divider**: `#E5E7EB` - Light border gray
- **Overlay**: Black with 5% opacity

## Usage Guidelines

### For Developers

1. **Always use semantic colors**:
   ```swift
   // ✅ Good
   .foregroundColor(.primaryText)
   
   // ❌ Avoid
   .foregroundColor(.black)
   ```

2. **Environment object access**:
   ```swift
   @EnvironmentObject var themeManager: ThemeManager
   ```

3. **Animated theme changes**:
   ```swift
   withAnimation(.easeInOut(duration: 0.3)) {
       themeManager.setTheme(.dark)
   }
   ```

### For Users

1. **Access theme settings**:
   - Profile → Settings → Appearance section
   - Quick toggle in Home view toolbar
   - Theme controls throughout the settings

2. **Theme options**:
   - **Light**: Always use light appearance
   - **Dark**: Always use dark appearance  
   - **System**: Follow device system setting

3. **Instant switching**: All theme changes take effect immediately with smooth animations

## Testing

### Preview Support

All components include both light and dark previews:

```swift
#Preview("Component - Light") {
    Component()
        .preferredColorScheme(.light)
}

#Preview("Component - Dark") {
    Component()
        .preferredColorScheme(.dark)
}
```

### Manual Testing

1. Test all three theme modes (Light, Dark, System)
2. Verify theme persistence across app launches
3. Check smooth transitions between themes
4. Ensure all text remains readable in both modes
5. Verify brand colors remain consistent

## Future Enhancements

Potential future improvements:
- Custom theme colors
- High contrast mode support
- Theme scheduling (automatic switching based on time)
- Additional accent color options
- Per-view theme overrides

## Troubleshooting

### Common Issues

1. **Colors not updating**: Ensure views use semantic colors from the color system
2. **Theme not persisting**: Verify ThemeManager is properly initialized
3. **Jarring transitions**: Use animation blocks for theme changes
4. **Inconsistent branding**: Check that brand colors are used consistently

### Debug Tips

- Use Theme Status Indicator to verify current theme
- Check console logs for theme change events  
- Verify Asset Catalog color definitions
- Test on both simulator and device 