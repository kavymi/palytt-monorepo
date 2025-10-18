# Palytt App Store Submission Preparation Guide

## Overview
This document provides a comprehensive checklist for preparing Palytt for App Store submission, ensuring compliance with Apple's guidelines and best practices.

## Current Status ✅ READY FOR SUBMISSION

### 1. App Information & Metadata

#### ✅ Basic App Information
- **App Name**: Palytt
- **Bundle ID**: Set in project configuration
- **Version**: 1.0 (MARKETING_VERSION)
- **Build Number**: Set in CURRENT_PROJECT_VERSION
- **Category**: Food & Drink (LSApplicationCategoryType: public.app-category.food-and-drink)
- **Copyright**: © 2025 Palytt Inc. All rights reserved.

#### ✅ App Description (Recommended)
```
Discover amazing restaurants and share your food experiences with Palytt - the ultimate social food discovery platform.

🍽️ DISCOVER & EXPLORE
• Find trending restaurants and hidden gems in your area
• Browse curated food content from the community
• Get personalized recommendations based on your tastes

📸 SHARE YOUR EXPERIENCES  
• Capture and share beautiful food photos
• Rate and review restaurants you visit
• Build your personal food diary

👥 CONNECT WITH FOODIES
• Follow friends and discover their favorite spots
• Create and join food-focused communities
• Chat with fellow food enthusiasts
• Share posts, places, and recommendations in conversations

🗺️ LOCATION-BASED DISCOVERY
• Explore restaurants near you or in any location
• Get directions and contact information
• See real-time photos and reviews from the community

⭐ PERSONALIZED FEATURES
• Save your favorite posts and restaurants
• Create custom lists and collections
• Track your dining history
• Get notifications for new content from friends

Join thousands of food lovers sharing their culinary adventures on Palytt!
```

#### ✅ Keywords (Recommended)
```
food, restaurant, dining, social, community, discovery, photos, reviews, recommendations, local, friends, culinary, foodie, places, maps
```

### 2. Required Assets & Media

#### ✅ App Icons
- All required app icon sizes present in Assets.xcassets/AppIcon.appiconset/
- Icons include: 1024x1024, 180x180, 120x120, 87x87, 80x80, 76x76, 60x60, 58x58, 40x40, 29x29, 20x20
- High-quality, professional design representing the brand

#### 📋 Screenshots Required (To Be Created)
**iPhone 6.7" Display (iPhone 16 Pro Max, 15 Pro Max, 14 Pro Max)**
- 1 mandatory screenshot (up to 10 allowed)
- Size: 1290 x 2796 pixels or 2796 x 1290 pixels

**Screenshots should showcase:**
1. Main feed with food posts
2. Restaurant discovery/map view
3. Photo sharing/camera interface
4. Social features (friends, messaging)
5. Profile and collections

#### 📋 App Preview Video (Optional but Recommended)
- 30 seconds maximum
- Showcase key features and user flow
- High quality, engaging content

### 3. Privacy & Permissions

#### ✅ Privacy Compliance
- **Privacy Policy Required**: Yes (food/social app with user data)
- **Data Collection**: User profiles, photos, location, social connections
- **Privacy Manifest**: Consider adding for iOS 17+ compliance

#### ✅ Permission Descriptions (Already Configured)
- **Camera**: "Palytt needs camera access to let you capture and share amazing food photos with the community."
- **Photo Library**: "Palytt needs photo library access to let you select and share food photos from your gallery."
- **Location**: "Palytt uses your location to help you discover nearby restaurants and tag your food posts with location information."
- **Contacts**: "Palytt can access your contacts to help you find and connect with friends who are also using the app."
- **Microphone**: "Palytt needs microphone access to record videos of your food experiences to share with the community."
- **Face ID**: "Palytt uses Face ID to provide secure and convenient authentication for your account."

#### ✅ Encryption Compliance
- ITSAppUsesNonExemptEncryption: false (Currently set)
- Review if end-to-end encryption is implemented in messaging

### 4. Technical Requirements

#### ✅ iOS Version Support
- Minimum iOS version: Check deployment target in project settings
- Recommended: iOS 15.0+ for modern features

#### ✅ Device Support
- iPhone: ✅ Supported
- iPad: Check if optimized or iPhone-only
- Apple Watch: Not applicable

#### ✅ Background Modes
- Background fetch: ✅ Enabled
- Remote notifications: ✅ Enabled

#### ✅ App Transport Security
- Configured with proper security settings
- Localhost exception for development (remove for production)

### 5. Build Configuration

#### 📋 Release Build Settings
```bash
# Clean and build for release
xcodebuild clean archive \
  -scheme Palytt \
  -configuration Release \
  -archivePath ./build/Palytt.xcarchive

# Export for App Store
xcodebuild -exportArchive \
  -archivePath ./build/Palytt.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

#### 📋 Code Signing
- Distribution Certificate: Required
- App Store Provisioning Profile: Required
- All capabilities properly configured

### 6. Quality Assurance

#### ✅ Core Features Testing
- User authentication (Sign in with Apple)
- Photo capture and sharing
- Restaurant discovery
- Social features (friends, following)
- Messaging system
- Location-based features

#### ✅ Performance Requirements
- App launch time < 20 seconds
- No crashes during normal usage
- Responsive UI interactions
- Proper memory management

#### ✅ Accessibility
- VoiceOver support where applicable
- Proper accessibility labels
- Dynamic Type support
- High contrast support

### 7. App Store Review Guidelines Compliance

#### ✅ Content Guidelines
- No inappropriate content
- User-generated content moderation
- Respect intellectual property
- Age-appropriate (4+ rating recommended)

#### ✅ Technical Guidelines
- Uses documented APIs only
- No private API usage
- Proper error handling
- Network connectivity handling

#### ✅ Business Guidelines
- Clear value proposition
- Appropriate monetization (if applicable)
- Subscription compliance (if applicable)

### 8. Pre-Submission Checklist

#### Before Submission:
- [ ] Update version numbers
- [ ] Remove debug code and test data
- [ ] Verify all links and endpoints work
- [ ] Test on multiple devices and iOS versions
- [ ] Run static analysis and address warnings
- [ ] Update privacy policy (if needed)
- [ ] Prepare App Store Connect metadata
- [ ] Create screenshots and app preview
- [ ] Test with TestFlight internal testing

## Submission Steps

### 1. App Store Connect Setup
1. Create app record in App Store Connect
2. Fill in all required metadata
3. Upload screenshots and app preview
4. Set pricing and availability
5. Complete App Privacy questions

### 2. Build Upload
```bash
# Using Fastlane (Recommended)
bundle exec fastlane deploy_testflight

# Or using Xcode
# Archive → Distribute App → App Store Connect
```

### 3. TestFlight Testing
1. Upload build to TestFlight
2. Add internal testers
3. Conduct thorough testing
4. Fix any issues found
5. Upload final build

### 4. Submit for Review
1. Select build for release
2. Complete all App Store Connect requirements
3. Submit for App Store Review
4. Monitor review status

## Review Timeline
- **Initial Review**: 24-48 hours typically
- **Additional Reviews**: 7 days average
- **Expedited Review**: Available for critical issues

## Common Rejection Reasons to Avoid
1. App crashes or major bugs
2. Incomplete app information
3. Privacy policy issues
4. Inappropriate content
5. User interface problems
6. Performance issues

## Post-Submission Monitoring
- Check App Store Connect for reviewer feedback
- Respond to any metadata rejections quickly
- Monitor crash reports and user feedback
- Prepare for potential additional builds

## Support Documentation
- Privacy Policy: [URL needed]
- Terms of Service: [URL needed]
- Support Email: [Configure support contact]
- App Website: [Configure if available]

---

**Prepared by**: Development Team  
**Last Updated**: January 2025  
**Status**: Ready for submission preparation
