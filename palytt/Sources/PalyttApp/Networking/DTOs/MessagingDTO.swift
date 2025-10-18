//
//  MessagingDTO.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Chatroom DTOs

struct ChatroomDTO: Codable {
    let id: String
    let type: String // "direct", "group"
    let name: String?
    let description: String?
    let imageUrl: String?
    let participantIds: [String]
    let adminIds: [String]?
    let lastMessage: MessageDTO?
    let lastMessageAt: String?
    let unreadCount: Int?
    let createdAt: String
    let updatedAt: String
    
    // Denormalized participant info (for convenience)
    let participants: [UserDTO]?
}

// MARK: - Message DTOs

struct MessageDTO: Codable {
    let id: String
    let chatroomId: String
    let senderId: String
    let content: String
    let type: String // "text", "image", "video", "post_share", "place_share", "link"
    let mediaUrl: String?
    let replyToId: String?
    let isRead: Bool?
    let createdAt: String
    let updatedAt: String
    
    // Denormalized sender info
    let senderUsername: String?
    let senderDisplayName: String?
    let senderProfileImageUrl: String?
    
    // For special message types
    let postId: String?
    let placeId: String?
    let linkMetadata: LinkMetadataDTO?
}

struct LinkMetadataDTO: Codable {
    let url: String
    let title: String?
    let description: String?
    let imageUrl: String?
}

// MARK: - Request DTOs

struct GetChatroomsRequest: Codable {
    let limit: Int?
}

struct GetMessagesRequest: Codable {
    let chatroomId: String
    let limit: Int?
    let cursor: String? // For pagination
}

struct SendMessageRequest: Codable {
    let chatroomId: String
    let content: String
    let type: String
    let mediaUrl: String?
    let replyToId: String?
}

struct CreateChatroomRequest: Codable {
    let participantIds: [String]
    let type: String
    let name: String?
    let description: String?
    let imageUrl: String?
}

struct MarkMessagesAsReadRequest: Codable {
    let chatroomId: String
}

struct SetTypingStatusRequest: Codable {
    let chatroomId: String
    let isTyping: Bool
}

struct DeleteMessageRequest: Codable {
    let messageId: String
    let chatroomId: String
}

struct UpdateGroupSettingsRequest: Codable {
    let chatroomId: String
    let name: String?
    let description: String?
    let imageUrl: String?
}

struct AddParticipantsRequest: Codable {
    let chatroomId: String
    let userIds: [String]
}

struct RemoveParticipantRequest: Codable {
    let chatroomId: String
    let userId: String
}

struct MakeAdminRequest: Codable {
    let chatroomId: String
    let userId: String
}

struct LeaveChatroomRequest: Codable {
    let chatroomId: String
}

struct GetSharedMediaRequest: Codable {
    let chatroomId: String
    let messageType: String?
    let limit: Int?
    let cursor: String?
}

// MARK: - Share Message Request DTOs

struct SendPostShareRequest: Codable {
    let chatroomId: String
    let postId: String
    let content: String
}

struct SendPlaceShareRequest: Codable {
    let chatroomId: String
    let placeId: String
    let content: String
}

struct SendLinkShareRequest: Codable {
    let chatroomId: String
    let url: String
    let title: String?
    let description: String?
    let imageUrl: String?
    let content: String
}

struct SendMediaMessageRequest: Codable {
    let chatroomId: String
    let mediaUrl: String
    let content: String
    let messageType: String // "image", "video"
}

// MARK: - Response DTOs

struct GetChatroomsResponse: Codable {
    let chatrooms: [ChatroomDTO]
    let total: Int
}

struct GetMessagesResponse: Codable {
    let messages: [MessageDTO]
    let hasMore: Bool
    let nextCursor: String?
}

struct SendMessageResponse: Codable {
    let success: Bool
    let message: MessageDTO
}

struct CreateChatroomResponse: Codable {
    let success: Bool
    let chatroomId: String
    let chatroom: ChatroomDTO?
}

struct MarkAsReadResponse: Codable {
    let success: Bool
    let markedCount: Int
}

struct TypingStatus: Codable {
    let isTyping: Bool
    let users: [String]? // User IDs currently typing
}

struct DeleteMessageResponse: Codable {
    let success: Bool
    let message: String?
}

struct UpdateGroupResponse: Codable {
    let success: Bool
    let chatroom: ChatroomDTO
}

struct ParticipantActionResponse: Codable {
    let success: Bool
    let message: String?
}

struct GetSharedMediaResponse: Codable {
    let messages: [MessageDTO]
    let total: Int
    let hasMore: Bool
    let nextCursor: String?
}

// MARK: - Domain Model Conversion

extension Chatroom {
    /// Convert backend ChatroomDTO to domain Chatroom model
    static func from(chatroomDTO: ChatroomDTO) -> Chatroom {
        let participants = chatroomDTO.participants?.map { User.from(userDTO: $0) } ?? []
        
        return Chatroom(
            id: UUID(uuidString: chatroomDTO.id) ?? UUID(),
            convexId: chatroomDTO.id,
            type: chatroomDTO.type == "group" ? .group : .direct,
            name: chatroomDTO.name,
            description: chatroomDTO.description,
            imageUrl: chatroomDTO.imageUrl.flatMap { URL(string: $0) },
            participants: participants,
            participantIds: chatroomDTO.participantIds.compactMap { UUID(uuidString: $0) },
            adminIds: chatroomDTO.adminIds?.compactMap { UUID(uuidString: $0) } ?? [],
            lastMessage: chatroomDTO.lastMessage.map { Message.from(messageDTO: $0) },
            lastMessageAt: chatroomDTO.lastMessageAt.flatMap { ISO8601DateFormatter().date(from: $0) },
            unreadCount: chatroomDTO.unreadCount ?? 0,
            createdAt: ISO8601DateFormatter().date(from: chatroomDTO.createdAt) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: chatroomDTO.updatedAt) ?? Date()
        )
    }
}

extension Message {
    /// Convert backend MessageDTO to domain Message model
    static func from(messageDTO: MessageDTO) -> Message {
        // Parse message type
        let messageType: MessageType = {
            switch messageDTO.type {
            case "text": return .text
            case "image": return .image
            case "video": return .video
            case "post_share": return .postShare
            case "place_share": return .placeShare
            case "link": return .link
            default: return .text
            }
        }()
        
        // Create sender user if we have sender info
        let sender: User? = {
            guard let username = messageDTO.senderUsername else { return nil }
            return User(
                id: UUID(uuidString: messageDTO.senderId) ?? UUID(),
                convexId: messageDTO.senderId,
                username: username,
                displayName: messageDTO.senderDisplayName ?? username,
                email: nil,
                phoneNumber: nil,
                bio: nil,
                profileImageUrl: messageDTO.senderProfileImageUrl.flatMap { URL(string: $0) }
            )
        }()
        
        return Message(
            id: UUID(uuidString: messageDTO.id) ?? UUID(),
            convexId: messageDTO.id,
            chatroomId: UUID(uuidString: messageDTO.chatroomId) ?? UUID(),
            senderId: UUID(uuidString: messageDTO.senderId) ?? UUID(),
            sender: sender,
            content: messageDTO.content,
            type: messageType,
            mediaUrl: messageDTO.mediaUrl.flatMap { URL(string: $0) },
            replyToId: messageDTO.replyToId.flatMap { UUID(uuidString: $0) },
            isRead: messageDTO.isRead ?? false,
            createdAt: ISO8601DateFormatter().date(from: messageDTO.createdAt) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: messageDTO.updatedAt) ?? Date()
        )
    }
}

// Domain models (if they don't exist yet)

enum ChatroomType {
    case direct
    case group
}

enum MessageType {
    case text
    case image
    case video
    case postShare
    case placeShare
    case link
}

