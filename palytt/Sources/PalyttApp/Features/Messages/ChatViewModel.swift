//
//  ChatViewModel.swift
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
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [BackendService.Message] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var isOtherUserTyping = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    private var chatroomId: String?
    private var realTimeSubscription: AnyCancellable?
    private var typingTimer: Timer?
    
    func loadMessages(for chatroomId: String) {
        guard !isLoading else { return }
        
        self.chatroomId = chatroomId
        
        Task { [weak self] in
            guard let self = self else { return }
            self.isLoading = true
            self.errorMessage = nil
            
            do {
                let fetchedMessages = try await self.backendService.getMessages(for: chatroomId)
                messages = fetchedMessages.sorted { $0.createdAt < $1.createdAt }
                
                // Mark messages as read
                let _ = try await backendService.markMessagesAsRead(in: chatroomId)
                
            } catch {
                errorMessage = "Failed to load messages: \(error.localizedDescription)"
                print("❌ Error loading messages: \(error)")
                HapticManager.shared.impact(.error)
            }
            
            isLoading = false
        }
    }
    
    func sendMessage(_ text: String, to chatroomId: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        await MainActor.run {
            isSending = true
            errorMessage = nil
        }
        
        do {
            let message = try await backendService.sendMessage(text, to: chatroomId)
            
            await MainActor.run {
                // Add message to local state immediately for smooth UX
                messages.append(message)
                messages.sort { $0.createdAt < $1.createdAt }
                
                // Clear typing status for current user
                setTypingStatus(false, for: chatroomId)
            }
            
            // Add success haptic
            HapticManager.shared.impact(.light, sound: .tap)
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to send message: \(error.localizedDescription)"
                print("❌ Error sending message: \(error)")
                HapticManager.shared.impact(.error)
            }
        }
        
        await MainActor.run {
            isSending = false
        }
    }
    
    func setTypingStatus(_ isTyping: Bool, for chatroomId: String) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.backendService.setTypingStatus(isTyping, for: chatroomId)
            } catch {
                print("❌ Error setting typing status: \(error)")
            }
        }
    }
    
    func startRealTimeUpdates(for chatroomId: String) {
        self.chatroomId = chatroomId
        
        // Set up real-time message updates
        realTimeSubscription = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.checkForNewMessages()
                    await self?.checkTypingStatus()
                }
            }
    }
    
    func stopRealTimeUpdates() {
        realTimeSubscription?.cancel()
        realTimeSubscription = nil
        
        // Clear typing status when leaving chat
        if let chatroomId = chatroomId {
            Task { [weak self] in
                guard let self = self else { return }
                try? await self.backendService.setTypingStatus(false, for: chatroomId)
            }
        }
        
        // Clear typing timer
        typingTimer?.invalidate()
        typingTimer = nil
    }
    
    private func checkForNewMessages() async {
        guard let chatroomId = chatroomId else { return }
        
        do {
            let fetchedMessages = try await backendService.getMessages(for: chatroomId)
            let sortedMessages = fetchedMessages.sorted { $0.createdAt < $1.createdAt }
            
            await MainActor.run {
                // Only update if there are new messages
                if sortedMessages.count > messages.count {
                    let newMessages = Array(sortedMessages.dropFirst(messages.count))
                    
                    // Add subtle haptic for received messages (not from current user)
                    let currentUserId = Clerk.shared.user?.id ?? ""
                    let hasNewFromOthers = newMessages.contains { $0.senderId != currentUserId }
                    
                    if hasNewFromOthers {
                        HapticManager.shared.impact(.light)
                    }
                    
                    messages = sortedMessages
                }
            }
        } catch {
            print("❌ Error checking for new messages: \(error)")
        }
    }
    
    private func checkTypingStatus() async {
        guard let chatroomId = chatroomId else { return }
        
        do {
            let typingStatus = try await backendService.getTypingStatus(for: chatroomId)
            let currentUserId = Clerk.shared.user?.id ?? ""
            
            await MainActor.run {
                // Show typing indicator if someone else is typing
                isOtherUserTyping = typingStatus.isTyping && typingStatus.userId != currentUserId
            }
        } catch {
            print("❌ Error checking typing status: \(error)")
        }
    }
    
    func refreshMessages() async {
        guard let chatroomId = chatroomId else { return }
        
        do {
            let fetchedMessages = try await backendService.getMessages(for: chatroomId)
            await MainActor.run {
                messages = fetchedMessages.sorted { $0.createdAt < $1.createdAt }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to refresh messages: \(error.localizedDescription)"
                print("❌ Error refreshing messages: \(error)")
                HapticManager.shared.impact(.error)
            }
        }
    }
    
    func markMessagesAsRead() {
        guard let chatroomId = chatroomId else { return }
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let _ = try await self.backendService.markMessagesAsRead(in: chatroomId)
            } catch {
                print("❌ Error marking messages as read: \(error)")
            }
        }
    }
    
    func deleteMessage(_ messageId: String) async {
        guard let chatroomId = chatroomId else { return }
        
        do {
            try await backendService.deleteMessage(messageId, from: chatroomId)
            
            await MainActor.run {
                messages.removeAll { $0._id == messageId }
                HapticManager.shared.impact(.medium)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete message: \(error.localizedDescription)"
                print("❌ Error deleting message: \(error)")
                HapticManager.shared.impact(.error)
            }
        }
    }
    
    func resendMessage(_ failedMessage: BackendService.Message) async {
        await sendMessage(failedMessage.text, to: chatroomId ?? "")
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stopRealTimeUpdates()
        }
    }
} 