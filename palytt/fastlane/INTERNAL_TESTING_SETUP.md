# Internal Testing Setup Guide

This guide will help you set up Fastlane for building and deploying to TestFlight for internal testing.

## Prerequisites

1. **Xcode** - Latest version installed
2. **Fastlane** - Already installed (check with `fastlane --version`)
3. **Apple Developer Account** - With access to App Store Connect
4. **App Store Connect Access** - Team member with Admin or App Manager role

## Environment Setup

### 1. Create `.env` file

Create a `.env` file in the `palytt` directory (NOT in fastlane folder):

```bash
cd /Users/kavyrattana/Coding/palytt-monorepo/palytt
touch .env
```

Add the following content to `.env`:

```bash
# Apple Developer Account
APPLE_ID=your-apple-id@example.com
TEAM_ID=YOUR_TEAM_ID
ITC_TEAM_ID=YOUR_ITC_TEAM_ID

# App Configuration
APP_IDENTIFIER=com.palytt.app

# Contact Information for Beta App Review
CONTACT_EMAIL=support@palytt.com
CONTACT_FIRST_NAME=Palytt
CONTACT_LAST_NAME=Team
CONTACT_PHONE=+1234567890
```

### 2. Find Your Team IDs

**Developer Team ID:**
1. Go to https://developer.apple.com/account
2. Click on "Membership" in the sidebar
3. Copy your "Team ID"

**App Store Connect Team ID:**
1. Go to https://appstoreconnect.apple.com
2. Click "Users and Access"
3. Your Team ID is in the top right corner

### 3. Set Up App in App Store Connect

1. Go to https://appstoreconnect.apple.com
2. Click "My Apps" → "+" → "New App"
3. Fill in app information:
   - **Platform:** iOS
   - **Name:** Palytt
   - **Primary Language:** English
   - **Bundle ID:** Select your bundle ID (com.palytt.app)
   - **SKU:** A unique identifier (e.g., PALYTT001)
   - **User Access:** Full Access

### 4. Create Internal Testing Group

1. In App Store Connect, select your app
2. Go to **TestFlight** tab
3. Click **Internal Testing** in the sidebar
4. Click the "+" button to create a new group
5. Name it **"Internal Testers"**
6. Add team members who should receive test builds

## Authentication Options

### Option A: App Store Connect API Key (Recommended for CI/CD)

1. Go to https://appstoreconnect.apple.com/access/api
2. Click "Generate API Key"
3. Give it a name (e.g., "Fastlane CI")
4. Select **"Admin"** or **"App Manager"** role
5. Download the `.p8` file
6. Save it securely (e.g., `~/palytt-secrets/AuthKey_KEYID.p8`)

Add to your `.env`:
```bash
APP_STORE_CONNECT_API_KEY_KEY_ID=YOUR_KEY_ID
APP_STORE_CONNECT_API_KEY_ISSUER_ID=YOUR_ISSUER_ID
APP_STORE_CONNECT_API_KEY_KEY=~/palytt-secrets/AuthKey_KEYID.p8
```

### Option B: Apple ID with App-Specific Password

1. Go to https://appleid.apple.com
2. Sign in and go to "Security"
3. Generate an app-specific password
4. Store it in Keychain or use `FASTLANE_PASSWORD` environment variable

## Usage

### Quick Internal Testing Build

Build and upload to TestFlight for internal testing:

```bash
cd /Users/kavyrattana/Coding/palytt-monorepo/palytt
fastlane internal_testing
```

With custom changelog:
```bash
fastlane internal_testing changelog:"Fixed login issue and improved performance"
```

### Build Only (No Upload)

Just build the IPA without uploading:

```bash
fastlane build_internal
```

### Upload Existing Build

Upload a previously built IPA:

```bash
fastlane upload_internal ipa:"./build/Palytt.ipa"
```

With custom changelog:
```bash
fastlane upload_internal ipa:"./build/Palytt.ipa" changelog:"Bug fixes"
```

### Full Build with Tests

Run all tests before building and uploading:

```bash
fastlane deploy_testflight
```

## Available Lanes

| Lane | Description | Tests? |
|------|-------------|--------|
| `internal_testing` | Quick build and upload to TestFlight internal testing | ❌ |
| `build_internal` | Build IPA only, no upload | ❌ |
| `upload_internal` | Upload existing IPA to TestFlight | ❌ |
| `deploy_testflight` | Full build with all tests + upload | ✅ |

## First-Time Setup Verification

Run this command to verify your setup:

```bash
fastlane pilot list
```

This should list your app and internal testers if everything is configured correctly.

## Troubleshooting

### "Authentication error"
- Verify your `.env` file is in the correct location (`palytt` directory, not `fastlane` directory)
- Check that APPLE_ID and TEAM_ID are correct
- Try logging in manually: `fastlane fastlane-credentials add --username your@email.com`

### "App not found"
- Ensure your app is created in App Store Connect
- Verify APP_IDENTIFIER matches your bundle ID exactly
- Check that your Apple ID has access to the app

### "Code signing error"
- In Xcode, go to Signing & Capabilities
- Enable "Automatically manage signing"
- Select your team
- Ensure you have valid certificates and provisioning profiles

### "Build number already exists"
- Fastlane automatically increments build numbers
- If it fails, manually increment in Xcode: Target → General → Build

## CI/CD Integration

### GitHub Actions

Create `.github/workflows/internal-testing.yml`:

```yaml
name: Internal Testing Build

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install dependencies
        run: |
          brew install fastlane
          
      - name: Build and upload to TestFlight
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          TEAM_ID: ${{ secrets.TEAM_ID }}
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY }}
        run: |
          cd palytt
          fastlane internal_testing
```

### Xcode Cloud Integration

The Xcode Cloud workflow (`.xcode/workflows/main-build.xccworkflow`) will build on every push to main.

To also upload to TestFlight from Xcode Cloud:
1. Open Xcode → Product → Xcode Cloud → Manage Workflows
2. Select "Main Branch Build" workflow
3. Add a post-action: "Upload to TestFlight"
4. Configure distribution to "Internal Testers" group

## Security Best Practices

- ✅ **Never commit** `.env` file to git
- ✅ **Never commit** `.p8` API key files
- ✅ Use environment variables for sensitive data
- ✅ Store secrets in CI/CD provider's secret management
- ✅ Rotate API keys periodically
- ✅ Use App-Specific Passwords instead of your main Apple ID password

## Next Steps

1. Create `.env` file with your credentials
2. Run `fastlane internal_testing` to build your first internal test
3. Check TestFlight in App Store Connect for your build
4. Invite internal testers to test the app

## Support

For more information:
- Fastlane Docs: https://docs.fastlane.tools
- TestFlight Guide: https://developer.apple.com/testflight/
- App Store Connect API: https://developer.apple.com/documentation/appstoreconnectapi











