//
//  MessagesView.swift
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
#if !targetEnvironment(simulator)
// import ConvexMobile // temporarily disabled
#endif
#endif

struct MessagesView: View {
    @StateObject private var viewModel = MessagesViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showingNewMessage = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.chatrooms.isEmpty {
                    // Loading state
                    VStack(spacing: 16) {
                        ForEach(0..<5, id: \.self) { _ in
                            ChatroomRowSkeleton()
                        }
                    }
                    .padding()
                } else if viewModel.chatrooms.isEmpty {
                    // Empty state
                    EmptyMessageStateView(onStartNewMessage: {
                        HapticManager.shared.impact(.light)
                        showingNewMessage = true
                    })
                } else {
                    // Messages list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.chatrooms, id: \._id) { chatroom in
                                NavigationLink(destination: ChatView(chatroom: chatroom)) {
                                    ChatroomRowView(chatroom: chatroom)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    .background(Color.background)
                }
            }
            .background(Color.background)
            .navigationTitle("Messages")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showingNewMessage = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primaryBrand)
                    }
                }
            }
            #endif
        }
        .onAppear {
            viewModel.loadChatrooms()
        }
        .sheet(isPresented: $showingNewMessage) {
            NewMessageView()
        }
        .refreshable {
            await viewModel.refreshChatrooms()
        }
    }
}

// MARK: - Chatroom Row View
struct ChatroomRowView: View {
    let chatroom: BackendService.Chatroom
    
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
        // Check if the other participant is online
        return otherParticipant?.isOnline ?? false
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with online status
            ZStack {
                if let participant = otherParticipant {
                    AsyncImage(url: URL(string: participant.avatarUrl ?? "")) { image in
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
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else {
                    // Group chat avatar
                    Circle()
                        .fill(LinearGradient.primaryGradient)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        )
                }
                
                // Online status indicator
                if isOnline && chatroom.type == "direct" {
                    Circle()
                        .fill(Color.success)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.cardBackground, lineWidth: 2)
                        )
                        .offset(x: 20, y: 20)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let lastMessage = chatroom.lastMessage {
                        Text(formatTimestamp(lastMessage.createdAt))
                            .font(.caption2)
                            .foregroundColor(.tertiaryText)
                    }
                }
                
                HStack {
                    if let lastMessage = chatroom.lastMessage {
                        // Show typing indicator if someone is typing
                        if chatroom.isTyping && chatroom.typingUserId != currentUserId {
                            TypingIndicatorView()
                        } else {
                            Text(lastMessage.text)
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Start a conversation")
                            .font(.caption)
                            .foregroundColor(.tertiaryText)
                            .italic()
                    }
                    
                    Spacer()
                    
                    // Unread count badge
                    if chatroom.unreadCount > 0 {
                        Text("\(chatroom.unreadCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Circle().fill(Color.primaryBrand))
                            .frame(minWidth: 20, minHeight: 20)
                    }
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private func formatTimestamp(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
        let formatter = DateFormatter()
        
        if Calendar.current.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "h:mm a"
        } else if Calendar.current.isDate(date, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            return "Yesterday"
        } else if Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: Date()) {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - Typing Indicator View
struct TypingIndicatorView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.primaryBrand.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animationOffset
                    )
            }
            
            Text("typing...")
                .font(.caption)
                .foregroundColor(.primaryBrand)
                .italic()
        }
        .onAppear {
            animationOffset = -3
        }
    }
}

// MARK: - Empty State View
struct EmptyMessageStateView: View {
    let onStartNewMessage: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Circle()
                .fill(LinearGradient.primaryGradient.opacity(0.2))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "message.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.primaryBrand)
                )
            
            VStack(spacing: 12) {
                Text("No Messages Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text("Start a conversation with your friends and share your favorite spots!")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: onStartNewMessage) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Start New Message")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient.primaryGradient
                        .cornerRadius(25)
                )
                .shadow(color: .primaryBrand.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(HapticButtonStyle(haptic: .medium, sound: .tap))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
    }
}

// MARK: - Chatroom Row Skeleton
struct ChatroomRowSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar skeleton
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 56, height: 56)
                .shimmer(isAnimating: $isAnimating)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Name skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 12)
                        .shimmer(isAnimating: $isAnimating)
                    
                    Spacer()
                    
                    // Time skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 10)
                        .shimmer(isAnimating: $isAnimating)
                }
                
                // Message skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 180, height: 10)
                    .shimmer(isAnimating: $isAnimating)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview
#Preview {
    MessagesView()
        .environmentObject(MockAppState())
} 