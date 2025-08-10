//
//  PrivacyControlsManager.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Combine
import Foundation

// MARK: - Privacy Controls Manager
@MainActor
class PrivacyControlsManager: ObservableObject {
    static let shared = PrivacyControlsManager()
    
    @Published var privacySettings = PrivacySettings()
    @Published var blockedUsers: Set<String> = []
    @Published var mutedUsers: Set<String> = []
    @Published var privacyScore: Double = 85.0
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadPrivacySettings()
        calculatePrivacyScore()
    }
    
    // MARK: - Privacy Settings Management
    
    func updatePrivacySetting<T>(_ keyPath: WritableKeyPath<PrivacySettings, T>, value: T) {
        privacySettings[keyPath: keyPath] = value
        savePrivacySettings()
        calculatePrivacyScore()
    }
    
    func getPrivacyLevel() -> PrivacyLevel {
        switch privacyScore {
        case 90...100:
            return .maximum
        case 70..<90:
            return .high
        case 50..<70:
            return .medium
        case 30..<50:
            return .low
        default:
            return .minimal
        }
    }
    
    // MARK: - User Blocking
    
    func blockUser(_ userId: String) {
        blockedUsers.insert(userId)
        saveBlockedUsers()
        print("🚫 Blocked user: \(userId)")
    }
    
    func unblockUser(_ userId: String) {
        blockedUsers.remove(userId)
        saveBlockedUsers()
        print("✅ Unblocked user: \(userId)")
    }
    
    func isUserBlocked(_ userId: String) -> Bool {
        return blockedUsers.contains(userId)
    }
    
    // MARK: - User Muting
    
    func muteUser(_ userId: String) {
        mutedUsers.insert(userId)
        saveMutedUsers()
        print("🔇 Muted user: \(userId)")
    }
    
    func unmuteUser(_ userId: String) {
        mutedUsers.remove(userId)
        saveMutedUsers()
        print("🔊 Unmuted user: \(userId)")
    }
    
    func isUserMuted(_ userId: String) -> Bool {
        return mutedUsers.contains(userId)
    }
    
    // MARK: - Permissions
    
    func canViewProfile(of userId: String, by viewerId: String) -> Bool {
        // Check if user is blocked
        if isUserBlocked(viewerId) {
            return false
        }
        
        // Check profile visibility settings
        switch privacySettings.profileVisibility {
        case .public:
            return true
        case .friends:
            // Would check if viewer is a friend
            return true // Simplified for now
        case .private:
            return userId == viewerId // Only self can view
        }
    }
    
    func canSendMessage(to userId: String, from senderId: String) -> Bool {
        // Check if sender is blocked
        if isUserBlocked(senderId) {
            return false
        }
        
        // Check message permissions
        switch privacySettings.messagePermissions {
        case .everyone:
            return true
        case .friends:
            // Would check if sender is a friend
            return true // Simplified for now
        case .none:
            return false
        }
    }
    
    func canViewPost(by authorId: String, viewer viewerId: String) -> Bool {
        // Check if viewer is blocked
        if isUserBlocked(viewerId) {
            return false
        }
        
        // Check post visibility settings
        switch privacySettings.postVisibility {
        case .public:
            return true
        case .friends:
            // Would check if viewer is a friend
            return true // Simplified for now
        case .private:
            return authorId == viewerId // Only author can view
        }
    }
    
    // MARK: - Privacy Score Calculation
    
    private func calculatePrivacyScore() {
        var score: Double = 0
        
        // Profile visibility (25 points)
        switch privacySettings.profileVisibility {
        case .public: score += 5
        case .friends: score += 15
        case .private: score += 25
        }
        
        // Post visibility (25 points)
        switch privacySettings.postVisibility {
        case .public: score += 5
        case .friends: score += 15
        case .private: score += 25
        }
        
        // Location sharing (20 points)
        switch privacySettings.locationSharing {
        case .none: score += 20
        case .city: score += 15
        case .neighborhood: score += 10
        case .exact: score += 5
        }
        
        // Message permissions (15 points)
        switch privacySettings.messagePermissions {
        case .none: score += 15
        case .friends: score += 10
        case .everyone: score += 5
        }
        
        // Additional privacy features (15 points)
        if !privacySettings.searchable { score += 5 }
        if !privacySettings.showOnlineStatus { score += 5 }
        if !privacySettings.allowTagging { score += 5 }
        
        privacyScore = score
    }
    
    // MARK: - Privacy Recommendations
    
    func getPrivacyRecommendations() -> [PrivacyRecommendation] {
        var recommendations: [PrivacyRecommendation] = []
        
        if privacySettings.profileVisibility == .public {
            recommendations.append(PrivacyRecommendation(
                title: "Make Profile Private",
                description: "Consider restricting your profile visibility to friends only",
                impact: .medium,
                action: {
                    self.updatePrivacySetting(\.profileVisibility, value: .friends)
                }
            ))
        }
        
        if privacySettings.locationSharing == .exact {
            recommendations.append(PrivacyRecommendation(
                title: "Limit Location Sharing",
                description: "Sharing exact location can compromise your privacy",
                impact: .high,
                action: {
                    self.updatePrivacySetting(\.locationSharing, value: .city)
                }
            ))
        }
        
        if privacySettings.searchable {
            recommendations.append(PrivacyRecommendation(
                title: "Disable Search Visibility",
                description: "Prevent others from finding you through search",
                impact: .low,
                action: {
                    self.updatePrivacySetting(\.searchable, value: false)
                }
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Persistence
    
    private func savePrivacySettings() {
        do {
            let data = try JSONEncoder().encode(privacySettings)
            UserDefaults.standard.set(data, forKey: "privacy_settings")
        } catch {
            print("Failed to save privacy settings: \(error)")
        }
    }
    
    private func loadPrivacySettings() {
        guard let data = UserDefaults.standard.data(forKey: "privacy_settings") else { return }
        
        do {
            privacySettings = try JSONDecoder().decode(PrivacySettings.self, from: data)
        } catch {
            print("Failed to load privacy settings: \(error)")
        }
    }
    
    private func saveBlockedUsers() {
        let blockedUsersArray = Array(blockedUsers)
        UserDefaults.standard.set(blockedUsersArray, forKey: "blocked_users")
    }
    
    private func loadBlockedUsers() {
        if let blockedUsersArray = UserDefaults.standard.array(forKey: "blocked_users") as? [String] {
            blockedUsers = Set(blockedUsersArray)
        }
    }
    
    private func saveMutedUsers() {
        let mutedUsersArray = Array(mutedUsers)
        UserDefaults.standard.set(mutedUsersArray, forKey: "muted_users")
    }
    
    private func loadMutedUsers() {
        if let mutedUsersArray = UserDefaults.standard.array(forKey: "muted_users") as? [String] {
            mutedUsers = Set(mutedUsersArray)
        }
    }
}

// MARK: - Supporting Models

struct PrivacySettings: Codable {
    var profileVisibility: VisibilityLevel = .friends
    var postVisibility: VisibilityLevel = .public
    var locationSharing: LocationSharingLevel = .city
    var messagePermissions: MessagePermissionLevel = .friends
    var searchable: Bool = true
    var showOnlineStatus: Bool = true
    var allowTagging: Bool = true
    var dataCollection: Bool = false
    var analyticsSharing: Bool = false
}

enum VisibilityLevel: String, Codable, CaseIterable {
    case public = "public"
    case friends = "friends"
    case private = "private"
    
    var displayName: String {
        switch self {
        case .public: return "Public"
        case .friends: return "Friends Only"
        case .private: return "Private"
        }
    }
}

enum LocationSharingLevel: String, Codable, CaseIterable {
    case none = "none"
    case city = "city"
    case neighborhood = "neighborhood"
    case exact = "exact"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .city: return "City Only"
        case .neighborhood: return "Neighborhood"
        case .exact: return "Exact Location"
        }
    }
}

enum MessagePermissionLevel: String, Codable, CaseIterable {
    case everyone = "everyone"
    case friends = "friends"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .everyone: return "Everyone"
        case .friends: return "Friends Only"
        case .none: return "No One"
        }
    }
}

enum PrivacyLevel {
    case maximum, high, medium, low, minimal
    
    var displayName: String {
        switch self {
        case .maximum: return "Maximum"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .minimal: return "Minimal"
        }
    }
    
    var color: Color {
        switch self {
        case .maximum: return .green
        case .high: return .mint
        case .medium: return .yellow
        case .low: return .orange
        case .minimal: return .red
        }
    }
}

enum PrivacyImpact {
    case low, medium, high
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct PrivacyRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let impact: PrivacyImpact
    let action: () -> Void
} 