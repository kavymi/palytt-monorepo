# Fastlane Quick Reference

## 🚀 Internal Testing (Most Common)

### Quick Deploy to TestFlight
```bash
cd palytt
fastlane internal_testing
```

### With Changelog
```bash
fastlane internal_testing changelog:"Fixed login bug and improved UI"
```

---

## 📋 All Available Lanes

### Testing Lanes
| Command | Description |
|---------|-------------|
| `fastlane test_unit` | Run unit tests only |
| `fastlane test_ui` | Run UI tests only |
| `fastlane test_all` | Run all tests |

### Build Lanes
| Command | Description |
|---------|-------------|
| `fastlane build_for_testing` | Build for testing (simulator) |
| `fastlane build_internal` | Build IPA for internal testing (no upload) |

### Internal Testing Lanes
| Command | Description |
|---------|-------------|
| `fastlane internal_testing` | ⭐ Quick build & upload to TestFlight (internal only) |
| `fastlane upload_internal` | Upload existing IPA to TestFlight |

### Full Deployment Lanes
| Command | Description |
|---------|-------------|
| `fastlane deploy_testflight` | Full build with tests + upload to TestFlight |
| `fastlane deploy_app_store` | Build and upload to App Store (production) |
| `fastlane prepare_app_store` | Prepare App Store build (build only, no upload) |

### Utility Lanes
| Command | Description |
|---------|-------------|
| `fastlane clean` | Clean derived data |
| `fastlane test_report` | Generate test report |
| `fastlane check_app_store_requirements` | Check App Store requirements |
| `fastlane setup_release` | Setup release configuration |

### CI/CD Lane
| Command | Description |
|---------|-------------|
| `fastlane ci` | Run in CI environment (build + test) |

---

## 🔧 Setup Required

Before running any lanes, ensure you have:

1. **Created `.env` file** in the `palytt` directory:
   ```bash
   APPLE_ID=your@email.com
   TEAM_ID=YOUR_TEAM_ID
   APP_IDENTIFIER=com.palytt.app
   ```

2. **Set up App in App Store Connect**
   - Created your app
   - Created "Internal Testers" group in TestFlight

📚 **Full Setup Guide:** See [INTERNAL_TESTING_SETUP.md](./INTERNAL_TESTING_SETUP.md)

---

## 💡 Examples

### Quick internal test after fixing a bug
```bash
fastlane internal_testing changelog:"Fixed crash on profile screen"
```

### Build locally to check before uploading
```bash
fastlane build_internal
# Check the IPA
fastlane upload_internal ipa:"./build/Palytt.ipa"
```

### Full release with all checks
```bash
fastlane deploy_testflight
```

### Clean build when things go wrong
```bash
fastlane clean
fastlane internal_testing
```

---

## 🆘 Troubleshooting

**Authentication failed?**
```bash
# Clear credentials and re-login
fastlane fastlane-credentials remove --username your@email.com
fastlane fastlane-credentials add --username your@email.com
```

**Build failed?**
```bash
# Clean everything
fastlane clean
rm -rf ~/Library/Developer/Xcode/DerivedData/*
# Try again
fastlane internal_testing
```

**Wrong build number?**
- Fastlane auto-increments based on TestFlight
- If it fails, manually set in Xcode: Target → General → Build

---

## 📱 What Happens When You Run `internal_testing`?

1. ✅ Cleans derived data
2. ✅ Increments build number automatically
3. ✅ Builds Release configuration
4. ✅ Exports IPA with App Store profile
5. ✅ Uploads to TestFlight
6. ✅ Distributes to "Internal Testers" group only
7. ✅ Cleans up build artifacts

**Time:** ~5-10 minutes (depending on your Mac)

---

## 🔐 Security

- ✅ `.env` file is in `.gitignore` - never commit it!
- ✅ Use App Store Connect API keys for CI/CD
- ✅ Use app-specific passwords, not your main Apple ID password

---

## 📚 More Resources

- Full Setup Guide: [INTERNAL_TESTING_SETUP.md](./INTERNAL_TESTING_SETUP.md)
- Fastlane Docs: https://docs.fastlane.tools
- TestFlight Guide: https://developer.apple.com/testflight/









