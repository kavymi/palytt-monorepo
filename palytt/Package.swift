// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PalyttApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PalyttApp",
            targets: ["PalyttApp"]
        ),
    ],
    dependencies: [
        // Modern networking
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        // Image loading and caching
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.10.0"),
        // Dependency injection
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.3.0"),
        // Clerk authentication
        .package(url: "https://github.com/clerk/clerk-ios", from: "0.3.0"),
        // Convex - enabled with conditional architecture support
        .package(url: "https://github.com/get-convex/convex-swift", from: "0.5.5"),
        // PostHog analytics
        .package(url: "https://github.com/PostHog/posthog-ios.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "PalyttApp",
            dependencies: [
                "Alamofire",
                "Kingfisher",
                "Factory",
                .product(name: "Clerk", package: "clerk-ios"),
                .product(name: "ConvexMobile", package: "convex-swift"),
                .product(name: "PostHog", package: "posthog-ios"),
            ],
            // Exclude resources since they're handled in the Xcode project directly
            resources: []
        ),
        .testTarget(
            name: "PalyttAppTests",
            dependencies: ["PalyttApp"]
        ),
    ]
) 