//
//  EnhancedProfileView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Kingfisher

// MARK: - Enhanced Profile View

struct EnhancedProfileView: View {
    let targetUser: User?
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var achievementService = AchievementService.shared
    @EnvironmentObject var appState: AppState
    
    @State private var selectedTab: ProfileTab = .posts
    @State private var showAchievementDetail = false

    @State private var showTasteProfile = false
    @State private var showAchievementUnlock = false
    @State private var unlockedAchievement: Achievement?
    
    init(targetUser: User? = nil) {
        self.targetUser = targetUser
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Enhanced Profile Header
                    enhancedProfileHeader
                    
                    // Achievement Summary
                    if let user = viewModel.currentUser {
                        achievementSummarySection(for: user)
                    }
                    
                    // Profile Tabs
                    profileTabSelector
                    
                    // Content based on selected tab
                    tabContent
                }
                .padding(.vertical)
            }
            .background(Color.appBackground)
            .refreshable {
                await refreshProfile()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { /* Show settings */ }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primaryBrand)
                    }
                }
            }
            .sheet(isPresented: $showAchievementDetail) {
                AchievementDetailView(userId: viewModel.currentUser?.clerkId ?? "")
            }

            .sheet(isPresented: $showTasteProfile) {
                TasteProfileView(user: viewModel.currentUser ?? User.preview)
            }
            .overlay(
                Group {
                    if showAchievementUnlock, let achievement = unlockedAchievement {
                        AchievementUnlockView(achievement: achievement, isPresented: $showAchievementUnlock)
                    }
                }
            )
        }
        .task {
            if let targetUser = targetUser {
                await viewModel.loadOtherUserProfile(targetUser)
            } else {
                await viewModel.loadUserProfile()
            }
            
            // Load achievements
            if let userId = viewModel.currentUser?.clerkId {
                await achievementService.checkAchievements(for: userId, context: createAchievementContext())
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AchievementUnlocked"))) { notification in
            if let achievement = notification.object as? Achievement {
                unlockedAchievement = achievement
                showAchievementUnlock = true
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var enhancedProfileHeader: some View {
        VStack(spacing: 16) {
            if let user = viewModel.currentUser {
                // Profile Image with Achievement Ring
                ZStack {
                    // Achievement ring based on progress
                    Circle()
                        .stroke(achievementRingGradient(for: user), lineWidth: 4)
                        .frame(width: 120, height: 120)
                    
                    // Profile Image
                    UserAvatar(user: user, size: 110)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        )
                    
                    // Level badge
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            levelBadge(for: user)
                                .offset(x: -10, y: -10)
                        }
                    }
                    .frame(width: 120, height: 120)
                }
                
                // User Info
                VStack(spacing: 8) {
                    Text(user.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .foregroundColor(.primaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Dietary Preferences
                    if !user.dietaryPreferences.isEmpty {
                        DietaryPreferencesChips(preferences: user.dietaryPreferences)
                    }
                }
                
                // Enhanced Stats
                enhancedStatsView(for: user)
                
                // Quick Actions
                quickActionsView(for: user)
            }
        }
        .padding(.horizontal)
    }
    
    private func achievementRingGradient(for user: User) -> LinearGradient {
        let achievements = achievementService.getUserAchievements(for: user.clerkId ?? "")
        let completionPercentage = achievements.isEmpty ? 0 : Double(achievements.filter { $0.isUnlocked }.count) / Double(achievements.count)
        
        if completionPercentage < 0.25 {
            return LinearGradient(colors: [.gray, .gray.opacity(0.3)], startPoint: .top, endPoint: .bottom)
        } else if completionPercentage < 0.5 {
            return LinearGradient(colors: [.green, .green.opacity(0.3)], startPoint: .top, endPoint: .bottom)
        } else if completionPercentage < 0.75 {
            return LinearGradient(colors: [.blue, .blue.opacity(0.3)], startPoint: .top, endPoint: .bottom)
        } else {
            return LinearGradient(colors: [.purple, .orange], startPoint: .top, endPoint: .bottom)
        }
    }
    
    private func levelBadge(for user: User) -> some View {
        let level = calculateUserLevel(for: user)
        
        return ZStack {
            Circle()
                .fill(LinearGradient.primaryGradient)
                .frame(width: 30, height: 30)
            
            Text("\(level)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Achievement Summary
    
    private func achievementSummarySection(for user: User) -> some View {
        let achievements = achievementService.getUserAchievements(for: user.clerkId ?? "")
        let unlockedCount = achievements.filter { $0.isUnlocked }.count
        let recentAchievements = achievements.filter { $0.isUnlocked }.sorted { 
            ($0.unlockedAt ?? Date.distantPast) > ($1.unlockedAt ?? Date.distantPast) 
        }.prefix(3)
        
        return VStack(spacing: 16) {
            // Achievement Stats
            HStack(spacing: 20) {
                StatCard(
                    title: "Achievements",
                    value: "\(unlockedCount)",
                    subtitle: "of \(achievements.count)",
                    color: .blue,
                    action: { showAchievementDetail = true }
                )
                
                StatCard(
                    title: "Level",
                    value: "\(calculateUserLevel(for: user))",
                    subtitle: "Food Explorer",
                    color: .purple,
                    action: { showTasteProfile = true }
                )
                
                StatCard(
                    title: "Journey",
                    value: "\(viewModel.userPosts.count)",
                    subtitle: "experiences",
                    color: .green,
                    action: { /* Journey functionality removed */ }
                )
            }
            
            // Recent Achievements
            if !recentAchievements.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Achievements")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                        
                        Spacer()
                        
                        Button("View All") {
                            showAchievementDetail = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.primaryBrand)
                    }
                    
                    LazyVStack(spacing: 8) {
                        ForEach(Array(recentAchievements), id: \.id) { achievement in
                            AchievementCardView(achievement, compact: true)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Enhanced Stats
    
    private func enhancedStatsView(for user: User) -> some View {
        HStack(spacing: 30) {
            StatItem(label: "Posts", value: "\(user.postsCount)", color: .blue)
            StatItem(label: "Followers", value: "\(user.followersCount)", color: .green)
            StatItem(label: "Following", value: "\(user.followingCount)", color: .purple)
        }
        .padding(.horizontal, 40)
    }
    
    private func quickActionsView(for user: User) -> some View {
        HStack(spacing: 16) {
            QuickActionButton(
                icon: "fork.knife",
                title: "Taste Profile",
                color: .orange
            ) {
                showTasteProfile = true
            }
            
            QuickActionButton(
                icon: "map.fill",
                title: "Food Journey",
                color: .green
            ) {
                /* Journey functionality removed */
            }
            
            QuickActionButton(
                icon: "trophy.fill",
                title: "Achievements",
                color: .yellow
            ) {
                showAchievementDetail = true
            }
            
            QuickActionButton(
                icon: "person.2.fill",
                title: "Social",
                color: .blue
            ) {
                // Navigate to social view
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Profile Tabs
    
    private var profileTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button(action: {
                    HapticManager.shared.impact(.light)
                    selectedTab = tab
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .medium))
                            Text(tab.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedTab == tab ? .primaryBrand : .secondaryText)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.primaryBrand : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
    
    private var tabContent: some View {
        VStack {
            switch selectedTab {
            case .posts:
                ProfilePostsGrid(posts: viewModel.userPosts)
            case .achievements:
                if let user = viewModel.currentUser {
                    let achievements = achievementService.getAchievementsByCategory(for: user.clerkId ?? "")
                    AchievementCategoryGridView(achievements: achievements, userId: user.clerkId ?? "")
                }
            case .journey:
                if let user = viewModel.currentUser {
                    FoodJourneyCompactView(user: user, posts: viewModel.userPosts)
                }
            case .social:
                SocialStatsView(user: viewModel.currentUser ?? User.preview)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helper Methods
    
    private func refreshProfile() async {
        await viewModel.refreshProfile()
        
        if let userId = viewModel.currentUser?.clerkId {
            await achievementService.checkAchievements(for: userId, context: createAchievementContext())
        }
    }
    
    private func createAchievementContext() -> AchievementContext {
        guard let user = viewModel.currentUser else { return .empty }
        
        return AchievementContext(
            totalPosts: viewModel.userPosts.count,
            totalLikes: viewModel.userPosts.reduce(0) { $0 + $1.likesCount },
            totalComments: viewModel.userPosts.reduce(0) { $0 + $1.commentsCount },
            totalFriends: user.followingCount,
            totalFollowers: user.followersCount,
            uniqueCuisines: Set(viewModel.userPosts.flatMap { $0.menuItems }),
            uniqueRestaurants: Set(viewModel.userPosts.compactMap { $0.shop?.name }),
            currentStreak: calculateCurrentStreak(),
            recentActions: []
        )
    }
    
    private func calculateCurrentStreak() -> Int {
        // Calculate posting streak
        let sortedPosts = viewModel.userPosts.sorted { $0.createdAt > $1.createdAt }
        var streak = 0
        var currentDate = Date()
        
        for post in sortedPosts {
            let daysDifference = Calendar.current.dateComponents([.day], from: post.createdAt, to: currentDate).day ?? 0
            
            if daysDifference <= 1 {
                streak += 1
                currentDate = post.createdAt
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func calculateUserLevel(for user: User) -> Int {
        let totalPosts = user.postsCount
        let totalFollowers = user.followersCount
        let achievements = achievementService.getUnlockedAchievements(for: user.clerkId ?? "").count
        
        // Simple level calculation
        let basePoints = totalPosts * 10 + totalFollowers * 5 + achievements * 25
        return max(1, basePoints / 100)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
    }
}

struct DietaryPreferencesChips: View {
    let preferences: [DietaryPreference]
    
    var body: some View {
        if !preferences.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(preferences.prefix(3), id: \.self) { preference in
                        Text(preference.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(12)
                    }
                    
                    if preferences.count > 3 {
                        Text("+\(preferences.count - 3)")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.secondaryText)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Profile Tab Enum

enum ProfileTab: String, CaseIterable {
    case posts = "posts"
    case achievements = "achievements"
    case journey = "journey"
    case social = "social"
    
    var title: String {
        switch self {
        case .posts: return "Posts"
        case .achievements: return "Achievements"
        case .journey: return "Journey"
        case .social: return "Social"
        }
    }
    
    var icon: String {
        switch self {
        case .posts: return "photo.on.rectangle"
        case .achievements: return "trophy.fill"
        case .journey: return "map.fill"
        case .social: return "person.2.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EnhancedProfileView()
            .environmentObject(MockAppState())
    }
} 