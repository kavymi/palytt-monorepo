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
#if canImport(ConvexMobile)
import ConvexMobile
#endif
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [BackendService.Message] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var isOtherUserTyping = false
    @Published var typingUsers: [TypingIndicator] = [] // Convex typing indicators
    @Published var messageReadStatus: [String: Bool] = [:] // messageId -> isRead by recipient
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    private var chatroomId: String?
    private var realTimeSubscription: AnyCancellable?
    private var typingSubscription: AnyCancellable?
    private var readReceiptsSubscription: Task<Void, Never>?
    private var typingTimer: Timer?
    
    #if canImport(ConvexMobile)
    private var convexClient: ConvexClient?
    #endif
    
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
            
            // Use Convex for real-time typing if available
            if BackendService.shared.isConvexAvailable {
                if isTyping {
                    await BackendService.shared.startTyping(in: chatroomId)
                } else {
                    await BackendService.shared.stopTyping(in: chatroomId)
                }
            } else {
                // Fallback to tRPC
                do {
                    try await self.backendService.setTypingStatus(isTyping, for: chatroomId)
                } catch {
                    print("❌ Error setting typing status: \(error)")
                }
            }
        }
    }
    
    func startRealTimeUpdates(for chatroomId: String) {
        self.chatroomId = chatroomId
        
        // Use Convex for real-time typing indicators if available
        if BackendService.shared.isConvexAvailable {
            // Initialize Convex client
            #if canImport(ConvexMobile)
            let deploymentUrl = APIConfigurationManager.shared.convexDeploymentURL
            convexClient = ConvexClient(deploymentUrl: deploymentUrl)
            #endif
            
            // Subscribe to Convex typing indicators
            BackendService.shared.subscribeToTypingIndicators(chatroomId: chatroomId)
            
            // Observe PresenceService typing indicators
            typingSubscription = PresenceService.shared.$typingIndicators
                .map { indicators -> Bool in
                    // Check if anyone is typing in this chatroom
                    return !(indicators[chatroomId]?.isEmpty ?? true)
                }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isTyping in
                    self?.isOtherUserTyping = isTyping
                    if let indicators = PresenceService.shared.typingIndicators[chatroomId] {
                        self?.typingUsers = indicators
                    }
                }
            
            // Subscribe to Convex read receipts
            subscribeToReadReceipts(chatroomId: chatroomId)
            
            print("🟢 ChatViewModel: Using Convex for real-time typing indicators and read receipts")
        }
        
        // Set up polling for message updates (still needed until we add Convex message sync)
        realTimeSubscription = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.checkForNewMessages()
                    // Only poll typing status if Convex is not available
                    if !BackendService.shared.isConvexAvailable {
                        await self?.checkTypingStatus()
                    }
                }
            }
    }
    
    /// Subscribe to real-time read receipts via Convex
    private func subscribeToReadReceipts(chatroomId: String) {
        #if canImport(ConvexMobile)
        guard let client = convexClient else { return }
        
        readReceiptsSubscription = Task {
            do {
                let args: [String: ConvexEncodable] = [
                    "chatroomId": chatroomId
                ]
                
                for try await result in client.subscribe(to: "readReceipts:getChatroomReadStatus", with: args) as AsyncThrowingStream<[ConvexReadReceipt], Error> {
                    await MainActor.run {
                        // Update local read status
                        for receipt in result {
                            self.messageReadStatus[receipt.messageId] = true
                        }
                        print("🔄 ChatViewModel: Updated \(result.count) read receipts")
                    }
                }
            } catch {
                print("❌ ChatViewModel: Read receipts subscription error: \(error)")
            }
        }
        #endif
    }
    
    /// Mark a message as read via Convex (for real-time receipts)
    func markMessageReadViaConvex(_ messageId: String) async {
        guard let chatroomId = chatroomId else { return }
        guard let clerkId = Clerk.shared.user?.id else { return }
        
        #if canImport(ConvexMobile)
        guard let client = convexClient else { return }
        
        do {
            let args: [String: ConvexEncodable] = [
                "messageId": messageId,
                "chatroomId": chatroomId,
                "readerClerkId": clerkId
            ]
            
            let _: String = try await client.mutation("readReceipts:markMessageRead", with: args)
            print("✅ ChatViewModel: Marked message \(messageId) as read via Convex")
        } catch {
            print("❌ ChatViewModel: Failed to mark message as read: \(error)")
        }
        #endif
    }
    
    /// Mark all messages in chatroom as read via Convex
    func markChatroomReadViaConvex() async {
        guard let chatroomId = chatroomId else { return }
        guard let clerkId = Clerk.shared.user?.id else { return }
        
        // Get the last message ID
        guard let lastMessageId = messages.last?._id else { return }
        
        #if canImport(ConvexMobile)
        guard let client = convexClient else { return }
        
        do {
            let args: [String: ConvexEncodable] = [
                "chatroomId": chatroomId,
                "readerClerkId": clerkId,
                "lastMessageId": lastMessageId
            ]
            
            let count: Int = try await client.mutation("readReceipts:markChatroomRead", with: args)
            print("✅ ChatViewModel: Marked \(count) messages as read in chatroom via Convex")
        } catch {
            print("❌ ChatViewModel: Failed to mark chatroom as read: \(error)")
        }
        #endif
    }
    
    func stopRealTimeUpdates() {
        realTimeSubscription?.cancel()
        realTimeSubscription = nil
        typingSubscription?.cancel()
        typingSubscription = nil
        readReceiptsSubscription?.cancel()
        readReceiptsSubscription = nil
        
        // Clear typing status when leaving chat
        if let chatroomId = chatroomId {
            Task { [weak self] in
                guard let self = self else { return }
                
                // Use Convex if available
                if BackendService.shared.isConvexAvailable {
                    await BackendService.shared.stopTyping(in: chatroomId)
                } else {
                    try? await self.backendService.setTypingStatus(false, for: chatroomId)
                }
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
    
    /// Get typing text for display (e.g., "John is typing...")
    var typingText: String? {
        guard let chatroomId = chatroomId else { return nil }
        return BackendService.shared.getTypingText(for: chatroomId)
    }
    
    /// Get names of users currently typing
    var typingUserNames: [String] {
        return typingUsers.compactMap { $0.userName }
    }
    
    // MARK: - Read Receipts
    
    /// Check if a message has been read by the recipient
    func isMessageRead(_ messageId: String) -> Bool {
        return messageReadStatus[messageId] ?? false
    }
    
    /// Get read status for a message (sent, delivered, read)
    func getReadStatus(for message: BackendService.Message) -> MessageReadStatus {
        let currentUserId = Clerk.shared.user?.id ?? ""
        
        // Only show read status for messages we sent
        guard message.senderId == currentUserId else {
            return .none
        }
        
        // Check if read
        if messageReadStatus[message._id] == true {
            return .read
        }
        
        // If message exists, it's at least delivered
        return .delivered
    }
    
    /// Mark visible messages as read (called when scrolling/viewing)
    func markVisibleMessagesAsRead(_ visibleMessageIds: [String]) {
        guard chatroomId != nil else { return }
        let currentUserId = Clerk.shared.user?.id ?? ""
        
        // Filter to only messages we didn't send
        let messagesToMark = visibleMessageIds.filter { messageId in
            guard let message = messages.first(where: { $0._id == messageId }) else { return false }
            return message.senderId != currentUserId
        }
        
        guard !messagesToMark.isEmpty else { return }
        
        // Mark via Convex if available (for real-time receipts)
        // The tRPC marking is still done via markMessagesAsRead()
        Task {
            // This would integrate with Convex readReceipts
            // For now, we rely on the existing tRPC implementation
        }
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stopRealTimeUpdates()
        }
    }
}

// MARK: - Message Read Status
enum MessageReadStatus {
    case none       // Not our message, no status shown
    case sent       // Message sent but not confirmed delivered
    case delivered  // Message delivered to server
    case read       // Message read by recipient
    
    var icon: String {
        switch self {
        case .none: return ""
        case .sent: return "checkmark"
        case .delivered: return "checkmark"
        case .read: return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .clear
        case .sent: return .gray
        case .delivered: return .gray
        case .read: return .primaryBrand
        }
    }
}

// MARK: - Convex Models

#if canImport(ConvexMobile)
/// Read receipt from Convex subscription
struct ConvexReadReceipt: Codable {
    let _id: String
    let messageId: String
    let chatroomId: String
    let readerClerkId: String
    let readAt: Int64
}
#endif 