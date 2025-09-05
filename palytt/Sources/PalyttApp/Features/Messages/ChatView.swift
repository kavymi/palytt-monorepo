//
//  ChatView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Kingfisher
import Clerk
#if !targetEnvironment(simulator)
// import ConvexMobile // temporarily disabled
#endif

struct ChatView: View {
    let chatroom: BackendService.Chatroom
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var isTyping = false
    @State private var showingPostPicker = false
    @State private var typingTimer: Timer?
    @FocusState private var isTextFieldFocused: Bool
    
    private var otherParticipant: BackendService.User? {
        chatroom.participants.first { $0.clerkId != currentUserId }
    }
    
    private var currentUserId: String {
        return Clerk.shared.user?.id ?? ""
    }
    
    private var displayName: String {
        if chatroom.type == "direct" {
            return otherParticipant?.displayName ?? otherParticipant?.username ?? "Unknown User"
        } else {
            return chatroom.name ?? "Group Chat"
        }
    }
    
    private var isOnline: Bool {
        return otherParticipant?.isOnline ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            ChatHeaderView(
                displayName: displayName,
                isOnline: isOnline,
                avatar: otherParticipant,
                onDismiss: {
                    HapticManager.shared.impact(.light)
                    dismiss()
                }
            )
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.isLoading && viewModel.messages.isEmpty {
                            // Loading skeleton
                            ForEach(0..<5, id: \.self) { _ in
                                MessageBubbleSkeleton()
                            }
                        } else {
                            ForEach(viewModel.messages, id: \._id) { message in
                                MessageBubbleView(
                                    message: message,
                                    isFromCurrentUser: message.senderId == currentUserId,
                                    showAvatar: shouldShowAvatar(for: message)
                                )
                                .id(message._id)
                            }
                            
                            // Typing indicator
                            if viewModel.isOtherUserTyping {
                                TypingBubbleView(user: otherParticipant)
                                    .id("typing")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                .background(Color.background)
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onChange(of: viewModel.isOtherUserTyping) { _, isTyping in
                    if isTyping {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input area
            ChatInputView(
                messageText: $messageText,
                isTyping: $isTyping,
                isTextFieldFocused: _isTextFieldFocused,
                onSend: sendMessage,
                onTypingChanged: handleTypingChanged,
                onSharePost: {
                    HapticManager.shared.impact(.light)
                    showingPostPicker = true
                }
            )
        }
        .background(Color.background)
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadMessages(for: chatroom._id)
            viewModel.startRealTimeUpdates(for: chatroom._id)
        }
        .onDisappear {
            viewModel.stopRealTimeUpdates()
            stopTypingIndicator()
        }
        .sheet(isPresented: $showingPostPicker) {
            PostPickerView { post in
                sharePost(post)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func shouldShowAvatar(for message: BackendService.Message) -> Bool {
        guard let messageIndex = viewModel.messages.firstIndex(where: { $0._id == message._id }) else {
            return true
        }
        
        // Show avatar if it's the first message or if the previous message is from a different sender
        if messageIndex == 0 {
            return true
        }
        
        let previousMessage = viewModel.messages[messageIndex - 1]
        return previousMessage.senderId != message.senderId
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.last {
            proxy.scrollTo(lastMessage._id, anchor: .bottom)
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        isTextFieldFocused = true
        
        HapticManager.shared.impact(.light, sound: .tap)
        
        Task {
            await viewModel.sendMessage(text, to: chatroom._id)
        }
        
        stopTypingIndicator()
    }
    
    private func sharePost(_ post: Post) {
        let postMessage = "📍 Shared a post: \(post.title ?? post.caption)\n\npalytt://post/\(post.id)"
        
        Task {
            await viewModel.sendMessage(postMessage, to: chatroom._id)
        }
        
        HapticManager.shared.impact(.medium, sound: .save)
    }
    
    private func handleTypingChanged() {
        // Reset the typing timer
        typingTimer?.invalidate()
        
        if !isTyping && !messageText.isEmpty {
            isTyping = true
            Task {
                viewModel.setTypingStatus(true, for: chatroom._id)
            }
        }
        
        // Set timer to stop typing indicator after 2 seconds of inactivity
        typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            stopTypingIndicator()
        }
    }
    
    private func stopTypingIndicator() {
        if isTyping {
            isTyping = false
            Task {
                viewModel.setTypingStatus(false, for: chatroom._id)
            }
        }
        typingTimer?.invalidate()
        typingTimer = nil
    }
}

// MARK: - Chat Header View
struct ChatHeaderView: View {
    let displayName: String
    let isOnline: Bool
    let avatar: BackendService.User?
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primaryBrand)
            }
            
            // Avatar
            if let user = avatar {
                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                    .overlay(
                        // Online status indicator
                        isOnline ? Circle()
                            .fill(Color.success)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.cardBackground, lineWidth: 2)
                            )
                            .offset(x: 14, y: 14) : nil
                    )
            } else {
                Circle()
                    .fill(LinearGradient.primaryGradient)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text(isOnline ? "Online" : "Offline")
                    .font(.caption2)
                    .foregroundColor(isOnline ? .success : .tertiaryText)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: BackendService.Message
    let isFromCurrentUser: Bool
    let showAvatar: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isFromCurrentUser {
                // Other user's avatar (only show when needed)
                if showAvatar, let user = message.sender {
                    AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 12))
                            )
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                } else {
                    // Spacer to maintain alignment
                    Color.clear
                        .frame(width: 28, height: 28)
                }
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Check if message is a shared post
                if message.text.contains("palytt://post/") {
                    SharedPostBubbleView(
                        message: message,
                        isFromCurrentUser: isFromCurrentUser
                    )
                } else {
                    // Regular text message
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(isFromCurrentUser ? .white : .primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(isFromCurrentUser ? 
                                      AnyShapeStyle(LinearGradient.primaryGradient) : 
                                      AnyShapeStyle(Color.cardBackground)
                                )
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                
                // Timestamp
                Text(formatTimestamp(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.tertiaryText)
                    .padding(.horizontal, 8)
            }
            
            if isFromCurrentUser {
                Spacer(minLength: 60) // Create space on the left for sent messages
            } else {
                Spacer(minLength: 60) // Create space on the right for received messages
            }
        }
    }
    
    private func formatTimestamp(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Shared Post Bubble View
struct SharedPostBubbleView: View {
    let message: BackendService.Message
    let isFromCurrentUser: Bool
    
    private var postId: String? {
        let components = message.text.components(separatedBy: "palytt://post/")
        return components.count > 1 ? components[1] : nil
    }
    
    private var postTitle: String {
        let lines = message.text.components(separatedBy: "\n")
        return lines.first?.replacingOccurrences(of: "📍 Shared a post: ", with: "") ?? "Shared Post"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .primaryBrand)
                
                Text("Shared a post")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .secondaryText)
            }
            
            Text(postTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isFromCurrentUser ? .white : .primaryText)
                .lineLimit(2)
            
            Button(action: {
                openPost()
            }) {
                Text("View Post")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isFromCurrentUser ? .primaryBrand : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isFromCurrentUser ? Color.white : Color.primaryBrand)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isFromCurrentUser ? 
                      AnyShapeStyle(LinearGradient.primaryGradient) : 
                      AnyShapeStyle(Color.cardBackground)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func openPost() {
        // TODO: Navigate to post detail view
        HapticManager.shared.impact(.medium)
        print("Opening post: \(postId ?? "unknown")")
    }
}

// MARK: - Typing Bubble View
struct TypingBubbleView: View {
    let user: BackendService.User?
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if let user = user {
                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                        )
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            }
            
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.primaryBrand.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .offset(y: animationOffset)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animationOffset
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.cardBackground)
            )
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            Spacer(minLength: 60)
        }
        .onAppear {
            animationOffset = -3
        }
        .onDisappear {
            animationOffset = 0
        }
    }
}

// MARK: - Chat Input View
struct ChatInputView: View {
    @Binding var messageText: String
    @Binding var isTyping: Bool
    @FocusState var isTextFieldFocused: Bool
    let onSend: () -> Void
    let onTypingChanged: () -> Void
    let onSharePost: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.divider)
            
            HStack(spacing: 12) {
                // Share post button
                Button(action: onSharePost) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primaryBrand)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.primaryBrand.opacity(0.1)))
                }
                .buttonStyle(HapticButtonStyle(haptic: .light))
                
                // Text input
                HStack(spacing: 8) {
                    TextField("Message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.body)
                        .foregroundColor(.primaryText)
                        .lineLimit(1...4)
                        .focused($isTextFieldFocused)
                        .onChange(of: messageText) { _, _ in
                            onTypingChanged()
                        }
                    
                    // Send button
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                           .tertiaryText : .primaryBrand)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(HapticButtonStyle(haptic: .medium, sound: .tap))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.cardBackground)
                        .stroke(Color.divider.opacity(0.5), lineWidth: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.background)
        }
    }
}

// MARK: - Message Bubble Skeleton
struct MessageBubbleSkeleton: View {
    @State private var isAnimating = false
    private let isFromCurrentUser = Bool.random()
    
    var body: some View {
        HStack {
            if !isFromCurrentUser {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .shimmer(isAnimating: $isAnimating)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: CGFloat.random(in: 100...200), height: 40)
                    .shimmer(isAnimating: $isAnimating)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 8)
                    .shimmer(isAnimating: $isAnimating)
            }
            
            if isFromCurrentUser {
                Spacer()
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Post Picker View
struct PostPickerView: View {
    let onPostSelected: (Post) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var posts: [Post] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoading {
                        ForEach(0..<3, id: \.self) { _ in
                            PostCardSkeleton()
                        }
                    } else {
                        ForEach(posts, id: \.id) { post in
                            Button(action: {
                                HapticManager.shared.impact(.medium)
                                onPostSelected(post)
                                dismiss()
                            }) {
                                PostCard(post: post)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .background(Color.background)
            .navigationTitle("Share a Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }
                    .foregroundColor(.primaryText)
                }
            }
        }
        .onAppear {
            loadUserPosts()
        }
    }
    
    private func loadUserPosts() {
        isLoading = true
        
        Task {
            do {
                guard let currentUser = Clerk.shared.user else {
                    posts = []
                    isLoading = false
                    return
                }
                
                // Load user's posts from backend
                let backendPosts = try await BackendService.shared.getPostsByUser(userId: currentUser.id)
                
                // Convert backend posts to Post model
                posts = backendPosts.compactMap { backendPost in
                    Post.from(backendPost: backendPost, author: nil)
                }
                
                print("✅ PostPickerView: Loaded \(posts.count) posts for sharing")
                
            } catch {
                print("❌ PostPickerView: Failed to load user posts: \(error)")
                posts = []
            }
            
            isLoading = false
        }
    }
}



// MARK: - Preview
#Preview {
    ChatView(chatroom: BackendService.Chatroom(
        _id: "1",
        name: nil,
        type: "direct",
        participants: [
            BackendService.User(
                _id: "1",
                clerkId: "user_1",
                username: "johndoe",
                displayName: "John Doe",
                avatarUrl: nil,
                bio: nil,
                isOnline: true,
                lastActiveAt: Int(Date().timeIntervalSince1970 * 1000)
            )
        ],
        createdBy: "user_1",
        lastMessageId: nil,
        lastMessage: nil,
        lastActivity: Int(Date().timeIntervalSince1970 * 1000),
        unreadCount: 0,
        isTyping: false,
        typingUserId: nil
    ))
} 