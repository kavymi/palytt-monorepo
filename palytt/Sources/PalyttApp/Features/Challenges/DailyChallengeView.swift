//
//  DailyChallengeView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI

// MARK: - Daily Challenge Banner (Compact for Home Feed)

struct DailyChallengeBanner: View {
    @StateObject private var challengeService = ChallengeService.shared
    @State private var showAllChallenges = false
    @State private var isPulsing = false
    
    var body: some View {
        if let topChallenge = challengeService.activeChallenges.first {
            VStack(spacing: 0) {
                Button(action: {
                    HapticManager.shared.impact(.light)
                    showAllChallenges = true
                }) {
                    HStack(spacing: 12) {
                        // Challenge icon with urgency indicator
                        ZStack {
                            Circle()
                                .fill(topChallenge.type.accentColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: topChallenge.iconName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(topChallenge.type.accentColor)
                            
                            // Urgency pulse
                            if topChallenge.urgencyLevel.pulseAnimation {
                                Circle()
                                    .stroke(topChallenge.urgencyLevel.color, lineWidth: 2)
                                    .frame(width: 44, height: 44)
                                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                                    .opacity(isPulsing ? 0 : 0.8)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(topChallenge.type.displayName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(topChallenge.type.accentColor)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                
                                Text("•")
                                    .foregroundColor(.tertiaryText)
                                
                                Text(topChallenge.timeRemainingFormatted)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(topChallenge.urgencyLevel.color)
                            }
                            
                            Text(topChallenge.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primaryText)
                                .lineLimit(1)
                            
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 4)
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(topChallenge.type.accentColor)
                                        .frame(width: geo.size.width * topChallenge.progressPercentage, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        
                        Spacer()
                        
                        // Reward preview
                        VStack(spacing: 2) {
                            Image(systemName: topChallenge.reward.type.icon)
                                .font(.system(size: 14))
                                .foregroundColor(.primaryBrand)
                            
                            Text("+\(topChallenge.reward.value)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primaryBrand)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.tertiaryText)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appCardBackground)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(topChallenge.type.accentColor.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // More challenges indicator
                if challengeService.activeChallenges.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<min(challengeService.activeChallenges.count, 4), id: \.self) { index in
                            Circle()
                                .fill(index == 0 ? Color.primaryBrand : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                        
                        if challengeService.activeChallenges.count > 4 {
                            Text("+\(challengeService.activeChallenges.count - 4)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondaryText)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 12)
            .onAppear {
                if topChallenge.urgencyLevel.pulseAnimation {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
            .sheet(isPresented: $showAllChallenges) {
                AllChallengesView()
            }
        }
    }
}

// MARK: - All Challenges View (Full Screen)

struct AllChallengesView: View {
    @StateObject private var challengeService = ChallengeService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ChallengeTab = .active
    
    enum ChallengeTab: String, CaseIterable {
        case active = "Active"
        case completed = "Completed"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                tabSelector
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedTab {
                        case .active:
                            activeChallengesSection
                        case .completed:
                            completedChallengesSection
                        }
                    }
                    .padding()
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Challenges")
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
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ChallengeTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    HapticManager.shared.impact(.light)
                }) {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: .semibold))
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
    }
    
    @ViewBuilder
    private var activeChallengesSection: some View {
        if challengeService.activeChallenges.isEmpty {
            EmptyChallengesView(type: .active)
        } else {
            ForEach(challengeService.activeChallenges) { challenge in
                ChallengeCard(challenge: challenge)
            }
        }
    }
    
    @ViewBuilder
    private var completedChallengesSection: some View {
        if challengeService.completedChallenges.isEmpty {
            EmptyChallengesView(type: .completed)
        } else {
            ForEach(challengeService.completedChallenges) { challenge in
                ChallengeCard(challenge: challenge, isCompleted: true)
            }
        }
    }
}

// MARK: - Challenge Card

struct ChallengeCard: View {
    let challenge: Challenge
    var isCompleted: Bool = false
    
    @State private var showDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(challenge.category.color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: challenge.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(challenge.category.color)
                    
                    if isCompleted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 18, y: 18)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(challenge.type.displayName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(challenge.type.accentColor)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        if !isCompleted {
                            Text("•")
                                .foregroundColor(.tertiaryText)
                            
                            Text(challenge.timeRemainingFormatted)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(challenge.urgencyLevel.color)
                        }
                    }
                    
                    Text(challenge.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primaryText)
                    
                    Text(challenge.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // Progress section
            if !isCompleted {
                VStack(spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondaryText)
                        
                        Spacer()
                        
                        Text("\(challenge.progress)/\(challenge.requirement.targetValue)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primaryText)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [challenge.category.color, challenge.category.color.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * challenge.progressPercentage, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
            
            // Reward section
            HStack(spacing: 8) {
                Image(systemName: challenge.reward.type.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.primaryBrand)
                
                Text(challenge.reward.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Text("+\(challenge.reward.value)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primaryBrand)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.primaryBrand.opacity(0.1))
                    )
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isCompleted ? Color.green.opacity(0.3) :
                    (challenge.urgencyLevel == .critical ? challenge.urgencyLevel.color.opacity(0.3) : Color.clear),
                    lineWidth: 2
                )
        )
        .opacity(isCompleted ? 0.8 : 1.0)
    }
}

// MARK: - Empty Challenges View

struct EmptyChallengesView: View {
    enum EmptyType {
        case active
        case completed
    }
    
    let type: EmptyType
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: type == .active ? "flag.fill" : "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.primaryBrand)
            }
            
            VStack(spacing: 8) {
                Text(type == .active ? "No Active Challenges" : "No Completed Challenges Yet")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text(type == .active ?
                     "Check back soon for new challenges!" :
                     "Complete challenges to earn rewards and badges")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Challenge Completion Celebration

struct ChallengeCompletionView: View {
    let challenge: Challenge
    @State private var showConfetti = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Trophy animation
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [challenge.category.color, challenge.category.color.opacity(0.3)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(scale)
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .scaleEffect(scale)
                }
                
                VStack(spacing: 12) {
                    Text("Challenge Complete!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(challenge.title)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // Reward
                HStack(spacing: 12) {
                    Image(systemName: challenge.reward.type.icon)
                        .font(.title2)
                        .foregroundColor(.primaryBrand)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(challenge.reward.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("+\(challenge.reward.value) \(challenge.reward.type.rawValue)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.15))
                )
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            HapticManager.shared.impact(.success)
        }
    }
}

// MARK: - Profile Challenges Section

struct ProfileChallengesSection: View {
    @StateObject private var challengeService = ChallengeService.shared
    @State private var showAllChallenges = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("Challenges")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Button(action: {
                    HapticManager.shared.impact(.light)
                    showAllChallenges = true
                }) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
            .padding(.horizontal, 16)
            
            // Active challenges preview
            if challengeService.activeChallenges.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 32))
                        .foregroundColor(.tertiaryText)
                    
                    Text("No active challenges")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Text("Check back soon for new challenges!")
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appCardBackground)
                )
                .padding(.horizontal, 16)
            } else {
                // Show up to 2 active challenges
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(challengeService.activeChallenges.prefix(3)) { challenge in
                            CompactChallengeCard(challenge: challenge)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Stats summary
            HStack(spacing: 0) {
                ChallengeStatItem(
                    value: "\(challengeService.activeChallenges.count)",
                    label: "Active",
                    icon: "flame.fill",
                    color: .orange
                )
                
                Divider()
                    .frame(height: 30)
                
                ChallengeStatItem(
                    value: "\(challengeService.completedChallenges.count)",
                    label: "Completed",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                Divider()
                    .frame(height: 30)
                
                ChallengeStatItem(
                    value: "\(calculateTotalPoints())",
                    label: "Points",
                    icon: "star.fill",
                    color: .primaryBrand
                )
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.appCardBackground)
            )
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showAllChallenges) {
            AllChallengesView()
        }
    }
    
    private func calculateTotalPoints() -> Int {
        challengeService.completedChallenges.reduce(0) { $0 + $1.reward.value }
    }
}

// MARK: - Compact Challenge Card (for Profile)

struct CompactChallengeCard: View {
    let challenge: Challenge
    @State private var isPulsing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with icon and type
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(challenge.type.accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: challenge.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(challenge.type.accentColor)
                    
                    // Urgency indicator
                    if challenge.urgencyLevel.pulseAnimation {
                        Circle()
                            .stroke(challenge.urgencyLevel.color, lineWidth: 2)
                            .frame(width: 36, height: 36)
                            .scaleEffect(isPulsing ? 1.15 : 1.0)
                            .opacity(isPulsing ? 0 : 0.6)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.type.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(challenge.type.accentColor)
                        .textCase(.uppercase)
                    
                    Text(challenge.timeRemainingFormatted)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(challenge.urgencyLevel.color)
                }
                
                Spacer()
            }
            
            // Title
            Text(challenge.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primaryText)
                .lineLimit(2)
            
            Spacer()
            
            // Progress and reward
            VStack(spacing: 8) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(challenge.type.accentColor)
                            .frame(width: geo.size.width * challenge.progressPercentage, height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text("\(Int(challenge.progressPercentage * 100))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Image(systemName: challenge.reward.type.icon)
                            .font(.system(size: 10))
                        Text("+\(challenge.reward.value)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
        }
        .padding(14)
        .frame(width: 180, height: 160)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(challenge.type.accentColor.opacity(0.15), lineWidth: 1)
        )
        .onAppear {
            if challenge.urgencyLevel.pulseAnimation {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }
}

// MARK: - Challenge Stat Item

struct ChallengeStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primaryText)
            }
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview("Daily Challenge Banner") {
    VStack {
        DailyChallengeBanner()
    }
    .padding()
    .background(Color.appBackground)
}

#Preview("All Challenges") {
    AllChallengesView()
}

#Preview("Challenge Card") {
    ChallengeCard(
        challenge: Challenge(
            id: "test",
            title: "Morning Foodie",
            description: "Share your breakfast before 10am",
            type: .daily,
            category: .timing,
            requirement: ChallengeRequirement(
                type: .postCount,
                targetValue: 1,
                criteria: [:]
            ),
            reward: ChallengeReward(
                type: .points,
                value: 50,
                title: "Early Bird Bonus",
                description: "Extra points",
                bonusMultiplier: 1.5
            ),
            iconName: "sunrise.fill",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            isRecurring: true,
            recurringSchedule: nil,
            progress: 0,
            isCompleted: false,
            completedAt: nil
        )
    )
    .padding()
    .background(Color.appBackground)
}

