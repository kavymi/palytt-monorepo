//
//  TrendingCarouselView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Kingfisher

// MARK: - Trending Carousel View

struct TrendingCarouselView: View {
    @StateObject private var viewModel = TrendingViewModel()
    @State private var selectedPost: Post?
    @State private var showPostDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                    
                    Text("Trending Near You")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primaryText)
                }
                
                Spacer()
                
                // Live indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Live")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.1))
                )
            }
            .padding(.horizontal, 16)
            
            // Trending posts carousel
            if viewModel.isLoading {
                trendingLoadingSkeleton
            } else if viewModel.trendingPosts.isEmpty {
                emptyTrendingView
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.trendingPosts) { post in
                            TrendingPostCard(
                                post: post,
                                mutualFriendsCount: viewModel.mutualFriendsLiked[post.id.uuidString] ?? 0
                            ) {
                                selectedPost = post
                                showPostDetail = true
                                HapticManager.shared.impact(.light)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color.appBackground)
        .fullScreenCover(isPresented: $showPostDetail) {
            if let post = selectedPost {
                PostDetailView(post: post)
            }
        }
        .task {
            await viewModel.loadTrendingPosts()
        }
    }
    
    private var trendingLoadingSkeleton: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    TrendingCardSkeleton()
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var emptyTrendingView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundColor(.secondaryText)
                Text("No trending posts nearby")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }
}

// MARK: - Trending Post Card

struct TrendingPostCard: View {
    let post: Post
    let mutualFriendsCount: Int
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var likesAnimating = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image section
                ZStack(alignment: .topTrailing) {
                    // Post image
                    if let imageUrl = post.mediaURLs.first {
                        KFImage(imageUrl)
                            .placeholder {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        ProgressView()
                                    )
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 180, height: 140)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(LinearGradient.primaryGradient.opacity(0.3))
                            .frame(width: 180, height: 140)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                    
                    // Hot badge
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("HOT")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .padding(8)
                }
                
                // Content section
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(post.title ?? "Delicious Food")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    // Location
                    if let shop = post.shop {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 11))
                            Text(shop.name)
                                .font(.system(size: 11))
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondaryText)
                    }
                    
                    // Social proof section
                    HStack(spacing: 8) {
                        // Likes with animation
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                                .scaleEffect(likesAnimating ? 1.2 : 1.0)
                            
                            Text("\(post.likesCount)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primaryText)
                        }
                        
                        // Mutual friends indicator
                        if mutualFriendsCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 10))
                                Text("\(mutualFriendsCount) friends liked")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.primaryBrand)
                        }
                    }
                    
                    // Author
                    HStack(spacing: 6) {
                        UserAvatar(user: post.author, size: 20)
                        
                        Text(post.author.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondaryText)
                            .lineLimit(1)
                    }
                }
                .padding(12)
            }
            .frame(width: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .onAppear {
            // Subtle animation for likes count
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                likesAnimating = true
            }
        }
    }
}

// MARK: - Trending Card Skeleton

struct TrendingCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 180, height: 140)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.4), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: isAnimating ? 200 : -200)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Title skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 14)
                
                // Location skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 100, height: 12)
                
                // Stats skeleton
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 40, height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 60, height: 12)
                }
                
                // Author skeleton
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 20, height: 20)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 60, height: 10)
                }
            }
            .padding(12)
        }
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appCardBackground)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Trending View Model

@MainActor
class TrendingViewModel: ObservableObject {
    @Published var trendingPosts: [Post] = []
    @Published var mutualFriendsLiked: [String: Int] = [:]
    @Published var isLoading = false
    @Published var error: String?
    
    private let backendService = BackendService.shared
    
    func loadTrendingPosts() async {
        isLoading = true
        error = nil
        
        // Get user's location for nearby trending
        let locationManager = LocationManager.shared
        let userLocation = locationManager.currentLocation
        
        do {
            // TODO: Create backend endpoint for trending posts
            // For now, use mock data
            try await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
            
            // Generate mock trending posts
            trendingPosts = MockData.generateTrendingPosts()
            
            // Generate mock mutual friends data
            for post in trendingPosts {
                mutualFriendsLiked[post.id.uuidString] = Int.random(in: 0...5)
            }
            
        } catch {
            self.error = error.localizedDescription
            print("❌ TrendingViewModel: Failed to load trending posts: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshTrendingPosts() async {
        await loadTrendingPosts()
    }
}

// MARK: - Previews

#Preview("Trending Carousel") {
    TrendingCarouselView()
        .background(Color.appBackground)
}

#Preview("Trending Post Card") {
    TrendingPostCard(
        post: MockData.generatePreviewPosts().first!,
        mutualFriendsCount: 3
    ) {
        print("Tapped")
    }
    .padding()
    .background(Color.appBackground)
}

