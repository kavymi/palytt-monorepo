fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test_unit

```sh
[bundle exec] fastlane ios test_unit
```

Run all unit tests

### ios test_ui

```sh
[bundle exec] fastlane ios test_ui
```

Run UI tests

### ios test_all

```sh
[bundle exec] fastlane ios test_all
```

Run all tests

### ios build_for_testing

```sh
[bundle exec] fastlane ios build_for_testing
```

Build for testing

### ios deploy_testflight

```sh
[bundle exec] fastlane ios deploy_testflight
```

Deploy to TestFlight (Full - with all tests)

### ios internal_testing

```sh
[bundle exec] fastlane ios internal_testing
```

Quick build and deploy to TestFlight for Internal Testing

### ios build_internal

```sh
[bundle exec] fastlane ios build_internal
```

Build only for Internal Testing (no upload)

### ios upload_internal

```sh
[bundle exec] fastlane ios upload_internal
```

Upload existing build to TestFlight for Internal Testing

### ios deploy_app_store

```sh
[bundle exec] fastlane ios deploy_app_store
```

Deploy to App Store

### ios prepare_app_store

```sh
[bundle exec] fastlane ios prepare_app_store
```

Prepare for App Store (build only)

### ios ci

```sh
[bundle exec] fastlane ios ci
```

CI Build and Test

### ios clean

```sh
[bundle exec] fastlane ios clean
```

Clean derived data

### ios test_report

```sh
[bundle exec] fastlane ios test_report
```

Generate test report

### ios check_app_store_requirements

```sh
[bundle exec] fastlane ios check_app_store_requirements
```

Check app metadata and assets

### ios setup_release

```sh
[bundle exec] fastlane ios setup_release
```

Setup release configuration

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
