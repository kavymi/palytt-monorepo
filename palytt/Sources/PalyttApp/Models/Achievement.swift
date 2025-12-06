//
//  Achievement.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import SwiftUI

// MARK: - Achievement System Models

struct Achievement: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let category: AchievementCategory
    let type: AchievementType
    let requirement: AchievementRequirement
    let reward: AchievementReward
    let iconName: String
    let rarity: AchievementRarity
    let isSecret: Bool
    
    // Progress tracking
    var isUnlocked: Bool = false
    var unlockedAt: Date?
    var progress: Int = 0
    var isProgressVisible: Bool = true
    
    // Display properties
    var displayTitle: String {
        isSecret && !isUnlocked ? "???" : title
    }
    
    var displayDescription: String {
        isSecret && !isUnlocked ? "Keep exploring to unlock this secret achievement!" : description
    }
    
    var progressPercentage: Double {
        guard requirement.targetValue > 0 else { return 0 }
        return min(100.0, (Double(progress) / Double(requirement.targetValue)) * 100.0)
    }
    
    var isCompleted: Bool {
        progress >= requirement.targetValue
    }
    
    init(id: String, title: String, description: String, category: AchievementCategory, 
         type: AchievementType, requirement: AchievementRequirement, reward: AchievementReward,
         iconName: String, rarity: AchievementRarity = .common, isSecret: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.type = type
        self.requirement = requirement
        self.reward = reward
        self.iconName = iconName
        self.rarity = rarity
        self.isSecret = isSecret
    }
}

// MARK: - Achievement Categories

enum AchievementCategory: String, CaseIterable, Codable {
    case culinary = "culinary"
    case social = "social"
    case explorer = "explorer"
    case creator = "creator"
    case community = "community"
    case seasonal = "seasonal"
    case milestone = "milestone"
    case special = "special"
    
    var title: String {
        switch self {
        case .culinary: return "Culinary"
        case .social: return "Social"
        case .explorer: return "Explorer"
        case .creator: return "Creator"
        case .community: return "Community"
        case .seasonal: return "Seasonal"
        case .milestone: return "Milestone"
        case .special: return "Special"
        }
    }
    
    var icon: String {
        switch self {
        case .culinary: return "fork.knife"
        case .social: return "person.2.fill"
        case .explorer: return "location.fill"
        case .creator: return "camera.fill"
        case .community: return "heart.fill"
        case .seasonal: return "calendar"
        case .milestone: return "trophy.fill"
        case .special: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .culinary: return .orange
        case .social: return .blue
        case .explorer: return .green
        case .creator: return .purple
        case .community: return .pink
        case .seasonal: return .cyan
        case .milestone: return .yellow
        case .special: return .red
        }
    }
}

// MARK: - Achievement Types

enum AchievementType: String, CaseIterable, Codable {
    case counter = "counter"        // Count-based (e.g., post 10 times)
    case streak = "streak"          // Consecutive days/actions
    case unique = "unique"          // Unique items (e.g., try 5 cuisines)
    case social = "social"          // Social interactions
    case time = "time"              // Time-based achievements
    case combo = "combo"            // Multiple requirements
    case discovery = "discovery"    // Discovery-based
    case quality = "quality"        // Quality-based (ratings, etc.)
}

// MARK: - Achievement Requirements

struct AchievementRequirement: Codable, Hashable {
    let type: AchievementType
    let targetValue: Int
    let timeframe: TimeFrame?
    let criteria: [String: String] // Additional criteria
    
    enum TimeFrame: String, CaseIterable, Codable {
        case day = "day"
        case week = "week"
        case month = "month"
        case year = "year"
        case allTime = "allTime"
        
        var title: String {
            switch self {
            case .day: return "in a day"
            case .week: return "in a week"
            case .month: return "in a month"
            case .year: return "in a year"
            case .allTime: return "all time"
            }
        }
    }
}

// MARK: - Achievement Rewards

struct AchievementReward: Codable, Hashable {
    let type: RewardType
    let value: Int
    let title: String
    let description: String
    
    enum RewardType: String, CaseIterable, Codable {
        case badge = "badge"
        case points = "points"
        case title = "title"
        case feature = "feature"
        case cosmetic = "cosmetic"
        
        var icon: String {
            switch self {
            case .badge: return "shield.checkered"
            case .points: return "star.fill"
            case .title: return "text.badge.star"
            case .feature: return "sparkles"
            case .cosmetic: return "paintbrush.fill"
            }
        }
    }
}

// MARK: - Achievement Rarity

enum AchievementRarity: String, CaseIterable, Codable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var title: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }
    
    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .common:
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        case .uncommon:
            return LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        case .rare:
            return LinearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        case .epic:
            return LinearGradient(colors: [.purple, .purple.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        case .legendary:
            return LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - User Achievement Progress

struct UserAchievementProgress: Identifiable, Codable {
    let id = UUID()
    let userId: String
    let achievementId: String
    var progress: Int
    var isUnlocked: Bool
    var unlockedAt: Date?
    var lastUpdated: Date
    
    init(userId: String, achievementId: String, progress: Int = 0) {
        self.userId = userId
        self.achievementId = achievementId
        self.progress = progress
        self.isUnlocked = false
        self.lastUpdated = Date()
    }
}

// MARK: - Achievement Service

@MainActor
class AchievementService: ObservableObject {
    @Published var userAchievements: [Achievement] = []
    @Published var unlockedAchievements: [Achievement] = []
    @Published var recentlyUnlocked: [Achievement] = []
    @Published var achievementProgress: [String: UserAchievementProgress] = [:]
    
    static let shared = AchievementService()
    
    private let achievements: [Achievement] = DefaultAchievements.all
    private var progressCache: [String: Int] = [:]
    
    private init() {
        loadUserProgress()
    }
    
    // MARK: - Public Methods
    
    func checkAchievements(for userId: String, context: AchievementContext) async {
        guard !userId.isEmpty else { return }
        
        for achievement in achievements {
            await updateAchievementProgress(achievement, for: userId, context: context)
        }
    }
    
    func updateProgress(achievementId: String, userId: String, increment: Int = 1) async {
        guard let achievement = achievements.first(where: { $0.id == achievementId }) else { return }
        
        let key = "\(userId)_\(achievementId)"
        var progress = achievementProgress[key] ?? UserAchievementProgress(userId: userId, achievementId: achievementId)
        
        progress.progress += increment
        progress.lastUpdated = Date()
        
        achievementProgress[key] = progress
        
        // Check if achievement is completed
        if progress.progress >= achievement.requirement.targetValue && !progress.isUnlocked {
            await unlockAchievement(achievement, for: userId)
        }
        
        saveProgress()
    }
    
    func getProgress(for achievementId: String, userId: String) -> UserAchievementProgress? {
        let key = "\(userId)_\(achievementId)"
        return achievementProgress[key]
    }
    
    func getUserAchievements(for userId: String) -> [Achievement] {
        return achievements.map { achievement in
            var updatedAchievement = achievement
            if let progress = getProgress(for: achievement.id, userId: userId) {
                updatedAchievement.progress = progress.progress
                updatedAchievement.isUnlocked = progress.isUnlocked
                updatedAchievement.unlockedAt = progress.unlockedAt
            }
            return updatedAchievement
        }
    }
    
    func getUnlockedAchievements(for userId: String) -> [Achievement] {
        return getUserAchievements(for: userId).filter { $0.isUnlocked }
    }
    
    func getAchievementsByCategory(for userId: String) -> [AchievementCategory: [Achievement]] {
        let userAchievements = getUserAchievements(for: userId)
        return Dictionary(grouping: userAchievements) { $0.category }
    }
    
    // MARK: - Private Methods
    
    private func updateAchievementProgress(_ achievement: Achievement, for userId: String, context: AchievementContext) async {
        let currentProgress = calculateProgress(for: achievement, userId: userId, context: context)
        let key = "\(userId)_\(achievement.id)"
        
        var progress = achievementProgress[key] ?? UserAchievementProgress(userId: userId, achievementId: achievement.id)
        
        if currentProgress > progress.progress {
            progress.progress = currentProgress
            progress.lastUpdated = Date()
            achievementProgress[key] = progress
            
            if progress.progress >= achievement.requirement.targetValue && !progress.isUnlocked {
                await unlockAchievement(achievement, for: userId)
            }
        }
    }
    
    private func calculateProgress(for achievement: Achievement, userId: String, context: AchievementContext) -> Int {
        // This would integrate with your backend to calculate actual progress
        // For now, using mock calculations
        
        switch achievement.type {
        case .counter:
            return calculateCounterProgress(achievement, context: context)
        case .social:
            return calculateSocialProgress(achievement, context: context)
        case .unique:
            return calculateUniqueProgress(achievement, context: context)
        case .streak:
            return calculateStreakProgress(achievement, context: context)
        default:
            return getProgress(for: achievement.id, userId: userId)?.progress ?? 0
        }
    }
    
    private func calculateCounterProgress(_ achievement: Achievement, context: AchievementContext) -> Int {
        switch achievement.id {
        case "first_post":
            return context.totalPosts > 0 ? 1 : 0
        case "food_explorer_10":
            return min(achievement.requirement.targetValue, context.totalPosts)
        case "social_butterfly":
            return min(achievement.requirement.targetValue, context.totalLikes + context.totalComments)
        // Comment achievements
        case "first_comment":
            return context.commentsGiven > 0 ? 1 : 0
        case "conversation_starter":
            return min(achievement.requirement.targetValue, context.maxRepliesOnComment)
        case "comment_engager":
            return min(achievement.requirement.targetValue, context.commentsGiven)
        case "insightful_commenter":
            return min(achievement.requirement.targetValue, context.maxLikesOnComment)
        case "reply_master":
            return min(achievement.requirement.targetValue, context.repliesGiven)
        default:
            return 0
        }
    }
    
    private func calculateSocialProgress(_ achievement: Achievement, context: AchievementContext) -> Int {
        switch achievement.id {
        case "people_person":
            return min(achievement.requirement.targetValue, context.totalFriends)
        case "community_leader":
            return min(achievement.requirement.targetValue, context.totalFollowers)
        // Referral achievements
        case "first_referral":
            return min(achievement.requirement.targetValue, context.totalReferrals)
        case "social_butterfly_referral":
            return min(achievement.requirement.targetValue, context.totalReferrals)
        case "community_builder":
            return min(achievement.requirement.targetValue, context.totalReferrals)
        case "palytt_ambassador":
            return min(achievement.requirement.targetValue, context.totalReferrals)
        case "viral_inviter":
            return min(achievement.requirement.targetValue, context.totalReferrals)
        default:
            return 0
        }
    }
    
    private func calculateUniqueProgress(_ achievement: Achievement, context: AchievementContext) -> Int {
        switch achievement.id {
        case "cuisine_explorer":
            return min(achievement.requirement.targetValue, context.uniqueCuisines.count)
        case "local_expert":
            return min(achievement.requirement.targetValue, context.uniqueRestaurants.count)
        default:
            return 0
        }
    }
    
    private func calculateStreakProgress(_ achievement: Achievement, context: AchievementContext) -> Int {
        switch achievement.id {
        case "daily_foodie":
            return min(achievement.requirement.targetValue, context.currentStreak)
        default:
            return 0
        }
    }
    
    private func unlockAchievement(_ achievement: Achievement, for userId: String) async {
        let key = "\(userId)_\(achievement.id)"
        var progress = achievementProgress[key] ?? UserAchievementProgress(userId: userId, achievementId: achievement.id)
        
        progress.isUnlocked = true
        progress.unlockedAt = Date()
        achievementProgress[key] = progress
        
        // Add to recently unlocked for display
        var unlockedAchievement = achievement
        unlockedAchievement.isUnlocked = true
        unlockedAchievement.unlockedAt = Date()
        
        recentlyUnlocked.append(unlockedAchievement)
        
        // Trigger celebration animation
        await showAchievementUnlocked(unlockedAchievement)
        
        saveProgress()
    }
    
    private func showAchievementUnlocked(_ achievement: Achievement) async {
        // Trigger haptic feedback
        HapticManager.shared.impact(.success)
        
        // Post notification for UI to show celebration
        NotificationCenter.default.post(
            name: NSNotification.Name("AchievementUnlocked"),
            object: achievement
        )
    }
    
    private func loadUserProgress() {
        // Load from UserDefaults or backend
        if let data = UserDefaults.standard.data(forKey: "achievement_progress"),
           let progress = try? JSONDecoder().decode([String: UserAchievementProgress].self, from: data) {
            achievementProgress = progress
        }
    }
    
    private func saveProgress() {
        if let data = try? JSONEncoder().encode(achievementProgress) {
            UserDefaults.standard.set(data, forKey: "achievement_progress")
        }
    }
}

// MARK: - Achievement Context

struct AchievementContext {
    let totalPosts: Int
    let totalLikes: Int
    let totalComments: Int
    let totalFriends: Int
    let totalFollowers: Int
    let uniqueCuisines: Set<String>
    let uniqueRestaurants: Set<String>
    let currentStreak: Int
    let recentActions: [AchievementAction]
    
    // Comment-specific metrics
    let commentsGiven: Int
    let repliesGiven: Int
    let maxRepliesOnComment: Int
    let maxLikesOnComment: Int
    
    // Referral metrics
    let totalReferrals: Int
    
    static let empty = AchievementContext(
        totalPosts: 0, totalLikes: 0, totalComments: 0,
        totalFriends: 0, totalFollowers: 0,
        uniqueCuisines: [], uniqueRestaurants: [],
        currentStreak: 0, recentActions: [],
        commentsGiven: 0, repliesGiven: 0,
        maxRepliesOnComment: 0, maxLikesOnComment: 0,
        totalReferrals: 0
    )
}

struct AchievementAction {
    let type: ActionType
    let timestamp: Date
    let metadata: [String: String]
    
    enum ActionType: String {
        case postCreated, postLiked, commentAdded, friendAdded, restaurantVisited
    }
}

// MARK: - Default Achievements

struct DefaultAchievements {
    static let all: [Achievement] = [
        // Culinary Achievements
        Achievement(
            id: "first_post",
            title: "First Bite",
            description: "Share your first food experience",
            category: .culinary,
            type: .counter,
            requirement: AchievementRequirement(type: .counter, targetValue: 1, timeframe: nil, criteria: [:]),
            reward: AchievementReward(type: .badge, value: 10, title: "First Bite Badge", description: "Welcome to the community!"),
            iconName: "fork.knife",
            rarity: .common
        ),
        
        Achievement(
            id: "food_explorer_10",
            title: "Food Explorer",
            description: "Share 10 different food experiences",
            category: .culinary,
            type: .counter,
            requirement: AchievementRequirement(type: .counter, targetValue: 10, timeframe: nil, criteria: [:]),
            reward: AchievementReward(type: .badge, value: 50, title: "Explorer Badge", description: "You're getting the hang of this!"),
            iconName: "map.fill",
            rarity: .uncommon
        ),
        
        Achievement(
            id: "cuisine_explorer",
            title: "Cuisine Explorer",
            description: "Try 5 different types of cuisine",
            category: .culinary,
            type: .unique,
            requirement: AchievementRequirement(type: .unique, targetValue: 5, timeframe: nil, criteria: ["type": "cuisine"]),
            reward: AchievementReward(type: .title, value: 0, title: "Adventurous Eater", description: "Show off your diverse palate"),
            iconName: "globe",
            rarity: .rare
        ),
        
        // Social Achievements
        Achievement(
            id: "social_butterfly",
            title: "Social Butterfly",
            description: "Give 50 likes and comments combined",
            category: .social,
            type: .counter,
            requirement: AchievementRequirement(type: .counter, targetValue: 50, timeframe: nil, criteria: [:]),
            reward: AchievementReward(type: .badge, value: 25, title: "Social Badge", description: "You love engaging with the community!"),
            iconName: "heart.fill",
            rarity: .common
        ),
        
        // Comment Achievements
        Achievement(
            id: "first_comment",
            title: "First Words",
            description: "Leave your first comment",
            category: .community,
            type: .counter,
            requirement: AchievementRequirement(type: .counter, targetValue: 1, timeframe: nil, criteria: ["type": "comment"]),
            reward: AchievementReward(type: .badge, value: 10, title: "First Words Badge", description: "You've joined the conversation!"),
            iconName: "bubble.left.fill",
            rarity: .common
        ),
        
        Achievement(
            id: "conversation_starter",
            title: "Conversation Starter",
            description: "Get 5 replies on a single comment",
            category: .community,
            type: .counter,
            requirement: AchievementRequirement(type: .counter, targetValue: 5, timeframe: nil, criteria: ["type": "comment_replies"]),
            reward: AchievementReward(type: .badge, value: 50, title: "Conversation Starter Badge", description: "Your comments spark discussions!"),
            iconName: "bubble.left.and.bubble.right.fill",
            rarity: .rare
        ),
        
        Achievement(
            id: "comment_engager",
            title: "Community Engager",
            description: "Leave 50 comments total",
            category: .community,
            type: .counter,
            requirement: AchievementRequirement(type: .counter, targetValue: 50, timeframe: nil, criteria: ["type": "comments_total"]),
            reward: AchievementReward(type: .title, value: 0, title: "Active Commenter", description: "You're always part of the conversation!"),
            iconName: "text.bubble.fill",
            rarity: .uncommon
        ),
        
        Achievement(
            id: "insightful_commenter",
            title: "Insightful Voice",
            description: "Get 10 likes on a single comment",
            category: .community,
            type: .counter,
            requirement: AchievementRequirement(type: .counter, targetValue: 10, timeframe: nil, criteria: ["type": "comment_likes"]),
            reward: AchievementReward(type: .badge, value: 75, title: "Insightful Badge", description: "People love what you have to say!"),
            iconName: "lightbulb.fill",
            rarity: .epic
        ),
        
        Achievement(
            id: "reply_master",
            title: "Reply Master",
            description: "Reply to 25 different comments",
            category: .community,
            type: .counter,
            requirement: AchievementRequirement(type: .counter, targetValue: 25, timeframe: nil, criteria: ["type": "replies_given"]),
            reward: AchievementReward(type: .badge, value: 40, title: "Reply Master Badge", description: "You keep conversations going!"),
            iconName: "arrowshape.turn.up.left.fill",
            rarity: .uncommon
        ),
        
        Achievement(
            id: "people_person",
            title: "People Person",
            description: "Connect with 10 friends",
            category: .social,
            type: .social,
            requirement: AchievementRequirement(type: .social, targetValue: 10, timeframe: nil, criteria: ["type": "friends"]),
            reward: AchievementReward(type: .feature, value: 0, title: "Friend Finder", description: "Enhanced friend discovery features"),
            iconName: "person.2.fill",
            rarity: .uncommon
        ),
        
        Achievement(
            id: "community_leader",
            title: "Community Leader",
            description: "Gain 100 followers",
            category: .social,
            type: .social,
            requirement: AchievementRequirement(type: .social, targetValue: 100, timeframe: nil, criteria: ["type": "followers"]),
            reward: AchievementReward(type: .title, value: 0, title: "Community Leader", description: "Your influence is growing!"),
            iconName: "crown.fill",
            rarity: .epic
        ),
        
        // Explorer Achievements
        Achievement(
            id: "local_expert",
            title: "Local Expert",
            description: "Visit 20 different restaurants",
            category: .explorer,
            type: .unique,
            requirement: AchievementRequirement(type: .unique, targetValue: 20, timeframe: nil, criteria: ["type": "restaurants"]),
            reward: AchievementReward(type: .title, value: 0, title: "Local Expert", description: "You know your neighborhood!"),
            iconName: "location.fill",
            rarity: .rare
        ),
        
        // Streak Achievements
        Achievement(
            id: "daily_foodie",
            title: "Daily Foodie",
            description: "Post for 7 consecutive days",
            category: .creator,
            type: .streak,
            requirement: AchievementRequirement(type: .streak, targetValue: 7, timeframe: .day, criteria: [:]),
            reward: AchievementReward(type: .cosmetic, value: 0, title: "Streak Master", description: "Special post animation unlocked!"),
            iconName: "flame.fill",
            rarity: .epic
        ),
        
        // Secret/Legendary Achievements
        Achievement(
            id: "legendary_critic",
            title: "Legendary Critic",
            description: "Write 100 detailed reviews with photos",
            category: .special,
            type: .combo,
            requirement: AchievementRequirement(type: .combo, targetValue: 100, timeframe: nil, criteria: ["photos": "required", "reviews": "detailed"]),
            reward: AchievementReward(type: .title, value: 0, title: "Legendary Critic", description: "Your reviews are legendary!"),
            iconName: "star.fill",
            rarity: .legendary,
            isSecret: true
        ),
        
        // Referral Achievements
        Achievement(
            id: "first_referral",
            title: "First Invite",
            description: "Invite your first friend to join Palytt",
            category: .social,
            type: .counter,
            requirement: AchievementRequirement(type: .counter, targetValue: 1, timeframe: nil, criteria: ["type": "referral"]),
            reward: AchievementReward(type: .badge, value: 100, title: "Referral Badge", description: "You're spreading the word!"),
            iconName: "person.badge.plus",
            rarity: .common
        ),
        
        Achievement(
            id: "social_butterfly_referral",
            title: "Social Butterfly",
            description: "Successfully refer 5 friends to Palytt",
            category: .social,
            type: .counter,
            requirement: AchievementRequirement(type: .counter, targetValue: 5, timeframe: nil, criteria: ["type": "referral"]),
            reward: AchievementReward(type: .badge, value: 500, title: "Social Butterfly Badge", description: "Your friends love Palytt thanks to you!"),
            iconName: "sparkles",
            rarity: .uncommon
        ),
        
        Achievement(
            id: "community_builder",
            title: "Community Builder",
            description: "Successfully refer 10 friends to Palytt",
            category: .community,
            type: .counter,
            requirement: AchievementRequirement(type: .counter, targetValue: 10, timeframe: nil, criteria: ["type": "referral"]),
            reward: AchievementReward(type: .feature, value: 3, title: "Streak Freeze x3", description: "Protect your posting streak!"),
            iconName: "building.2.fill",
            rarity: .rare
        ),
        
        Achievement(
            id: "palytt_ambassador",
            title: "Palytt Ambassador",
            description: "Successfully refer 25 friends to Palytt",
            category: .special,
            type: .counter,
            requirement: AchievementRequirement(type: .counter, targetValue: 25, timeframe: nil, criteria: ["type": "referral"]),
            reward: AchievementReward(type: .title, value: 0, title: "Palytt Ambassador", description: "You're a true community champion!"),
            iconName: "crown.fill",
            rarity: .legendary
        ),
        
        Achievement(
            id: "viral_inviter",
            title: "Viral Inviter",
            description: "Successfully refer 50 friends to Palytt",
            category: .special,
            type: .counter,
            requirement: AchievementRequirement(type: .counter, targetValue: 50, timeframe: nil, criteria: ["type": "referral"]),
            reward: AchievementReward(type: .cosmetic, value: 0, title: "Golden Profile Frame", description: "Stand out with a golden profile frame!"),
            iconName: "flame.fill",
            rarity: .legendary,
            isSecret: true
        )
    ]
} 