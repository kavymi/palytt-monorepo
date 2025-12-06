//
//  StoriesView.swift
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

// MARK: - Story Model

struct Story: Identifiable, Equatable {
    let id: String
    let authorId: String
    let authorName: String
    let authorUsername: String
    let authorAvatarUrl: String?
    let mediaUrl: String
    let mediaType: StoryMediaType
    let caption: String?
    let shopName: String?
    let createdAt: Date
    let expiresAt: Date
    var viewCount: Int
    var hasViewed: Bool
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var timeRemaining: String {
        let remaining = expiresAt.timeIntervalSince(Date())
        if remaining <= 0 { return "Expired" }
        
        let hours = Int(remaining) / 3600
        if hours > 0 {
            return "\(hours)h left"
        } else {
            let minutes = Int(remaining) / 60
            return "\(minutes)m left"
        }
    }
}

enum StoryMediaType: String, Codable {
    case photo
    case video
}

// MARK: - User Stories (Grouped by User)

struct UserStories: Identifiable {
    let id: String
    let userId: String
    let displayName: String
    let username: String
    let avatarUrl: String?
    var stories: [Story]
    var hasUnviewedStories: Bool
    var isCurrentUser: Bool
    
    var latestStory: Story? {
        stories.last
    }
}

// MARK: - Stories Row View (Home Feed Header)

struct StoriesRowView: View {
    @StateObject private var viewModel = StoriesViewModel()
    @State private var showStoryViewer = false
    @State private var selectedUserStories: UserStories?
    @State private var showCreateStory = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Stories")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Stories scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Add story button (current user)
                    addStoryButton
                    
                    // Friends' stories
                    ForEach(viewModel.userStories) { userStory in
                        StoryAvatarView(
                            userStory: userStory,
                            onTap: {
                                selectedUserStories = userStory
                                showStoryViewer = true
                                HapticManager.shared.impact(.light)
                            }
                        )
                    }
                    
                    // Loading skeleton
                    if viewModel.isLoading {
                        ForEach(0..<3, id: \.self) { _ in
                            StoryAvatarSkeleton()
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(Color.appBackground)
        .fullScreenCover(isPresented: $showStoryViewer) {
            if let userStories = selectedUserStories {
                StoryViewerView(
                    userStories: userStories,
                    allUserStories: viewModel.userStories,
                    onDismiss: { showStoryViewer = false }
                )
            }
        }
        .sheet(isPresented: $showCreateStory) {
            StoryCreationView()
        }
        .task {
            await viewModel.loadStories()
        }
    }
    
    private var addStoryButton: some View {
        Button(action: {
            showCreateStory = true
            HapticManager.shared.impact(.light)
        }) {
            VStack(spacing: 6) {
                ZStack {
                    // Avatar with dashed border if no story
                    if let currentUser = viewModel.currentUserStories {
                        // User has stories - show their avatar
                        if let avatarUrl = currentUser.avatarUrl, let url = URL(string: avatarUrl) {
                            KFImage(url)
                                .placeholder {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.primaryBrand, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 3
                                        )
                                )
                        }
                    } else {
                        // No stories - show add button
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 2, dash: [5])
                                    )
                                    .foregroundColor(.primaryBrand)
                            )
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primaryBrand)
                            )
                    }
                    
                    // Add button overlay
                    Circle()
                        .fill(Color.primaryBrand)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 22, y: 22)
                }
                
                Text("Add Story")
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
            }
            .frame(width: 70)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Story Avatar View

struct StoryAvatarView: View {
    let userStory: UserStories
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Avatar with gradient ring
                ZStack {
                    if let avatarUrl = userStory.avatarUrl, let url = URL(string: avatarUrl) {
                        KFImage(url)
                            .placeholder {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(userStory.displayName.prefix(1).uppercased())
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            )
                    }
                }
                .overlay(
                    Circle()
                        .stroke(
                            userStory.hasUnviewedStories ?
                            LinearGradient(
                                colors: [.primaryBrand, .orange, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [.gray.opacity(0.3), .gray.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 66, height: 66)
                )
                
                // Username
                Text(userStory.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
            }
            .frame(width: 70)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Story Avatar Skeleton

struct StoryAvatarSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.4), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: isAnimating ? 60 : -60)
                )
                .clipShape(Circle())
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 10)
        }
        .frame(width: 70)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Story Viewer View

struct StoryViewerView: View {
    let userStories: UserStories
    let allUserStories: [UserStories]
    let onDismiss: () -> Void
    
    @State private var currentStoryIndex = 0
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?
    @State private var isPaused = false
    @State private var dragOffset: CGFloat = 0
    
    private let storyDuration: TimeInterval = 5.0
    
    var currentStory: Story? {
        guard currentStoryIndex < userStories.stories.count else { return nil }
        return userStories.stories[currentStoryIndex]
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let story = currentStory {
                    // Story content
                    storyContent(story: story, size: geo.size)
                }
                
                // Overlay controls
                VStack(spacing: 0) {
                    // Progress bars
                    storyProgressBars
                        .padding(.top, 50)
                        .padding(.horizontal)
                    
                    // Header
                    storyHeader
                        .padding()
                    
                    Spacer()
                    
                    // Caption and location badge
                    storyCaption(currentStory?.caption ?? "")
                        .padding(.bottom)
                }
                
                // Tap areas
                HStack(spacing: 0) {
                    // Previous story tap area
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            goToPreviousStory()
                        }
                    
                    // Next story tap area
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            goToNextStory()
                        }
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            onDismiss()
                        } else {
                            withAnimation {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .offset(y: dragOffset)
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
        }
    }
    
    private func storyContent(story: Story, size: CGSize) -> some View {
        KFImage(URL(string: story.mediaUrl))
            .placeholder {
                ProgressView()
                    .tint(.white)
            }
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: size.width, maxHeight: size.height)
    }
    
    private var storyProgressBars: some View {
        HStack(spacing: 4) {
            ForEach(0..<userStories.stories.count, id: \.self) { index in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                        
                        Capsule()
                            .fill(Color.white)
                            .frame(width: progressWidth(for: index, totalWidth: geo.size.width))
                    }
                }
                .frame(height: 3)
            }
        }
    }
    
    private func progressWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentStoryIndex {
            return totalWidth
        } else if index == currentStoryIndex {
            return totalWidth * progress
        } else {
            return 0
        }
    }
    
    private var storyHeader: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarUrl = userStories.avatarUrl, let url = URL(string: avatarUrl) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 36)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(userStories.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if let story = currentStory {
                    Text(story.timeRemaining)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(8)
            }
        }
    }
    
    private func storyCaption(_ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Prominent location badge
            if let shopName = currentStory?.shopName {
                HStack(spacing: 10) {
                    // Location pin with gradient background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.primaryBrand, .primaryBrand.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shopName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Tap to get directions")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.black.opacity(0.4))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            
            // Caption text
            if !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Timer Logic
    
    private func startTimer() {
        stopTimer()
        progress = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard !isPaused else { return }
            
            progress += 0.05 / storyDuration
            
            if progress >= 1.0 {
                goToNextStory()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func goToNextStory() {
        if currentStoryIndex < userStories.stories.count - 1 {
            currentStoryIndex += 1
            startTimer()
        } else {
            // TODO: Go to next user's stories or dismiss
            onDismiss()
        }
        HapticManager.shared.impact(.light)
    }
    
    private func goToPreviousStory() {
        if currentStoryIndex > 0 {
            currentStoryIndex -= 1
            startTimer()
        }
        HapticManager.shared.impact(.light)
    }
}

// MARK: - Story Creation View

struct StoryCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var caption = ""
    @State private var shopName = ""
    @State private var isUploading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Camera preview placeholder
                ZStack {
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 400)
                            .clipped()
                            .cornerRadius(20)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 400)
                            .overlay(
                                VStack(spacing: 16) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                    
                                    Text("Tap to capture your food moment")
                                        .font(.subheadline)
                                        .foregroundColor(.secondaryText)
                                }
                            )
                            .onTapGesture {
                                // TODO: Open camera
                                HapticManager.shared.impact(.light)
                            }
                    }
                }
                .padding(.horizontal)
                
                // Caption input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Caption")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    TextField("What are you eating?", text: $caption)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                // Shop/Restaurant input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location (optional)")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    TextField("Restaurant or place", text: $shopName)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Share button
                Button(action: {
                    // TODO: Upload story
                    isUploading = true
                    HapticManager.shared.impact(.medium)
                    
                    // Simulate upload
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isUploading = false
                        dismiss()
                    }
                }) {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Share Story")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.primaryBrand)
                    )
                }
                .disabled(isUploading)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color.appBackground)
            .navigationTitle("New Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
        }
    }
}

// MARK: - Stories View Model

@MainActor
class StoriesViewModel: ObservableObject {
    @Published var userStories: [UserStories] = []
    @Published var currentUserStories: UserStories?
    @Published var isLoading = false
    @Published var error: String?
    
    private let backendService = BackendService.shared
    
    func loadStories() async {
        isLoading = true
        error = nil
        
        // TODO: Fetch from backend when endpoint is ready
        // For now, generate mock data
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        generateMockStories()
        
        isLoading = false
    }
    
    private func generateMockStories() {
        let now = Date()
        let calendar = Calendar.current
        
        // Mock stories data
        let mockStories: [UserStories] = [
            UserStories(
                id: "1",
                userId: "user1",
                displayName: "FoodieQueen",
                username: "foodiequeen",
                avatarUrl: nil,
                stories: [
                    Story(
                        id: "s1",
                        authorId: "user1",
                        authorName: "FoodieQueen",
                        authorUsername: "foodiequeen",
                        authorAvatarUrl: nil,
                        mediaUrl: "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800",
                        mediaType: .photo,
                        caption: "Best pizza in town! 🍕",
                        shopName: "Luigi's Pizzeria",
                        createdAt: calendar.date(byAdding: .hour, value: -2, to: now)!,
                        expiresAt: calendar.date(byAdding: .hour, value: 22, to: now)!,
                        viewCount: 45,
                        hasViewed: false
                    )
                ],
                hasUnviewedStories: true,
                isCurrentUser: false
            ),
            UserStories(
                id: "2",
                userId: "user2",
                displayName: "SushiMaster",
                username: "sushimaster",
                avatarUrl: nil,
                stories: [
                    Story(
                        id: "s2",
                        authorId: "user2",
                        authorName: "SushiMaster",
                        authorUsername: "sushimaster",
                        authorAvatarUrl: nil,
                        mediaUrl: "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800",
                        mediaType: .photo,
                        caption: "Fresh sashimi today! 🍣",
                        shopName: "Tokyo Garden",
                        createdAt: calendar.date(byAdding: .hour, value: -5, to: now)!,
                        expiresAt: calendar.date(byAdding: .hour, value: 19, to: now)!,
                        viewCount: 78,
                        hasViewed: true
                    ),
                    Story(
                        id: "s3",
                        authorId: "user2",
                        authorName: "SushiMaster",
                        authorUsername: "sushimaster",
                        authorAvatarUrl: nil,
                        mediaUrl: "https://images.unsplash.com/photo-1553621042-f6e147245754?w=800",
                        mediaType: .photo,
                        caption: "Can't get enough!",
                        shopName: "Tokyo Garden",
                        createdAt: calendar.date(byAdding: .hour, value: -3, to: now)!,
                        expiresAt: calendar.date(byAdding: .hour, value: 21, to: now)!,
                        viewCount: 32,
                        hasViewed: false
                    )
                ],
                hasUnviewedStories: true,
                isCurrentUser: false
            ),
            UserStories(
                id: "3",
                userId: "user3",
                displayName: "CoffeeAddict",
                username: "coffeeaddict",
                avatarUrl: nil,
                stories: [
                    Story(
                        id: "s4",
                        authorId: "user3",
                        authorName: "CoffeeAddict",
                        authorUsername: "coffeeaddict",
                        authorAvatarUrl: nil,
                        mediaUrl: "https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800",
                        mediaType: .photo,
                        caption: "Morning vibes ☕",
                        shopName: "The Coffee Lab",
                        createdAt: calendar.date(byAdding: .hour, value: -8, to: now)!,
                        expiresAt: calendar.date(byAdding: .hour, value: 16, to: now)!,
                        viewCount: 120,
                        hasViewed: true
                    )
                ],
                hasUnviewedStories: false,
                isCurrentUser: false
            )
        ]
        
        userStories = mockStories
    }
    
    func markAsViewed(_ story: Story) async {
        // TODO: Update backend
        // Update local state
        if let userIndex = userStories.firstIndex(where: { $0.stories.contains(where: { $0.id == story.id }) }),
           let storyIndex = userStories[userIndex].stories.firstIndex(where: { $0.id == story.id }) {
            userStories[userIndex].stories[storyIndex].hasViewed = true
            
            // Update hasUnviewedStories
            userStories[userIndex].hasUnviewedStories = userStories[userIndex].stories.contains { !$0.hasViewed }
        }
    }
}

// MARK: - Previews

#Preview("Stories Row") {
    StoriesRowView()
        .background(Color.appBackground)
}

#Preview("Story Creation") {
    StoryCreationView()
}


