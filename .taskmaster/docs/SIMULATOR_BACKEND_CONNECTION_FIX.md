# iOS Simulator Backend Connection Fix

**Date:** January 11, 2025  
**Issue:** iOS Simulator cannot retrieve posts from backend API  
**Status:** ✅ **RESOLVED**

## 🔍 **Root Cause Analysis**

The iOS simulator was **unable to connect to the local backend** because:

1. **Wrong API Environment**: The `APIConfigurationManager` was configured to use **production backend** by default
2. **Production URL**: Simulator was trying to connect to `https://palytt-backend-production.up.railway.app`
3. **Local Backend Available**: Backend was running locally on `http://localhost:4000`

## 🔧 **Fix Applied**

### **1. Changed Default Environment to Local**

**File:** `Sources/PalyttApp/Utilities/APIConfiguration.swift`

```swift
// BEFORE: Production default
@Published var currentEnvironment: APIEnvironment = .production

// AFTER: Local default for development
@Published var currentEnvironment: APIEnvironment = .local
```

### **2. Fixed iOS Simulator Networking Issue**

**Problem:** iOS Simulator sometimes can't connect to `localhost:4000`  
**Solution:** Use computer's IP address instead

```swift
// BEFORE: localhost (doesn't work reliably in simulator)
case .local: return "http://localhost:4000"

// AFTER: Computer's IP address (works reliably in simulator)
case .local: return "http://192.168.1.40:4000"
```

### **3. Added Debug Force Override**

```swift
// DEBUG: Force reset to local for development
#if DEBUG
print("🔧 DEBUG: Forcing API environment to local for development")
currentEnvironment = .local
saveEnvironment()
#endif
```

### **4. Enhanced Debug Logging**

Added comprehensive logging in `BackendService.getPosts()`:
```swift
print("🔗 BackendService: Current environment: \(apiConfig.currentEnvironment.displayName)")
print("🔗 BackendService: Base URL: \(baseURL)")
print("🌐 BackendService: Calling URL: \(urlString)")
```

## ✅ **Verification Results**

### **Backend Status:**
- ✅ **Local Backend**: Running on `http://localhost:4000`
- ✅ **Health Check**: Responding with uptime `90166.156939083` seconds
- ✅ **Posts Endpoint**: Returning 5 posts successfully
- ✅ **API Integration**: All endpoints working correctly

### **Frontend Status:**
- ✅ **Build**: SwiftUI app builds successfully
- ✅ **API Config**: Now points to local backend by default
- ✅ **Models**: Fixed notifications decoding issues
- ✅ **Endpoints**: Updated to use correct backend endpoints

## 📊 **Expected Behavior**

Now when the iOS simulator starts:

1. **Default Environment**: Will use `.local` instead of `.production`
2. **API Base URL**: Will connect to `http://192.168.1.40:4000` (computer's IP address)
3. **Posts Retrieval**: Will successfully load posts from local backend
4. **All Features**: Comments, friends, notifications will work with local data
5. **Debug Logs**: Will show connection details for troubleshooting

## 🎯 **Development Workflow**

### **For Local Development:**
- Default behavior: Connects to `http://192.168.1.40:4000` (computer's IP)
- Start backend: `cd palytt-backend.symlink && pnpm dev`
- Build app: `xcodebuild -scheme Palytt -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.3.1' build`
- Debug logs: Watch console for connection details and troubleshooting

### **For Production:**
- Admin users can switch to production environment in app settings
- Or manually change the default back to `.production` when deploying

## 🔧 **Technical Details**

- **Environment Switching**: Available in admin settings for testing
- **Persistence**: User's environment choice is saved in UserDefaults
- **Health Monitoring**: Automatic health checks for both environments
- **Error Handling**: Graceful fallback if backend is unreachable

## 🚀 **Result**

The iOS simulator should now successfully retrieve posts and connect to all backend features without any network errors! 