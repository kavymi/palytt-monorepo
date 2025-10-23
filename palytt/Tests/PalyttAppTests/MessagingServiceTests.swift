//
//  MessagingServiceTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import PalyttApp

@MainActor
final class MessagingServiceTests: XCTestCase {
    
    var sut: MessagingService!
    var mockAPIClient: MockAPIClient!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = MessagingService(apiClient: mockAPIClient)
    }
    
    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        super.tearDown()
    }
    
    // MARK: - Chatroom Tests
    
    func testGetChatrooms_Success() async throws {
        // Given
        let mockChatrooms = [createMockChatroomDTO(), createMockChatroomDTO()]
        let response = GetChatroomsResponse(chatrooms: mockChatrooms, total: 2)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let chatrooms = try await sut.getChatrooms(limit: 50)
        
        // Then
        XCTAssertEqual(chatrooms.count, 2)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/messaging.getChatrooms")
    }
    
    func testCreateDirectChatroom_Success() async throws {
        // Given
        let mockChatroom = createMockChatroomDTO(type: "direct")
        let response = CreateChatroomResponse(success: true, chatroomId: mockChatroom.id, chatroom: mockChatroom)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let chatroom = try await sut.createDirectChatroom(with: "user456")
        
        // Then
        XCTAssertNotNil(chatroom)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/messaging.createDirectChatroom")
    }
    
    func testCreateGroupChatroom_Success() async throws {
        // Given
        let mockChatroom = createMockChatroomDTO(type: "group", name: "Group Chat")
        let response = CreateChatroomResponse(success: true, chatroomId: mockChatroom.id, chatroom: mockChatroom)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let chatroom = try await sut.createGroupChatroom(
            name: "Group Chat",
            description: "Test group",
            participantIds: ["user1", "user2"],
            imageUrl: nil
        )
        
        // Then
        XCTAssertNotNil(chatroom)
        XCTAssertEqual(chatroom.name, "Group Chat")
    }
    
    func testUpdateGroupSettings_Success() async throws {
        // Given
        let mockChatroom = createMockChatroomDTO(type: "group", name: "Updated Group")
        let response = UpdateGroupResponse(success: true, chatroom: mockChatroom)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let chatroom = try await sut.updateGroupSettings(
            chatroomId: "chatroom123",
            name: "Updated Group",
            description: nil,
            imageUrl: nil
        )
        
        // Then
        XCTAssertEqual(chatroom.name, "Updated Group")
    }
    
    func testLeaveChatroom_Success() async throws {
        // Given
        let response = ParticipantActionResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.leaveChatroom("chatroom123")
        
        // Then
        XCTAssertTrue(success)
    }
    
    // MARK: - Message Tests
    
    func testGetMessages_Success() async throws {
        // Given
        let mockMessages = [createMockMessageDTO(), createMockMessageDTO()]
        let response = GetMessagesResponse(messages: mockMessages, hasMore: false, nextCursor: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let messages = try await sut.getMessages(for: "chatroom123", limit: 50)
        
        // Then
        XCTAssertEqual(messages.count, 2)
    }
    
    func testSendTextMessage_Success() async throws {
        // Given
        let mockMessage = createMockMessageDTO(type: "text")
        let response = SendMessageResponse(success: true, message: mockMessage)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let message = try await sut.sendTextMessage("Hello!", to: "chatroom123")
        
        // Then
        XCTAssertNotNil(message)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/messaging.sendMessage")
    }
    
    func testSendMediaMessage_Success() async throws {
        // Given
        let mockMessage = createMockMessageDTO(type: "image")
        let response = SendMessageResponse(success: true, message: mockMessage)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let message = try await sut.sendMediaMessage(
            "https://example.com/image.jpg",
            content: "Check this out!",
            messageType: "image",
            to: "chatroom123"
        )
        
        // Then
        XCTAssertNotNil(message)
    }
    
    func testSendPostShare_Success() async throws {
        // Given
        let mockMessage = createMockMessageDTO(type: "post_share")
        let response = SendMessageResponse(success: true, message: mockMessage)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let message = try await sut.sendPostShare("post123", content: "Great post!", to: "chatroom123")
        
        // Then
        XCTAssertNotNil(message)
    }
    
    func testSendPlaceShare_Success() async throws {
        // Given
        let mockMessage = createMockMessageDTO(type: "place_share")
        let response = SendMessageResponse(success: true, message: mockMessage)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let message = try await sut.sendPlaceShare("place123", content: "Check out this place!", to: "chatroom123")
        
        // Then
        XCTAssertNotNil(message)
    }
    
    func testSendLinkShare_Success() async throws {
        // Given
        let mockMessage = createMockMessageDTO(type: "link")
        let response = SendMessageResponse(success: true, message: mockMessage)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let message = try await sut.sendLinkShare(
            url: "https://example.com",
            title: "Example",
            description: "Example site",
            imageUrl: nil,
            content: "Check this link",
            to: "chatroom123"
        )
        
        // Then
        XCTAssertNotNil(message)
    }
    
    func testDeleteMessage_Success() async throws {
        // Given
        let response = DeleteMessageResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.deleteMessage("message123", from: "chatroom123")
        
        // Then
        XCTAssertTrue(success)
    }
    
    // MARK: - Participants Tests
    
    func testAddParticipants_Success() async throws {
        // Given
        let response = ParticipantActionResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.addParticipants(to: "chatroom123", userIds: ["user1", "user2"])
        
        // Then
        XCTAssertTrue(success)
    }
    
    func testRemoveParticipant_Success() async throws {
        // Given
        let response = ParticipantActionResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.removeParticipant(from: "chatroom123", userId: "user456")
        
        // Then
        XCTAssertTrue(success)
    }
    
    func testMakeAdmin_Success() async throws {
        // Given
        let response = ParticipantActionResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.makeAdmin(in: "chatroom123", userId: "user456")
        
        // Then
        XCTAssertTrue(success)
    }
    
    // MARK: - Read Status & Typing Tests
    
    func testMarkMessagesAsRead_Success() async throws {
        // Given
        let response = MarkAsReadResponse(success: true, markedCount: 5)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let count = try await sut.markMessagesAsRead(in: "chatroom123")
        
        // Then
        XCTAssertEqual(count, 5)
    }
    
    func testSetTypingStatus_Success() async throws {
        // Given
        struct SetTypingResponse: Codable {
            let success: Bool
        }
        let response = SetTypingResponse(success: true)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.setTypingStatus(true, for: "chatroom123")
        
        // Then
        XCTAssertTrue(success)
    }
    
    func testGetTypingStatus_Success() async throws {
        // Given
        let response = TypingStatus(isTyping: true, users: ["user456"])
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let status = try await sut.getTypingStatus(for: "chatroom123")
        
        // Then
        XCTAssertTrue(status.isTyping)
        XCTAssertEqual(status.users?.count, 1)
    }
    
    // MARK: - Media & Search Tests
    
    func testGetSharedMedia_Success() async throws {
        // Given
        let mockMessages = [createMockMessageDTO(type: "image")]
        let response = GetSharedMediaResponse(messages: mockMessages, total: 1, hasMore: false, nextCursor: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let messages = try await sut.getSharedMedia(in: "chatroom123", messageType: "image", limit: 20, cursor: nil)
        
        // Then
        XCTAssertEqual(messages.count, 1)
    }
    
    func testSearchUsersForMessaging_Success() async throws {
        // Given
        let mockUsers = [createMockUserDTO(), createMockUserDTO()]
        let response = SearchUsersResponse(users: mockUsers, total: 2, hasMore: false)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let users = try await sut.searchUsersForMessaging(query: "test", limit: 20)
        
        // Then
        XCTAssertEqual(users.count, 2)
    }
    
    // MARK: - Helper Methods
    
    private func createMockChatroomDTO(type: String = "direct", name: String? = nil) -> ChatroomDTO {
        return ChatroomDTO(
            id: UUID().uuidString,
            type: type,
            name: name,
            description: nil,
            imageUrl: nil,
            participantIds: ["user1", "user2"],
            adminIds: type == "group" ? ["user1"] : nil,
            lastMessage: nil,
            lastMessageAt: nil,
            unreadCount: 0,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            participants: nil
        )
    }
    
    private func createMockMessageDTO(type: String = "text") -> MessageDTO {
        return MessageDTO(
            id: UUID().uuidString,
            chatroomId: "chatroom123",
            senderId: "user123",
            content: "Test message",
            type: type,
            mediaUrl: nil,
            replyToId: nil,
            isRead: false,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            senderUsername: "testuser",
            senderDisplayName: "Test User",
            senderProfileImageUrl: nil,
            postId: nil,
            placeId: nil,
            linkMetadata: nil
        )
    }
    
    private func createMockUserDTO() -> UserDTO {
        return UserDTO(
            id: UUID().uuidString,
            clerkId: "clerk_test",
            username: "testuser",
            displayName: "Test User",
            email: "test@test.com",
            phoneNumber: nil,
            bio: nil,
            profileImageUrl: nil,
            isPrivate: false,
            isVerified: false,
            followersCount: 0,
            followingCount: 0,
            postsCount: 0,
            friendsCount: 0,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            instagramHandle: nil,
            twitterHandle: nil,
            tikTokHandle: nil,
            location: nil,
            website: nil,
            dateOfBirth: nil,
            appleId: nil,
            googleId: nil
        )
    }
}

