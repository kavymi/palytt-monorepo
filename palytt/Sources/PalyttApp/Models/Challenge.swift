//
//  Challenge.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation
import SwiftUI

// MARK: - Challenge Models

/// Represents a time-limited challenge for users
struct Challenge: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let type: ChallengeType
    let category: ChallengeCategory
    let requirement: ChallengeRequirement
    let reward: ChallengeReward
    let iconName: String
    let startTime: Date
    let endTime: Date
    let isRecurring: Bool
    let recurringSchedule: RecurringSchedule?
    
    // User progress
    var progress: Int = 0
    var isCompleted: Bool = false
    var completedAt: Date?
    
    // Computed properties
    var isActive: Bool {
        let now = Date()
        return now >= startTime && now <= endTime && !isCompleted
    }
    
    var isExpired: Bool {
        Date() > endTime
    }
    
    var timeRemaining: TimeInterval {
        max(0, endTime.timeIntervalSince(Date()))
    }
    
    var timeRemainingFormatted: String {
        let remaining = timeRemaining
        if remaining <= 0 {
            return "Expired"
        }
        
        let hours = Int(remaining) / 3600
        let minutes = Int(remaining) / 60 % 60
        
        if hours > 24 {
            let days = hours / 24
            return "\(days)d left"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else if minutes > 0 {
            return "\(minutes)m left"
        } else {
            return "< 1m left"
        }
    }
    
    var progressPercentage: Double {
        guard requirement.targetValue > 0 else { return 0 }
        return min(1.0, Double(progress) / Double(requirement.targetValue))
    }
    
    var urgencyLevel: UrgencyLevel {
        let remaining = timeRemaining
        if remaining < 3600 { // Less than 1 hour
            return .critical
        } else if remaining < 7200 { // Less than 2 hours
            return .high
        } else if remaining < 21600 { // Less than 6 hours
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Challenge Types

enum ChallengeType: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case special = "special"
    case community = "community"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily Challenge"
        case .weekly: return "Weekly Challenge"
        case .special: return "Special Event"
        case .community: return "Community Goal"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .daily: return .orange
        case .weekly: return .blue
        case .special: return .purple
        case .community: return .green
        }
    }
}

// MARK: - Challenge Categories

enum ChallengeCategory: String, CaseIterable, Codable {
    case posting = "posting"
    case exploration = "exploration"
    case social = "social"
    case cuisine = "cuisine"
    case timing = "timing"
    
    var displayName: String {
        switch self {
        case .posting: return "Post Challenges"
        case .exploration: return "Explore"
        case .social: return "Social"
        case .cuisine: return "Cuisine"
        case .timing: return "Time-Based"
        }
    }
    
    var icon: String {
        switch self {
        case .posting: return "camera.fill"
        case .exploration: return "map.fill"
        case .social: return "person.2.fill"
        case .cuisine: return "fork.knife"
        case .timing: return "clock.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .posting: return .orange
        case .exploration: return .green
        case .social: return .blue
        case .cuisine: return .red
        case .timing: return .purple
        }
    }
}

// MARK: - Challenge Requirement

struct ChallengeRequirement: Codable, Hashable {
    let type: RequirementType
    let targetValue: Int
    let criteria: [String: String]
    
    enum RequirementType: String, Codable {
        case postCount = "post_count"
        case uniqueCuisines = "unique_cuisines"
        case uniqueRestaurants = "unique_restaurants"
        case socialInteractions = "social_interactions"
        case timeWindow = "time_window"
        case specificTag = "specific_tag"
    }
}

// MARK: - Challenge Reward

struct ChallengeReward: Codable, Hashable {
    let type: RewardType
    let value: Int
    let title: String
    let description: String
    let bonusMultiplier: Double? // For streak bonuses
    
    enum RewardType: String, Codable {
        case points = "points"
        case badge = "badge"
        case streakFreeze = "streak_freeze"
        case profileHighlight = "profile_highlight"
        case exclusiveFeature = "exclusive_feature"
        
        var icon: String {
            switch self {
            case .points: return "star.fill"
            case .badge: return "shield.checkered"
            case .streakFreeze: return "snowflake"
            case .profileHighlight: return "sparkles"
            case .exclusiveFeature: return "gift.fill"
            }
        }
    }
}

// MARK: - Recurring Schedule

struct RecurringSchedule: Codable, Hashable {
    let frequency: Frequency
    let startHour: Int // 0-23
    let endHour: Int // 0-23
    let daysOfWeek: [Int]? // 1-7, Sunday = 1
    
    enum Frequency: String, Codable {
        case daily = "daily"
        case weekly = "weekly"
        case weekdays = "weekdays"
        case weekends = "weekends"
    }
}

// MARK: - Urgency Level

enum UrgencyLevel: String {
    case low
    case medium
    case high
    case critical
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    var pulseAnimation: Bool {
        self == .critical || self == .high
    }
}

// MARK: - Challenge Service

@MainActor
class ChallengeService: ObservableObject {
    static let shared = ChallengeService()
    
    @Published var activeChallenges: [Challenge] = []
    @Published var completedChallenges: [Challenge] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let backendService = BackendService.shared
    
    private init() {
        loadMockChallenges()
    }
    
    // MARK: - Public Methods
    
    func loadChallenges() async {
        isLoading = true
        error = nil
        
        // TODO: Fetch from backend when endpoint is ready
        // For now, use mock data
        loadMockChallenges()
        
        isLoading = false
    }
    
    func updateProgress(for challengeId: String, increment: Int = 1) async {
        guard let index = activeChallenges.firstIndex(where: { $0.id == challengeId }) else { return }
        
        var challenge = activeChallenges[index]
        challenge.progress += increment
        
        // Check if completed
        if challenge.progress >= challenge.requirement.targetValue {
            challenge.isCompleted = true
            challenge.completedAt = Date()
            
            // Move to completed
            completedChallenges.append(challenge)
            activeChallenges.remove(at: index)
            
            // Award reward
            await awardReward(challenge.reward)
            
            // Trigger celebration
            NotificationCenter.default.post(
                name: NSNotification.Name("ChallengeCompleted"),
                object: challenge
            )
            
            HapticManager.shared.impact(.success)
        } else {
            activeChallenges[index] = challenge
        }
    }
    
    func refreshChallenges() async {
        // Remove expired challenges
        activeChallenges.removeAll { $0.isExpired }
        
        // Load new challenges
        await loadChallenges()
    }
    
    // MARK: - Private Methods
    
    private func awardReward(_ reward: ChallengeReward) async {
        // TODO: Implement reward system integration
        print("🎁 Awarded reward: \(reward.title) - \(reward.value) \(reward.type.rawValue)")
    }
    
    private func loadMockChallenges() {
        let calendar = Calendar.current
        let now = Date()
        
        // Daily breakfast challenge
        let breakfastEnd = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
        let breakfastChallenge = Challenge(
            id: "daily_breakfast",
            title: "Morning Foodie",
            description: "Share your breakfast before 10am",
            type: .daily,
            category: .timing,
            requirement: ChallengeRequirement(
                type: .postCount,
                targetValue: 1,
                criteria: ["timeWindow": "breakfast"]
            ),
            reward: ChallengeReward(
                type: .points,
                value: 50,
                title: "Early Bird Bonus",
                description: "Extra points for morning posts",
                bonusMultiplier: 1.5
            ),
            iconName: "sunrise.fill",
            startTime: calendar.startOfDay(for: now),
            endTime: breakfastEnd,
            isRecurring: true,
            recurringSchedule: RecurringSchedule(
                frequency: .daily,
                startHour: 6,
                endHour: 10,
                daysOfWeek: nil
            ),
            progress: 0,
            isCompleted: false,
            completedAt: nil
        )
        
        // Try new cuisine challenge
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now)) ?? now
        let cuisineChallenge = Challenge(
            id: "weekly_cuisine",
            title: "Cuisine Explorer",
            description: "Try and post 3 different cuisines this week",
            type: .weekly,
            category: .cuisine,
            requirement: ChallengeRequirement(
                type: .uniqueCuisines,
                targetValue: 3,
                criteria: [:]
            ),
            reward: ChallengeReward(
                type: .badge,
                value: 100,
                title: "World Traveler Badge",
                description: "Show off your diverse palate",
                bonusMultiplier: nil
            ),
            iconName: "globe.americas.fill",
            startTime: calendar.startOfDay(for: now),
            endTime: weekEnd,
            isRecurring: true,
            recurringSchedule: RecurringSchedule(
                frequency: .weekly,
                startHour: 0,
                endHour: 23,
                daysOfWeek: nil
            ),
            progress: 1,
            isCompleted: false,
            completedAt: nil
        )
        
        // Social engagement challenge
        let todayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
        let socialChallenge = Challenge(
            id: "daily_social",
            title: "Social Butterfly",
            description: "Like and comment on 5 friends' posts today",
            type: .daily,
            category: .social,
            requirement: ChallengeRequirement(
                type: .socialInteractions,
                targetValue: 5,
                criteria: ["types": "like,comment"]
            ),
            reward: ChallengeReward(
                type: .points,
                value: 30,
                title: "Community Builder",
                description: "Supporting your foodie friends",
                bonusMultiplier: nil
            ),
            iconName: "heart.fill",
            startTime: calendar.startOfDay(for: now),
            endTime: todayEnd,
            isRecurring: true,
            recurringSchedule: RecurringSchedule(
                frequency: .daily,
                startHour: 0,
                endHour: 23,
                daysOfWeek: nil
            ),
            progress: 2,
            isCompleted: false,
            completedAt: nil
        )
        
        // New restaurant challenge
        let newRestaurantChallenge = Challenge(
            id: "daily_explore",
            title: "Discovery Day",
            description: "Post from a restaurant you've never been to",
            type: .daily,
            category: .exploration,
            requirement: ChallengeRequirement(
                type: .uniqueRestaurants,
                targetValue: 1,
                criteria: ["newOnly": "true"]
            ),
            reward: ChallengeReward(
                type: .points,
                value: 75,
                title: "Explorer Bonus",
                description: "Discovering new places",
                bonusMultiplier: nil
            ),
            iconName: "mappin.and.ellipse",
            startTime: calendar.startOfDay(for: now),
            endTime: todayEnd,
            isRecurring: true,
            recurringSchedule: RecurringSchedule(
                frequency: .daily,
                startHour: 0,
                endHour: 23,
                daysOfWeek: nil
            ),
            progress: 0,
            isCompleted: false,
            completedAt: nil
        )
        
        activeChallenges = [breakfastChallenge, cuisineChallenge, socialChallenge, newRestaurantChallenge]
            .filter { !$0.isExpired }
    }
}

// MARK: - Default Challenges Generator

struct DefaultChallenges {
    static func generateDailyChallenges() -> [Challenge] {
        // This would be called by the backend to generate daily challenges
        return []
    }
    
    static func generateWeeklyChallenges() -> [Challenge] {
        // This would be called by the backend to generate weekly challenges
        return []
    }
}

