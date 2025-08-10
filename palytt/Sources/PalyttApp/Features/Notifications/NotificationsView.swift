//
//  NotificationsView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Kingfisher
import Clerk
#if !targetEnvironment(simulator)
// import ConvexMobile // temporarily disabled
#endif

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    @ObservedObject private var notificationService = PalyttNotificationService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.isLoading {
                        ForEach(0..<5, id: \.self) { _ in
                            NotificationRowSkeleton()
                        }
                    } else if viewModel.friendRequests.isEmpty && notificationService.notifications.isEmpty {
                        EmptyStateView(
                            icon: "bell",
                            title: "No Notifications",
                            message: "When people interact with your posts or send friend requests, you'll see them here"
                        )
                        .padding(.top, 100)
                    } else {
                        // General Notifications Section
                        if !notificationService.notifications.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recent Activity")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primaryText)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                ForEach(notificationService.notifications, id: \._id) { notification in
                                    NotificationRowView(notification: notification) {
                                        await notificationService.markAsRead(notificationId: notification._id)
                                    }
                                }
                            }
                        }
                        
                        // Friend Requests Section
                        if !viewModel.friendRequests.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Friend Requests")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primaryText)
                                    
                                    Spacer()
                                    
                                    if viewModel.friendRequests.count > 1 {
                                        Text("\(viewModel.friendRequests.count)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.primaryBrand)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal)
                                
                                ForEach(viewModel.friendRequests, id: \._id) { request in
                                    NotificationFriendRequestRowView(request: request) { action in
                                        await viewModel.handleFriendRequest(request, action: action)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Notifications")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await notificationService.markAllAsRead()
                            await viewModel.loadNotifications()
                        }
                    }) {
                        Text("Mark All Read")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .disabled(notificationService.notifications.isEmpty || notificationService.notifications.allSatisfy(\.isRead))
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task {
                            await notificationService.markAllAsRead()
                            await viewModel.loadNotifications()
                        }
                    }) {
                        Text("Mark All Read")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .disabled(notificationService.notifications.isEmpty || notificationService.notifications.allSatisfy(\.isRead))
                }
                #endif
            }
            .refreshable {
                // Refresh both friend requests and notifications
                await viewModel.loadNotifications()
                await notificationService.refreshNotifications()
            }
            .task {
                // Initial load of notifications
                await viewModel.loadNotifications()
                
                // Ensure notification subscription is active
                if notificationService.notifications.isEmpty {
                    notificationService.subscribeToNotifications()
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil || notificationService.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                    notificationService.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? notificationService.errorMessage ?? "Unknown error occurred")
            }
            .onDisappear {
                // Don't cancel the subscription when disappearing, as we want to keep it active
                // but mark all as read
                Task {
                    await notificationService.fetchUnreadCount()
                }
            }
        }
    }
}

// MARK: - General Notification Row
struct NotificationRowView: View {
    let notification: BackendService.BackendNotification
    let onTap: () async -> Void
    
    var body: some View {
        Button(action: {
            Task {
                await onTap()
            }
        }) {
            HStack(spacing: 12) {
                // Icon based on notification type
                notificationIcon
                    .frame(width: 50, height: 50)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(.subheadline)
                        .fontWeight(notification.isRead ? .medium : .semibold)
                        .foregroundColor(.primaryText)
                        .multilineTextAlignment(.leading)
                    
                    Text(notification.message)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.leading)
                    
                    Text(formatTimestamp(Date(timeIntervalSince1970: Double(notification.createdAt) / 1000)))
                        .font(.caption2)
                        .foregroundColor(.tertiaryText)
                }
                
                Spacer()
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.primaryBrand)
                        .frame(width: 8, height: 8)
                }
            }
            .padding()
            .background(notification.isRead ? Color.cardBackground : Color.cardBackground.opacity(0.8))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var notificationIcon: some View {
        let iconConfig = getIconConfig(for: notification.type)
        
        return ZStack {
            Circle()
                .fill(iconConfig.color.opacity(0.15))
            
            Image(systemName: iconConfig.name)
                .foregroundColor(iconConfig.color)
                .font(.title3)
        }
    }
    
    private func getIconConfig(for type: BackendService.NotificationType) -> (name: String, color: Color) {
        switch type {
        case .friendRequest, .friendRequestAccepted:
            return ("person.badge.plus", .primaryBrand)
        case .newFollower:
            return ("person.fill.checkmark", .green)
        case .postLike:
            return ("heart.fill", .red)
        case .postComment:
            return ("message.fill", .blue)
        case .commentLike:
            return ("hand.thumbsup.fill", .orange)
        case .friendPost:
            return ("photo.fill", .purple)
        case .postMention:
            return ("at", .blue)
        case .message:
            return ("envelope.fill", .green)
        case .general:
            return ("bell.fill", .gray)
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Friend Request Row
struct NotificationFriendRequestRowView: View {
    let request: BackendService.FriendRequest
    let onAction: (FriendRequestAction) async -> Void
    @State private var isProcessing = false
    
    enum FriendRequestAction {
        case accept, reject
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(LinearGradient.primaryGradient)
                .frame(width: 50, height: 50)
                .overlay(
                    Text((request.sender?.displayName ?? "U").prefix(1).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("\(request.sender?.displayName ?? "Someone") sent you a friend request")
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                
                Text(formatTimestamp(Date(timeIntervalSince1970: Double(request.createdAt) / 1000)))
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button("Accept") {
                        isProcessing = true
                        Task {
                            await onAction(.accept)
                            isProcessing = false
                        }
                        HapticManager.shared.impact(.success)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isProcessing)
                    
                    Button("Decline") {
                        isProcessing = true
                        Task {
                            await onAction(.reject)
                            isProcessing = false
                        }
                        HapticManager.shared.impact(.light)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isProcessing)
                }
                .padding(.top, 4)
            }
            
            Spacer()
            
            if isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Skeleton View
struct NotificationRowSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .shimmer(isAnimating: $isAnimating)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .shimmer(isAnimating: $isAnimating)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 12)
                    .shimmer(isAnimating: $isAnimating)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Notifications View Model
@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var friendRequests: [BackendService.FriendRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    
    func loadNotifications() async {
        guard let currentUser = Clerk.shared.user else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Load friend request notifications for the dedicated section
            friendRequests = try await backendService.getPendingFriendRequests(userId: currentUser.id)
            
            // Refresh notification service
            await PalyttNotificationService.shared.fetchUnreadCount()
        } catch {
            print("❌ Failed to load notifications: \(error)")
            errorMessage = "Failed to load notifications: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func handleFriendRequest(_ request: BackendService.FriendRequest, action: NotificationFriendRequestRowView.FriendRequestAction) async {
        do {
            switch action {
            case .accept:
                let response = try await backendService.acceptFriendRequest(requestId: request._id)
                if response.success {
                    friendRequests.removeAll { $0._id == request._id }
                    HapticManager.shared.impact(.success)
                    // Reload notifications to update the list
                    await loadNotifications()
                }
            case .reject:
                let response = try await backendService.rejectFriendRequest(requestId: request._id)
                if response.success {
                    friendRequests.removeAll { $0._id == request._id }
                    HapticManager.shared.impact(.light)
                    // Reload notifications to update the list
                    await loadNotifications()
                }
            }
        } catch {
            errorMessage = "Failed to handle friend request: \(error.localizedDescription)"
            print("❌ Failed to handle friend request: \(error)")
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
}

#Preview {
    NotificationsView()
        .environmentObject(MockAppState())
} 