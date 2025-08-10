//
//  OnboardingManager.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import SwiftUI

// MARK: - Onboarding Manager

class OnboardingManager: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    
    @Published var shouldShowOnboarding = false
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        self.hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedOnboarding")
        
        // Show onboarding if not completed
        self.shouldShowOnboarding = !hasCompletedOnboarding
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        shouldShowOnboarding = false
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        shouldShowOnboarding = true
    }
    
    // For testing/demo purposes
    func showOnboardingAgain() {
        shouldShowOnboarding = true
    }
}

// MARK: - Onboarding Features

enum OnboardingFeature: String, CaseIterable {
    case foodSharing = "food_sharing"
    case discovery = "discovery"
    case clustering = "clustering"
    case social = "social"
    case notifications = "notifications"
    
    var title: String {
        switch self {
        case .foodSharing:
            return "Share Your Food Adventures"
        case .discovery:
            return "Discover Nearby Places"
        case .clustering:
            return "Explore Food Clusters"
        case .social:
            return "Connect with Food Lovers"
        case .notifications:
            return "Stay Updated"
        }
    }
    
    var description: String {
        switch self {
        case .foodSharing:
            return "Capture and share your favorite food moments with the community"
        case .discovery:
            return "Find amazing restaurants, cafes, and hidden gems around you"
        case .clustering:
            return "See what's popular in each area with our smart map clustering"
        case .social:
            return "Follow friends and discover new tastes together"
        case .notifications:
            return "Get notified about new posts and activity from your network"
        }
    }
    
    var systemImage: String {
        switch self {
        case .foodSharing:
            return "camera.fill"
        case .discovery:
            return "location.fill"
        case .clustering:
            return "map.fill"
        case .social:
            return "heart.fill"
        case .notifications:
            return "bell.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .foodSharing:
            return .milkTea
        case .discovery:
            return .matchaGreen
        case .clustering:
            return .matchaGreen
        case .social:
            return .errorColor
        case .notifications:
            return .warningColor
        }
    }
}

// MARK: - Onboarding Preferences

struct OnboardingPreferences {
    var enableNotifications = true
    var shareLocation = true
    var discoverableProfile = true
    var emailUpdates = false
    
    static var `default`: OnboardingPreferences {
        return OnboardingPreferences()
    }
}

extension OnboardingManager {
    func savePreferences(_ preferences: OnboardingPreferences) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(preferences) {
            userDefaults.set(data, forKey: "onboardingPreferences")
        }
    }
    
    func loadPreferences() -> OnboardingPreferences {
        guard let data = userDefaults.data(forKey: "onboardingPreferences"),
              let preferences = try? JSONDecoder().decode(OnboardingPreferences.self, from: data) else {
            return .default
        }
        return preferences
    }
}

// MARK: - Onboarding Preferences Conformance

extension OnboardingPreferences: Codable {} 