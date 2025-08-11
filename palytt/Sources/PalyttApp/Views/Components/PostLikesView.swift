//
//  PostLikesView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Clerk

// MARK: - Post Likes View Model
@MainActor
class PostLikesViewModel: ObservableObject {
    @Published var likes: [PostLike] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    private var nextCursor: String?
    private var hasMoreLikes = true
    
    func loadLikes(for postId: String) async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await backendService.getPostLikes(
                postId: postId,
                limit: 20,
                cursor: nil
            )
            
            // Convert backend likes to UI likes
            var convertedLikes: [PostLike] = []
            for backendLike in response.likes {
                let like = PostLike(
                    id: backendLike.id,
                    postId: backendLike.postId,
                    user: backendLike.user.toUser(),
                    createdAt: ISO8601DateFormatter().date(from: backendLike.createdAt) ?? Date()
                )
                convertedLikes.append(like)
            }
            
            likes = convertedLikes
            nextCursor = response.nextCursor
            hasMoreLikes = response.nextCursor != nil
            
        } catch {
            print("❌ Failed to load post likes: \(error)")
            errorMessage = error.localizedDescription
            likes = []
        }
        
        isLoading = false
    }
    
    func loadMoreLikes(for postId: String) async {
        guard !isLoading, hasMoreLikes, let cursor = nextCursor else { return }
        
        isLoading = true
        
        do {
            let response = try await backendService.getPostLikes(
                postId: postId,
                limit: 20,
                cursor: cursor
            )
            
            // Convert and append new likes
            var newLikes: [PostLike] = []
            for backendLike in response.likes {
                let like = PostLike(
                    id: backendLike.id,
                    postId: backendLike.postId,
                    user: backendLike.user.toUser(),
                    createdAt: ISO8601DateFormatter().date(from: backendLike.createdAt) ?? Date()
                )
                newLikes.append(like)
            }
            
            likes.append(contentsOf: newLikes)
            nextCursor = response.nextCursor
            hasMoreLikes = response.nextCursor != nil
            
        } catch {
            print("❌ Failed to load more post likes: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Post Like Model
struct PostLike: Identifiable {
    let id: String
    let postId: String
    let user: User
    let createdAt: Date
}

// MARK: - Post Likes View
struct PostLikesView: View {
    let post: Post
    @StateObject private var viewModel = PostLikesViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                contentView
            }
            .navigationTitle("Likes")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") { dismiss() }
            )
            .task {
                await viewModel.loadLikes(for: post.convexId)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.likes.isEmpty {
            // Initial loading state
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                    .scaleEffect(1.2)
                
                Text("Loading likes...")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        } else if viewModel.likes.isEmpty && !viewModel.isLoading {
            // Empty state
            VStack(spacing: 20) {
                Image("palytt-logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .opacity(0.6)
                
                VStack(spacing: 8) {
                    Text("No likes yet")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    
                    Text("Be the first to like this post!")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            
        } else {
            // Likes list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.likes) { like in
                        LikeRow(like: like)
                            .onAppear {
                                // Load more when reaching near the end
                                if like.id == viewModel.likes.last?.id {
                                    Task {
                                        await viewModel.loadMoreLikes(for: post.convexId)
                                    }
                                }
                            }
                    }
                    
                    // Loading more indicator
                    if viewModel.isLoading && !viewModel.likes.isEmpty {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                                .scaleEffect(0.8)
                            
                            Text("Loading more...")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        .padding()
                    }
                }
            }
        }
        
        if let errorMessage = viewModel.errorMessage {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                
                Text("Error loading likes")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                
                Button("Try Again") {
                    Task {
                        await viewModel.loadLikes(for: post.convexId)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.primaryBrand)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}

// MARK: - Like Row
struct LikeRow: View {
    let like: PostLike
    @State private var isFollowing: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // User Avatar
            NavigationLink(destination: UserProfileView(user: like.user)) {
                UserAvatar(user: like.user, size: 44)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Display name
                Text(like.user.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
                
                // Username
                Text("@\(like.user.username)")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            // Time ago
            Text(like.createdAt.timeAgoDisplay())
                .font(.caption2)
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appCardBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            // Navigate to user profile
        }
    }
}

// MARK: - Date Extension for Time Ago Display
extension Date {
    func timeAgoDisplay() -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(self)
        
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: self)
        }
    }
}

#Preview {
    PostLikesView(post: MockData.generatePreviewPosts()[0])
        .environmentObject(MockAppState())
}
