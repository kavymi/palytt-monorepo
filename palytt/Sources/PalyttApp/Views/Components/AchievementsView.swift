//
//  AchievementsView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

struct AchievementsView: View {
    @StateObject private var achievementService = AchievementService.shared
    @EnvironmentObject var appState: AppState
    @State private var selectedCategory: AchievementCategory = .culinary
    @State private var showingAchievementDetail: Achievement? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with stats
                achievementStatsHeader
                
                // Category selector
                categorySelector
                
                // Achievements grid
                achievementsGrid
            }
            .background(Color.background)
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadUserAchievements()
            }
            .sheet(item: $showingAchievementDetail) { achievement in
                AchievementDetailSheet(achievement: achievement)
            }
        }
    }
    
    // MARK: - Achievement Stats Header
    
    private var achievementStatsHeader: some View {
        VStack(spacing: 16) {
            // Overall progress
            VStack(spacing: 8) {
                Text("Achievement Progress")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                let unlockedCount = achievementService.unlockedAchievements.count
                let totalCount = achievementService.userAchievements.count
                let progress = totalCount > 0 ? Double(unlockedCount) / Double(totalCount) : 0.0
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .primaryBrand))
                    .scaleEffect(y: 3)
                    .animation(.easeInOut, value: progress)
                
                Text("\(unlockedCount) of \(totalCount) unlocked")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            // Stats cards
            HStack(spacing: 16) {
                StatCard(
                    icon: "trophy.fill",
                    title: "Unlocked",
                    value: "\(achievementService.unlockedAchievements.count)",
                    color: .orange
                )
                
                StatCard(
                    icon: "star.fill",
                    title: "Points",
                    value: "\(calculateTotalPoints())",
                    color: .yellow
                )
                
                StatCard(
                    icon: "shield.checkered",
                    title: "Badges",
                    value: "\(achievementService.unlockedAchievements.filter { $0.reward.type == .badge }.count)",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8)
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Category Selector
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        HapticManager.shared.impact(.light)
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Achievements Grid
    
    private var achievementsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(filteredAchievements, id: \.id) { achievement in
                    AchievementCard(achievement: achievement) {
                        showingAchievementDetail = achievement
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100) // Space for tab bar
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredAchievements: [Achievement] {
        achievementService.userAchievements.filter { $0.category == selectedCategory }
    }
    
    private func calculateTotalPoints() -> Int {
        return achievementService.unlockedAchievements
            .filter { $0.reward.type == .points }
            .reduce(0) { $0 + $1.reward.value }
    }
    
    // MARK: - Helper Methods
    
    private func loadUserAchievements() {
        guard let userId = appState.currentUser?.clerkId else { return }
        
        Task {
            // In a real app, this would load from the backend
            // For now, we'll use the local achievement service
            await achievementService.checkAchievements(for: userId, context: .empty)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: AchievementCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                
                Text(category.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? category.color : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Achievement Card

struct AchievementCard: View {
    let achievement: Achievement
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon and rarity indicator
                ZStack {
                    Circle()
                        .fill(achievement.rarity.gradient)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: achievement.iconName)
                        .font(.title2)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
                .overlay(
                    // Progress ring for unlocked achievements
                    Circle()
                        .stroke(achievement.isUnlocked ? Color.green : Color.gray.opacity(0.3), lineWidth: 3)
                        .frame(width: 66, height: 66)
                )
                .scaleEffect(achievement.isUnlocked ? 1.0 : 0.7)
                .saturation(achievement.isUnlocked ? 1.0 : 0.3)
                
                // Title and description
                VStack(spacing: 4) {
                    Text(achievement.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    Text(achievement.displayDescription)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                
                // Progress bar
                if !achievement.isUnlocked && achievement.isProgressVisible {
                    VStack(spacing: 4) {
                        ProgressView(value: achievement.progressPercentage / 100.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: achievement.category.color))
                            .scaleEffect(y: 2)
                        
                        Text("\(achievement.progress)/\(achievement.requirement.targetValue)")
                            .font(.caption2)
                            .foregroundColor(.tertiaryText)
                    }
                }
                
                // Rarity badge
                Text(achievement.rarity.title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(achievement.rarity.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(achievement.rarity.color.opacity(0.1))
                    .cornerRadius(6)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(achievement.isUnlocked ? achievement.rarity.color.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(achievement.isUnlocked ? 1.0 : 0.95)
        .animation(.spring(response: 0.3), value: achievement.isUnlocked)
    }
}

// MARK: - Achievement Detail Sheet

struct AchievementDetailSheet: View {
    let achievement: Achievement
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Large icon
                ZStack {
                    Circle()
                        .fill(achievement.rarity.gradient)
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .overlay(
                    Circle()
                        .stroke(achievement.isUnlocked ? Color.green : Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 130, height: 130)
                )
                .scaleEffect(achievement.isUnlocked ? 1.0 : 0.8)
                .saturation(achievement.isUnlocked ? 1.0 : 0.3)
                
                // Title and description
                VStack(spacing: 12) {
                    Text(achievement.displayTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text(achievement.displayDescription)
                        .font(.body)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                // Progress section
                if !achievement.isUnlocked && achievement.isProgressVisible {
                    VStack(spacing: 12) {
                        Text("Progress")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        ProgressView(value: achievement.progressPercentage / 100.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: achievement.category.color))
                            .scaleEffect(y: 3)
                        
                        Text("\(achievement.progress) / \(achievement.requirement.targetValue)")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Reward section
                VStack(spacing: 12) {
                    Text("Reward")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    
                    HStack(spacing: 12) {
                        Image(systemName: achievement.reward.type.icon)
                            .font(.title3)
                            .foregroundColor(achievement.category.color)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(achievement.reward.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                            
                            Text(achievement.reward.description)
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                        
                        Text("+\(achievement.reward.value)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(achievement.category.color)
                    }
                    .padding()
                    .background(achievement.category.color.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Achievement")
            .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    AchievementsView()
        .environmentObject(MockAppState())
} 