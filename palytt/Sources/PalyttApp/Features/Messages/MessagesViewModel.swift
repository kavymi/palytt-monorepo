//
//  MessagesViewModel.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Clerk
#if !targetEnvironment(simulator)
// import ConvexMobile // temporarily disabled
#endif

@MainActor
class MessagesViewModel: ObservableObject {
    @Published var chatrooms: [BackendService.Chatroom] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    
    func loadChatrooms() {
        guard !isLoading else { return }
        
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let fetchedChatrooms = try await backendService.getChatrooms()
                chatrooms = fetchedChatrooms.sorted { chatroom1, chatroom2 in
                    // Sort by last activity (most recent first)
                    chatroom1.lastActivity > chatroom2.lastActivity
                }
            } catch {
                errorMessage = "Failed to load messages: \(error.localizedDescription)"
                print("❌ Error loading chatrooms: \(error)")
                
                // Add haptic feedback for errors
                HapticManager.shared.impact(.error)
            }
            
            isLoading = false
        }
    }
    
    func refreshChatrooms() async {
        await MainActor.run {
            errorMessage = nil
        }
        
        do {
            let fetchedChatrooms = try await backendService.getChatrooms()
            await MainActor.run {
                chatrooms = fetchedChatrooms.sorted { chatroom1, chatroom2 in
                    chatroom1.lastActivity > chatroom2.lastActivity
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to refresh messages: \(error.localizedDescription)"
                print("❌ Error refreshing chatrooms: \(error)")
                HapticManager.shared.impact(.error)
            }
        }
    }
    
    func markChatroomAsRead(_ chatroomId: String) {
        guard let index = chatrooms.firstIndex(where: { $0._id == chatroomId }) else { return }
        
        Task {
            do {
                try await backendService.markChatroomAsRead(chatroomId)
                
                // Update local state
                await MainActor.run {
                    chatrooms[index] = BackendService.Chatroom(
                        _id: chatrooms[index]._id,
                        name: chatrooms[index].name,
                        type: chatrooms[index].type,
                        participants: chatrooms[index].participants,
                        createdBy: chatrooms[index].createdBy,
                        lastMessageId: chatrooms[index].lastMessageId,
                        lastMessage: chatrooms[index].lastMessage,
                        lastActivity: chatrooms[index].lastActivity,
                        unreadCount: 0, // Mark as read
                        isTyping: chatrooms[index].isTyping,
                        typingUserId: chatrooms[index].typingUserId
                    )
                }
            } catch {
                print("❌ Error marking chatroom as read: \(error)")
            }
        }
    }
    
    func updateChatroomWithNewMessage(_ chatroomId: String, message: BackendService.Message) {
        guard let index = chatrooms.firstIndex(where: { $0._id == chatroomId }) else { return }
        
        let currentUserId = Clerk.shared.user?.id ?? ""
        let isFromCurrentUser = message.senderId == currentUserId
        
        // Update chatroom with new last message and activity
        chatrooms[index] = BackendService.Chatroom(
            _id: chatrooms[index]._id,
            name: chatrooms[index].name,
            type: chatrooms[index].type,
            participants: chatrooms[index].participants,
            createdBy: chatrooms[index].createdBy,
            lastMessageId: message._id,
            lastMessage: message,
            lastActivity: message.createdAt,
            unreadCount: isFromCurrentUser ? chatrooms[index].unreadCount : chatrooms[index].unreadCount + 1,
            isTyping: false, // Clear typing when new message arrives
            typingUserId: nil
        )
        
        // Resort chatrooms by last activity
        chatrooms.sort { $0.lastActivity > $1.lastActivity }
    }
    
    func updateTypingStatus(for chatroomId: String, userId: String?, isTyping: Bool) {
        guard let index = chatrooms.firstIndex(where: { $0._id == chatroomId }) else { return }
        
        chatrooms[index] = BackendService.Chatroom(
            _id: chatrooms[index]._id,
            name: chatrooms[index].name,
            type: chatrooms[index].type,
            participants: chatrooms[index].participants,
            createdBy: chatrooms[index].createdBy,
            lastMessageId: chatrooms[index].lastMessageId,
            lastMessage: chatrooms[index].lastMessage,
            lastActivity: chatrooms[index].lastActivity,
            unreadCount: chatrooms[index].unreadCount,
            isTyping: isTyping,
            typingUserId: isTyping ? userId : nil
        )
    }
    
    func updateUserOnlineStatus(_ userId: String, isOnline: Bool) {
        for (chatroomIndex, chatroom) in chatrooms.enumerated() {
            for (participantIndex, participant) in chatroom.participants.enumerated() {
                if participant.clerkId == userId {
                    chatrooms[chatroomIndex].participants[participantIndex] = BackendService.User(
                        _id: participant._id,
                        clerkId: participant.clerkId,
                        username: participant.username,
                        displayName: participant.displayName,
                        avatarUrl: participant.avatarUrl,
                        bio: participant.bio,
                        isOnline: isOnline,
                        lastActiveAt: isOnline ? Int(Date().timeIntervalSince1970 * 1000) : participant.lastActiveAt
                    )
                }
            }
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
} 