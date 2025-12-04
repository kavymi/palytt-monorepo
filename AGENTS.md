# Agent Guidelines for Palytt Monorepo

This document provides guidelines for AI agents working on the Palytt codebase.

## Project Structure

- `palytt/` - iOS SwiftUI application
- `palytt-backend/` - Node.js backend with tRPC

## iOS Development Guidelines

### Building the App

- **Don't build unless explicitly asked**
- Use Xcode build for iOS 18 (iPhone 17 Pro):
  ```bash
  cd palytt && xcodebuild -scheme Palytt -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build
  ```

### Rerunning the App (CRITICAL)

**When the app is already running on the simulator, DO NOT do a full rebuild.**

Instead, use the MCP tool to rerun the app:

```
mcp_XcodeBuildMCP_build_run_sim({
  projectPath: '/Users/kavyrattana/Coding/palytt-monorepo/palytt/Palytt.xcodeproj',
  scheme: 'Palytt',
  simulatorName: 'iPhone 17 Pro'
})
```

This is significantly faster because:
- Uses incremental compilation (only recompiles changed files)
- Automatically stops the existing app instance
- Reinstalls and relaunches the updated app

**Only use full `xcodebuild clean build` when:**
- Starting fresh after major changes
- Encountering unexplained build issues
- Explicitly asked to do a clean build

### File Management

- If a new Swift file is created, add it to `project.pbxproj`
- Do not modify `Package.swift` unless specifically asked
- Create mock data for Preview Mode in each SwiftUI view

## Backend Development

Backend runs on:
- 🚀 Server: http://localhost:4000
- ⚡ tRPC endpoint: http://localhost:4000/trpc
- 🌐 tRPC panel: http://localhost:4000/trpc/panel
- 💓 Health check: http://localhost:4000/health

### Environment Variables (CRITICAL)

The backend requires these environment variables to be set:
- `CLERK_SECRET_KEY` - Required for JWT token verification
- `DATABASE_URL` - PostgreSQL connection string

When running with Docker, ensure `.env` file contains `CLERK_SECRET_KEY` or pass it via environment.

### Integration

- Use tRPC connection for frontend and backend communication
- Update typings and enhance type safety
- Update backend at `palytt-backend/` when building features requiring API integration

### Authentication Pattern (IMPORTANT)

**iOS App Authentication:**
- Always use `getAuthHeaders()` method from `BackendService` for authenticated requests
- NEVER directly call `Clerk.shared.session?.getToken()?.jwt` - this pattern is unreliable
- The `getAuthHeaders()` method properly uses `AuthProvider.shared.getHeadersWithUserId()` which:
  - Retrieves the JWT token correctly from Clerk
  - Includes the `x-clerk-user-id` header for backend identification
  - Handles token caching and refresh

**Example - Correct Pattern:**
```swift
// ✅ CORRECT: Use getAuthHeaders()
let authHeaders = await getAuthHeaders()
let headers = HTTPHeaders(authHeaders.map { HTTPHeader(name: $0.key, value: $0.value) })
AF.request(urlString, method: .get, headers: headers)

// ❌ WRONG: Don't directly access Clerk token
guard let token = try? await Clerk.shared.session?.getToken()?.jwt else { ... }
```

## Testing

After making changes:
1. Build validation (if not already running)
2. Rerun the app using MCP tool (if already running)
3. Verify changes work in the running simulator
4. Test key user flows affected by the changes

## Additional Resources

See also:
- `palytt/CLAUDE.md` - Claude-specific guidelines
- `.cursor/rules/` - Cursor rules for code patterns
- `palytt/docs/` - Feature documentation

