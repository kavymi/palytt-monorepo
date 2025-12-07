Do's:

- Don't build the app unless I tell you to.
- Use xcode build to build for iOS 18 (iPhone 17 Pro). "xcodebuild -scheme Palytt -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build"

- Update our backend at @palytt-backend folder when building features that required API integration.
- Update typings and enahnce type safety.
- Use tRPC connection for frontend and backend.
- Do not modify the @Package.swift file unless specifically asked to.
- If a new file is created, make sure to add it to @project.pbxproj.
- After building the app successfully, run it on our iPhone 17 Pro device. The simulator is already running.
- For each view, create mock data for Preview Mode so we can Preview the View in Xcode.

**Rerunning the App (IMPORTANT):**
- **If the app is already running on the simulator**, use `mcp_XcodeBuildMCP_build_run_sim` to rerun instead of doing a full rebuild.
- This is much faster as it uses incremental compilation.
- Example usage:
  ```
  mcp_XcodeBuildMCP_build_run_sim({
    projectPath: '/Users/kavyrattana/Coding/palytt-monorepo/palytt/Palytt.xcodeproj',
    scheme: 'Palytt',
    simulatorName: 'iPhone 17 Pro'
  })
  ```
- Do NOT run a full `xcodebuild clean build` when the app is already running - just use the MCP tool to rerun.

## Authentication Pattern (CRITICAL)

**When making authenticated API requests in BackendService:**

✅ **CORRECT - Use `getAuthHeaders()`:**
```swift
let authHeaders = await getAuthHeaders()
guard authHeaders["Authorization"] != nil else {
    throw BackendError.trpcError("User not authenticated", 401)
}
let headers = HTTPHeaders(authHeaders.map { HTTPHeader(name: $0.key, value: $0.value) })
AF.request(urlString, method: .get, headers: headers)
```

❌ **WRONG - Don't directly access Clerk token:**
```swift
// This pattern is unreliable and can silently fail!
guard let token = try? await Clerk.shared.session?.getToken()?.jwt else { ... }
```

**Why this matters:**
- `getAuthHeaders()` uses `AuthProvider.shared.getHeadersWithUserId()` which properly handles:
  - JWT token retrieval from Clerk
  - Token caching and refresh
  - Including `x-clerk-user-id` header (needed by backend)
- Direct Clerk access with `try?` silently swallows errors

## Backend Environment

Backend runs on:

🚀 Server ready at: <http://localhost:4000>
⚡ tRPC endpoint: <http://localhost:4000/trpc>
🌐 tRPC panel: <http://localhost:4000/trpc/panel>
💓 Health check: <http://localhost:4000/health>

**Required Environment Variables:**
- `CLERK_SECRET_KEY` - Must be set for JWT verification to work
- `DATABASE_URL` - PostgreSQL connection string

[06:41:51 UTC] INFO: Server listening at <http://127.0.0.1:4000>
[06:41:51 UTC] INFO: Server listening at <http://192.168.1.75:4000>
[06:41:51 UTC] INFO: Server listening at <http://192.168.64.1:4000>

## Design System (CRITICAL)

**Always follow the Palytt design system when building UI features.**

### Design Tokens

Use tokens from `palytt/Sources/PalyttApp/Design/DesignTokens.swift`:

```swift
// ✅ DO: Use design tokens
VStack(spacing: DesignTokens.Spacing.lg) {
    Text("Title")
        .font(DesignTokens.Typography.title(weight: .bold))
        .foregroundColor(.primaryText)
}
.padding(DesignTokens.Spacing.Component.cardHorizontalPadding)
.background(
    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.Component.card)
        .fill(Color.cardBackground)
        .cardShadow()
)

// ❌ DON'T: Use hardcoded values
VStack(spacing: 16) {
    Text("Title").font(.system(size: 28))
}
.padding(16)
.background(Color.white)
```

### Colors

**Always use semantic colors** that adapt to light/dark mode:

```swift
// ✅ DO: Use semantic colors
Color.primaryText         // Main text (adapts to theme)
Color.primaryBrand        // #d29985 - Brand color
Color.cardBackground      // Card background (adapts to theme)
Color.background          // Main background (adapts to theme)

// ❌ DON'T: Hardcode colors
Color.black               // Use Color.primaryText instead
Color.white               // Use Color.cardBackground instead
Color(hex: "#d29985")    // Use Color.primaryBrand instead
```

### Reusable Components

**Check for existing components before creating new ones:**

- `UserAvatar` - User profile images (sizes: xs, sm, md, lg, xl, xxl, xxxl)
- `PostCard` - Post display in feeds
- `LoadingView` / `MiniLoadingView` - Loading states
- `EmptyStateView` - Empty states
- Button styles: `ActionButtonStyle`, `HapticButtonStyle`

```swift
// ✅ DO: Use existing components
UserAvatar(user: user, size: 44)
PostCard(post: post, onLike: { ... })
LoadingView("Loading...")

// ❌ DON'T: Create custom components when reusable ones exist
AsyncImage(url: user.avatarURL) { ... }  // Use UserAvatar instead
```

### Design Patterns

1. **Cards**: Padding 16pt horizontal, 14pt vertical, corner radius 24pt, card shadow
2. **Buttons**: Include haptic feedback with `HapticManager.shared.impact(.medium)`
3. **Animations**: Use `DesignTokens.Animation.springQuick` or `springSmooth`
4. **Spacing**: Use `DesignTokens.Spacing` (xs, sm, md, lg, xl, xxl)
5. **Typography**: Use `DesignTokens.Typography` methods for font sizes

### Reference Files

- **Design System Rules**: `.cursor/rules/design_system.mdc` - Complete guidelines
- **Colors**: `palytt/Sources/PalyttApp/Design/Colors.swift`
- **Design Tokens**: `palytt/Sources/PalyttApp/Design/DesignTokens.swift`
- **Components**: `palytt/Sources/PalyttApp/Views/Components/`
