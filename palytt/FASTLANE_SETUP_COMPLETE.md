# ✅ Fastlane Setup Complete - Internal Testing Ready

Your Fastlane configuration has been set up for internal testing via TestFlight!

## 📦 What Was Configured

### 1. New Fastlane Lanes for Internal Testing

#### Main Lane: `internal_testing` 🚀
Quick build and deploy to TestFlight for internal testers only:
```bash
cd palytt
fastlane internal_testing
```

Features:
- ✅ Auto-increments build number
- ✅ Builds Release configuration
- ✅ Uploads to TestFlight
- ✅ Distributes to "Internal Testers" group only
- ✅ No external testers notified
- ✅ Includes timestamps in changelog
- ✅ Cleans up automatically

#### Supporting Lanes:
- `build_internal` - Build only, no upload
- `upload_internal` - Upload existing IPA
- `deploy_testflight` - Full build with all tests (original lane)

### 2. Configuration Files Created

```
palytt/
├── fastlane/
│   ├── Appfile                          ✅ NEW - App & team configuration
│   ├── Fastfile                         ✅ UPDATED - New internal testing lanes
│   ├── INTERNAL_TESTING_SETUP.md        ✅ NEW - Complete setup guide
│   └── QUICK_REFERENCE.md               ✅ NEW - Quick command reference
├── .gitignore                           ✅ UPDATED - Protects sensitive files
└── .xcode/workflows/
    └── main-build.xccworkflow           ✅ UPDATED - Latest iOS version
```

## 🎯 Next Steps to Start Using

### Step 1: Create `.env` File

Create a file at `palytt/.env` (not in the fastlane folder):

```bash
cd /Users/kavyrattana/Coding/palytt-monorepo/palytt
cat > .env << 'EOF'
# Apple Developer Account
APPLE_ID=your-apple-id@example.com
TEAM_ID=YOUR_TEAM_ID
ITC_TEAM_ID=YOUR_ITC_TEAM_ID

# App Configuration
APP_IDENTIFIER=com.palytt.app

# Contact Information
CONTACT_EMAIL=support@palytt.com
CONTACT_FIRST_NAME=Palytt
CONTACT_LAST_NAME=Team
CONTACT_PHONE=+1234567890
EOF
```

Then edit it with your actual values:
```bash
nano .env  # or use your preferred editor
```

### Step 2: Find Your Team IDs

**Developer Team ID:**
1. Visit https://developer.apple.com/account
2. Click "Membership"
3. Copy your Team ID

**App Store Connect Team ID:**
1. Visit https://appstoreconnect.apple.com
2. Click "Users and Access"
3. Copy Team ID from top right

### Step 3: Set Up App in App Store Connect

1. Go to https://appstoreconnect.apple.com
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - Platform: iOS
   - Name: Palytt
   - Bundle ID: com.palytt.app (or your actual bundle ID)
   - SKU: PALYTT001

### Step 4: Create Internal Testing Group

1. In App Store Connect, select your app
2. Go to **TestFlight** tab
3. Click **Internal Testing**
4. Click "+" to create new group
5. Name it **"Internal Testers"**
6. Add your team members

### Step 5: Run Your First Build! 🎉

```bash
cd /Users/kavyrattana/Coding/palytt-monorepo/palytt
fastlane internal_testing
```

## 📚 Documentation

| File | Purpose |
|------|---------|
| [INTERNAL_TESTING_SETUP.md](./fastlane/INTERNAL_TESTING_SETUP.md) | Complete setup guide with troubleshooting |
| [QUICK_REFERENCE.md](./fastlane/QUICK_REFERENCE.md) | Quick command reference for daily use |
| [Appfile](./fastlane/Appfile) | App configuration |
| [Fastfile](./fastlane/Fastfile) | Lane definitions |

## 🔄 Common Workflows

### Daily Development - Quick Test
```bash
# Make code changes, then:
fastlane internal_testing changelog:"Fixed profile loading issue"
```

### Before Pushing to Main
```bash
# Run full test suite:
fastlane deploy_testflight
```

### Build Locally First
```bash
# Build without uploading:
fastlane build_internal

# Review IPA, then upload:
fastlane upload_internal ipa:"./build/Palytt.ipa"
```

### Clean Build (When Things Break)
```bash
fastlane clean
fastlane internal_testing
```

## 🔐 Security Notes

Your `.gitignore` is configured to protect:
- ✅ `.env` - Environment variables (NEVER commit!)
- ✅ `.p12` - Certificates
- ✅ `*.mobileprovision` - Provisioning profiles
- ✅ `*.cer` - Certificate files

## 🚀 CI/CD Ready

For automated builds, consider using App Store Connect API Key instead of Apple ID:

1. Generate at https://appstoreconnect.apple.com/access/api
2. Download `.p8` file
3. Add to `.env`:
   ```bash
   APP_STORE_CONNECT_API_KEY_KEY_ID=YOUR_KEY_ID
   APP_STORE_CONNECT_API_KEY_ISSUER_ID=YOUR_ISSUER_ID
   APP_STORE_CONNECT_API_KEY_KEY=~/palytt-secrets/AuthKey_KEYID.p8
   ```

## ✨ Xcode Cloud Integration

Your Xcode Cloud workflow (`.xcode/workflows/main-build.xccworkflow`) is also configured to:
- ✅ Build on every push to main
- ✅ Use latest iOS version
- ✅ Run tests automatically

To enable TestFlight uploads from Xcode Cloud:
1. Open Xcode
2. Product → Xcode Cloud → Manage Workflows
3. Select "Main Branch Build"
4. Add post-action: "Upload to TestFlight"

## 🎊 You're Ready!

You can now:
- ✅ Build and deploy to TestFlight with one command
- ✅ Share builds with internal testers quickly
- ✅ Iterate fast without manual App Store Connect steps
- ✅ Automate builds in CI/CD when ready

**First build command:**
```bash
cd /Users/kavyrattana/Coding/palytt-monorepo/palytt
fastlane internal_testing
```

Good luck with your internal testing! 🚀

---

**Questions?** Check the full guides:
- Setup: `fastlane/INTERNAL_TESTING_SETUP.md`
- Quick Ref: `fastlane/QUICK_REFERENCE.md`








