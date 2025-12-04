# HomeView First Load Fix

**Date:** December 4, 2025  
**Issue:** Posts don't load automatically on first app launch - require tab switching or pull-to-refresh

## Problem Analysis

### Current Behavior
1. ❌ App launches and shows empty state immediately
2. ❌ Posts don't load until user pulls to refresh or switches tabs
3. ✅ Pull-to-refresh works correctly
4. ✅ Posts load after manual refresh

### Root Cause

The issue is in the timing of authentication and post loading:

**HomeView.swift (Before Fix):**
```swift
.onAppear {
    // ❌ This checks for auth but may execute before Clerk session is ready
    viewModel.fetchPostsIfNeeded()
    
    // Shows loading state if not authenticated
    if !appState.isAuthenticated && viewModel.posts.isEmpty {
        viewModel.isLoading = true
    }
}
```

**HomeViewModel.swift (Before Fix):**
```swift
func fetchPostsIfNeeded() {
    // ❌ Returns early if session not ready - but doesn't retry
    guard Clerk.shared.session != nil else {
        print("⏳ HomeViewModel: Waiting for authentication before fetching posts")
        return
    }
    
    if posts.isEmpty || isDataStale {
        fetchPosts()
    }
}
```

### The Race Condition

1. App launches → HomeView appears
2. `onAppear` calls `fetchPostsIfNeeded()`
3. Clerk session might not be ready yet
4. Method returns early with "Waiting for authentication" message
5. `onChange(of: appState.isAuthenticated)` should trigger when auth completes
6. **BUT** if `appState.isAuthenticated` was already `true` when the view appeared, `onChange` never fires
7. Result: Posts never load automatically

## Solution

### Fix 1: Improve onAppear Logic

**HomeView.swift (After Fix):**
```swift
.onAppear {
    // ✅ Check auth state first, then decide action
    if appState.isAuthenticated {
        // User is already authenticated - fetch posts if needed
        viewModel.fetchPostsIfNeeded()
    } else if viewModel.posts.isEmpty {
        // Not authenticated yet - show loading state
        // The onChange handler will trigger fetch when auth is ready
        viewModel.isLoading = true
    }
}
```

**Benefits:**
- Explicitly checks `appState.isAuthenticated` before attempting fetch
- Shows loading state immediately if not authenticated
- Clearer logic flow

### Fix 2: Add Better Logging

**HomeViewModel.swift (After Fix):**
```swift
func fetchPostsIfNeeded() {
    if isPreviewMode {
        return
    }
    
    // ✅ Check session availability
    let hasSession = Clerk.shared.session != nil
    
    if !hasSession {
        print("⏳ HomeViewModel: Waiting for authentication before fetching posts")
        return
    }
    
    // ✅ Log decision making
    if posts.isEmpty || isDataStale {
        print("📱 HomeViewModel: Fetching posts (isEmpty: \(posts.isEmpty), isStale: \(isDataStale))")
        fetchPosts()
    } else {
        print("✅ HomeViewModel: Posts already loaded and fresh, skipping fetch")
    }
}
```

**Benefits:**
- Better visibility into what's happening
- Helps debug timing issues
- Shows why posts are or aren't being fetched

## Testing the Fix

### Test Case 1: Fresh App Launch
**Steps:**
1. Kill the app completely
2. Launch the app
3. Wait for authentication to complete

**Expected Result:**
- ✅ Loading skeleton shows immediately
- ✅ Posts load automatically within 1-2 seconds
- ✅ No manual refresh needed

**Current Result (Before Fix):**
- ❌ Empty state shows immediately
- ❌ Posts don't load
- ❌ Requires pull-to-refresh

### Test Case 2: Pull-to-Refresh
**Steps:**
1. Pull down on the feed
2. Release

**Expected Result:**
- ✅ Loading indicator shows
- ✅ Posts refresh
- ✅ New posts appear

**Current Result:**
- ✅ Works correctly (already working)

### Test Case 3: Tab Switching
**Steps:**
1. Switch to another tab
2. Switch back to Home tab

**Expected Result:**
- ✅ Posts remain visible
- ✅ Refreshes only if data is stale (>5 minutes)

**Current Result:**
- ✅ Works correctly (already working)

## Implementation Status

### ✅ Code Changes Made

1. **HomeView.swift** - Updated `onAppear` logic
   - Lines 161-171: Improved authentication check
   
2. **HomeViewModel.swift** - Enhanced logging
   - Lines 248-265: Better debug output

### ⚠️ Build Issues

Encountered Xcode DerivedData corruption during testing:
```
error: accessing build database: disk I/O error
error: error closing SessionDelegate.o: No such file or directory
```

**Resolution Required:**
1. Clean DerivedData folder completely
2. Restart Xcode
3. Rebuild project from scratch

**Command to clean:**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/Palytt-*
```

## Additional Improvements Recommended

### 1. Add Retry Logic

Consider adding automatic retry if authentication fails:

```swift
private var authRetryCount = 0
private let maxAuthRetries = 3

func fetchPostsIfNeeded() {
    let hasSession = Clerk.shared.session != nil
    
    if !hasSession {
        if authRetryCount < maxAuthRetries {
            authRetryCount += 1
            // Retry after delay
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await MainActor.run {
                    fetchPostsIfNeeded()
                }
            }
        }
        return
    }
    
    authRetryCount = 0 // Reset on success
    // ... rest of logic
}
```

### 2. Add Loading State Timeout

Prevent infinite loading state:

```swift
private var loadingTimeout: Task<Void, Never>?

func fetchPosts() {
    isLoading = true
    
    // Set timeout
    loadingTimeout?.cancel()
    loadingTimeout = Task {
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        await MainActor.run {
            if isLoading {
                isLoading = false
                errorMessage = "Loading timed out. Please try again."
            }
        }
    }
    
    // ... rest of logic
}
```

### 3. Improve Empty State Logic

Show different messages based on state:

```swift
@ViewBuilder
private var mainContentSection: some View {
    if viewModel.isLoading && viewModel.posts.isEmpty {
        // Loading skeleton
        ForEach(0..<3, id: \.self) { _ in
            PostCardSkeleton()
        }
    } else if !appState.isAuthenticated {
        // Not authenticated message
        AuthenticationRequiredView()
    } else if viewModel.posts.isEmpty && viewModel.errorMessage != nil {
        // Error state
        ErrorStateView(message: viewModel.errorMessage!)
    } else if viewModel.posts.isEmpty {
        // Empty state (no friends or no posts)
        EmptyFeedView()
    } else {
        // Posts list
        PostsList()
    }
}
```

## Related Files

- `palytt/Sources/PalyttApp/Features/Home/HomeView.swift` - Main view
- `palytt/Sources/PalyttApp/Features/Home/HomeViewModel.swift` - View model
- `palytt/Sources/PalyttApp/Networking/Auth/AuthProvider.swift` - Auth handling
- `palytt/Sources/PalyttApp/App/AppState.swift` - Global auth state

## Next Steps

1. ✅ Code changes completed
2. ⏳ Clean build environment
3. ⏳ Rebuild and test on simulator
4. ⏳ Verify posts load on first launch
5. ⏳ Test all three scenarios (fresh launch, refresh, tab switch)
6. ⏳ Consider implementing recommended improvements

## Success Criteria

- [x] Pull-to-refresh works
- [ ] Posts load automatically on first launch
- [ ] Loading skeleton shows during initial load
- [ ] No manual refresh required
- [ ] Proper error handling
- [ ] Good user experience

## Related Documentation

- [Token Expiry Fix](TOKEN_EXPIRY_FIX_SUMMARY.md)
- [HomeView Test Results](HOMEVIEW_TEST_RESULTS.md)
- [Authentication Status](../palytt/docs/architecture/AUTHENTICATION_STATUS.md)


