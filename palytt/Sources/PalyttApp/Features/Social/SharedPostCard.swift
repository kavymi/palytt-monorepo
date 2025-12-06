//
//  SharedPostCard.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Kingfisher

// MARK: - Shared Post Data Model

struct SharedPostData: Identifiable, Equatable {
    let id: String // Convex document ID
    let senderClerkId: String
    let senderName: String?
    let senderProfileImage: String?
    let recipientClerkId: String
    let postId: String
    let postTitle: String?
    let postImageUrl: String?
    let postShopName: String?
    let postAuthorName: String?
    let postAuthorClerkId: String?
    let isRead: Bool
    let createdAt: Date
    
    var isFromCurrentUser: Bool {
        // This will be set based on context
        false
    }
}

// MARK: - Shared Post Card View

struct SharedPostCard: View {
    let sharedPost: SharedPostData
    let isFromCurrentUser: Bool
    let onPostTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name (only show for received posts)
                if !isFromCurrentUser, let senderName = sharedPost.senderName {
                    Text(senderName)
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 4)
                }
                
                // Post preview card
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    onPostTap()
                }) {
                    postPreviewCard
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
                
                // Timestamp
                Text(formatTimestamp(sharedPost.createdAt))
                    .font(.caption2)
                    .foregroundColor(.tertiaryText)
                    .padding(.horizontal, 4)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
    
    // MARK: - Post Preview Card
    
    private var postPreviewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Post image
            if let imageUrl = sharedPost.postImageUrl, let url = URL(string: imageUrl) {
                KFImage(url)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                ProgressView()
                                    .tint(.primaryBrand)
                            )
                    }
                    .resizable()
                    .aspectRatio(4/3, contentMode: .fill)
                    .frame(width: 220, height: 165)
                    .clipped()
            } else {
                // Placeholder for posts without images
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.primaryBrand.opacity(0.3), Color.primaryBrand.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 220, height: 165)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.primaryBrand.opacity(0.5))
                    )
            }
            
            // Post info
            VStack(alignment: .leading, spacing: 6) {
                // Title
                if let title = sharedPost.postTitle, !title.isEmpty {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .lineLimit(2)
                }
                
                // Shop name
                if let shopName = sharedPost.postShopName, !shopName.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.primaryBrand)
                        
                        Text(shopName)
                            .font(.caption)
                            .foregroundColor(.primaryBrand)
                            .lineLimit(1)
                    }
                }
                
                // Author
                if let authorName = sharedPost.postAuthorName {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondaryText)
                        
                        Text("by \(authorName)")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 220, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isFromCurrentUser ? Color.primaryBrand.opacity(0.1) : Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isFromCurrentUser ? Color.primaryBrand.opacity(0.3) : Color.divider.opacity(0.5),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Helper Methods
    
    private func formatTimestamp(_ date: Date) -> String {
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

// MARK: - Shared Post Bubble (Alternative compact style)

struct SharedPostBubble: View {
    let sharedPost: SharedPostData
    let isFromCurrentUser: Bool
    let onPostTap: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 40)
            }
            
            Button(action: {
                HapticManager.shared.impact(.medium)
                onPostTap()
            }) {
                HStack(spacing: 10) {
                    // Thumbnail
                    if let imageUrl = sharedPost.postImageUrl, let url = URL(string: imageUrl) {
                        KFImage(url)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primaryBrand.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primaryBrand)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sharedPost.postTitle ?? "Shared Post")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primaryText)
                            .lineLimit(1)
                        
                        if let shopName = sharedPost.postShopName {
                            Text(shopName)
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.tertiaryText)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isFromCurrentUser ? Color.primaryBrand.opacity(0.15) : Color.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.divider.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if !isFromCurrentUser {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Skeleton Loading View

struct SharedPostCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                // Sender name skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 10)
                    .shimmer(isAnimating: $isAnimating)
                
                // Post preview skeleton
                VStack(alignment: .leading, spacing: 0) {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 220, height: 165)
                        .shimmer(isAnimating: $isAnimating)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 160, height: 14)
                            .shimmer(isAnimating: $isAnimating)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 100, height: 10)
                            .shimmer(isAnimating: $isAnimating)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cardBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Timestamp skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 8)
                    .shimmer(isAnimating: $isAnimating)
            }
            
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Received post
            SharedPostCard(
                sharedPost: SharedPostData(
                    id: "1",
                    senderClerkId: "friend123",
                    senderName: "John Doe",
                    senderProfileImage: nil,
                    recipientClerkId: "me123",
                    postId: "post1",
                    postTitle: "Amazing Ramen Bowl",
                    postImageUrl: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400",
                    postShopName: "Ichiran Ramen",
                    postAuthorName: "Jane Smith",
                    postAuthorClerkId: "jane123",
                    isRead: false,
                    createdAt: Date()
                ),
                isFromCurrentUser: false,
                onPostTap: {}
            )
            
            // Sent post
            SharedPostCard(
                sharedPost: SharedPostData(
                    id: "2",
                    senderClerkId: "me123",
                    senderName: "Me",
                    senderProfileImage: nil,
                    recipientClerkId: "friend123",
                    postId: "post2",
                    postTitle: "Best Coffee Ever",
                    postImageUrl: "https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400",
                    postShopName: "Blue Bottle Coffee",
                    postAuthorName: "Me",
                    postAuthorClerkId: "me123",
                    isRead: true,
                    createdAt: Date().addingTimeInterval(-3600)
                ),
                isFromCurrentUser: true,
                onPostTap: {}
            )
            
            // Skeleton
            SharedPostCardSkeleton()
        }
        .padding()
    }
    .background(Color.background)
}

