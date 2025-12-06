//
//  ReferralsView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Clerk

// MARK: - Referrals View

struct ReferralsView: View {
    @StateObject private var viewModel = ReferralsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Referral Code Card
                        referralCodeCard
                        
                        // Stats Section
                        statsSection
                        
                        // Rewards Section
                        if !viewModel.rewards.isEmpty || viewModel.unclaimedRewardsCount > 0 {
                            rewardsSection
                        }
                        
                        // Friends Who Joined
                        if !viewModel.friendsJoined.isEmpty {
                            friendsJoinedSection
                        }
                        
                        // Share Options
                        shareOptionsSection
                    }
                    .padding()
                }
                
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("Referrals")
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
            await viewModel.loadReferralData()
        }
    }
    
    // MARK: - Referral Code Card
    
    private var referralCodeCard: some View {
        VStack(spacing: 16) {
            Text("Your Referral Code")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            Text(viewModel.referralCode ?? "Loading...")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.primaryText)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.primaryBrand.opacity(0.3), lineWidth: 2)
                        )
                )
            
            Button(action: {
                HapticManager.shared.impact(.light)
                viewModel.copyReferralCode()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                    Text(viewModel.copied ? "Copied!" : "Copy Code")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primaryBrand)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
        )
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            statCard(
                icon: "paperplane.fill",
                value: "\(viewModel.stats?.totalInvitesSent ?? 0)",
                label: "Invites Sent",
                color: .blue
            )
            
            statCard(
                icon: "person.badge.plus",
                value: "\(viewModel.stats?.friendsJoined ?? 0)",
                label: "Friends Joined",
                color: .green
            )
            
            statCard(
                icon: "gift.fill",
                value: "\(viewModel.stats?.rewardsEarned ?? 0)",
                label: "Rewards",
                color: .orange
            )
        }
    }
    
    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }
            
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
    
    // MARK: - Rewards Section
    
    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Rewards")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                if viewModel.unclaimedRewardsCount > 0 {
                    Text("\(viewModel.unclaimedRewardsCount) unclaimed")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(10)
                }
            }
            
            if viewModel.rewards.isEmpty {
                HStack {
                    Image(systemName: "gift")
                        .font(.title2)
                        .foregroundColor(.secondaryText)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Invite friends to earn rewards!")
                            .font(.subheadline)
                            .foregroundColor(.primaryText)
                        Text("1 referral = Streak Freeze")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cardBackground)
                )
            } else {
                ForEach(viewModel.rewards) { reward in
                    RewardCard(reward: reward) {
                        Task {
                            await viewModel.claimReward(reward.id)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Friends Joined Section
    
    private var friendsJoinedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Friends Who Joined")
                .font(.headline)
                .foregroundColor(.primaryText)
            
            ForEach(viewModel.friendsJoined, id: \.id) { friend in
                HStack(spacing: 12) {
                    // Avatar
                    if let avatarUrl = friend.profileImage, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.cardBackground
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.primaryBrand.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String((friend.name ?? friend.username ?? "?").prefix(1)).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.primaryBrand)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(friend.name ?? friend.username ?? "Unknown")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                        
                        if let joinedAt = friend.joinedAt {
                            Text("Joined \(formatDate(joinedAt))")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.cardBackground)
                )
            }
        }
    }
    
    // MARK: - Share Options Section
    
    private var shareOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite Friends")
                .font(.headline)
                .foregroundColor(.primaryText)
            
            HStack(spacing: 12) {
                shareButton(
                    icon: "square.and.arrow.up",
                    label: "Share Link",
                    color: .primaryBrand
                ) {
                    viewModel.shareReferralLink()
                }
                
                shareButton(
                    icon: "message.fill",
                    label: "Message",
                    color: .green
                ) {
                    viewModel.shareViaMessage()
                }
                
                shareButton(
                    icon: "doc.on.doc",
                    label: "Copy",
                    color: .blue
                ) {
                    viewModel.copyReferralCode()
                }
            }
        }
    }
    
    private func shareButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Loading...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardBackground)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ isoString: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        guard let date = dateFormatter.date(from: isoString) else {
            return "recently"
        }
        
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .abbreviated
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Referral Stats Model

struct ReferralStats {
    let totalInvitesSent: Int
    let pendingInvites: Int
    let friendsJoined: Int
    let rewardsEarned: Int
}

struct ReferredFriend: Identifiable, Codable {
    let id: String
    let name: String?
    let username: String?
    let profileImage: String?
    let joinedAt: String?
}

// MARK: - Reward Card

struct RewardCard: View {
    let reward: BackendService.ReferralRewardItem
    let onClaim: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Reward Icon
            ZStack {
                Circle()
                    .fill(rewardColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: reward.rewardIcon)
                    .font(.system(size: 20))
                    .foregroundColor(rewardColor)
            }
            
            // Reward Info
            VStack(alignment: .leading, spacing: 4) {
                Text(reward.rewardDescription)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("Milestone: \(reward.milestone) referral\(reward.milestone > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            // Claim Button or Status
            if reward.isClaimable {
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    onClaim()
                }) {
                    Text("Claim")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.primaryBrand)
                        .cornerRadius(16)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Claimed")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(reward.isClaimable ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        )
    }
    
    private var rewardColor: Color {
        switch reward.type {
        case "STREAK_FREEZE":
            return .cyan
        case "PREMIUM_WEEK", "PREMIUM_MONTH":
            return .purple
        case "BADGE":
            return .orange
        case "VIP_STATUS":
            return .yellow
        default:
            return .primaryBrand
        }
    }
}

// MARK: - Referrals View Model

@MainActor
class ReferralsViewModel: ObservableObject {
    @Published var referralCode: String?
    @Published var stats: ReferralStats?
    @Published var friendsJoined: [ReferredFriend] = []
    @Published var rewards: [BackendService.ReferralRewardItem] = []
    @Published var unclaimedRewardsCount: Int = 0
    @Published var isLoading = false
    @Published var copied = false
    
    private let backendService = BackendService.shared
    
    func loadReferralData() async {
        isLoading = true
        
        do {
            // Load referral code
            let codeResponse = try await backendService.getReferralCode()
            referralCode = codeResponse.code
            
            // Load stats
            let statsResponse = try await backendService.getReferralStats()
            stats = ReferralStats(
                totalInvitesSent: statsResponse.totalInvitesSent,
                pendingInvites: statsResponse.pendingInvites,
                friendsJoined: statsResponse.friendsJoined,
                rewardsEarned: statsResponse.rewardsEarned
            )
            
            friendsJoined = statsResponse.friends
            
            // Load rewards
            await loadRewards()
            
        } catch {
            print("❌ ReferralsViewModel: Failed to load referral data: \(error)")
        }
        
        isLoading = false
    }
    
    func loadRewards() async {
        do {
            let rewardsResponse = try await backendService.getReferralRewards()
            rewards = rewardsResponse.rewards
            unclaimedRewardsCount = rewardsResponse.unclaimedCount
        } catch {
            print("❌ ReferralsViewModel: Failed to load rewards: \(error)")
        }
    }
    
    func claimReward(_ rewardId: String) async {
        do {
            let result = try await backendService.claimReferralReward(rewardId)
            if result.success {
                HapticManager.shared.impact(.success)
                // Reload rewards to update the UI
                await loadRewards()
            } else {
                print("⚠️ ReferralsViewModel: Failed to claim reward: \(result.message)")
            }
        } catch {
            print("❌ ReferralsViewModel: Error claiming reward: \(error)")
        }
    }
    
    func copyReferralCode() {
        guard let code = referralCode else { return }
        UIPasteboard.general.string = code
        copied = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.copied = false
        }
    }
    
    func shareReferralLink() {
        guard let code = referralCode else { return }
        let message = "Join me on Palytt! Use my referral code: \(code)\n\nhttps://palytt.app/invite/\(code)"
        
        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    func shareViaMessage() {
        // For now, use the same share flow
        shareReferralLink()
    }
}

// MARK: - Preview

#Preview {
    ReferralsView()
}

