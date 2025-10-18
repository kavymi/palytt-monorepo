//
//  MessagingService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Protocol

protocol MessagingServiceProtocol {
    // Chatrooms
    func getChatrooms(limit: Int) async throws -> [Chatroom]
    func createDirectChatroom(with participantId: String) async throws -> Chatroom
    func createGroupChatroom(name: String, description: String?, participantIds: [String], imageUrl: String?) async throws -> Chatroom
    func updateGroupSettings(chatroomId: String, name: String?, description: String?, imageUrl: String?) async throws -> Chatroom
    func leaveChatroom(_ chatroomId: String) async throws -> Bool
    
    // Messages
    func getMessages(for chatroomId: String, limit: Int) async throws -> [Message]
    func sendTextMessage(_ content: String, to chatroomId: String) async throws -> Message
    func sendMediaMessage(_ mediaUrl: String, content: String, messageType: String, to chatroomId: String) async throws -> Message
    func sendPostShare(_ postId: String, content: String, to chatroomId: String) async throws -> Message
    func sendPlaceShare(_ placeId: String, content: String, to chatroomId: String) async throws -> Message
    func sendLinkShare(url: String, title: String?, description: String?, imageUrl: String?, content: String, to chatroomId: String) async throws -> Message
    func deleteMessage(_ messageId: String, from chatroomId: String) async throws -> Bool
    
    // Participants
    func addParticipants(to chatroomId: String, userIds: [String]) async throws -> Bool
    func removeParticipant(from chatroomId: String, userId: String) async throws -> Bool
    func makeAdmin(in chatroomId: String, userId: String) async throws -> Bool
    
    // Read Status & Typing
    func markMessagesAsRead(in chatroomId: String) async throws -> Int
    func setTypingStatus(_ isTyping: Bool, for chatroomId: String) async throws -> Bool
    func getTypingStatus(for chatroomId: String) async throws -> TypingStatus
    
    // Media & Search
    func getSharedMedia(in chatroomId: String, messageType: String?, limit: Int, cursor: String?) async throws -> [Message]
    func searchUsersForMessaging(query: String, limit: Int) async throws -> [User]
}

// MARK: - Service Implementation

@MainActor
final class MessagingService: MessagingServiceProtocol {
    
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    convenience init(baseURL: URL) {
        let apiClient = APIClient(baseURL: baseURL)
        self.init(apiClient: apiClient)
    }
    
    // MARK: - Chatrooms
    
    func getChatrooms(limit: Int = 50) async throws -> [Chatroom] {
        print("💬 MessagingService: Getting chatrooms")
        
        let request = GetChatroomsRequest(limit: limit)
        
        let response = try await apiClient.request(
            path: "trpc/messaging.getChatrooms",
            method: .get,
            parameters: request,
            responseType: GetChatroomsResponse.self
        )
        
        print("✅ MessagingService: Retrieved \(response.chatrooms.count) chatrooms")
        return response.chatrooms.map { Chatroom.from(chatroomDTO: $0) }
    }
    
    func createDirectChatroom(with participantId: String) async throws -> Chatroom {
        print("💬 MessagingService: Creating direct chatroom with \(participantId)")
        
        let request = CreateChatroomRequest(
            participantIds: [participantId],
            type: "direct",
            name: nil,
            description: nil,
            imageUrl: nil
        )
        
        let response = try await apiClient.request(
            path: "trpc/messaging.createDirectChatroom",
            method: .post,
            parameters: request,
            responseType: CreateChatroomResponse.self
        )
        
        guard response.success, let chatroom = response.chatroom else {
            throw APIError.serverError(message: "Failed to create direct chatroom")
        }
        
        print("✅ MessagingService: Created direct chatroom")
        return Chatroom.from(chatroomDTO: chatroom)
    }
    
    func createGroupChatroom(
        name: String,
        description: String?,
        participantIds: [String],
        imageUrl: String?
    ) async throws -> Chatroom {
        print("💬 MessagingService: Creating group chatroom '\(name)'")
        
        let request = CreateChatroomRequest(
            participantIds: participantIds,
            type: "group",
            name: name,
            description: description,
            imageUrl: imageUrl
        )
        
        let response = try await apiClient.request(
            path: "trpc/messaging.createGroupChatroom",
            method: .post,
            parameters: request,
            responseType: CreateChatroomResponse.self
        )
        
        guard response.success, let chatroom = response.chatroom else {
            throw APIError.serverError(message: "Failed to create group chatroom")
        }
        
        print("✅ MessagingService: Created group chatroom")
        return Chatroom.from(chatroomDTO: chatroom)
    }
    
    func updateGroupSettings(
        chatroomId: String,
        name: String?,
        description: String?,
        imageUrl: String?
    ) async throws -> Chatroom {
        print("✏️ MessagingService: Updating group settings for \(chatroomId)")
        
        let request = UpdateGroupSettingsRequest(
            chatroomId: chatroomId,
            name: name,
            description: description,
            imageUrl: imageUrl
        )
        
        let response = try await apiClient.request(
            path: "trpc/messaging.updateGroupSettings",
            method: .post,
            parameters: request,
            responseType: UpdateGroupResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to update group settings")
        }
        
        print("✅ MessagingService: Updated group settings")
        return Chatroom.from(chatroomDTO: response.chatroom)
    }
    
    func leaveChatroom(_ chatroomId: String) async throws -> Bool {
        print("👋 MessagingService: Leaving chatroom \(chatroomId)")
        
        let request = LeaveChatroomRequest(chatroomId: chatroomId)
        
        let response = try await apiClient.request(
            path: "trpc/messaging.leaveChatroom",
            method: .post,
            parameters: request,
            responseType: ParticipantActionResponse.self
        )
        
        print("✅ MessagingService: Left chatroom")
        return response.success
    }
    
    // MARK: - Messages
    
    func getMessages(for chatroomId: String, limit: Int = 50) async throws -> [Message] {
        print("💬 MessagingService: Getting messages for chatroom \(chatroomId)")
        
        let request = GetMessagesRequest(
            chatroomId: chatroomId,
            limit: limit,
            cursor: nil
        )
        
        let response = try await apiClient.request(
            path: "trpc/messaging.getMessages",
            method: .get,
            parameters: request,
            responseType: GetMessagesResponse.self
        )
        
        print("✅ MessagingService: Retrieved \(response.messages.count) messages")
        return response.messages.map { Message.from(messageDTO: $0) }
    }
    
    func sendTextMessage(_ content: String, to chatroomId: String) async throws -> Message {
        print("✉️ MessagingService: Sending text message to \(chatroomId)")
        
        let request = SendMessageRequest(
            chatroomId: chatroomId,
            content: content,
            type: "text",
            mediaUrl: nil,
            replyToId: nil
        )
        
        let response = try await apiClient.request(
            path: "trpc/messaging.sendMessage",
            method: .post,
            parameters: request,
            responseType: SendMessageResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to send message")
        }
        
        print("✅ MessagingService: Sent text message")
        return Message.from(messageDTO: response.message)
    }
    
    func sendMediaMessage(
        _ mediaUrl: String,
        content: String,
        messageType: String,
        to chatroomId: String
    ) async throws -> Message {
        print("📸 MessagingService: Sending \(messageType) message to \(chatroomId)")
        
        let request = SendMediaMessageRequest(
            chatroomId: chatroomId,
            mediaUrl: mediaUrl,
            content: content,
            messageType: messageType
        )
        
        let response = try await apiClient.request(
            path: "trpc/messaging.sendMediaMessage",
            method: .post,
            parameters: request,
            responseType: SendMessageResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to send media message")
        }
        
        print("✅ MessagingService: Sent \(messageType) message")
        return Message.from(messageDTO: response.message)
    }
    
    func sendPostShare(_ postId: String, content: String, to chatroomId: String) async throws -> Message {
        print("📮 MessagingService: Sharing post \(postId) to \(chatroomId)")
        
        let request = SendPostShareRequest(
            chatroomId: chatroomId,
            postId: postId,
            content: content
        )
        
        let response = try await apiClient.request(
            path: "trpc/messaging.sendPostShare",
            method: .post,
            parameters: request,
            responseType: SendMessageResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to share post")
        }
        
        print("✅ MessagingService: Shared post")
        return Message.from(messageDTO: response.message)
    }
    
    func sendPlaceShare(_ placeId: String, content: String, to chatroomId: String) async throws -> Message {
        print("📍 MessagingService: Sharing place \(placeId) to \(chatroomId)")
        
        let request = SendPlaceShareRequest(
            chatroomId: chatroomId,
            placeId: placeId,
            content: content
        )
        
        let response = try await apiClient.request(
            path: "trpc/messaging.sendPlaceShare",
            method: .post,
            parameters: request,
            responseType: SendMessageResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to share place")
        }
        
        print("✅ MessagingService: Shared place")
        return Message.from(messageDTO: response.message)
    }
    
    func sendLinkShare(
        url: String,
        title: String?,
        description: String?,
        imageUrl: String?,
        content: String,
        to chatroomId: String
    ) async throws -> Message {
        print("🔗 MessagingService: Sharing link to \(chatroomId)")
        
        let request = SendLinkShareRequest(
            chatroomId: chatroomId,
            url: url,
            title: title,
            description: description,
            imageUrl: imageUrl,
            content: content
        )
        
        let response = try await apiClient.request(
            path: "trpc/messaging.sendLinkShare",
            method: .post,
            parameters: request,
            responseType: SendMessageResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to share link")
        }
        
        print("✅ MessagingService: Shared link")
        return Message.from(messageDTO: response.message)
    }
    
    func deleteMessage(_ messageId: String, from chatroomId: String) async throws -> Bool {
        print("🗑️ MessagingService: Deleting message \(messageId)")
        
        let request = DeleteMessageRequest(messageId: messageId, chatroomId: chatroomId)
        
        let response = try await apiClient.request(
            path: "trpc/messaging.deleteMessage",
            method: .post,
            parameters: request,
            responseType: DeleteMessageResponse.self
        )
        
        print("✅ MessagingService: Deleted message")
        return response.success
    }
    
    // MARK: - Participants
    
    func addParticipants(to chatroomId: String, userIds: [String]) async throws -> Bool {
        print("➕ MessagingService: Adding \(userIds.count) participants to \(chatroomId)")
        
        let request = AddParticipantsRequest(chatroomId: chatroomId, userIds: userIds)
        
        let response = try await apiClient.request(
            path: "trpc/messaging.addParticipants",
            method: .post,
            parameters: request,
            responseType: ParticipantActionResponse.self
        )
        
        print("✅ MessagingService: Added participants")
        return response.success
    }
    
    func removeParticipant(from chatroomId: String, userId: String) async throws -> Bool {
        print("➖ MessagingService: Removing participant \(userId) from \(chatroomId)")
        
        let request = RemoveParticipantRequest(chatroomId: chatroomId, userId: userId)
        
        let response = try await apiClient.request(
            path: "trpc/messaging.removeParticipant",
            method: .post,
            parameters: request,
            responseType: ParticipantActionResponse.self
        )
        
        print("✅ MessagingService: Removed participant")
        return response.success
    }
    
    func makeAdmin(in chatroomId: String, userId: String) async throws -> Bool {
        print("👑 MessagingService: Making \(userId) admin in \(chatroomId)")
        
        let request = MakeAdminRequest(chatroomId: chatroomId, userId: userId)
        
        let response = try await apiClient.request(
            path: "trpc/messaging.makeAdmin",
            method: .post,
            parameters: request,
            responseType: ParticipantActionResponse.self
        )
        
        print("✅ MessagingService: Made user admin")
        return response.success
    }
    
    // MARK: - Read Status & Typing
    
    func markMessagesAsRead(in chatroomId: String) async throws -> Int {
        print("✅ MessagingService: Marking messages as read in \(chatroomId)")
        
        let request = MarkMessagesAsReadRequest(chatroomId: chatroomId)
        
        let response = try await apiClient.request(
            path: "trpc/messaging.markAsRead",
            method: .post,
            parameters: request,
            responseType: MarkAsReadResponse.self
        )
        
        print("✅ MessagingService: Marked \(response.markedCount) messages as read")
        return response.markedCount
    }
    
    func setTypingStatus(_ isTyping: Bool, for chatroomId: String) async throws -> Bool {
        print("⌨️ MessagingService: Setting typing status: \(isTyping) for \(chatroomId)")
        
        let request = SetTypingStatusRequest(chatroomId: chatroomId, isTyping: isTyping)
        
        struct SetTypingResponse: Decodable {
            let success: Bool
        }
        
        let response = try await apiClient.request(
            path: "trpc/messaging.setTypingStatus",
            method: .post,
            parameters: request,
            responseType: SetTypingResponse.self
        )
        
        return response.success
    }
    
    func getTypingStatus(for chatroomId: String) async throws -> TypingStatus {
        print("⌨️ MessagingService: Getting typing status for \(chatroomId)")
        
        struct GetTypingStatusRequest: Encodable {
            let chatroomId: String
        }
        
        let request = GetTypingStatusRequest(chatroomId: chatroomId)
        
        let response = try await apiClient.request(
            path: "trpc/messaging.getTypingStatus",
            method: .get,
            parameters: request,
            responseType: TypingStatus.self
        )
        
        return response
    }
    
    // MARK: - Media & Search
    
    func getSharedMedia(
        in chatroomId: String,
        messageType: String? = nil,
        limit: Int = 20,
        cursor: String? = nil
    ) async throws -> [Message] {
        print("📁 MessagingService: Getting shared media for \(chatroomId)")
        
        let request = GetSharedMediaRequest(
            chatroomId: chatroomId,
            messageType: messageType,
            limit: limit,
            cursor: cursor
        )
        
        let response = try await apiClient.request(
            path: "trpc/messaging.getSharedMedia",
            method: .get,
            parameters: request,
            responseType: GetSharedMediaResponse.self
        )
        
        print("✅ MessagingService: Retrieved \(response.messages.count) media items")
        return response.messages.map { Message.from(messageDTO: $0) }
    }
    
    func searchUsersForMessaging(query: String, limit: Int = 20) async throws -> [User] {
        print("🔍 MessagingService: Searching users for messaging: '\(query)'")
        
        let request = SearchUsersRequest(query: query, limit: limit, offset: 0)
        
        let response = try await apiClient.request(
            path: "trpc/messaging.searchUsers",
            method: .get,
            parameters: request,
            responseType: SearchUsersResponse.self
        )
        
        print("✅ MessagingService: Found \(response.users.count) users")
        return response.users.map { User.from(userDTO: $0) }
    }
}

// MARK: - Mock Implementation for Testing

#if DEBUG
final class MockMessagingService: MessagingServiceProtocol {
    var mockChatrooms: [Chatroom] = []
    var mockChatroom: Chatroom?
    var mockMessages: [Message] = []
    var mockMessage: Message?
    var mockUsers: [User] = []
    var mockTypingStatus = TypingStatus(isTyping: false, users: nil)
    var shouldFail = false
    var mockError: APIError = .networkError(URLError(.notConnectedToInternet))
    var mockSuccess = true
    var mockMarkedCount = 0
    
    func getChatrooms(limit: Int) async throws -> [Chatroom] {
        if shouldFail { throw mockError }
        return mockChatrooms
    }
    
    func createDirectChatroom(with participantId: String) async throws -> Chatroom {
        if shouldFail { throw mockError }
        return mockChatroom ?? Chatroom(id: UUID(), type: .direct, participants: [])
    }
    
    func createGroupChatroom(name: String, description: String?, participantIds: [String], imageUrl: String?) async throws -> Chatroom {
        if shouldFail { throw mockError }
        return mockChatroom ?? Chatroom(id: UUID(), type: .group, name: name, participants: [])
    }
    
    func updateGroupSettings(chatroomId: String, name: String?, description: String?, imageUrl: String?) async throws -> Chatroom {
        if shouldFail { throw mockError }
        return mockChatroom ?? Chatroom(id: UUID(), type: .group, participants: [])
    }
    
    func leaveChatroom(_ chatroomId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockSuccess
    }
    
    func getMessages(for chatroomId: String, limit: Int) async throws -> [Message] {
        if shouldFail { throw mockError }
        return mockMessages
    }
    
    func sendTextMessage(_ content: String, to chatroomId: String) async throws -> Message {
        if shouldFail { throw mockError }
        return mockMessage ?? Message(id: UUID(), chatroomId: UUID(), senderId: UUID(), content: content, type: .text)
    }
    
    func sendMediaMessage(_ mediaUrl: String, content: String, messageType: String, to chatroomId: String) async throws -> Message {
        if shouldFail { throw mockError }
        return mockMessage ?? Message(id: UUID(), chatroomId: UUID(), senderId: UUID(), content: content, type: .image)
    }
    
    func sendPostShare(_ postId: String, content: String, to chatroomId: String) async throws -> Message {
        if shouldFail { throw mockError }
        return mockMessage ?? Message(id: UUID(), chatroomId: UUID(), senderId: UUID(), content: content, type: .postShare)
    }
    
    func sendPlaceShare(_ placeId: String, content: String, to chatroomId: String) async throws -> Message {
        if shouldFail { throw mockError }
        return mockMessage ?? Message(id: UUID(), chatroomId: UUID(), senderId: UUID(), content: content, type: .placeShare)
    }
    
    func sendLinkShare(url: String, title: String?, description: String?, imageUrl: String?, content: String, to chatroomId: String) async throws -> Message {
        if shouldFail { throw mockError }
        return mockMessage ?? Message(id: UUID(), chatroomId: UUID(), senderId: UUID(), content: content, type: .link)
    }
    
    func deleteMessage(_ messageId: String, from chatroomId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockSuccess
    }
    
    func addParticipants(to chatroomId: String, userIds: [String]) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockSuccess
    }
    
    func removeParticipant(from chatroomId: String, userId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockSuccess
    }
    
    func makeAdmin(in chatroomId: String, userId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockSuccess
    }
    
    func markMessagesAsRead(in chatroomId: String) async throws -> Int {
        if shouldFail { throw mockError }
        return mockMarkedCount
    }
    
    func setTypingStatus(_ isTyping: Bool, for chatroomId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockSuccess
    }
    
    func getTypingStatus(for chatroomId: String) async throws -> TypingStatus {
        if shouldFail { throw mockError }
        return mockTypingStatus
    }
    
    func getSharedMedia(in chatroomId: String, messageType: String?, limit: Int, cursor: String?) async throws -> [Message] {
        if shouldFail { throw mockError }
        return mockMessages
    }
    
    func searchUsersForMessaging(query: String, limit: Int) async throws -> [User] {
        if shouldFail { throw mockError }
        return mockUsers
    }
}
#endif

