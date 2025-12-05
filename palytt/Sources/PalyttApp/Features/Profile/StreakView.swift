//
//  StreakView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Clerk

// MARK: - Streak View

struct StreakView: View {
    @StateObject private var viewModel = StreakViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: StreakTab = .myStreak
    @State private var showFreezeConfirmation = false
    
    enum StreakTab: String, CaseIterable {
        case myStreak = "My Streak"
        case leaderboard = "Friends"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab selector
                    streakTabSelector
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            if selectedTab == .myStreak {
                                // Current Streak Card
                                currentStreakCard
                                
                                // Streak Freeze Protection
                                streakFreezeSection
                                
                                // Streak Status
                                streakStatusCard
                                
                                // Milestones Section
                                milestonesSection
                                
                                // Stats Grid
                                statsGrid
                                
                                // Encouragement
                                encouragementCard
                            } else {
                                // Friends Leaderboard
                                friendsLeaderboard
                            }
                        }
                        .padding()
                    }
                }
                
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("Posting Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
            .alert("Use Streak Freeze?", isPresented: $showFreezeConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Use Freeze") {
                    Task {
                        await viewModel.useStreakFreeze()
                    }
                }
            } message: {
                Text("This will protect your streak for today. You have \(viewModel.streakFreezeCount) freeze(s) available.")
            }
        }
        .task {
            await viewModel.loadStreakInfo()
            await viewModel.loadFriendsLeaderboard()
        }
    }
    
    // MARK: - Tab Selector
    
    private var streakTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(StreakTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    HapticManager.shared.impact(.light)
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: tab == .myStreak ? "flame.fill" : "person.2.fill")
                                .font(.system(size: 14))
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(selectedTab == tab ? .primaryBrand : .secondaryText)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.primaryBrand : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color.appBackground)
    }
    
    // MARK: - Current Streak Card
    
    private var currentStreakCard: some View {
        VStack(spacing: 16) {
            // Fire emoji with animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Text("🔥")
                    .font(.system(size: 50))
            }
            
            VStack(spacing: 4) {
                Text("\(viewModel.currentStreak)")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.primaryText)
                
                Text(viewModel.currentStreak == 1 ? "Day Streak" : "Day Streak")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
            }
            
            // Streak indicator dots (last 7 days)
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.currentStreak ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cardBackground)
        )
    }
    
    // MARK: - Streak Freeze Protection
    
    private var streakFreezeSection: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.cyan)
                    
                    Text("Streak Freeze")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                }
                
                Spacer()
                
                Text("\(viewModel.streakFreezeCount) available")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            
            Text("Protect your streak when you can't post. Earn freezes by completing challenges or maintaining long streaks.")
                .font(.caption)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.leading)
            
            HStack(spacing: 12) {
                // Use freeze button
                Button(action: {
                    if viewModel.streakFreezeCount > 0 && !viewModel.isStreakActive {
                        showFreezeConfirmation = true
                    }
                    HapticManager.shared.impact(.light)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 14))
                        Text("Use Freeze")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(viewModel.streakFreezeCount > 0 && !viewModel.isStreakActive ? .white : .gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(viewModel.streakFreezeCount > 0 && !viewModel.isStreakActive ? Color.cyan : Color.gray.opacity(0.2))
                    )
                }
                .disabled(viewModel.streakFreezeCount == 0 || viewModel.isStreakActive)
                
                // Earn more
                Button(action: {
                    // Navigate to challenges
                    HapticManager.shared.impact(.light)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Earn More")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.primaryBrand)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .stroke(Color.primaryBrand, lineWidth: 2)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Friends Leaderboard
    
    private var friendsLeaderboard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Leaderboard")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    
                    Text("Resets every Sunday")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                // Your rank badge
                if let rank = viewModel.myLeaderboardRank {
                    VStack(spacing: 2) {
                        Text("#\(rank)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primaryBrand)
                        Text("Your Rank")
                            .font(.system(size: 10))
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primaryBrand.opacity(0.1))
                    )
                }
            }
            
            // Leaderboard list
            if viewModel.friendsLeaderboard.isEmpty {
                emptyLeaderboardView
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.friendsLeaderboard.enumerated()), id: \.element.id) { index, friend in
                        LeaderboardRow(
                            rank: index + 1,
                            friend: friend,
                            isCurrentUser: friend.isCurrentUser
                        )
                    }
                }
            }
            
            // Motivation card
            motivationCard
        }
    }
    
    private var emptyLeaderboardView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.2.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.primaryBrand)
            }
            
            VStack(spacing: 8) {
                Text("No Friends Yet")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Text("Add friends to compete on the leaderboard!")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var motivationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.friendsPostedToday) friends posted today")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("Don't let them get ahead!")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Streak Status Card
    
    private var streakStatusCard: some View {
        HStack(spacing: 16) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(viewModel.isStreakActive ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: viewModel.isStreakActive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.isStreakActive ? .green : .orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.isStreakActive ? "Streak Active!" : "Post Today!")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Text(viewModel.isStreakActive ? 
                     "You've posted today. Keep it up!" : 
                     "Don't lose your \(viewModel.currentStreak) day streak!")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground)
        )
    }
    
    // MARK: - Milestones Section
    
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.headline)
                .foregroundColor(.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                milestoneItem(days: 7, icon: "star.fill", achieved: viewModel.achievedMilestones.contains(7))
                milestoneItem(days: 14, icon: "sparkles", achieved: viewModel.achievedMilestones.contains(14))
                milestoneItem(days: 30, icon: "flame.fill", achieved: viewModel.achievedMilestones.contains(30))
                milestoneItem(days: 60, icon: "bolt.fill", achieved: viewModel.achievedMilestones.contains(60))
                milestoneItem(days: 100, icon: "crown.fill", achieved: viewModel.achievedMilestones.contains(100))
                milestoneItem(days: 365, icon: "medal.fill", achieved: viewModel.achievedMilestones.contains(365))
            }
            
            if let nextMilestone = viewModel.nextMilestone {
                HStack {
                    Text("Next milestone:")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Text("\(nextMilestone) days")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryBrand)
                    
                    Text("(\(nextMilestone - viewModel.currentStreak) more to go)")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding(.top, 4)
            }
        }
    }
    
    private func milestoneItem(days: Int, icon: String, achieved: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achieved ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(achieved ? .orange : .gray.opacity(0.5))
            }
            
            Text("\(days) days")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(achieved ? .primaryText : .secondaryText)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(achieved ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        )
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        HStack(spacing: 16) {
            statItem(value: "\(viewModel.currentStreak)", label: "Current", icon: "flame")
            statItem(value: "\(viewModel.longestStreak)", label: "Best", icon: "trophy")
            statItem(value: "\(viewModel.streakFreezeCount)", label: "Freezes", icon: "snowflake")
        }
    }
    
    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.primaryBrand)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground)
        )
    }
    
    // MARK: - Encouragement Card
    
    private var encouragementCard: some View {
        VStack(spacing: 12) {
            Text(viewModel.encouragementMessage)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
            
            if !viewModel.isStreakActive {
                Button(action: {
                    // Navigate to create post
                    HapticManager.shared.impact(.medium)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create a Post")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.primaryBrand)
                    .cornerRadius(25)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primaryBrand.opacity(0.05))
        )
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            ProgressView()
                .scaleEffect(1.2)
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cardBackground)
                )
        }
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let rank: Int
    let friend: StreakLeaderboardEntry
    let isCurrentUser: Bool
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .clear
        }
    }
    
    private var rankIcon: String? {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return nil
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            ZStack {
                if let icon = rankIcon {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(rankColor)
                } else {
                    Text("\(rank)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondaryText)
                }
            }
            .frame(width: 30)
            
            // Avatar
            if let avatarUrl = friend.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(friend.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }
            
            // Name and streak
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(friend.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isCurrentUser ? .primaryBrand : .primaryText)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.primaryBrand)
                    }
                }
                
                Text(friend.postedToday ? "Posted today ✓" : "Not posted yet")
                    .font(.caption)
                    .foregroundColor(friend.postedToday ? .green : .secondaryText)
            }
            
            Spacer()
            
            // Streak count
            HStack(spacing: 4) {
                Text("🔥")
                    .font(.system(size: 14))
                
                Text("\(friend.currentStreak)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.15))
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentUser ? Color.primaryBrand.opacity(0.08) : Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrentUser ? Color.primaryBrand.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        )
    }
}

// MARK: - Leaderboard Entry Model

struct StreakLeaderboardEntry: Identifiable {
    let id: String
    let displayName: String
    let avatarUrl: String?
    let currentStreak: Int
    let postedToday: Bool
    let isCurrentUser: Bool
}

// MARK: - Streak Badge View (for Profile)

struct StreakBadgeView: View {
    let currentStreak: Int
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Text("🔥")
                .font(.system(size: 16))
            
            Text("\(currentStreak)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isActive ? .orange : .gray)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isActive ? Color.orange.opacity(0.15) : Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Streak View Model

@MainActor
class StreakViewModel: ObservableObject {
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var isStreakActive: Bool = false
    @Published var nextMilestone: Int?
    @Published var achievedMilestones: [Int] = []
    @Published var streakFreezeCount: Int = 0
    @Published var isLoading = false
    
    // Leaderboard properties
    @Published var friendsLeaderboard: [StreakLeaderboardEntry] = []
    @Published var myLeaderboardRank: Int?
    @Published var friendsPostedToday: Int = 0
    
    private let backendService = BackendService.shared
    
    var encouragementMessage: String {
        if currentStreak == 0 {
            return "Start your streak today by sharing something delicious! 🍕"
        } else if currentStreak < 7 {
            return "You're building momentum! Keep posting daily to grow your streak."
        } else if currentStreak < 30 {
            return "Amazing consistency! You're on fire! 🔥"
        } else if currentStreak < 100 {
            return "You're a true foodie! Your dedication is inspiring!"
        } else {
            return "Legendary streak! You're a Palytt master! 👑"
        }
    }
    
    func loadStreakInfo() async {
        isLoading = true
        
        do {
            guard let currentUser = Clerk.shared.user else {
                isLoading = false
                return
            }
            
            let response = try await backendService.getStreakInfo(clerkId: currentUser.id)
            
            currentStreak = response.currentStreak
            longestStreak = response.longestStreak
            isStreakActive = response.isStreakActive
            nextMilestone = response.nextMilestone
            achievedMilestones = response.achievedMilestones
            streakFreezeCount = response.streakFreezeCount
            
        } catch {
            print("❌ StreakViewModel: Failed to load streak info: \(error)")
        }
        
        isLoading = false
    }
    
    func loadFriendsLeaderboard() async {
        // TODO: Fetch from backend when endpoint is ready
        // For now, generate mock leaderboard data
        
        guard let currentUser = Clerk.shared.user else { return }
        
        // Mock leaderboard data
        let mockEntries: [StreakLeaderboardEntry] = [
            StreakLeaderboardEntry(
                id: "1",
                displayName: "FoodieQueen",
                avatarUrl: nil,
                currentStreak: 45,
                postedToday: true,
                isCurrentUser: false
            ),
            StreakLeaderboardEntry(
                id: "2",
                displayName: "TasteExplorer",
                avatarUrl: nil,
                currentStreak: 32,
                postedToday: true,
                isCurrentUser: false
            ),
            StreakLeaderboardEntry(
                id: currentUser.id,
                displayName: currentUser.firstName ?? "You",
                avatarUrl: currentUser.imageUrl,
                currentStreak: currentStreak,
                postedToday: isStreakActive,
                isCurrentUser: true
            ),
            StreakLeaderboardEntry(
                id: "3",
                displayName: "BrunchMaster",
                avatarUrl: nil,
                currentStreak: 18,
                postedToday: false,
                isCurrentUser: false
            ),
            StreakLeaderboardEntry(
                id: "4",
                displayName: "CoffeeAddict",
                avatarUrl: nil,
                currentStreak: 12,
                postedToday: true,
                isCurrentUser: false
            ),
            StreakLeaderboardEntry(
                id: "5",
                displayName: "SushiLover",
                avatarUrl: nil,
                currentStreak: 8,
                postedToday: false,
                isCurrentUser: false
            )
        ]
        
        // Sort by streak count
        friendsLeaderboard = mockEntries.sorted { $0.currentStreak > $1.currentStreak }
        
        // Find user's rank
        if let index = friendsLeaderboard.firstIndex(where: { $0.isCurrentUser }) {
            myLeaderboardRank = index + 1
        }
        
        // Count friends who posted today
        friendsPostedToday = friendsLeaderboard.filter { $0.postedToday && !$0.isCurrentUser }.count
    }
    
    func useStreakFreeze() async {
        guard streakFreezeCount > 0 else { return }
        
        // TODO: Call backend to use streak freeze
        // For now, just decrement locally
        streakFreezeCount -= 1
        isStreakActive = true
        
        HapticManager.shared.impact(.success)
        
        // Post notification
        NotificationCenter.default.post(
            name: NSNotification.Name("StreakFreezeUsed"),
            object: nil
        )
    }
}

// MARK: - Preview

#Preview {
    StreakView()
}



