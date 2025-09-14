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

struct NotificationsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingMarkAllAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if notificationService.notifications.isEmpty && !notificationService.isLoading {
                    emptyStateView
                } else {
                    notificationsList
                }
                
                if notificationService.isLoading && notificationService.notifications.isEmpty {
                    loadingView
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !notificationService.notifications.isEmpty {
                        Button("Mark All Read") {
                            showingMarkAllAlert = true
                        }
                        .font(.system(size: 14, weight: .medium))
                    }
                }
            }
            .alert("Mark All as Read", isPresented: $showingMarkAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Mark All Read") {
                    Task {
                        await notificationService.markAllAsRead()
                    }
                }
            } message: {
                Text("This will mark all notifications as read.")
            }
            .refreshable {
                await notificationService.refresh()
            }
        }
        .task {
            await notificationService.loadNotifications(refresh: true)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.tertiaryText)
            
            VStack(spacing: 8) {
                Text("No Notifications")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("When you receive notifications, they'll appear here")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading notifications...")
                .font(.body)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(notificationService.notifications) { notification in
                    NotificationRowView(notification: notification)
                        .onAppear {
                            // Load more notifications when reaching the end
                            if notification.id == notificationService.notifications.last?.id {
                                Task {
                                    await notificationService.loadNotifications()
                                }
                            }
                        }
                }
                
                if notificationService.isLoading && !notificationService.notifications.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more...")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.vertical, 20)
                }
            }
        }
    }
}

// MARK: - Notification Row View
struct NotificationRowView: View {
    let notification: PalyttNotification
    @StateObject private var notificationService = NotificationService.shared
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            handleNotificationTap()
        }) {
            HStack(spacing: 12) {
                // Notification icon
                notificationIcon
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // Sender info and action
                        Text(notification.senderName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primaryText) +
                        Text(" \(notification.actionText)")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondaryText)
                        
                        Spacer()
                        
                        // Time
                        Text(notification.timeAgo)
                            .font(.caption)
                            .foregroundColor(.tertiaryText)
                    }
                    
                    // Additional content based on notification type
                    if let postTitle = notification.data?.postTitle, !postTitle.isEmpty {
                        Text(postTitle)
                            .font(.system(size: 14))
                            .foregroundColor(.secondaryText)
                            .lineLimit(2)
                    }
                    
                    // Username if available
                    if let username = notification.senderUsername {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundColor(.tertiaryText)
                    }
                }
                
                // Post image if available
                if let postImageURL = notification.postImageURL {
                    AsyncImage(url: postImageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.cardBackground)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.primaryBrand)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(notification.isRead ? Color.clear : Color.primaryBrand.opacity(0.05))
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0) { pressing in
            isPressed = pressing
        } perform: {
            // Long press action - mark as read
            if !notification.isRead {
                Task {
                    await notificationService.markAsRead(notificationIds: [notification.id])
                }
            }
        }
        .contextMenu {
            if !notification.isRead {
                Button(action: {
                    Task {
                        await notificationService.markAsRead(notificationIds: [notification.id])
                    }
                }) {
                    Label("Mark as Read", systemImage: "checkmark.circle")
                }
            }
        }
    }
    
    private var notificationIcon: some View {
        ZStack {
            Circle()
                .fill(Color(notification.type.iconColor).opacity(0.15))
                .frame(width: 40, height: 40)
            
            Image(systemName: notification.type.iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(notification.type.iconColor))
        }
    }
    
    private func handleNotificationTap() {
        // Mark as read if unread
        if !notification.isRead {
            Task {
                await notificationService.markAsRead(notificationIds: [notification.id])
            }
        }
        
        // Handle navigation based on notification type
        // TODO: Implement navigation to relevant screens
        switch notification.type {
        case .postLike, .comment, .commentLike:
            // Navigate to post detail
            if let postId = notification.data?.postId {
                print("Navigate to post: \(postId)")
                // NavigationManager.shared.navigateToPost(postId)
            }
        case .friendRequest:
            // Navigate to friend requests
            print("Navigate to friend requests")
            // NavigationManager.shared.navigateToFriendRequests()
        case .friendAccepted:
            // Navigate to user profile
            if let senderId = notification.data?.senderId {
                print("Navigate to user profile: \(senderId)")
                // NavigationManager.shared.navigateToProfile(senderId)
            }
        case .message:
            // Navigate to messages
            print("Navigate to messages")
            // NavigationManager.shared.navigateToMessages()
        default:
            print("Notification tapped: \(notification.type.displayName)")
        }
    }
}

#Preview {
    NotificationsView()
        .preferredColorScheme(.light)
}