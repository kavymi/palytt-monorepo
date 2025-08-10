//
//  ModernMessagesViewModel.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Observation
import Combine

@Observable
@MainActor
class ModernMessagesViewModel {
    var chatrooms: [BackendService.Chatroom] = []
    var isLoading = false
    var errorMessage: String?
    var connectionStatus: WebSocketManager.ConnectionStatus = .disconnected
    
    private let backendService = BackendService.shared
    private let webSocketManager = WebSocketManager()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupWebSocketConnection()
    }
    
    private func setupWebSocketConnection() {
        // Connect to WebSocket for real-time updates
        if let url = URL(string: "wss://your-websocket-server.com/messaging") {
            webSocketManager.connect(to: url)
        }
        
        // Listen for WebSocket messages
        webSocketManager.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                Task { @MainActor in
                    await self?.handleWebSocketMessage(message)
                }
            }
            .store(in: &cancellables)
        
        // Monitor connection status
        webSocketManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \ModernMessagesViewModel.connectionStatus, on: self)
            .store(in: &cancellables)
    }
    
    func loadChatrooms() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedChatrooms = try await backendService.getChatrooms()
            chatrooms = fetchedChatrooms.sorted { chatroom1, chatroom2 in
                chatroom1.lastActivity > chatroom2.lastActivity
            }
        } catch {
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
            print("❌ Error loading chatrooms: \(error)")
            HapticManager.shared.impact(.error)
        }
        
        isLoading = false
    }
    
    @MainActor
    private func handleWebSocketMessage(_ message: WebSocketManager.WebSocketMessage) async {
        switch message.type {
        case "new_message":
            await handleNewMessage(message)
        case "typing_start", "typing_stop":
            await handleTypingStatus(message)
        case "user_online":
            await handleUserOnlineStatus(message)
        case "chatroom_updated":
            await refreshSpecificChatroom(message.chatroomId)
        default:
            print("Unknown WebSocket message type: \(message.type)")
        }
    }
    
    private func handleNewMessage(_ message: WebSocketManager.WebSocketMessage) async {
        guard let chatroomId = message.chatroomId else { return }
        
        // Update local chatroom with new message
        if let chatroomIndex = chatrooms.firstIndex(where: { $0._id == chatroomId }) {
            // Refresh this specific chatroom
            do {
                let updatedChatrooms = try await backendService.getChatrooms()
                if let updatedChatroom = updatedChatrooms.first(where: { $0._id == chatroomId }) {
                    chatrooms[chatroomIndex] = updatedChatroom
                    
                    // Resort chatrooms by last activity
                    chatrooms.sort { $0.lastActivity > $1.lastActivity }
                    
                    // Add haptic feedback for new messages
                    HapticManager.shared.impact(.light)
                }
            } catch {
                print("❌ Error refreshing chatroom: \(error)")
            }
        }
    }
    
    private func handleTypingStatus(_ message: WebSocketManager.WebSocketMessage) async {
        guard let chatroomId = message.chatroomId,
              let senderId = message.senderId else { return }
        
        let isTyping = message.type == "typing_start"
        updateTypingStatus(for: chatroomId, userId: senderId, isTyping: isTyping)
    }
    
    private func handleUserOnlineStatus(_ message: WebSocketManager.WebSocketMessage) async {
        guard let senderId = message.senderId else { return }
        
        let isOnline = message.type == "user_online"
        updateUserOnlineStatus(senderId, isOnline: isOnline)
    }
    
    private func refreshSpecificChatroom(_ chatroomId: String?) async {
        guard let chatroomId = chatroomId else { return }
        
        do {
            let updatedChatrooms = try await backendService.getChatrooms()
            if let updatedChatroom = updatedChatrooms.first(where: { $0._id == chatroomId }),
               let index = chatrooms.firstIndex(where: { $0._id == chatroomId }) {
                chatrooms[index] = updatedChatroom
                chatrooms.sort { $0.lastActivity > $1.lastActivity }
            }
        } catch {
            print("❌ Error refreshing specific chatroom: \(error)")
        }
    }
    
    func refreshChatrooms() async {
        errorMessage = nil
        
        do {
            let fetchedChatrooms = try await backendService.getChatrooms()
            chatrooms = fetchedChatrooms.sorted { chatroom1, chatroom2 in
                chatroom1.lastActivity > chatroom2.lastActivity
            }
        } catch {
            errorMessage = "Failed to refresh messages: \(error.localizedDescription)"
            print("❌ Error refreshing chatrooms: \(error)")
            HapticManager.shared.impact(.error)
        }
    }
    
    func markChatroomAsRead(_ chatroomId: String) async {
        do {
            try await backendService.markChatroomAsRead(chatroomId)
            
            // Update local state
            if let index = chatrooms.firstIndex(where: { $0._id == chatroomId }) {
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
    
    private func updateTypingStatus(for chatroomId: String, userId: String?, isTyping: Bool) {
        if let index = chatrooms.firstIndex(where: { $0._id == chatroomId }) {
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
    }
    
    private func updateUserOnlineStatus(_ userId: String, isOnline: Bool) {
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
    
    deinit {
        // Cancellables and WebSocket will be cleaned up automatically when the object is deallocated
    }
} 