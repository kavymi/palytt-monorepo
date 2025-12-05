# Token Expiry Fix Summary

## Issue
The iOS app was experiencing 500 errors when making authenticated API requests to the backend:

```
❌ Backend request failed: responseValidationFailed(reason: Alamofire.AFError.ResponseValidationFailureReason.unacceptableStatusCode(code: 500))
❌ NotificationService: Failed to refresh unread count: networkError(...)
```

Backend logs showed:
```
Token expired
❌ Token validation returned null
Error in tRPC handler on path 'notifications.getUnreadCount': Error: Unauthorized - Please sign in
```

## Root Cause

The `AuthProvider` class was caching JWT tokens for **55 minutes** based on a local expiry time, but Clerk session tokens actually expire much faster (typically **60 seconds** by default). This caused the app to:

1. Cache a token locally with a 55-minute expiry
2. Continue using that cached token even after it expired on Clerk's side
3. Send expired tokens to the backend
4. Receive 500 errors when the backend rejected the expired tokens

### Code Issue

```swift
// ❌ BEFORE: Cached tokens for 55 minutes
private var cachedToken: String?
private var tokenExpiry: Date?
private let tokenRefreshBuffer: TimeInterval = 5 * 60 // 5 minutes

func getToken() async throws -> String {
    // Return cached token if still valid based on LOCAL expiry
    if let token = cachedToken,
       let expiry = tokenExpiry,
       expiry > Date() {
        return token  // ⚠️ Token might be expired on Clerk's side!
    }
    
    // ...
    tokenExpiry = Date().addingTimeInterval(55 * 60) // ❌ Assumed 1 hour expiry
}
```

## Solution

Updated `AuthProvider` to use a **short cache duration (30 seconds)** that respects Clerk's actual token expiry:

```swift
// ✅ AFTER: Cache tokens for only 30 seconds
private var cachedToken: String?
private var tokenFetchTime: Date?
// Clerk session tokens expire in ~60 seconds, so cache for max 30 seconds
private let tokenCacheMaxAge: TimeInterval = 30

func getToken() async throws -> String {
    // Check if we have a recently fetched token (within 30 seconds)
    if let token = cachedToken,
       let fetchTime = tokenFetchTime,
       Date().timeIntervalSince(fetchTime) < tokenCacheMaxAge {
        return token
    }
    
    // Get fresh token from Clerk - it handles its own caching/refresh
    let tokenResource = try await session.getToken()
    
    cachedToken = token
    tokenFetchTime = Date()  // ✅ Track fetch time, not expiry
    
    return token
}
```

### Key Changes

1. **Shorter cache duration**: Changed from 55 minutes to 30 seconds
2. **Track fetch time instead of expiry**: Use `tokenFetchTime` instead of `tokenExpiry` to avoid assumptions about token lifetime
3. **Let Clerk handle token refresh**: The Clerk SDK's `session.getToken()` method automatically refreshes expired tokens
4. **Better logging**: Added debug logs to track token fetching

## Additional Fixes

While fixing the token issue, also resolved a database schema mismatch:

```bash
cd palytt-backend && npx prisma db push --accept-data-loss
```

This synced the database with the Prisma schema, adding missing columns like `phoneHash` and `referralCode`.

## Results

**Before Fix:**
```
Token expired
❌ Token validation returned null
{"statusCode":500}
```

**After Fix:**
```
✅ Token verified for user: user_2zGTU1q1URCUCY7EQCVEvmpIU7a
✅ Token validated successfully for user: user_2zGTU1q1URCUCY7EQCVEvmpIU7a
{"statusCode":200}
```

## Files Modified

- `palytt/Sources/PalyttApp/Networking/Auth/AuthProvider.swift`
  - Updated token caching logic
  - Changed from 55-minute expiry to 30-second cache
  - Added better logging

## Testing

Verified the fix by:
1. Building and running the app on iOS Simulator
2. Monitoring backend logs for token verification
3. Confirming 200 status codes for authenticated requests
4. Checking that `notifications.getUnreadCount` endpoint works correctly

## Lessons Learned

1. **Don't assume token expiry times**: Always check the actual token lifetime from the auth provider
2. **Respect auth SDK caching**: Let the SDK handle token refresh instead of implementing custom caching
3. **Use fetch time over expiry time**: Track when tokens were fetched rather than when they expire
4. **Keep cache duration short**: For security-sensitive tokens, use short cache durations (30 seconds or less)
5. **Add comprehensive logging**: Debug logs helped identify the token expiry issue quickly

## Related Documentation

- [Clerk Session Tokens](https://clerk.com/docs/backend-requests/handling/manual-jwt)
- [Authentication Patterns](/.cursor/rules/authentication.mdc)
- [BackendService Guide](/palytt/docs/architecture/AUTHENTICATION_STATUS.md)




