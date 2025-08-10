//
//  NotificationSettings.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import SwiftUI

// MARK: - Notification Settings Model
@MainActor
class NotificationSettings: ObservableObject {
    static let shared = NotificationSettings()
    
    // MARK: - Published Properties
    @Published var allNotificationsEnabled: Bool = true {
        didSet { save() }
    }
    
    // Social Notifications
    @Published var commentsEnabled: Bool = true {
        didSet { save() }
    }
    @Published var likesEnabled: Bool = true {
        didSet { save() }
    }
    @Published var mentionsEnabled: Bool = true {
        didSet { save() }
    }
    @Published var followsEnabled: Bool = true {
        didSet { save() }
    }
    @Published var friendRequestsEnabled: Bool = true {
        didSet { save() }
    }
    
    // Post & Content Notifications
    @Published var newPostsFromFriendsEnabled: Bool = true {
        didSet { save() }
    }
    @Published var trendingPostsEnabled: Bool = false {
        didSet { save() }
    }
    @Published var nearbyPostsEnabled: Bool = true {
        didSet { save() }
    }
    
    // Message & Direct Notifications
    @Published var messagesEnabled: Bool = true {
        didSet { save() }
    }
    @Published var groupMessagesEnabled: Bool = true {
        didSet { save() }
    }
    
    // System & App Notifications
    @Published var systemUpdatesEnabled: Bool = true {
        didSet { save() }
    }
    @Published var securityAlertsEnabled: Bool = true {
        didSet { save() }
    }
    @Published var achievementsEnabled: Bool = true {
        didSet { save() }
    }
    
    // Sound & Haptic Settings
    @Published var soundsEnabled: Bool = true {
        didSet { save() }
    }
    @Published var hapticsEnabled: Bool = true {
        didSet { save() }
    }
    @Published var notificationSoundsEnabled: Bool = true {
        didSet { save() }
    }
    
    // Timing & Frequency Settings
    @Published var quietHoursEnabled: Bool = false {
        didSet { save() }
    }
    @Published var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date() {
        didSet { save() }
    }
    @Published var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date() {
        didSet { save() }
    }
    @Published var pauseNotificationsUntil: Date? = nil {
        didSet { save() }
    }
    
    // Preview & Summary Settings
    @Published var showPreviewInLockScreen: Bool = true {
        didSet { save() }
    }
    @Published var showPreviewInNotificationCenter: Bool = true {
        didSet { save() }
    }
    @Published var groupSimilarNotifications: Bool = true {
        didSet { save() }
    }
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let allNotificationsEnabled = "notification_all_enabled"
        static let commentsEnabled = "notification_comments_enabled"
        static let likesEnabled = "notification_likes_enabled"
        static let mentionsEnabled = "notification_mentions_enabled"
        static let followsEnabled = "notification_follows_enabled"
        static let friendRequestsEnabled = "notification_friend_requests_enabled"
        static let newPostsFromFriendsEnabled = "notification_new_posts_friends_enabled"
        static let trendingPostsEnabled = "notification_trending_posts_enabled"
        static let nearbyPostsEnabled = "notification_nearby_posts_enabled"
        static let messagesEnabled = "notification_messages_enabled"
        static let groupMessagesEnabled = "notification_group_messages_enabled"
        static let systemUpdatesEnabled = "notification_system_updates_enabled"
        static let securityAlertsEnabled = "notification_security_alerts_enabled"
        static let achievementsEnabled = "notification_achievements_enabled"
        static let soundsEnabled = "notification_sounds_enabled"
        static let hapticsEnabled = "notification_haptics_enabled"
        static let notificationSoundsEnabled = "notification_notification_sounds_enabled"
        static let quietHoursEnabled = "notification_quiet_hours_enabled"
        static let quietHoursStart = "notification_quiet_hours_start"
        static let quietHoursEnd = "notification_quiet_hours_end"
        static let pauseNotificationsUntil = "notification_pause_until"
        static let showPreviewInLockScreen = "notification_preview_lock_screen"
        static let showPreviewInNotificationCenter = "notification_preview_notification_center"
        static let groupSimilarNotifications = "notification_group_similar"
    }
    
    // MARK: - Initialization
    private init() {
        load()
    }
    
    // MARK: - Persistence
    private func save() {
        let defaults = UserDefaults.standard
        
        defaults.set(allNotificationsEnabled, forKey: Keys.allNotificationsEnabled)
        defaults.set(commentsEnabled, forKey: Keys.commentsEnabled)
        defaults.set(likesEnabled, forKey: Keys.likesEnabled)
        defaults.set(mentionsEnabled, forKey: Keys.mentionsEnabled)
        defaults.set(followsEnabled, forKey: Keys.followsEnabled)
        defaults.set(friendRequestsEnabled, forKey: Keys.friendRequestsEnabled)
        defaults.set(newPostsFromFriendsEnabled, forKey: Keys.newPostsFromFriendsEnabled)
        defaults.set(trendingPostsEnabled, forKey: Keys.trendingPostsEnabled)
        defaults.set(nearbyPostsEnabled, forKey: Keys.nearbyPostsEnabled)
        defaults.set(messagesEnabled, forKey: Keys.messagesEnabled)
        defaults.set(groupMessagesEnabled, forKey: Keys.groupMessagesEnabled)
        defaults.set(systemUpdatesEnabled, forKey: Keys.systemUpdatesEnabled)
        defaults.set(securityAlertsEnabled, forKey: Keys.securityAlertsEnabled)
        defaults.set(achievementsEnabled, forKey: Keys.achievementsEnabled)
        defaults.set(soundsEnabled, forKey: Keys.soundsEnabled)
        defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled)
        defaults.set(notificationSoundsEnabled, forKey: Keys.notificationSoundsEnabled)
        defaults.set(quietHoursEnabled, forKey: Keys.quietHoursEnabled)
        defaults.set(quietHoursStart, forKey: Keys.quietHoursStart)
        defaults.set(quietHoursEnd, forKey: Keys.quietHoursEnd)
        defaults.set(pauseNotificationsUntil, forKey: Keys.pauseNotificationsUntil)
        defaults.set(showPreviewInLockScreen, forKey: Keys.showPreviewInLockScreen)
        defaults.set(showPreviewInNotificationCenter, forKey: Keys.showPreviewInNotificationCenter)
        defaults.set(groupSimilarNotifications, forKey: Keys.groupSimilarNotifications)
        
        print("📱 NotificationSettings: Saved preferences")
    }
    
    private func load() {
        let defaults = UserDefaults.standard
        
        // Check if we have any saved settings (first run check)
        if defaults.object(forKey: Keys.allNotificationsEnabled) == nil {
            // First run - save defaults
            save()
            return
        }
        
        allNotificationsEnabled = defaults.bool(forKey: Keys.allNotificationsEnabled)
        commentsEnabled = defaults.bool(forKey: Keys.commentsEnabled)
        likesEnabled = defaults.bool(forKey: Keys.likesEnabled)
        mentionsEnabled = defaults.bool(forKey: Keys.mentionsEnabled)
        followsEnabled = defaults.bool(forKey: Keys.followsEnabled)
        friendRequestsEnabled = defaults.bool(forKey: Keys.friendRequestsEnabled)
        newPostsFromFriendsEnabled = defaults.bool(forKey: Keys.newPostsFromFriendsEnabled)
        trendingPostsEnabled = defaults.bool(forKey: Keys.trendingPostsEnabled)
        nearbyPostsEnabled = defaults.bool(forKey: Keys.nearbyPostsEnabled)
        messagesEnabled = defaults.bool(forKey: Keys.messagesEnabled)
        groupMessagesEnabled = defaults.bool(forKey: Keys.groupMessagesEnabled)
        systemUpdatesEnabled = defaults.bool(forKey: Keys.systemUpdatesEnabled)
        securityAlertsEnabled = defaults.bool(forKey: Keys.securityAlertsEnabled)
        achievementsEnabled = defaults.bool(forKey: Keys.achievementsEnabled)
        soundsEnabled = defaults.bool(forKey: Keys.soundsEnabled)
        hapticsEnabled = defaults.bool(forKey: Keys.hapticsEnabled)
        notificationSoundsEnabled = defaults.bool(forKey: Keys.notificationSoundsEnabled)
        quietHoursEnabled = defaults.bool(forKey: Keys.quietHoursEnabled)
        
        if let startDate = defaults.object(forKey: Keys.quietHoursStart) as? Date {
            quietHoursStart = startDate
        }
        if let endDate = defaults.object(forKey: Keys.quietHoursEnd) as? Date {
            quietHoursEnd = endDate
        }
        if let pauseDate = defaults.object(forKey: Keys.pauseNotificationsUntil) as? Date {
            pauseNotificationsUntil = pauseDate
        }
        
        showPreviewInLockScreen = defaults.bool(forKey: Keys.showPreviewInLockScreen)
        showPreviewInNotificationCenter = defaults.bool(forKey: Keys.showPreviewInNotificationCenter)
        groupSimilarNotifications = defaults.bool(forKey: Keys.groupSimilarNotifications)
        
        print("📱 NotificationSettings: Loaded preferences")
    }
    
    // MARK: - Convenience Methods
    
    /// Check if notifications should be sent based on current settings and timing
    func shouldSendNotification(type: NotificationType) -> Bool {
        // Global setting check
        guard allNotificationsEnabled else { return false }
        
        // Paused notifications check
        if let pauseUntil = pauseNotificationsUntil, Date() < pauseUntil {
            return false
        }
        
        // Quiet hours check
        if quietHoursEnabled && isInQuietHours() {
            return false
        }
        
        // Type-specific checks
        switch type {
        case .comment:
            return commentsEnabled
        case .like:
            return likesEnabled
        case .mention:
            return mentionsEnabled
        case .follow:
            return followsEnabled
        case .friendRequest:
            return friendRequestsEnabled
        case .newPostFromFriend:
            return newPostsFromFriendsEnabled
        case .trendingPost:
            return trendingPostsEnabled
        case .nearbyPost:
            return nearbyPostsEnabled
        case .message:
            return messagesEnabled
        case .groupMessage:
            return groupMessagesEnabled
        case .systemUpdate:
            return systemUpdatesEnabled
        case .securityAlert:
            return securityAlertsEnabled
        case .achievement:
            return achievementsEnabled
        }
    }
    
    /// Check if current time is within quiet hours
    private func isInQuietHours() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        let startComponents = calendar.dateComponents([.hour, .minute], from: quietHoursStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: quietHoursEnd)
        
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        
        guard let startHour = startComponents.hour,
              let startMinute = startComponents.minute,
              let endHour = endComponents.hour,
              let endMinute = endComponents.minute,
              let nowHour = nowComponents.hour,
              let nowMinute = nowComponents.minute else {
            return false
        }
        
        let startMinutesSinceMidnight = startHour * 60 + startMinute
        let endMinutesSinceMidnight = endHour * 60 + endMinute
        let nowMinutesSinceMidnight = nowHour * 60 + nowMinute
        
        if startMinutesSinceMidnight < endMinutesSinceMidnight {
            // Same day (e.g., 9 AM to 5 PM)
            return nowMinutesSinceMidnight >= startMinutesSinceMidnight && nowMinutesSinceMidnight <= endMinutesSinceMidnight
        } else {
            // Crosses midnight (e.g., 10 PM to 8 AM)
            return nowMinutesSinceMidnight >= startMinutesSinceMidnight || nowMinutesSinceMidnight <= endMinutesSinceMidnight
        }
    }
    
    /// Pause notifications for a specific duration
    func pauseNotifications(for duration: TimeInterval) {
        pauseNotificationsUntil = Date().addingTimeInterval(duration)
    }
    
    /// Resume notifications immediately
    func resumeNotifications() {
        pauseNotificationsUntil = nil
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        allNotificationsEnabled = true
        commentsEnabled = true
        likesEnabled = true
        mentionsEnabled = true
        followsEnabled = true
        friendRequestsEnabled = true
        newPostsFromFriendsEnabled = true
        trendingPostsEnabled = false
        nearbyPostsEnabled = true
        messagesEnabled = true
        groupMessagesEnabled = true
        systemUpdatesEnabled = true
        securityAlertsEnabled = true
        achievementsEnabled = true
        soundsEnabled = true
        hapticsEnabled = true
        notificationSoundsEnabled = true
        quietHoursEnabled = false
        quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
        pauseNotificationsUntil = nil
        showPreviewInLockScreen = true
        showPreviewInNotificationCenter = true
        groupSimilarNotifications = true
    }
}

// MARK: - Notification Type Enum
enum NotificationType {
    case comment
    case like
    case mention
    case follow
    case friendRequest
    case newPostFromFriend
    case trendingPost
    case nearbyPost
    case message
    case groupMessage
    case systemUpdate
    case securityAlert
    case achievement
    
    var displayName: String {
        switch self {
        case .comment:
            return "Comments"
        case .like:
            return "Likes"
        case .mention:
            return "Mentions"
        case .follow:
            return "New Followers"
        case .friendRequest:
            return "Friend Requests"
        case .newPostFromFriend:
            return "Friend Posts"
        case .trendingPost:
            return "Trending Posts"
        case .nearbyPost:
            return "Nearby Posts"
        case .message:
            return "Messages"
        case .groupMessage:
            return "Group Messages"
        case .systemUpdate:
            return "App Updates"
        case .securityAlert:
            return "Security Alerts"
        case .achievement:
            return "Achievements"
        }
    }
    
    var description: String {
        switch self {
        case .comment:
            return "When someone comments on your posts"
        case .like:
            return "When someone likes your posts or comments"
        case .mention:
            return "When someone mentions you in a comment"
        case .follow:
            return "When someone follows you"
        case .friendRequest:
            return "When someone sends you a friend request"
        case .newPostFromFriend:
            return "When your friends create new posts"
        case .trendingPost:
            return "When posts are trending in your area"
        case .nearbyPost:
            return "When there are new posts near your location"
        case .message:
            return "When you receive direct messages"
        case .groupMessage:
            return "When you receive group messages"
        case .systemUpdate:
            return "App updates and feature announcements"
        case .securityAlert:
            return "Important security notifications"
        case .achievement:
            return "When you unlock new achievements"
        }
    }
    
    var icon: String {
        switch self {
        case .comment:
            return "bubble.left.fill"
        case .like:
            return "heart.fill"
        case .mention:
            return "at"
        case .follow:
            return "person.badge.plus.fill"
        case .friendRequest:
            return "person.2.badge.plus.fill"
        case .newPostFromFriend:
            return "person.3.sequence.fill"
        case .trendingPost:
            return "flame.fill"
        case .nearbyPost:
            return "location.fill"
        case .message:
            return "message.fill"
        case .groupMessage:
            return "message.badge.filled.fill"
        case .systemUpdate:
            return "app.badge.fill"
        case .securityAlert:
            return "shield.fill"
        case .achievement:
            return "star.fill"
        }
    }
} 