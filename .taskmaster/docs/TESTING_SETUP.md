# 🧪 Automated Testing Setup Guide

This guide will help you set up automated testing for your Palytt iOS app using multiple testing tools.

## 🛠 Prerequisites

1. **Xcode 15+** with iOS 17+ SDK
2. **Homebrew** installed
3. **Node.js 18+** and **pnpm**
4. **Ruby** for Fastlane

## 📱 Testing Tools Overview

| Tool | Purpose | Type |
|------|---------|------|
| **XCTest** | Unit tests for business logic | Built-in |
| **XCUITest** | UI automation tests | Built-in |
| **Maestro** | Modern mobile UI testing | Third-party |
| **Fastlane** | CI/CD automation | Third-party |

## 🔧 Installation

### 1. Install Fastlane
```bash
# Install Fastlane
gem install fastlane

# Or using Homebrew
brew install fastlane
```

### 2. Install Maestro
```bash
# Install Maestro
curl -Ls https://get.maestro.mobile.dev | bash

# Add to PATH (add to ~/.zshrc)
export PATH="$PATH":"$HOME/.maestro/bin"
```

### 3. Setup Fastlane
```bash
# Initialize Fastlane (if not already done)
cd /path/to/palytt-swiftui
fastlane init

# Install dependencies
bundle install
```

## 🚀 Running Tests

### Option 1: Built-in Xcode Tests

#### Unit Tests (XCTest)
```bash
# Run all unit tests
xcodebuild test -scheme Palytt -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -only-testing:PalyttAppTests/FriendsServiceTests

# Run specific test
xcodebuild test -scheme Palytt -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -only-testing:PalyttAppTests/FriendsServiceTests/testSendFriendRequest
```

#### UI Tests (XCUITest)
```bash
# Run all UI tests
xcodebuild test -scheme Palytt -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -only-testing:PalyttAppTests/FriendsUITests

# Run specific UI test
xcodebuild test -scheme Palytt -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -only-testing:PalyttAppTests/FriendsUITests/testAddFriendsViewNavigation
```

### Option 2: Maestro Tests

```bash
# Make sure your backend is running
cd palytt-backend.symlink && pnpm run dev

# In another terminal, run Maestro tests
maestro test .maestro/friends_flow_test.yaml

# Run with device recording
maestro test .maestro/friends_flow_test.yaml --format junit --output results.xml
```

### Option 3: Fastlane Automation

```bash
# Run unit tests only
fastlane test_unit

# Run UI tests only
fastlane test_ui

# Run all tests (recommended)
fastlane test_all

# CI pipeline (full automation)
fastlane ci
```

## 🎯 Test Categories

### 1. Unit Tests (`FriendsServiceTests.swift`)
- ✅ Send friend requests
- ✅ Accept/reject friend requests
- ✅ Remove friends
- ✅ Get friend lists
- ✅ Error handling
- ✅ Performance testing

### 2. UI Tests (`FriendsUITests.swift`)
- ✅ Navigation flows
- ✅ Search functionality
- ✅ Button interactions
- ✅ Visual verifications
- ✅ User workflows

### 3. Maestro Tests (`.maestro/friends_flow_test.yaml`)
- ✅ Complete user journeys
- ✅ Cross-platform compatibility
- ✅ Visual testing
- ✅ Performance monitoring

## 📊 Continuous Integration

### GitHub Actions Setup
Create `.github/workflows/ios-tests.yml`:

```yaml
name: iOS Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        
    - name: Install pnpm
      run: npm install -g pnpm
        
    - name: Install backend dependencies
      run: cd palytt-backend.symlink && pnpm install
      
    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.0'
        bundler-cache: true
        
    - name: Install Fastlane
      run: gem install fastlane
      
    - name: Run CI Pipeline
      run: fastlane ci
```

### Xcode Cloud Setup
1. Open Xcode
2. Go to Product → Xcode Cloud → Create Workflow
3. Select your scheme: `Palytt`
4. Configure actions:
   - **Build**: iOS Simulator
   - **Test**: Run `PalyttAppTests`
   - **Archive**: For releases

## 🔍 Test Reports & Monitoring

### Viewing Test Results

1. **Xcode Test Navigator**: Built-in test results
2. **Fastlane HTML Reports**: Generated in `./fastlane/test_output/`
3. **Maestro Reports**: JSON/JUnit format
4. **Code Coverage**: Enable in Xcode scheme settings

### Test Metrics
- **Code Coverage**: Aim for 80%+ on friends functionality
- **Performance**: Friend request < 500ms
- **UI Response**: Interactions < 100ms
- **Reliability**: 95%+ test pass rate

## 🚨 Troubleshooting

### Common Issues

1. **Backend not running**
   ```bash
   # Check if backend is running
   curl http://localhost:4000/health
   
   # Start backend
   cd palytt-backend.symlink && pnpm run dev
   ```

2. **Simulator issues**
   ```bash
   # Reset simulator
   xcrun simctl erase all
   
   # Boot specific simulator
   xcrun simctl boot "iPhone 16 Pro"
   ```

3. **Test timeouts**
   ```bash
   # Increase timeout in test files
   XCTAssertTrue(element.waitForExistence(timeout: 10))
   ```

4. **Maestro installation**
   ```bash
   # Reinstall Maestro
   curl -Ls https://get.maestro.mobile.dev | bash
   ```

## 📋 Best Practices

### Writing Tests
- ✅ Use descriptive test names
- ✅ Test one thing per test method
- ✅ Use setup/teardown properly
- ✅ Mock external dependencies
- ✅ Test both success and failure cases

### Maintaining Tests
- ✅ Run tests before committing
- ✅ Update tests when UI changes
- ✅ Keep tests fast and reliable
- ✅ Review test coverage regularly
- ✅ Clean up test data

### CI/CD Integration
- ✅ Run tests on every PR
- ✅ Block merges on test failures
- ✅ Generate test reports
- ✅ Monitor test performance
- ✅ Automate deployment after tests pass

## 🎉 Quick Start Commands

```bash
# 1. Start backend
cd palytt-backend.symlink && pnpm run dev

# 2. Run all tests (in another terminal)
fastlane test_all

# 3. Generate test report
fastlane test_report

# 4. View results
open fastlane/test_output/report.html
```

## 📞 Need Help?

- **Xcode Tests**: Use Xcode Test Navigator
- **Fastlane**: Run `fastlane --help`
- **Maestro**: Check [documentation](https://maestro.mobile.dev/)
- **CI Issues**: Check workflow logs

Your friends functionality is now fully testable with automated tools! 🎯 