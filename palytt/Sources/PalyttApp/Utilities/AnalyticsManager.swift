//
//  AnalyticsManager.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation
import PostHog

/// Manager for handling analytics events using PostHog
@MainActor
final class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    private let apiKey = "phc_8bRVEzHB4HUJWOqGMxViCWt0HuIG6azIxQzoW02gTuS"
    private let host = "https://us.i.posthog.com"
    
    private var isConfigured = false
    
    private init() {}
    
    /// Configure PostHog analytics
    func configure() {
        guard !isConfigured else {
            print("📊 AnalyticsManager: Already configured")
            return
        }
        
        let config = PostHogConfig(apiKey: apiKey, host: host)
        
        // Optional configuration
        config.debug = false // Set to true for development debugging
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = true
        
        PostHogSDK.shared.setup(config)
        
        isConfigured = true
        print("📊 AnalyticsManager: PostHog configured successfully")
        
        // Send initial event to verify integration
        capture("app_analytics_configured")
    }
    
    /// Capture a simple event
    func capture(_ event: String) {
        guard isConfigured else {
            print("⚠️ AnalyticsManager: Not configured, skipping event: \(event)")
            return
        }
        
        PostHogSDK.shared.capture(event)
        print("📊 AnalyticsManager: Captured event: \(event)")
    }
    
    /// Capture an event with properties
    func capture(_ event: String, properties: [String: Any]) {
        guard isConfigured else {
            print("⚠️ AnalyticsManager: Not configured, skipping event: \(event)")
            return
        }
        
        PostHogSDK.shared.capture(event, properties: properties)
        print("📊 AnalyticsManager: Captured event: \(event) with properties: \(properties)")
    }
    
    /// Identify a user
    func identify(userId: String, properties: [String: Any]? = nil) {
        guard isConfigured else {
            print("⚠️ AnalyticsManager: Not configured, skipping identify for user: \(userId)")
            return
        }
        
        if let properties = properties {
            PostHogSDK.shared.identify(userId, properties: properties)
            print("📊 AnalyticsManager: Identified user: \(userId) with properties: \(properties)")
        } else {
            PostHogSDK.shared.identify(userId)
            print("📊 AnalyticsManager: Identified user: \(userId)")
        }
    }
    
    /// Reset user identity (useful for logout)
    func reset() {
        guard isConfigured else {
            print("⚠️ AnalyticsManager: Not configured, skipping reset")
            return
        }
        
        PostHogSDK.shared.reset()
        print("📊 AnalyticsManager: User identity reset")
    }
    
    /// Flush events immediately
    func flush() {
        guard isConfigured else {
            print("⚠️ AnalyticsManager: Not configured, skipping flush")
            return
        }
        
        PostHogSDK.shared.flush()
        print("📊 AnalyticsManager: Events flushed")
    }
}

// MARK: - Convenience Methods for Common Events

extension AnalyticsManager {
    
    /// Track app launch
    func trackAppLaunch() {
        capture("app_launched")
    }
    
    /// Track user authentication
    func trackUserLogin(method: String) {
        capture("user_login", properties: ["method": method])
    }
    
    /// Track user logout
    func trackUserLogout() {
        capture("user_logout")
        reset() // Reset user identity on logout
    }
    
    /// Track screen views
    func trackScreenView(_ screenName: String, properties: [String: Any]? = nil) {
        var eventProperties = ["screen_name": screenName]
        if let additionalProperties = properties {
            eventProperties.merge(additionalProperties) { _, new in new }
        }
        capture("screen_view", properties: eventProperties)
    }
    
    /// Track post creation
    func trackPostCreated(postType: String? = nil) {
        var properties: [String: Any] = [:]
        if let postType = postType {
            properties["post_type"] = postType
        }
        capture("post_created", properties: properties)
    }
    
    /// Track post interaction
    func trackPostInteraction(action: String, postId: String? = nil) {
        var properties = ["action": action]
        if let postId = postId {
            properties["post_id"] = postId
        }
        capture("post_interaction", properties: properties)
    }
    
    /// Track search
    func trackSearch(query: String, resultsCount: Int? = nil) {
        var properties = ["query": query]
        if let resultsCount = resultsCount {
            properties["results_count"] = resultsCount
        }
        capture("search_performed", properties: properties)
    }
    
    /// Track social actions
    func trackSocialAction(action: String, targetUserId: String? = nil) {
        var properties = ["action": action]
        if let targetUserId = targetUserId {
            properties["target_user_id"] = targetUserId
        }
        capture("social_action", properties: properties)
    }
    
    /// Track feature usage
    func trackFeatureUsed(_ featureName: String, context: [String: Any]? = nil) {
        var properties = ["feature": featureName]
        if let context = context {
            properties.merge(context) { _, new in new }
        }
        capture("feature_used", properties: properties)
    }
    
    /// Track errors
    func trackError(_ error: Error, context: [String: Any]? = nil) {
        var properties = [
            "error_description": error.localizedDescription,
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code
        ] as [String: Any]
        
        if let context = context {
            properties.merge(context) { _, new in new }
        }
        
        capture("error_occurred", properties: properties)
    }
}
