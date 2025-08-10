//
//  PrivacyControls.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import SwiftUI

// MARK: - Privacy Controls Manager

@MainActor
class PrivacyControlsManager: ObservableObject {
    static let shared = PrivacyControlsManager()
    
    @Published var privacySettings = PrivacySettings()
    @Published var blockedUsers: Set<String> = []
    @Published var mutedUsers: Set<String> = []
    
    private init() {
        loadPrivacySettings()
    }
    
    func updatePrivacySetting<T>(_ keyPath: WritableKeyPath<PrivacySettings, T>, value: T) {
        privacySettings[keyPath: keyPath] = value
        savePrivacySettings()
    }
    
    func blockUser(_ userId: String) {
        blockedUsers.insert(userId)
        saveBlockedUsers()
    }
    
    func unblockUser(_ userId: String) {
        blockedUsers.remove(userId)
        saveBlockedUsers()
    }
    
    func muteUser(_ userId: String) {
        mutedUsers.insert(userId)
        saveMutedUsers()
    }
    
    func unmuteUser(_ userId: String) {
        mutedUsers.remove(userId)
        saveMutedUsers()
    }
    
    private func loadPrivacySettings() {
        if let data = UserDefaults.standard.data(forKey: "privacy_settings"),
           let settings = try? JSONDecoder().decode(PrivacySettings.self, from: data) {
            privacySettings = settings
        }
        
        if let data = UserDefaults.standard.data(forKey: "blocked_users"),
           let users = try? JSONDecoder().decode(Set<String>.self, from: data) {
            blockedUsers = users
        }
        
        if let data = UserDefaults.standard.data(forKey: "muted_users"),
           let users = try? JSONDecoder().decode(Set<String>.self, from: data) {
            mutedUsers = users
        }
    }
    
    private func savePrivacySettings() {
        if let data = try? JSONEncoder().encode(privacySettings) {
            UserDefaults.standard.set(data, forKey: "privacy_settings")
        }
    }
    
    private func saveBlockedUsers() {
        if let data = try? JSONEncoder().encode(blockedUsers) {
            UserDefaults.standard.set(data, forKey: "blocked_users")
        }
    }
    
    private func saveMutedUsers() {
        if let data = try? JSONEncoder().encode(mutedUsers) {
            UserDefaults.standard.set(data, forKey: "muted_users")
        }
    }
}

// MARK: - Privacy Settings Model

struct PrivacySettings: Codable {
    var profileVisibility: ProfileVisibility = .public
    var postsVisibility: PostsVisibility = .public
    var locationSharing: LocationSharing = .exact
    var searchability: Searchability = .everyone
    var messagePermissions: MessagePermissions = .everyone
    var activitySharing: ActivitySharing = .all
    
    enum ProfileVisibility: String, CaseIterable, Codable {
        case public = "public"
        case friendsOnly = "friendsOnly"
        case private = "private"
        
        var title: String {
            switch self {
            case .public: return "Public"
            case .friendsOnly: return "Friends Only"
            case .private: return "Private"
            }
        }
        
        var description: String {
            switch self {
            case .public: return "Anyone can see your profile"
            case .friendsOnly: return "Only your friends can see your profile"
            case .private: return "Only you can see your profile"
            }
        }
    }
    
    enum PostsVisibility: String, CaseIterable, Codable {
        case public = "public"
        case friendsOnly = "friendsOnly"
        case private = "private"
        
        var title: String {
            switch self {
            case .public: return "Public"
            case .friendsOnly: return "Friends Only"
            case .private: return "Private"
            }
        }
    }
    
    enum LocationSharing: String, CaseIterable, Codable {
        case none = "none"
        case city = "city"
        case neighborhood = "neighborhood"
        case exact = "exact"
        
        var title: String {
            switch self {
            case .none: return "Don't Share"
            case .city: return "City Only"
            case .neighborhood: return "Neighborhood"
            case .exact: return "Exact Location"
            }
        }
    }
    
    enum Searchability: String, CaseIterable, Codable {
        case everyone = "everyone"
        case friendsOnly = "friendsOnly"
        case none = "none"
        
        var title: String {
            switch self {
            case .everyone: return "Everyone"
            case .friendsOnly: return "Friends Only"
            case .none: return "No One"
            }
        }
    }
    
    enum MessagePermissions: String, CaseIterable, Codable {
        case everyone = "everyone"
        case friendsOnly = "friendsOnly"
        case none = "none"
        
        var title: String {
            switch self {
            case .everyone: return "Everyone"
            case .friendsOnly: return "Friends Only"
            case .none: return "No One"
            }
        }
    }
    
    enum ActivitySharing: String, CaseIterable, Codable {
        case all = "all"
        case friendsOnly = "friendsOnly"
        case none = "none"
        
        var title: String {
            switch self {
            case .all: return "Share All Activity"
            case .friendsOnly: return "Friends Only"
            case .none: return "Don't Share Activity"
            }
        }
    }
}

// MARK: - Privacy Dashboard View

struct PrivacyDashboardView: View {
    @StateObject private var privacyManager = PrivacyControlsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    PrivacySettingRow(
                        title: "Profile Visibility",
                        description: "Who can see your profile",
                        value: privacyManager.privacySettings.profileVisibility.title
                    ) {
                        // Show profile visibility picker
                    }
                    
                    PrivacySettingRow(
                        title: "Posts Visibility",
                        description: "Who can see your posts",
                        value: privacyManager.privacySettings.postsVisibility.title
                    ) {
                        // Show posts visibility picker
                    }
                } header: {
                    Text("Visibility")
                }
                
                // Location Section
                Section {
                    PrivacySettingRow(
                        title: "Location Sharing",
                        description: "How much location detail to share",
                        value: privacyManager.privacySettings.locationSharing.title
                    ) {
                        // Show location sharing picker
                    }
                } header: {
                    Text("Location")
                }
                
                // Communication Section
                Section {
                    PrivacySettingRow(
                        title: "Who Can Find You",
                        description: "Who can find you in search",
                        value: privacyManager.privacySettings.searchability.title
                    ) {
                        // Show searchability picker
                    }
                    
                    PrivacySettingRow(
                        title: "Who Can Message You",
                        description: "Who can send you messages",
                        value: privacyManager.privacySettings.messagePermissions.title
                    ) {
                        // Show message permissions picker
                    }
                } header: {
                    Text("Communication")
                }
                
                // Activity Section
                Section {
                    PrivacySettingRow(
                        title: "Activity Sharing",
                        description: "Share your app activity",
                        value: privacyManager.privacySettings.activitySharing.title
                    ) {
                        // Show activity sharing picker
                    }
                } header: {
                    Text("Activity")
                }
                
                // Blocked Users Section
                Section {
                    NavigationLink("Blocked Users") {
                        BlockedUsersView()
                    }
                    
                    NavigationLink("Muted Users") {
                        MutedUsersView()
                    }
                } header: {
                    Text("Blocked & Muted")
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PrivacySettingRow: View {
    let title: String
    let description: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primaryText)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primaryBrand)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct BlockedUsersView: View {
    @StateObject private var privacyManager = PrivacyControlsManager.shared
    
    var body: some View {
        List {
            if privacyManager.blockedUsers.isEmpty {
                Text("No blocked users")
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(Array(privacyManager.blockedUsers), id: \.self) { userId in
                    HStack {
                        Text("User \(userId)")
                            .foregroundColor(.primaryText)
                        
                        Spacer()
                        
                        Button("Unblock") {
                            privacyManager.unblockUser(userId)
                        }
                        .foregroundColor(.primaryBrand)
                    }
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct MutedUsersView: View {
    @StateObject private var privacyManager = PrivacyControlsManager.shared
    
    var body: some View {
        List {
            if privacyManager.mutedUsers.isEmpty {
                Text("No muted users")
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(Array(privacyManager.mutedUsers), id: \.self) { userId in
                    HStack {
                        Text("User \(userId)")
                            .foregroundColor(.primaryText)
                        
                        Spacer()
                        
                        Button("Unmute") {
                            privacyManager.unmuteUser(userId)
                        }
                        .foregroundColor(.primaryBrand)
                    }
                }
            }
        }
        .navigationTitle("Muted Users")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    PrivacyDashboardView()
} 