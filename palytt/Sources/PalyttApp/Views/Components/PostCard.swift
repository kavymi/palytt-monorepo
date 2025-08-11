//
//  PostCard.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Kingfisher
import MapKit

struct PostCard: View {
    let post: Post
    let onLike: ((UUID) -> Void)?
    let onBookmark: ((UUID) -> Void)?
    let onBookmarkNavigate: (() -> Void)?
    
    @State private var isLiked: Bool = false
    @State private var isSaved: Bool = false
    @State private var isCommentPressed: Bool = false
    @State private var currentImageIndex: Int = 0
    @State private var showComments: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var showHeartAnimation: Bool = false
    @State private var showSaveOptions: Bool = false
    @State private var currentCommentsCount: Int = 0
    @State private var showPostLikes: Bool = false
    @State private var recentComments: [Comment] = []
    @State private var isLoadingComments: Bool = false
    
    init(post: Post, onLike: ((UUID) -> Void)? = nil, onBookmark: ((UUID) -> Void)? = nil, onBookmarkNavigate: (() -> Void)? = nil) {
        self.post = post
        self.onLike = onLike
        self.onBookmark = onBookmark
        self.onBookmarkNavigate = onBookmarkNavigate
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            authorHeader
            mediaCarousel
            interactionBar
            titleSection
            captionSection
            recentCommentsSection
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .onAppear {
            isLiked = post.isLiked
            isSaved = post.isSaved
            currentCommentsCount = post.commentsCount
            
            // Load recent comments
            Task {
                await loadRecentComments()
            }
        }
        .onChange(of: post.isLiked) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isLiked = newValue
            }
        }
        .sheet(isPresented: $showComments) {
            CommentsView(post: post) { newCount in
                // Update the local comment count for real-time UI updates
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentCommentsCount = newCount
                }
            }
        }
        .sheet(isPresented: $showPostLikes) {
            PostLikesView(post: post)
        }
    }
    
    // MARK: - View Components
    private var authorHeader: some View {
        HStack {
            NavigationLink(destination: UserProfileView(user: post.author)) {
                UserAvatar(user: post.author, size: 40)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.author.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                if let shop = post.shop {
                    Button(action: {
                        openDirections(to: shop)
                    }) {
                        Text(shop.name)
                            .font(.caption)
                            .foregroundColor(.primaryBrand)
                            .underline()
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private var mediaCarousel: some View {
        GeometryReader { geometry in
            ZStack {
                carouselBackground
                carouselImages(geometry: geometry)
                carouselIndicators
                carouselCounter
                
                // Heart Animation Overlay
                if showHeartAnimation {
                    HeartAnimationView()
                        .allowsHitTesting(false)
                }
            }
        }
        .aspectRatio(3/4, contentMode: .fit)
        .cornerRadius(16)
        .clipped()
    }
    
    private var carouselBackground: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .cornerRadius(16)
    }
    
    private func carouselImages(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(post.mediaURLs.prefix(6).enumerated()), id: \.offset) { index, url in
                KFImage(url)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                                    .scaleEffect(0.8)
                            )
                            .shimmer(isAnimating: .constant(true))
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .onTapGesture(count: 2) {
                        doubleTapToLike()
                    }
                    .scaleEffect(
                        currentImageIndex == index ? (isDragging ? 0.98 : 1.0) : 0.95
                    )
                    .opacity(
                        currentImageIndex == index ? 1.0 : 0.7
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0.2), value: currentImageIndex)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragging)
            }
        }
        .offset(x: -CGFloat(currentImageIndex) * geometry.size.width + dragOffset)
        .animation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1), value: currentImageIndex)
        .gesture(carouselDragGesture(geometry: geometry))
    }
    
    private func carouselDragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                // Only handle horizontal drags if they're significant
                let horizontalAmount = abs(value.translation.width)
                let verticalAmount = abs(value.translation.height)
                
                // If vertical drag is more significant, don't handle the gesture
                if verticalAmount > horizontalAmount && verticalAmount > 20 {
                    return
                }
                
                // Only start handling if horizontal drag is significant
                if horizontalAmount > 10 {
                    isDragging = true
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                isDragging = false
                let threshold: CGFloat = 50
                let dragThreshold = geometry.size.width * 0.25
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    if abs(value.translation.width) > threshold {
                        if value.translation.width > 0 && currentImageIndex > 0 {
                            currentImageIndex -= 1
                        } else if value.translation.width < 0 && currentImageIndex < min(post.mediaURLs.count, 6) - 1 {
                            currentImageIndex += 1
                        }
                    }
                    dragOffset = 0
                }
                
                if abs(value.translation.width) > dragThreshold {
                    HapticManager.shared.impact(.light)
                }
            }
    }
    
    private var carouselIndicators: some View {
        Group {
            if post.mediaURLs.count > 1 {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Spacer()
                        ForEach(0..<min(post.mediaURLs.count, 6), id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(currentImageIndex == index ? Color.white : Color.white.opacity(0.5))
                                .frame(
                                    width: currentImageIndex == index ? 24 : 8,
                                    height: 4
                                )
                                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: currentImageIndex)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        currentImageIndex = index
                                    }
                                    HapticManager.shared.impact(.light)
                                }
                        }
                        Spacer()
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }
    
    private var carouselCounter: some View {
        Group {
            if post.mediaURLs.count > 1 {
                VStack {
                    HStack {
                        Spacer()
                        Text("\(currentImageIndex + 1)/\(min(post.mediaURLs.count, 6))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .padding(.top, 12)
                            .padding(.trailing, 12)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private var interactionBar: some View {
        HStack(spacing: 16) {
            ratingView
            Spacer()
            likeButton
            commentButton
            saveButton
        }
        .font(.system(size: 20))
        .padding(.top, 8)
    }
    
    private var ratingView: some View {
        Group {
            if let rating = post.rating {
                HStack(spacing: 4) {
                    ForEach(Array(1...5), id: \.self) { star in
                        let starRating = Double(star)
                        Image(systemName: {
                            if rating >= starRating {
                                return "star.fill"
                            } else if rating >= starRating - 0.5 {
                                return "star.leadinghalf.filled"
                            } else {
                                return "star"
                            }
                        }())
                        .foregroundColor(.orange)
                        .font(.caption2)
                    }
                }
                .padding(.trailing, 12)
            }
        }
    }
    
    private var likeButton: some View {
        HStack(spacing: 8) {
            // Heart icon button
            Button(action: { 
                HapticManager.shared.impact(.medium)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isLiked.toggle()
                }
                onLike?(post.id)
            }) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundColor(isLiked ? .red : .primaryText)
                    .scaleEffect(isLiked ? 1.2 : 1.0)
                    .rotation3DEffect(.degrees(isLiked ? 360 : 0), axis: (x: 0, y: 1, z: 0))
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isLiked)
            }
            .scaleEffect(isLiked ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLiked)
            
            // Clickable likes count
            if post.likesCount > 0 {
                Button(action: {
                    HapticManager.shared.impact(.light)
                    showPostLikes = true
                }) {
                    Text("\(post.likesCount) likes")
                        .font(.caption)
                        .foregroundColor(.primaryText)
                        .fontWeight(.medium)
                        .contentTransition(.numericText())
                }
            }
        }
    }
    
    private var commentButton: some View {
        Button(action: { 
            HapticManager.shared.impact(.light)
            showComments = true 
        }) {
            HStack(spacing: 4) {
                Image(systemName: "bubble.left")
                    .foregroundColor(.primaryText)
                    .scaleEffect(isCommentPressed ? 0.9 : 1.0)
                Text("\(currentCommentsCount)")
                    .font(.caption)
                    .foregroundColor(.primaryText)
                    .contentTransition(.numericText())
            }
        }
        .scaleEffect(isCommentPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0.05) {
            withAnimation(.easeOut(duration: 0.1)) {
                isCommentPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeIn(duration: 0.1)) {
                    isCommentPressed = false
                }
            }
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showSaveOptions = true
            }
        }) {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 22))
                .foregroundColor(isSaved ? .matchaGreen : .primaryText)
                .scaleEffect(isSaved ? 1.15 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSaved)
        }
        .sheet(isPresented: $showSaveOptions) {
            SaveOptionsView(
                post: post,
                isSaved: $isSaved,
                onListSelected: { list in
                    // Update saved state
                    isSaved = true
                    onBookmark?(post.id)
                }
            )
        }
    }
    
    private var titleSection: some View {
        Group {
            if let title = post.title, !title.isEmpty {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
    }
    
    private var captionSection: some View {
        Text(post.caption)
            .font(.footnote)
            .lineLimit(2)
            .foregroundColor(.primaryText)
    }
    
    @ViewBuilder
    private var recentCommentsSection: some View {
        if !recentComments.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                // "View all comments" button if there are more comments
                if currentCommentsCount > recentComments.count {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showComments = true
                    }) {
                        Text("View all \(currentCommentsCount) comments")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .fontWeight(.medium)
                    }
                }
                
                // Recent comments
                ForEach(recentComments.prefix(2)) { comment in
                    RecentCommentRow(comment: comment)
                }
            }
            .padding(.top, 4)
        } else if isLoadingComments {
            // Show skeleton loader for comments
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 12)
                        .frame(maxWidth: 200)
                    
                    Spacer()
                }
                .shimmer(isAnimating: .constant(true))
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Helper Functions
    private func doubleTapToLike() {
        HapticManager.shared.impact(.medium)
        
        // Show heart animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showHeartAnimation = true
        }
        
        // Hide heart animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showHeartAnimation = false
        }
        
        if !isLiked {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isLiked = true
            }
            onLike?(post.id)
        }
    }
    
    private func openDirections(to shop: Shop) {
        let coordinate = CLLocationCoordinate2D(
            latitude: shop.location.latitude,
            longitude: shop.location.longitude
        )
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = shop.name
        
        let launchOptions = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
    }
    
    private func loadRecentComments() async {
        guard !isLoadingComments else { return }
        
        isLoadingComments = true
        
        do {
            let backendComments = try await BackendService.shared.getRecentComments(
                postId: post.convexId,
                limit: 2
            )
            
            // Convert backend comments to frontend comments
            var convertedComments: [Comment] = []
            for backendComment in backendComments {
                // Try to get author information
                var author: User?
                do {
                    let backendAuthor = try await BackendService.shared.getUserByClerkId(clerkId: backendComment.authorClerkId)
                    author = backendAuthor.toUser()
                } catch {
                    print("⚠️ Failed to get author info for comment: \(error)")
                }
                
                let comment = Comment.from(backendComment, author: author)
                convertedComments.append(comment)
            }
            
            await MainActor.run {
                recentComments = convertedComments
            }
            
        } catch {
            print("❌ Failed to load recent comments: \(error)")
            await MainActor.run {
                recentComments = []
            }
        }
        
        isLoadingComments = false
    }
}

// MARK: - Recent Comment Row
struct RecentCommentRow: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Small avatar
            UserAvatar(user: comment.author, size: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                // Comment content with username
                Group {
                    Text(comment.author.username)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText) +
                    Text(" ") +
                    Text(comment.text)
                        .foregroundColor(.primaryText)
                }
                .font(.caption)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                
                // Time ago
                Text(comment.createdAt.timeAgoDisplay())
                    .font(.caption2)
                    .foregroundColor(.tertiaryText)
            }
            
            Spacer()
        }
    }
}

// Enhanced shimmer effect extension
extension View {
    func shimmer(isAnimating: Binding<Bool>) -> some View {
        self.overlay(
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.4),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .rotationEffect(.degrees(30))
            .offset(x: isAnimating.wrappedValue ? 300 : -300)
            .animation(
                Animation.linear(duration: 2.0)
                    .repeatForever(autoreverses: false),
                value: isAnimating.wrappedValue
            )
            .mask(self)
        )
    }
} 

// MARK: - Heart Animation View
struct HeartAnimationView: View {
    @State private var scale: CGFloat = 0.0
    @State private var opacity: Double = 0.0
    
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 80))
            .foregroundColor(.red)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scale = 1.2
                    opacity = 1.0
                }
                
                withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
                    scale = 1.5
                    opacity = 0.0
                }
            }
    }
} 

// MARK: - SwiftUI Previews
#Preview("Standard Post") {
    PostCard(post: MockData.generatePreviewPosts()[0])
        .environmentObject(MockAppState())
}

#Preview("Post with Multiple Images") {
    PostCard(post: MockData.generatePreviewPosts()[1]) // Truffle pasta with wine pairing
        .environmentObject(MockAppState())
}

#Preview("Omakase Experience") {
    PostCard(post: MockData.generatePreviewPosts()[6]) // David Kimura's sushi post
        .environmentObject(MockAppState())
}

#Preview("Vegan Post") {
    PostCard(post: MockData.generatePostsForDiet(.vegan)[0])
        .environmentObject(MockAppState())
}

#Preview("Japanese Cuisine") {
    PostCard(post: MockData.generatePostsForCuisine(.japanese)[0])
        .environmentObject(MockAppState())
}

#Preview("Trending Posts") {
    VStack {
        ForEach(MockData.generateTrendingPosts().prefix(3), id: \.id) { post in
            PostCard(post: post)
                .environmentObject(MockAppState())
        }
    }
}

#Preview("Dark Mode") {
    PostCard(post: MockData.generatePreviewPosts()[3]) // Vegan chocolate post
        .environmentObject(MockAppState())
        .preferredColorScheme(.dark)
} 
