//
//  AchievementDetailView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Achievement Detail View

struct AchievementDetailView: View {
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var achievementService = AchievementService.shared
    @State private var selectedCategory: AchievementCategory = .culinary
    @State private var searchText = ""
    @State private var showOnlyUnlocked = false
    
    private var achievements: [Achievement] {
        achievementService.getUserAchievements(for: userId)
    }
    
    private var filteredAchievements: [Achievement] {
        var filtered = achievements.filter { $0.category == selectedCategory }
        
        if showOnlyUnlocked {
            filtered = filtered.filter { $0.isUnlocked }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered.sorted { achievement1, achievement2 in
            if achievement1.isUnlocked != achievement2.isUnlocked {
                return achievement1.isUnlocked && !achievement2.isUnlocked
            }
            return achievement1.rarity.rawValue > achievement2.rarity.rawValue
        }
    }
    
    private var stats: AchievementStats {
        AchievementStats(achievements: achievements)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Stats
                headerStatsView
                
                // Search and Filter
                searchAndFilterView
                
                // Category Selector
                categorySelector
                
                // Achievements List
                achievementsList
            }
            .background(Color.appBackground)
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
        }
    }
    
    // MARK: - Header Stats
    
    private var headerStatsView: some View {
        VStack(spacing: 16) {
            // Progress Ring and Summary
            HStack(spacing: 30) {
                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: stats.completionPercentage / 100)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: stats.completionPercentage)
                    
                    VStack(spacing: 4) {
                        Text("\(Int(stats.completionPercentage))%")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primaryText)
                        
                        Text("Complete")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
                
                // Stats Summary
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(
                        icon: "checkmark.circle.fill",
                        label: "Unlocked",
                        value: "\(stats.unlockedCount) / \(stats.totalCount)",
                        color: .green
                    )
                    
                    StatRow(
                        icon: "star.fill",
                        label: "Points Earned",
                        value: "\(stats.totalPoints)",
                        color: .yellow
                    )
                    
                    StatRow(
                        icon: "crown.fill",
                        label: "Rare & Above",
                        value: "\(stats.rareCount)",
                        color: .purple
                    )
                }
            }
            
            // Achievement Rarity Breakdown
            rarityBreakdownView
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var rarityBreakdownView: some View {
        HStack(spacing: 16) {
            ForEach(AchievementRarity.allCases.reversed(), id: \.self) { rarity in
                let count = achievements.filter { $0.isUnlocked && $0.rarity == rarity }.count
                
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(rarity.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(rarity.color)
                    }
                    
                    Text(rarity.title)
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
            }
        }
    }
    
    // MARK: - Search and Filter
    
    private var searchAndFilterView: some View {
        HStack(spacing: 16) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondaryText)
                
                TextField("Search achievements...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Filter Toggle
            Button(action: {
                HapticManager.shared.impact(.light)
                showOnlyUnlocked.toggle()
            }) {
                Image(systemName: showOnlyUnlocked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(showOnlyUnlocked ? .green : .secondaryText)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Category Selector
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    let categoryAchievements = achievements.filter { $0.category == category }
                    let unlockedCount = categoryAchievements.filter { $0.isUnlocked }.count
                    
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category,
                        totalCount: categoryAchievements.count,
                        unlockedCount: unlockedCount
                    ) {
                        HapticManager.shared.impact(.light)
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Achievements List
    
    private var achievementsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredAchievements.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredAchievements, id: \.id) { achievement in
                        AchievementDetailCard(achievement: achievement)
                            .onTapGesture {
                                HapticManager.shared.impact(.medium)
                                // Show detailed achievement view or animation
                            }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? selectedCategory.icon : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondaryText)
            
            Text(searchText.isEmpty ? "No achievements in this category" : "No matching achievements")
                .font(.headline)
                .foregroundColor(.primaryText)
            
            Text(searchText.isEmpty ? 
                 "Keep exploring to unlock \(selectedCategory.title.lowercased()) achievements!" :
                 "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Supporting Views

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            Spacer()
        }
    }
}

struct CategoryChip: View {
    let category: AchievementCategory
    let isSelected: Bool
    let totalCount: Int
    let unlockedCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? category.color : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? .white : .gray)
                }
                
                VStack(spacing: 2) {
                    Text(category.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .primaryText : .secondaryText)
                    
                    if totalCount > 0 {
                        Text("\(unlockedCount)/\(totalCount)")
                            .font(.caption2)
                            .foregroundColor(.tertiaryText)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct AchievementDetailCard: View {
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 16) {
            // Achievement Icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.rarity.gradient : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(achievement.isUnlocked ? .white : .gray)
            }
            .opacity(achievement.isUnlocked ? 1.0 : 0.6)
            
            // Achievement Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(achievement.displayTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Rarity Badge
                    Text(achievement.rarity.title.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(achievement.rarity.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(achievement.rarity.color.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Text(achievement.displayDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
                
                // Progress or Unlock Info
                if achievement.isUnlocked {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        if let unlockedAt = achievement.unlockedAt {
                            Text("Unlocked \(unlockedAt, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                        
                        if achievement.reward.value > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                
                                Text("+\(achievement.reward.value)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                } else if achievement.isProgressVisible {
                    VStack(spacing: 6) {
                        HStack {
                            Text("Progress")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            Spacer()
                            
                            Text("\(achievement.progress) / \(achievement.requirement.targetValue)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                        }
                        
                        ProgressView(value: achievement.progressPercentage / 100.0)
                            .progressViewStyle(CustomProgressViewStyle(color: achievement.category.color))
                            .frame(height: 4)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(achievement.rarity.color.opacity(achievement.isUnlocked ? 0.3 : 0), lineWidth: 2)
        )
    }
}

// MARK: - Preview

#Preview {
    AchievementDetailView(userId: "preview-user")
} 