//
//  AchievementViews.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Achievement Card View

struct AchievementCardView: View {
    let achievement: Achievement
    let isCompact: Bool
    
    init(_ achievement: Achievement, compact: Bool = false) {
        self.achievement = achievement
        self.isCompact = compact
    }
    
    var body: some View {
        if isCompact {
            compactView
        } else {
            fullView
        }
    }
    
    private var compactView: some View {
        HStack(spacing: 12) {
            achievementIcon
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text(achievement.displayDescription)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
                
                if !achievement.isUnlocked && achievement.isProgressVisible {
                    ProgressView(value: achievement.progressPercentage / 100.0)
                        .progressViewStyle(CustomProgressViewStyle(color: achievement.category.color))
                        .frame(height: 4)
                }
            }
            
            Spacer()
            
            rarityBadge
        }
        .padding(12)
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var fullView: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                achievementIcon
                    .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(achievement.displayTitle)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    
                    HStack(spacing: 8) {
                        categoryBadge
                        rarityBadge
                    }
                }
                
                Spacer()
                
                if achievement.isUnlocked {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        if let unlockedAt = achievement.unlockedAt {
                            Text("Unlocked")
                                .font(.caption2)
                                .foregroundColor(.secondaryText)
                            
                            Text(unlockedAt, style: .date)
                                .font(.caption2)
                                .foregroundColor(.tertiaryText)
                        }
                    }
                }
            }
            
            // Description
            Text(achievement.displayDescription)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Progress Section
            if !achievement.isUnlocked {
                progressSection
            }
            
            // Reward Section
            if achievement.isUnlocked || !achievement.isSecret {
                rewardSection
            }
        }
        .padding(20)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(achievement.rarity.color.opacity(0.3), lineWidth: achievement.isUnlocked ? 2 : 0)
        )
    }
    
    private var achievementIcon: some View {
        ZStack {
            Circle()
                .fill(achievement.isUnlocked ? achievement.rarity.gradient : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom))
            
            Image(systemName: achievement.iconName)
                .font(.system(size: isCompact ? 20 : 24, weight: .medium))
                .foregroundColor(achievement.isUnlocked ? .white : .gray)
                .scaleEffect(achievement.isUnlocked ? 1.0 : 0.8)
        }
        .opacity(achievement.isUnlocked ? 1.0 : 0.6)
    }
    
    private var categoryBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: achievement.category.icon)
                .font(.caption2)
            Text(achievement.category.title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(achievement.category.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(achievement.category.color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var rarityBadge: some View {
        Text(achievement.rarity.title.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(achievement.rarity.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(achievement.rarity.color.opacity(0.1))
            .cornerRadius(6)
    }
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                
                Spacer()
                
                Text("\(achievement.progress) / \(achievement.requirement.targetValue)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            ProgressView(value: achievement.progressPercentage / 100.0)
                .progressViewStyle(CustomProgressViewStyle(color: achievement.category.color))
                .frame(height: 6)
        }
    }
    
    private var rewardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reward")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondaryText)
            
            HStack(spacing: 8) {
                Image(systemName: achievement.reward.type.icon)
                    .font(.caption)
                    .foregroundColor(.primaryBrand)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(achievement.reward.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    
                    Text(achievement.reward.description)
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                if achievement.reward.value > 0 {
                    Text("+\(achievement.reward.value)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryBrand)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: isCompact ? 12 : 16)
            .fill(Color.cardBackground)
    }
}

// MARK: - Achievement Category Grid

struct AchievementCategoryGridView: View {
    let achievements: [AchievementCategory: [Achievement]]
    let userId: String
    @State private var selectedCategory: AchievementCategory = .culinary
    
    var body: some View {
        VStack(spacing: 16) {
            // Category Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AchievementCategory.allCases, id: \.self) { category in
                        CategoryButton(
                            category: category,
                            isSelected: selectedCategory == category,
                            count: achievements[category]?.count ?? 0,
                            unlockedCount: achievements[category]?.filter { $0.isUnlocked }.count ?? 0
                        ) {
                            HapticManager.shared.impact(.light)
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Achievements List
            if let categoryAchievements = achievements[selectedCategory] {
                LazyVStack(spacing: 12) {
                    ForEach(categoryAchievements, id: \.id) { achievement in
                        AchievementCardView(achievement, compact: true)
                            .onTapGesture {
                                HapticManager.shared.impact(.medium)
                                // Show detailed view
                            }
                    }
                }
                .padding(.horizontal)
            } else {
                EmptyAchievementView(category: selectedCategory)
            }
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let category: AchievementCategory
    let isSelected: Bool
    let count: Int
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
                    
                    if count > 0 {
                        Text("\(unlockedCount)/\(count)")
                            .font(.caption2)
                            .foregroundColor(.tertiaryText)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Achievement Stats View

struct AchievementStatsView: View {
    let achievements: [Achievement]
    
    private var stats: AchievementStats {
        AchievementStats(achievements: achievements)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Achievement Progress")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
            
            HStack(spacing: 20) {
                StatItem(
                    title: "Unlocked",
                    value: "\(stats.unlockedCount)",
                    subtitle: "of \(stats.totalCount)",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                StatItem(
                    title: "Points",
                    value: "\(stats.totalPoints)",
                    subtitle: "earned",
                    color: .blue,
                    icon: "star.fill"
                )
                
                StatItem(
                    title: "Rare+",
                    value: "\(stats.rareCount)",
                    subtitle: "achievements",
                    color: .purple,
                    icon: "crown.fill"
                )
            }
            
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: stats.completionPercentage / 100)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("\(Int(stats.completionPercentage))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    
                    Text("Complete")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Achievement Unlock Celebration

struct AchievementUnlockView: View {
    let achievement: Achievement
    @Binding var isPresented: Bool
    @State private var animationPhase = 0
    @State private var sparkleOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissCelebration()
                }
            
            VStack(spacing: 24) {
                // Celebration Icon
                ZStack {
                    // Sparkle effects
                    ForEach(0..<8, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.title)
                            .foregroundColor(.yellow)
                            .offset(
                                x: cos(Double(index) * .pi / 4) * (60 + sparkleOffset),
                                y: sin(Double(index) * .pi / 4) * (60 + sparkleOffset)
                            )
                            .opacity(animationPhase >= 1 ? 1 : 0)
                            .scaleEffect(animationPhase >= 1 ? 1 : 0)
                    }
                    
                    // Achievement Icon
                    ZStack {
                        Circle()
                            .fill(achievement.rarity.gradient)
                            .frame(width: 100, height: 100)
                            .scaleEffect(animationPhase >= 0 ? 1 : 0)
                        
                        Image(systemName: achievement.iconName)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(animationPhase >= 0 ? 1 : 0)
                    }
                    .shadow(color: achievement.rarity.color.opacity(0.5), radius: 20, x: 0, y: 10)
                }
                
                // Achievement Info
                VStack(spacing: 16) {
                    Text("Achievement Unlocked!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(animationPhase >= 2 ? 1 : 0)
                    
                    VStack(spacing: 8) {
                        Text(achievement.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(achievement.description)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .opacity(animationPhase >= 2 ? 1 : 0)
                    
                    // Rarity Badge
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(achievement.rarity.color)
                        
                        Text(achievement.rarity.title.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(achievement.rarity.color)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(achievement.rarity.color.opacity(0.2))
                    .cornerRadius(20)
                    .opacity(animationPhase >= 3 ? 1 : 0)
                }
                
                // Close Button
                Button(action: dismissCelebration) {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(LinearGradient.primaryGradient)
                        .cornerRadius(25)
                }
                .opacity(animationPhase >= 3 ? 1 : 0)
            }
            .padding(40)
        }
        .onAppear {
            startCelebrationAnimation()
        }
    }
    
    private func startCelebrationAnimation() {
        // Phase 0: Icon appears
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            animationPhase = 0
        }
        
        // Phase 1: Sparkles appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) {
                animationPhase = 1
            }
            
            // Sparkle animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                sparkleOffset = 20
            }
        }
        
        // Phase 2: Text appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.4)) {
                animationPhase = 2
            }
        }
        
        // Phase 3: Badge and button appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                animationPhase = 3
            }
        }
        
        // Haptic feedback
        HapticManager.shared.impact(.heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            HapticManager.shared.impact(.medium)
        }
    }
    
    private func dismissCelebration() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

// MARK: - Empty Achievement View

struct EmptyAchievementView: View {
    let category: AchievementCategory
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.system(size: 50))
                .foregroundColor(category.color.opacity(0.5))
            
            Text("No \(category.title) Achievements Yet")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            Text("Keep exploring to unlock achievements in this category!")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Custom Progress View Style

struct CustomProgressViewStyle: ProgressViewStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * (configuration.fractionCompleted ?? 0), height: 8)
                    .animation(.easeInOut(duration: 0.5), value: configuration.fractionCompleted)
            }
        }
    }
}

// MARK: - Achievement Stats Helper

struct AchievementStats {
    let totalCount: Int
    let unlockedCount: Int
    let totalPoints: Int
    let rareCount: Int
    let completionPercentage: Double
    
    init(achievements: [Achievement]) {
        totalCount = achievements.count
        unlockedCount = achievements.filter { $0.isUnlocked }.count
        totalPoints = achievements.filter { $0.isUnlocked }.reduce(0) { $0 + $1.reward.value }
        rareCount = achievements.filter { $0.isUnlocked && ($0.rarity == .rare || $0.rarity == .epic || $0.rarity == .legendary) }.count
        completionPercentage = totalCount > 0 ? (Double(unlockedCount) / Double(totalCount)) * 100 : 0
    }
}

// MARK: - Preview

#Preview("Achievement Card") {
    VStack(spacing: 16) {
        AchievementCardView(DefaultAchievements.all[0], compact: true)
        AchievementCardView(DefaultAchievements.all[1])
    }
    .padding()
}

#Preview("Achievement Stats") {
    AchievementStatsView(achievements: DefaultAchievements.all)
        .padding()
} 