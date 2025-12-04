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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Current Streak Card
                        currentStreakCard
                        
                        // Streak Status
                        streakStatusCard
                        
                        // Milestones Section
                        milestonesSection
                        
                        // Stats Grid
                        statsGrid
                        
                        // Encouragement
                        encouragementCard
                    }
                    .padding()
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
        }
        .task {
            await viewModel.loadStreakInfo()
        }
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
}

// MARK: - Preview

#Preview {
    StreakView()
}


