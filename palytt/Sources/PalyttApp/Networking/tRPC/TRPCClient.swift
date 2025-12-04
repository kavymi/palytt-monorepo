//
//  TRPCClient.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  Type-safe tRPC client for making API calls.
//

import Foundation

// MARK: - tRPC Client Protocol

/// Protocol for type-safe tRPC operations
protocol TRPCClientProtocol {
    /// Execute a tRPC query (GET request)
    func query<P: TRPCQuery, Input: Encodable, Output: Decodable>(
        _ procedure: P.Type,
        input: Input
    ) async throws -> Output where P.Input == Input, P.Output == Output
    
    /// Execute a tRPC query without input (GET request)
    func query<P: TRPCQuery, Output: Decodable>(
        _ procedure: P.Type
    ) async throws -> Output where P.Input == EmptyInput, P.Output == Output
    
    /// Execute a tRPC mutation (POST request)
    func mutate<P: TRPCMutation, Input: Encodable, Output: Decodable>(
        _ procedure: P.Type,
        input: Input
    ) async throws -> Output where P.Input == Input, P.Output == Output
    
    /// Execute a tRPC mutation without input (POST request)
    func mutate<P: TRPCMutation, Output: Decodable>(
        _ procedure: P.Type
    ) async throws -> Output where P.Input == EmptyInput, P.Output == Output
}

// MARK: - tRPC Procedure Protocol Extensions

/// Protocol that all tRPC procedures conform to
protocol TRPCProcedure {
    associatedtype Input: Encodable
    associatedtype Output: Decodable
    static var procedure: String { get }
}

// MARK: - tRPC Client Implementation

/// Type-safe tRPC client for making API calls
@MainActor
final class TRPCClient: TRPCClientProtocol {
    
    // MARK: - Properties
    
    private let apiClient: APIClientProtocol
    
    // MARK: - Shared Instance
    
    /// Shared instance using the current API configuration
    static var shared: TRPCClient {
        let baseURL = URL(string: APIConfigurationManager.shared.currentBaseURL)!
        return TRPCClient(apiClient: APIClient(baseURL: baseURL))
    }
    
    // MARK: - Initialization
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    convenience init(baseURL: URL) {
        self.init(apiClient: APIClient(baseURL: baseURL))
    }
    
    // MARK: - Query Methods
    
    /// Execute a tRPC query with input
    func query<P: TRPCQuery, Input: Encodable, Output: Decodable>(
        _ procedure: P.Type,
        input: Input
    ) async throws -> Output where P.Input == Input, P.Output == Output {
        guard let procedureType = procedure as? any TRPCProcedure.Type else {
            throw APIError.invalidData
        }
        return try await apiClient.call(
            procedure: procedureType.procedure,
            input: input,
            method: .get
        )
    }
    
    /// Execute a tRPC query without input
    func query<P: TRPCQuery, Output: Decodable>(
        _ procedure: P.Type
    ) async throws -> Output where P.Input == EmptyInput, P.Output == Output {
        guard let procedureType = procedure as? any TRPCProcedure.Type else {
            throw APIError.invalidData
        }
        return try await apiClient.call(
            procedure: procedureType.procedure,
            input: EmptyInput(),
            method: .get
        )
    }
    
    // MARK: - Mutation Methods
    
    /// Execute a tRPC mutation with input
    func mutate<P: TRPCMutation, Input: Encodable, Output: Decodable>(
        _ procedure: P.Type,
        input: Input
    ) async throws -> Output where P.Input == Input, P.Output == Output {
        guard let procedureType = procedure as? any TRPCProcedure.Type else {
            throw APIError.invalidData
        }
        return try await apiClient.call(
            procedure: procedureType.procedure,
            input: input,
            method: .post
        )
    }
    
    /// Execute a tRPC mutation without input
    func mutate<P: TRPCMutation, Output: Decodable>(
        _ procedure: P.Type
    ) async throws -> Output where P.Input == EmptyInput, P.Output == Output {
        guard let procedureType = procedure as? any TRPCProcedure.Type else {
            throw APIError.invalidData
        }
        return try await apiClient.call(
            procedure: procedureType.procedure,
            input: EmptyInput(),
            method: .post
        )
    }
    
    // MARK: - Convenience Methods (Direct Procedure Calls)
    
    /// Call a procedure by name with input (for dynamic usage)
    func call<Input: Encodable, Output: Decodable>(
        procedure: String,
        input: Input,
        isQuery: Bool = true
    ) async throws -> Output {
        return try await apiClient.call(
            procedure: procedure,
            input: input,
            method: isQuery ? .get : .post
        )
    }
    
    /// Call a procedure by name without input
    func call<Output: Decodable>(
        procedure: String,
        isQuery: Bool = true
    ) async throws -> Output {
        return try await apiClient.call(
            procedure: procedure,
            method: isQuery ? .get : .post
        )
    }
}

// MARK: - Type-Safe Router Extensions

/// Extension providing type-safe access to posts procedures
extension TRPCClient {
    
    // MARK: - Posts
    
    func getRecentPosts(limit: Int = 20, page: Int = 1) async throws -> PostsProcedures.GetRecentPosts.Output {
        let input = PostsProcedures.GetRecentPosts.Input(limit: limit, page: page)
        return try await call(procedure: PostsProcedures.GetRecentPosts.procedure, input: input)
    }
    
    func getFeedPosts(limit: Int = 20, cursor: String? = nil) async throws -> PostsProcedures.GetFeedPosts.Output {
        let input = PostsProcedures.GetFeedPosts.Input(limit: limit, cursor: cursor)
        return try await call(procedure: PostsProcedures.GetFeedPosts.procedure, input: input)
    }
    
    func getPostById(id: String) async throws -> TRPCPost {
        let input = PostsProcedures.GetPostById.Input(id: id)
        return try await call(procedure: PostsProcedures.GetPostById.procedure, input: input)
    }
    
    func getPostsByUserId(userId: String, limit: Int = 20, cursor: String? = nil) async throws -> PostsProcedures.GetPostsByUserId.Output {
        let input = PostsProcedures.GetPostsByUserId.Input(userId: userId, limit: limit, cursor: cursor)
        return try await call(procedure: PostsProcedures.GetPostsByUserId.procedure, input: input)
    }
    
    func likePost(postId: String) async throws -> PostsProcedures.LikePost.Output {
        let input = PostsProcedures.LikePost.Input(postId: postId)
        return try await call(procedure: PostsProcedures.LikePost.procedure, input: input, isQuery: false)
    }
    
    func savePost(postId: String) async throws -> PostsProcedures.SavePost.Output {
        let input = PostsProcedures.SavePost.Input(postId: postId)
        return try await call(procedure: PostsProcedures.SavePost.procedure, input: input, isQuery: false)
    }
    
    func getSavedPosts(limit: Int = 20, cursor: String? = nil) async throws -> PostsProcedures.GetSavedPosts.Output {
        let input = PostsProcedures.GetSavedPosts.Input(limit: limit, cursor: cursor)
        return try await call(procedure: PostsProcedures.GetSavedPosts.procedure, input: input)
    }
    
    func searchPosts(query: String, limit: Int = 20, cursor: String? = nil) async throws -> PostsProcedures.SearchPosts.Output {
        let input = PostsProcedures.SearchPosts.Input(query: query, limit: limit, cursor: cursor)
        return try await call(procedure: PostsProcedures.SearchPosts.procedure, input: input)
    }
    
    // MARK: - Users
    
    func getUserByClerkId(clerkId: String) async throws -> TRPCUser? {
        let input = UsersProcedures.GetUserByClerkId.Input(clerkId: clerkId)
        return try await call(procedure: UsersProcedures.GetUserByClerkId.procedure, input: input)
    }
    
    func getUserByUsername(username: String) async throws -> TRPCUser? {
        let input = UsersProcedures.GetByUsername.Input(username: username)
        return try await call(procedure: UsersProcedures.GetByUsername.procedure, input: input)
    }
    
    func searchUsers(query: String, limit: Int = 20) async throws -> [TRPCUser] {
        let input = UsersProcedures.SearchUsers.Input(query: query, limit: limit)
        return try await call(procedure: UsersProcedures.SearchUsers.procedure, input: input)
    }
    
    // MARK: - Friends
    
    func sendFriendRequest(receiverId: String) async throws -> TRPCFriend {
        let input = FriendsProcedures.SendRequest.Input(receiverId: receiverId)
        return try await call(procedure: FriendsProcedures.SendRequest.procedure, input: input, isQuery: false)
    }
    
    func acceptFriendRequest(requestId: String) async throws -> TRPCFriend {
        let input = FriendsProcedures.AcceptRequest.Input(requestId: requestId)
        return try await call(procedure: FriendsProcedures.AcceptRequest.procedure, input: input, isQuery: false)
    }
    
    func rejectFriendRequest(requestId: String) async throws -> SuccessResponse {
        let input = FriendsProcedures.RejectRequest.Input(requestId: requestId)
        return try await call(procedure: FriendsProcedures.RejectRequest.procedure, input: input, isQuery: false)
    }
    
    func getFriends(userId: String? = nil, limit: Int = 50, cursor: String? = nil) async throws -> FriendsProcedures.GetFriends.Output {
        let input = FriendsProcedures.GetFriends.Input(userId: userId, limit: limit, cursor: cursor)
        return try await call(procedure: FriendsProcedures.GetFriends.procedure, input: input)
    }
    
    func getPendingFriendRequests(type: FriendRequestFilterType = .all, limit: Int = 20, cursor: String? = nil) async throws -> FriendsProcedures.GetPendingRequests.Output {
        let input = FriendsProcedures.GetPendingRequests.Input(type: type, limit: limit, cursor: cursor)
        return try await call(procedure: FriendsProcedures.GetPendingRequests.procedure, input: input)
    }
    
    func areFriends(userId1: String, userId2: String) async throws -> Bool {
        let input = FriendsProcedures.AreFriends.Input(userId1: userId1, userId2: userId2)
        let response: FriendsProcedures.AreFriends.Output = try await call(procedure: FriendsProcedures.AreFriends.procedure, input: input)
        return response.areFriends
    }
    
    func removeFriend(friendId: String) async throws -> SuccessResponse {
        let input = FriendsProcedures.RemoveFriend.Input(friendId: friendId)
        return try await call(procedure: FriendsProcedures.RemoveFriend.procedure, input: input, isQuery: false)
    }
    
    func blockUser(userId: String) async throws -> SuccessResponse {
        let input = FriendsProcedures.BlockUser.Input(userId: userId)
        return try await call(procedure: FriendsProcedures.BlockUser.procedure, input: input, isQuery: false)
    }
    
    func getMutualFriends(userId1: String, userId2: String, limit: Int = 10) async throws -> FriendsProcedures.GetMutualFriends.Output {
        let input = FriendsProcedures.GetMutualFriends.Input(userId1: userId1, userId2: userId2, limit: limit)
        return try await call(procedure: FriendsProcedures.GetMutualFriends.procedure, input: input)
    }
    
    func getFriendSuggestions(limit: Int = 20) async throws -> FriendsProcedures.GetFriendSuggestions.Output {
        let input = FriendsProcedures.GetFriendSuggestions.Input(limit: limit)
        return try await call(procedure: FriendsProcedures.GetFriendSuggestions.procedure, input: input)
    }
    
    // MARK: - Follows
    
    func follow(userId: String) async throws -> TRPCFollow {
        let input = FollowsProcedures.Follow.Input(userId: userId)
        return try await call(procedure: FollowsProcedures.Follow.procedure, input: input, isQuery: false)
    }
    
    func unfollow(userId: String) async throws -> SuccessResponse {
        let input = FollowsProcedures.Unfollow.Input(userId: userId)
        return try await call(procedure: FollowsProcedures.Unfollow.procedure, input: input, isQuery: false)
    }
    
    func getFollowing(userId: String? = nil, limit: Int = 50, cursor: String? = nil) async throws -> FollowsProcedures.GetFollowing.Output {
        let input = FollowsProcedures.GetFollowing.Input(userId: userId, limit: limit, cursor: cursor)
        return try await call(procedure: FollowsProcedures.GetFollowing.procedure, input: input)
    }
    
    func getFollowers(userId: String? = nil, limit: Int = 50, cursor: String? = nil) async throws -> FollowsProcedures.GetFollowers.Output {
        let input = FollowsProcedures.GetFollowers.Input(userId: userId, limit: limit, cursor: cursor)
        return try await call(procedure: FollowsProcedures.GetFollowers.procedure, input: input)
    }
    
    func isFollowing(followerId: String, followingId: String) async throws -> Bool {
        let input = FollowsProcedures.IsFollowing.Input(followerId: followerId, followingId: followingId)
        let response: FollowsProcedures.IsFollowing.Output = try await call(procedure: FollowsProcedures.IsFollowing.procedure, input: input)
        return response.isFollowing
    }
    
    func getFollowStats(userId: String) async throws -> TRPCFollowStats {
        let input = FollowsProcedures.GetFollowStats.Input(userId: userId)
        return try await call(procedure: FollowsProcedures.GetFollowStats.procedure, input: input)
    }
    
    func getSuggestedFollows(limit: Int = 10) async throws -> FollowsProcedures.GetSuggestedFollows.Output {
        let input = FollowsProcedures.GetSuggestedFollows.Input(limit: limit)
        return try await call(procedure: FollowsProcedures.GetSuggestedFollows.procedure, input: input)
    }
    
    // MARK: - Comments
    
    func getComments(postId: String, limit: Int = 20, cursor: String? = nil) async throws -> CommentsProcedures.GetComments.Output {
        let input = CommentsProcedures.GetComments.Input(postId: postId, limit: limit, cursor: cursor)
        return try await call(procedure: CommentsProcedures.GetComments.procedure, input: input)
    }
    
    func addComment(postId: String, content: String) async throws -> TRPCComment {
        let input = CommentsProcedures.AddComment.Input(postId: postId, content: content)
        return try await call(procedure: CommentsProcedures.AddComment.procedure, input: input, isQuery: false)
    }
    
    func deleteComment(commentId: String) async throws -> SuccessResponse {
        let input = CommentsProcedures.DeleteComment.Input(commentId: commentId)
        return try await call(procedure: CommentsProcedures.DeleteComment.procedure, input: input, isQuery: false)
    }
    
    func getCommentsByUser(userId: String, limit: Int = 20, cursor: String? = nil) async throws -> CommentsProcedures.GetCommentsByUser.Output {
        let input = CommentsProcedures.GetCommentsByUser.Input(userId: userId, limit: limit, cursor: cursor)
        return try await call(procedure: CommentsProcedures.GetCommentsByUser.procedure, input: input)
    }
    
    // MARK: - Messages
    
    func getChatrooms(limit: Int = 20, cursor: String? = nil) async throws -> MessagesProcedures.GetChatrooms.Output {
        let input = MessagesProcedures.GetChatrooms.Input(limit: limit, cursor: cursor)
        return try await call(procedure: MessagesProcedures.GetChatrooms.procedure, input: input)
    }
    
    func createDirectChatroom(participantId: String) async throws -> TRPCChatroom {
        let input = MessagesProcedures.CreateChatroom.Input(participantId: participantId)
        return try await call(procedure: MessagesProcedures.CreateChatroom.procedure, input: input, isQuery: false)
    }
    
    func createGroupChatroom(participantIds: [String], name: String, description: String? = nil) async throws -> TRPCChatroom {
        let input = MessagesProcedures.CreateChatroom.Input(participantIds: participantIds, name: name, description: description)
        return try await call(procedure: MessagesProcedures.CreateChatroom.procedure, input: input, isQuery: false)
    }
    
    func sendMessage(chatroomId: String, content: String, messageType: TRPCMessageType = .text) async throws -> TRPCMessage {
        let input = MessagesProcedures.SendMessage.Input(chatroomId: chatroomId, content: content, messageType: messageType)
        return try await call(procedure: MessagesProcedures.SendMessage.procedure, input: input, isQuery: false)
    }
    
    func getMessages(chatroomId: String, limit: Int = 50, cursor: String? = nil) async throws -> MessagesProcedures.GetMessages.Output {
        let input = MessagesProcedures.GetMessages.Input(chatroomId: chatroomId, limit: limit, cursor: cursor)
        return try await call(procedure: MessagesProcedures.GetMessages.procedure, input: input)
    }
    
    func markMessagesAsRead(chatroomId: String, messageIds: [String]? = nil) async throws -> SuccessResponse {
        let input = MessagesProcedures.MarkMessagesAsRead.Input(chatroomId: chatroomId, messageIds: messageIds)
        return try await call(procedure: MessagesProcedures.MarkMessagesAsRead.procedure, input: input, isQuery: false)
    }
    
    func getMessagesUnreadCount() async throws -> Int {
        let response: MessagesProcedures.GetUnreadCount.Output = try await call(procedure: MessagesProcedures.GetUnreadCount.procedure, input: EmptyInput())
        return response.unreadCount
    }
    
    func leaveChatroom(chatroomId: String) async throws -> SuccessResponse {
        let input = MessagesProcedures.LeaveChatroom.Input(chatroomId: chatroomId)
        return try await call(procedure: MessagesProcedures.LeaveChatroom.procedure, input: input, isQuery: false)
    }
    
    // MARK: - Notifications
    
    func getNotifications(limit: Int = 20, cursor: String? = nil, type: NotificationType? = nil, types: [NotificationType]? = nil, unreadOnly: Bool = false) async throws -> NotificationsProcedures.GetNotifications.Output {
        let input = NotificationsProcedures.GetNotifications.Input(limit: limit, cursor: cursor, type: type, types: types, unreadOnly: unreadOnly)
        return try await call(procedure: NotificationsProcedures.GetNotifications.procedure, input: input)
    }
    
    func markNotificationsAsRead(notificationIds: [String]? = nil) async throws -> SuccessResponse {
        let input = NotificationsProcedures.MarkAsRead.Input(notificationIds: notificationIds)
        return try await call(procedure: NotificationsProcedures.MarkAsRead.procedure, input: input, isQuery: false)
    }
    
    func markAllNotificationsAsRead() async throws -> SuccessResponse {
        return try await call(procedure: NotificationsProcedures.MarkAllAsRead.procedure, input: EmptyInput(), isQuery: false)
    }
    
    func getNotificationsUnreadCount() async throws -> Int {
        let response: NotificationsProcedures.GetUnreadCount.Output = try await call(procedure: NotificationsProcedures.GetUnreadCount.procedure, input: EmptyInput())
        return response.count
    }
    
    func deleteNotifications(notificationIds: [String]) async throws -> SuccessResponse {
        let input = NotificationsProcedures.DeleteNotifications.Input(notificationIds: notificationIds)
        return try await call(procedure: NotificationsProcedures.DeleteNotifications.procedure, input: input, isQuery: false)
    }
    
    func clearAllNotifications() async throws -> SuccessResponse {
        return try await call(procedure: NotificationsProcedures.ClearAll.procedure, input: EmptyInput(), isQuery: false)
    }
    
    func getNotificationSettings() async throws -> TRPCNotificationSettings {
        return try await call(procedure: NotificationsProcedures.GetSettings.procedure, input: EmptyInput())
    }
    
    // MARK: - Lists
    
    func getUserLists(userId: String) async throws -> ListsProcedures.GetUserLists.Output {
        let input = ListsProcedures.GetUserLists.Input(userId: userId)
        return try await call(procedure: ListsProcedures.GetUserLists.procedure, input: input)
    }
    
    func getListById(listId: String) async throws -> TRPCList {
        let input = ListsProcedures.GetListById.Input(listId: listId)
        return try await call(procedure: ListsProcedures.GetListById.procedure, input: input)
    }
    
    func createList(name: String, description: String? = nil, isPublic: Bool = true) async throws -> TRPCList {
        let input = ListsProcedures.CreateList.Input(name: name, description: description, isPublic: isPublic)
        return try await call(procedure: ListsProcedures.CreateList.procedure, input: input, isQuery: false)
    }
    
    func deleteList(listId: String) async throws -> SuccessResponse {
        let input = ListsProcedures.DeleteList.Input(listId: listId)
        return try await call(procedure: ListsProcedures.DeleteList.procedure, input: input, isQuery: false)
    }
    
    func addToList(listId: String, placeId: String, notes: String? = nil) async throws -> TRPCListItem {
        let input = ListsProcedures.AddToList.Input(listId: listId, placeId: placeId, notes: notes)
        return try await call(procedure: ListsProcedures.AddToList.procedure, input: input, isQuery: false)
    }
    
    func removeFromList(listId: String, placeId: String) async throws -> SuccessResponse {
        let input = ListsProcedures.RemoveFromList.Input(listId: listId, placeId: placeId)
        return try await call(procedure: ListsProcedures.RemoveFromList.procedure, input: input, isQuery: false)
    }
    
    // MARK: - Places
    
    func searchPlaces(query: String, limit: Int = 10) async throws -> [TRPCPlace] {
        let input = PlacesProcedures.SearchPlaces.Input(query: query, limit: limit)
        return try await call(procedure: PlacesProcedures.SearchPlaces.procedure, input: input)
    }
}

// MARK: - Mock Client for Testing

#if DEBUG
@MainActor
final class MockTRPCClient: TRPCClientProtocol {
    var shouldFail = false
    var mockError: APIError = .networkError(URLError(.notConnectedToInternet))
    var mockResponses: [String: Any] = [:]
    
    func query<P: TRPCQuery, Input: Encodable, Output: Decodable>(
        _ procedure: P.Type,
        input: Input
    ) async throws -> Output where P.Input == Input, P.Output == Output {
        if shouldFail { throw mockError }
        guard let response = mockResponses[String(describing: procedure)] as? Output else {
            throw APIError.invalidData
        }
        return response
    }
    
    func query<P: TRPCQuery, Output: Decodable>(
        _ procedure: P.Type
    ) async throws -> Output where P.Input == EmptyInput, P.Output == Output {
        if shouldFail { throw mockError }
        guard let response = mockResponses[String(describing: procedure)] as? Output else {
            throw APIError.invalidData
        }
        return response
    }
    
    func mutate<P: TRPCMutation, Input: Encodable, Output: Decodable>(
        _ procedure: P.Type,
        input: Input
    ) async throws -> Output where P.Input == Input, P.Output == Output {
        if shouldFail { throw mockError }
        guard let response = mockResponses[String(describing: procedure)] as? Output else {
            throw APIError.invalidData
        }
        return response
    }
    
    func mutate<P: TRPCMutation, Output: Decodable>(
        _ procedure: P.Type
    ) async throws -> Output where P.Input == EmptyInput, P.Output == Output {
        if shouldFail { throw mockError }
        guard let response = mockResponses[String(describing: procedure)] as? Output else {
            throw APIError.invalidData
        }
        return response
    }
}
#endif
