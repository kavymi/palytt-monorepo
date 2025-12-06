//
//  FriendMessagesViewModel.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation
import SwiftUI
import Combine
import Clerk

#if canImport(ConvexMobile)
import ConvexMobile
#endif

// MARK: - Conversation Summary

struct ConversationSummary: Identifiable, Equatable {
    let friendClerkId: String
    let friendName: String?
    let friendProfileImage: String?
    let lastPost: SharedPostData?
    let unreadCount: Int
    let lastActivityDate: Date?
    
    var id: String { friendClerkId }
}

// MARK: - Friend Messages ViewModel

@MainActor
class FriendMessagesViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Current conversation's shared posts
    @Published var sharedPosts: [SharedPostData] = []
    
    /// List of conversations for Messages tab
    @Published var conversations: [ConversationSummary] = []
    
    /// Total unread count across all conversations
    @Published var totalUnreadCount: Int = 0
    
    /// Loading states
    @Published var isLoadingConversation: Bool = false
    @Published var isLoadingConversations: Bool = false
    @Published var isSendingPost: Bool = false
    
    /// Error handling
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let backendService = BackendService.shared
    private let apiConfig = APIConfigurationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    #if canImport(ConvexMobile)
    private var convexClient: ConvexClient?
    private var conversationSubscription: ConvexSubscription<[ConvexSharedPost]>?
    private var conversationsListSubscription: ConvexSubscription<[ConvexConversation]>?
    private var unreadCountSubscription: ConvexSubscription<ConvexUnreadCount>?
    #endif
    
    // Current user and friend IDs for the active conversation
    private var currentUserClerkId: String?
    private var activeFriendClerkId: String?
    
    // MARK: - Initialization
    
    init() {
        setupConvexClient()
    }
    
    deinit {
        // Cancel subscriptions directly without calling the async method
        #if canImport(ConvexMobile)
        conversationSubscription?.cancel()
        conversationsListSubscription?.cancel()
        unreadCountSubscription?.cancel()
        #endif
    }
    
    // MARK: - Setup
    
    private func setupConvexClient() {
        #if canImport(ConvexMobile)
        guard backendService.isConvexAvailable else {
            print("🟡 FriendMessagesViewModel: Convex not available on this architecture")
            return
        }
        
        let deploymentUrl = apiConfig.convexDeploymentURL
        convexClient = ConvexClient(deploymentUrl: deploymentUrl)
        print("🟢 FriendMessagesViewModel: Convex client initialized")
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Load conversation between current user and a friend
    func loadConversation(with friendClerkId: String) async {
        guard let currentUserId = Clerk.shared.user?.id else {
            errorMessage = "Please sign in to view messages"
            return
        }
        
        currentUserClerkId = currentUserId
        activeFriendClerkId = friendClerkId
        isLoadingConversation = true
        errorMessage = nil
        
        #if canImport(ConvexMobile)
        if let client = convexClient {
            await subscribeToConversation(client: client, userClerkId: currentUserId, friendClerkId: friendClerkId)
        } else {
            // Fallback to one-time fetch if Convex not available
            await fetchConversationOnce(userClerkId: currentUserId, friendClerkId: friendClerkId)
        }
        #else
        await fetchConversationOnce(userClerkId: currentUserId, friendClerkId: friendClerkId)
        #endif
        
        isLoadingConversation = false
        
        // Mark conversation as read
        await markConversationAsRead(friendClerkId: friendClerkId)
    }
    
    /// Load all conversations for the Messages tab
    func loadConversationsList() async {
        guard let currentUserId = Clerk.shared.user?.id else {
            errorMessage = "Please sign in to view messages"
            return
        }
        
        currentUserClerkId = currentUserId
        isLoadingConversations = true
        errorMessage = nil
        
        #if canImport(ConvexMobile)
        if let client = convexClient {
            await subscribeToConversationsList(client: client, clerkId: currentUserId)
        } else {
            await fetchConversationsListOnce(clerkId: currentUserId)
        }
        #else
        await fetchConversationsListOnce(clerkId: currentUserId)
        #endif
        
        isLoadingConversations = false
    }
    
    /// Share a post with a friend
    func sharePost(_ post: Post, with friendClerkId: String) async {
        guard let currentUser = Clerk.shared.user else {
            errorMessage = "Please sign in to share posts"
            return
        }
        
        isSendingPost = true
        errorMessage = nil
        
        do {
            #if canImport(ConvexMobile)
            if let client = convexClient {
                try await sharePostViaConvex(
                    client: client,
                    senderClerkId: currentUser.id,
                    senderName: currentUser.fullName ?? currentUser.username ?? "Unknown",
                    senderProfileImage: currentUser.imageUrl?.absoluteString,
                    recipientClerkId: friendClerkId,
                    post: post
                )
            } else {
                // Fallback to backend API
                try await sharePostViaBackend(
                    senderClerkId: currentUser.id,
                    recipientClerkId: friendClerkId,
                    post: post
                )
            }
            #else
            try await sharePostViaBackend(
                senderClerkId: currentUser.id,
                recipientClerkId: friendClerkId,
                post: post
            )
            #endif
            
            HapticManager.shared.haptic(.success)
            print("✅ FriendMessagesViewModel: Post shared successfully")
            
        } catch {
            errorMessage = "Failed to share post: \(error.localizedDescription)"
            HapticManager.shared.haptic(.error)
            print("❌ FriendMessagesViewModel: Failed to share post: \(error)")
        }
        
        isSendingPost = false
    }
    
    /// Mark all posts from a friend as read
    func markConversationAsRead(friendClerkId: String) async {
        guard let currentUserId = currentUserClerkId else { return }
        
        #if canImport(ConvexMobile)
        if let client = convexClient {
            do {
                let _ = try await client.mutation(
                    "sharedPosts:markConversationAsRead",
                    args: [
                        "recipientClerkId": currentUserId,
                        "senderClerkId": friendClerkId
                    ]
                )
                print("✅ FriendMessagesViewModel: Marked conversation as read")
            } catch {
                print("❌ FriendMessagesViewModel: Failed to mark as read: \(error)")
            }
        }
        #endif
    }
    
    /// Subscribe to total unread count
    func subscribeToUnreadCount() async {
        guard let currentUserId = Clerk.shared.user?.id else { return }
        
        #if canImport(ConvexMobile)
        if let client = convexClient {
            await subscribeToUnreadCountInternal(client: client, clerkId: currentUserId)
        }
        #endif
    }
    
    /// Stop all subscriptions
    func stopAllSubscriptions() {
        #if canImport(ConvexMobile)
        conversationSubscription?.cancel()
        conversationsListSubscription?.cancel()
        unreadCountSubscription?.cancel()
        conversationSubscription = nil
        conversationsListSubscription = nil
        unreadCountSubscription = nil
        #endif
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Convex Subscriptions
    
    #if canImport(ConvexMobile)
    
    private func subscribeToConversation(client: ConvexClient, userClerkId: String, friendClerkId: String) async {
        // Cancel existing subscription
        conversationSubscription?.cancel()
        
        do {
            conversationSubscription = client.subscribe(
                to: "sharedPosts:getConversation",
                args: [
                    "userClerkId": userClerkId,
                    "friendClerkId": friendClerkId,
                    "limit": 50
                ]
            )
            
            // Process updates
            Task { @MainActor in
                guard let subscription = conversationSubscription else { return }
                for try await posts in subscription {
                    self.sharedPosts = posts.map { self.convertToSharedPostData($0, currentUserId: userClerkId) }
                    print("🔄 FriendMessagesViewModel: Received \(posts.count) shared posts")
                }
            }
        }
    }
    
    private func subscribeToConversationsList(client: ConvexClient, clerkId: String) async {
        // Cancel existing subscription
        conversationsListSubscription?.cancel()
        
        do {
            conversationsListSubscription = client.subscribe(
                to: "sharedPosts:getConversationsList",
                args: ["clerkId": clerkId]
            )
            
            // Process updates
            Task { @MainActor in
                guard let subscription = conversationsListSubscription else { return }
                for try await convos in subscription {
                    self.conversations = convos.map { self.convertToConversationSummary($0) }
                    print("🔄 FriendMessagesViewModel: Received \(convos.count) conversations")
                }
            }
        }
    }
    
    private func subscribeToUnreadCountInternal(client: ConvexClient, clerkId: String) async {
        // Cancel existing subscription
        unreadCountSubscription?.cancel()
        
        do {
            unreadCountSubscription = client.subscribe(
                to: "sharedPosts:getUnreadCount",
                args: ["clerkId": clerkId]
            )
            
            // Process updates
            Task { @MainActor in
                guard let subscription = unreadCountSubscription else { return }
                for try await result in subscription {
                    self.totalUnreadCount = result.count
                    print("🔄 FriendMessagesViewModel: Unread count: \(result.count)")
                }
            }
        }
    }
    
    private func sharePostViaConvex(
        client: ConvexClient,
        senderClerkId: String,
        senderName: String,
        senderProfileImage: String?,
        recipientClerkId: String,
        post: Post
    ) async throws {
        let postPreview: [String: Any?] = [
            "title": post.title,
            "imageUrl": post.mediaURLs.first?.absoluteString,
            "shopName": post.shop?.name,
            "authorName": post.author.displayName,
            "authorClerkId": post.author.clerkId
        ]
        
        var args: [String: Any] = [
            "senderClerkId": senderClerkId,
            "senderName": senderName,
            "recipientClerkId": recipientClerkId,
            "postId": post.convexId.isEmpty ? post.id.uuidString : post.convexId,
            "postPreview": postPreview.compactMapValues { $0 }
        ]
        
        if let profileImage = senderProfileImage {
            args["senderProfileImage"] = profileImage
        }
        
        let _ = try await client.mutation("sharedPosts:sharePost", args: args)
    }
    
    #endif
    
    // MARK: - Fallback Methods (when Convex is not available)
    
    private func fetchConversationOnce(userClerkId: String, friendClerkId: String) async {
        // This would call a backend API endpoint
        // For now, we'll just set empty data
        print("⚠️ FriendMessagesViewModel: Convex not available, using fallback")
        sharedPosts = []
    }
    
    private func fetchConversationsListOnce(clerkId: String) async {
        // This would call a backend API endpoint
        // For now, we'll just set empty data
        print("⚠️ FriendMessagesViewModel: Convex not available, using fallback")
        conversations = []
    }
    
    private func sharePostViaBackend(
        senderClerkId: String,
        recipientClerkId: String,
        post: Post
    ) async throws {
        // This would call a backend API endpoint
        // For now, we'll throw an error
        throw NSError(domain: "FriendMessagesViewModel", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Post sharing via backend not yet implemented"
        ])
    }
    
    // MARK: - Data Conversion
    
    #if canImport(ConvexMobile)
    
    private func convertToSharedPostData(_ convexPost: ConvexSharedPost, currentUserId: String) -> SharedPostData {
        SharedPostData(
            id: convexPost._id,
            senderClerkId: convexPost.senderClerkId,
            senderName: convexPost.senderName,
            senderProfileImage: convexPost.senderProfileImage,
            recipientClerkId: convexPost.recipientClerkId,
            postId: convexPost.postId,
            postTitle: convexPost.postPreview.title,
            postImageUrl: convexPost.postPreview.imageUrl,
            postShopName: convexPost.postPreview.shopName,
            postAuthorName: convexPost.postPreview.authorName,
            postAuthorClerkId: convexPost.postPreview.authorClerkId,
            isRead: convexPost.isRead,
            createdAt: Date(timeIntervalSince1970: Double(convexPost.createdAt) / 1000.0)
        )
    }
    
    private func convertToConversationSummary(_ convexConvo: ConvexConversation) -> ConversationSummary {
        let lastPost: SharedPostData? = convexConvo.lastPost.map { post in
            SharedPostData(
                id: post._id,
                senderClerkId: post.senderClerkId,
                senderName: post.senderName,
                senderProfileImage: post.senderProfileImage,
                recipientClerkId: post.recipientClerkId,
                postId: post.postId,
                postTitle: post.postPreview.title,
                postImageUrl: post.postPreview.imageUrl,
                postShopName: post.postPreview.shopName,
                postAuthorName: post.postPreview.authorName,
                postAuthorClerkId: post.postPreview.authorClerkId,
                isRead: post.isRead,
                createdAt: Date(timeIntervalSince1970: Double(post.createdAt) / 1000.0)
            )
        }
        
        return ConversationSummary(
            friendClerkId: convexConvo.friendClerkId,
            friendName: convexConvo.friendName,
            friendProfileImage: convexConvo.friendProfileImage,
            lastPost: lastPost,
            unreadCount: convexConvo.unreadCount,
            lastActivityDate: lastPost?.createdAt
        )
    }
    
    #endif
}

// MARK: - Convex Data Models

#if canImport(ConvexMobile)

struct ConvexPostPreview: Codable {
    let title: String?
    let imageUrl: String?
    let shopName: String?
    let authorName: String?
    let authorClerkId: String?
}

struct ConvexSharedPost: Codable {
    let _id: String
    let senderClerkId: String
    let senderName: String?
    let senderProfileImage: String?
    let recipientClerkId: String
    let postId: String
    let postPreview: ConvexPostPreview
    let isRead: Bool
    let createdAt: Int64
}

struct ConvexConversation: Codable {
    let friendClerkId: String
    let friendName: String?
    let friendProfileImage: String?
    let lastPost: ConvexSharedPost?
    let unreadCount: Int
}

struct ConvexUnreadCount: Codable {
    let count: Int
}

#endif

