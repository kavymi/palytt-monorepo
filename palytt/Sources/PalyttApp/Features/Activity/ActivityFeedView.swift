//
//  ActivityFeedView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Clerk
#if canImport(ConvexMobile)
import ConvexMobile
#endif

// MARK: - Activity Feed View

/// Real-time activity feed showing friend activities via Convex
struct ActivityFeedView: View {
    @StateObject private var viewModel = ActivityFeedViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.activities.isEmpty {
                    loadingView
                } else if viewModel.activities.isEmpty {
                    emptyStateView
                } else {
                    activityList
                }
            }
            .navigationTitle("Friend Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.loadActivities()
            viewModel.subscribeToActivities()
        }
        .onDisappear {
            viewModel.unsubscribe()
        }
    }
    
    // MARK: - Activity List
    
    private var activityList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.activities) { activity in
                    ActivityItemView(activity: activity)
                        .padding(.horizontal, 16)
                }
                
                // Load more indicator
                if viewModel.hasMore && !viewModel.isLoading {
                    Button("Load More") {
                        Task { await viewModel.loadMore() }
                    }
                    .font(.subheadline)
                    .foregroundColor(.primaryBrand)
                    .padding()
                } else if viewModel.isLoading {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.top, 16)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.wave.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.tertiaryText)
            
            VStack(spacing: 8) {
                Text("No Friend Activity")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("When your friends post, like, or comment, you'll see their activity here in real-time")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading friend activity...")
                .font(.body)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Activity Item View

struct ActivityItemView: View {
    let activity: FriendActivity
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Actor avatar
            actorAvatar
            
            VStack(alignment: .leading, spacing: 4) {
                // Activity description
                activityDescription
                
                // Timestamp
                Text(activity.timeAgo)
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            }
            
            Spacer()
            
            // Activity icon
            activityIcon
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Actor Avatar
    
    private var actorAvatar: some View {
        Group {
            if let imageUrl = activity.actorProfileImage,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderAvatar
                }
            } else {
                placeholderAvatar
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }
    
    private var placeholderAvatar: some View {
        Circle()
            .fill(LinearGradient.primaryGradient)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 18))
            )
    }
    
    // MARK: - Activity Description
    
    private var activityDescription: some View {
        Group {
            Text(activity.actorName ?? "Someone")
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            +
            Text(" \(activity.activityText)")
                .foregroundColor(.secondaryText)
            +
            Text(activity.targetPreview != nil ? " \"\(activity.targetPreview!)\"" : "")
                .foregroundColor(.primaryText)
                .italic()
        }
        .font(.subheadline)
        .lineLimit(2)
    }
    
    // MARK: - Activity Icon
    
    private var activityIcon: some View {
        Image(systemName: activity.iconName)
            .font(.system(size: 18))
            .foregroundColor(activity.iconColor)
            .frame(width: 32, height: 32)
            .background(activity.iconColor.opacity(0.1))
            .clipShape(Circle())
    }
}

// MARK: - View Model

@MainActor
class ActivityFeedViewModel: ObservableObject {
    @Published var activities: [FriendActivity] = []
    @Published var isLoading: Bool = false
    @Published var hasMore: Bool = true
    @Published var errorMessage: String?
    
    private var isSubscribed = false
    private let limit = 30
    
    #if canImport(ConvexMobile)
    private var convexClient: ConvexClient?
    private var subscriptionTask: Task<Void, Never>?
    #endif
    
    init() {
        #if canImport(ConvexMobile)
        if BackendService.shared.isConvexAvailable {
            let deploymentUrl = APIConfigurationManager.shared.convexDeploymentURL
            convexClient = ConvexClient(deploymentUrl: deploymentUrl)
        }
        #endif
    }
    
    // MARK: - Load Activities
    
    func loadActivities() async {
        guard !isLoading else { return }
        guard let clerkId = Clerk.shared.user?.id else { return }
        
        isLoading = true
        
        #if canImport(ConvexMobile)
        guard let client = convexClient else {
            isLoading = false
            return
        }
        
        do {
            let args: [String: ConvexEncodable] = [
                "clerkId": clerkId,
                "limit": limit
            ]
            
            let result: [ConvexFriendActivity] = try await client.query(
                "friendActivity:getFriendActivityFeed",
                with: args
            )
            
            activities = result.map { $0.toFriendActivity() }
            hasMore = result.count >= limit
            
            print("✅ ActivityFeedViewModel: Loaded \(activities.count) activities")
        } catch {
            print("❌ ActivityFeedViewModel: Failed to load activities: \(error)")
            errorMessage = "Failed to load friend activity"
        }
        #endif
        
        isLoading = false
    }
    
    func loadMore() async {
        // In a real implementation, we'd use cursor-based pagination
        await loadActivities()
    }
    
    func refresh() async {
        activities = []
        await loadActivities()
    }
    
    // MARK: - Subscribe to Real-Time Updates
    
    func subscribeToActivities() {
        guard !isSubscribed else { return }
        guard let clerkId = Clerk.shared.user?.id else { return }
        
        #if canImport(ConvexMobile)
        guard let client = convexClient else { return }
        
        isSubscribed = true
        
        subscriptionTask = Task {
            do {
                let args: [String: ConvexEncodable] = [
                    "clerkId": clerkId,
                    "limit": limit
                ]
                
                for try await result in client.subscribe(to: "friendActivity:getFriendActivityFeed", with: args) as AsyncThrowingStream<[ConvexFriendActivity], Error> {
                    await MainActor.run {
                        let newActivities = result.map { $0.toFriendActivity() }
                        
                        // Check for truly new activities
                        let existingIds = Set(self.activities.map { $0.id })
                        let freshActivities = newActivities.filter { !existingIds.contains($0.id) }
                        
                        if !freshActivities.isEmpty {
                            HapticManager.shared.impact(.light)
                        }
                        
                        self.activities = newActivities
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSubscribed = false
                    print("❌ ActivityFeedViewModel: Subscription error: \(error)")
                }
            }
        }
        
        print("🟢 ActivityFeedViewModel: Subscribed to friend activity feed")
        #endif
    }
    
    func unsubscribe() {
        isSubscribed = false
        #if canImport(ConvexMobile)
        subscriptionTask?.cancel()
        subscriptionTask = nil
        #endif
    }
}

// MARK: - Models

/// Friend activity model for UI
struct FriendActivity: Identifiable {
    let id: String
    let actorClerkId: String
    let actorName: String?
    let actorProfileImage: String?
    let activityType: FriendActivityType
    let targetId: String?
    let targetType: String?
    let targetPreview: String?
    let createdAt: Date
    
    var activityText: String {
        switch activityType {
        case .posted:
            return "shared a new post"
        case .likedPost:
            return "liked a post"
        case .commented:
            return "commented on a post"
        case .followed:
            return "followed someone"
        case .joinedGathering:
            return "joined a gathering"
        case .sharedPlace:
            return "shared a place"
        }
    }
    
    var iconName: String {
        switch activityType {
        case .posted:
            return "square.and.pencil"
        case .likedPost:
            return "heart.fill"
        case .commented:
            return "bubble.left.fill"
        case .followed:
            return "person.badge.plus"
        case .joinedGathering:
            return "person.3.fill"
        case .sharedPlace:
            return "mappin.and.ellipse"
        }
    }
    
    var iconColor: Color {
        switch activityType {
        case .posted:
            return .primaryBrand
        case .likedPost:
            return .red
        case .commented:
            return .blue
        case .followed:
            return .green
        case .joinedGathering:
            return .purple
        case .sharedPlace:
            return .orange
        }
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

enum FriendActivityType: String, Codable {
    case posted
    case likedPost = "liked_post"
    case commented
    case followed
    case joinedGathering = "joined_gathering"
    case sharedPlace = "shared_place"
}

// MARK: - Convex Model

#if canImport(ConvexMobile)
/// Convex friend activity model from subscription
struct ConvexFriendActivity: Codable {
    let _id: String
    let actorClerkId: String
    let actorName: String?
    let actorProfileImage: String?
    let activityType: String
    let targetId: String?
    let targetType: String?
    let targetPreview: String?
    let createdAt: Int64
    let expiresAt: Int64
    
    func toFriendActivity() -> FriendActivity {
        let type = FriendActivityType(rawValue: activityType) ?? .posted
        
        return FriendActivity(
            id: _id,
            actorClerkId: actorClerkId,
            actorName: actorName,
            actorProfileImage: actorProfileImage,
            activityType: type,
            targetId: targetId,
            targetType: targetType,
            targetPreview: targetPreview,
            createdAt: Date(timeIntervalSince1970: Double(createdAt) / 1000.0)
        )
    }
}
#endif

// MARK: - Preview

#Preview {
    ActivityFeedView()
}


