//
//  TimelineView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

struct FeedTimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showingFeedPreferences = false
    @State private var selectedFilter: TimelineFilter = .all
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Bar
                filterBar
                
                // Content
                content
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingFeedPreferences = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.primaryBrand)
                    }
                }
            }
            .sheet(isPresented: $showingFeedPreferences) {
                FeedPreferencesView()
            }
            .refreshable {
                await viewModel.refreshTimeline()
            }
        }
        .task {
            await viewModel.loadTimeline()
        }
    }
    
    // MARK: - Filter Bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimelineFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                        viewModel.applyFilter(filter)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.background)
    }
    
    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            loadingView
        } else if viewModel.posts.isEmpty {
            emptyStateView
        } else {
            timelineList
        }
    }
    
    // MARK: - Timeline List
    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(groupedPosts, id: \.date) { group in
                    TimelineDateSection(
                        date: group.date,
                        posts: group.posts
                    )
                }
                
                // Load More Button
                if viewModel.hasMorePosts {
                    loadMoreButton
                        .padding()
                }
            }
        }
        .background(Color.background)
    }
    
    // MARK: - Grouped Posts
    private var groupedPosts: [TimelineDateGroup] {
        Dictionary(grouping: viewModel.posts) { post in
            Calendar.current.startOfDay(for: post.createdAt)
        }
        .map { TimelineDateGroup(date: $0.key, posts: $0.value) }
        .sorted { $0.date > $1.date }
    }
    
    // MARK: - Load More Button
    private var loadMoreButton: some View {
        Button(action: {
            Task {
                await viewModel.loadMorePosts()
            }
        }) {
            if viewModel.isLoadingMore {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                        .scaleEffect(0.8)
                    
                    Text("Loading more...")
                        .font(.subheadline)
                        .foregroundColor(.primaryBrand)
                }
            } else {
                Text("Load More")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryBrand)
            }
        }
        .disabled(viewModel.isLoadingMore)
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                .scaleEffect(1.2)
            
            Text("Loading your timeline...")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.fill")
                .font(.system(size: 60))
                .foregroundColor(.milkTea)
            
            VStack(spacing: 8) {
                Text("Your Timeline is Empty")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text("Follow some friends or explore new posts to see them here!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondaryText)
            }
            
            Button(action: {
                appState.selectedTab = .explore
            }) {
                Text("Explore Posts")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.primaryBrand)
                    .cornerRadius(25)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
    }
}

// MARK: - Timeline Date Group
struct TimelineDateGroup {
    let date: Date
    let posts: [Post]
}

// MARK: - Timeline Date Section
struct TimelineDateSection: View {
    let date: Date
    let posts: [Post]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var isYesterday: Bool {
        Calendar.current.isDateInYesterday(date)
    }
    
    private var dateString: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            return dateFormatter.string(from: date)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date Header
            HStack {
                Text(dateString)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Text("\(posts.count) post\(posts.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Posts
            LazyVStack(spacing: 12) {
                ForEach(posts.sorted { $0.createdAt > $1.createdAt }, id: \.id) { post in
                    TimelinePostCard(post: post)
                        .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Timeline Post Card
struct TimelinePostCard: View {
    let post: Post
    @State private var showingComments = false
    @State private var currentCommentsCount: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                AsyncImage(url: post.author.avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    
                    HStack(spacing: 4) {
                        Text(timeAgoString)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        if let location = post.location {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            Text(location.displayName)
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                Menu {
                    Button("Share", action: {})
                    Button("Save", action: {})
                    Button("Report", action: {})
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.tertiaryText)
                }
            }
            
            // Content
            if !post.content.isEmpty {
                Text(post.content)
                    .font(.body)
                    .foregroundColor(.primaryText)
                    .multilineTextAlignment(.leading)
            }
            
            // Images
            if !post.imageUrls.isEmpty {
                TimelineImageGrid(imageUrls: post.imageUrls)
            }
            
            // Rating
            if let rating = post.rating {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(.warning)
                    }
                }
            }
            
            // Actions
            HStack {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(post.isLiked ? .red : .tertiaryText)
                        
                        if post.likesCount > 0 {
                            Text("\(post.likesCount)")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
                
                Button(action: {
                    showingComments = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.tertiaryText)
                        
                        if currentCommentsCount > 0 {
                            Text("\(currentCommentsCount)")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .contentTransition(.numericText())
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: post.isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(post.isBookmarked ? .primaryBrand : .tertiaryText)
                }
            }
            .font(.title3)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            currentCommentsCount = post.commentsCount
        }
        .sheet(isPresented: $showingComments) {
            CommentsView(post: post) { newCount in
                // Update the local comment count for real-time UI updates
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentCommentsCount = newCount
                }
            }
        }
    }
    
    private var timeAgoString: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(post.createdAt)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        }
    }
}

// MARK: - Timeline Image Grid
struct TimelineImageGrid: View {
    let imageUrls: [String]
    
    var body: some View {
        if imageUrls.count == 1 {
            AsyncImage(url: URL(string: imageUrls[0])) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(maxHeight: 300)
            .clipped()
            .cornerRadius(12)
        } else {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4)
            ], spacing: 4) {
                ForEach(Array(imageUrls.prefix(4).enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: URL(string: url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        index == 3 && imageUrls.count > 4 ?
                        ZStack {
                            Color.black.opacity(0.6)
                            
                            Text("+\(imageUrls.count - 4)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .cornerRadius(8)
                        : nil
                    )
                }
            }
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let filter: TimelineFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                
                Text(filter.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.primaryBrand : Color.cardBackground)
            )
            .foregroundColor(isSelected ? .white : .primaryText)
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.divider, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Timeline Filter
enum TimelineFilter: String, CaseIterable {
    case all = "all"
    case following = "following"
    case friends = "friends"
    case nearby = "nearby"
    case liked = "liked"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .following: return "Following"
        case .friends: return "Friends"
        case .nearby: return "Nearby"
        case .liked: return "Liked"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .following: return "person.badge.plus"
        case .friends: return "person.2.fill"
        case .nearby: return "location.fill"
        case .liked: return "heart.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    TimelineView()
        .environmentObject(MockAppState())
} 