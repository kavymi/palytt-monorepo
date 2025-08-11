//
//  EnhancedPostPickerView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Clerk

struct EnhancedPostPickerView: View {
    let onPostSelected: (Post) -> Void
    let onPlaceSelected: ((Place) -> Void)?
    let onLinkSelected: ((String) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var posts: [Post] = []
    @State private var savedPlaces: [Place] = []
    @State private var isLoading = true
    @State private var linkText = ""
    
    private let tabs = ["Posts", "Places", "Links"]
    
    init(onPostSelected: @escaping (Post) -> Void, onPlaceSelected: ((Place) -> Void)? = nil, onLinkSelected: ((String) -> Void)? = nil) {
        self.onPostSelected = onPostSelected
        self.onPlaceSelected = onPlaceSelected
        self.onLinkSelected = onLinkSelected
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom tab picker
                tabPicker
                
                Divider()
                    .background(Color.divider)
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    postsTabView
                        .tag(0)
                    
                    placesTabView
                        .tag(1)
                    
                    linksTabView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .background(Color.background)
            .navigationTitle("Share Content")
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
            loadContent()
        }
    }
    
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    HapticManager.shared.impact(.light)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tabs[index])
                            .font(.subheadline)
                            .fontWeight(selectedTab == index ? .semibold : .medium)
                            .foregroundColor(selectedTab == index ? .primaryBrand : .secondaryText)
                        
                        Rectangle()
                            .fill(selectedTab == index ? Color.primaryBrand : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var postsTabView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if isLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        PostCardSkeleton()
                    }
                } else if posts.isEmpty {
                    EmptyPostsStateView()
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
            .padding(.top, 16)
        }
        .background(Color.background)
    }
    
    private var placesTabView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if isLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        PlaceCardSkeleton()
                    }
                } else if savedPlaces.isEmpty {
                    EmptyPlacesStateView()
                } else {
                    ForEach(savedPlaces, id: \.id) { place in
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            onPlaceSelected?(place)
                            dismiss()
                        }) {
                            PlaceShareCard(place: place)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color.background)
    }
    
    private var linksTabView: some View {
        VStack(spacing: 24) {
            // Link input section
            VStack(alignment: .leading, spacing: 12) {
                Text("Share a Link")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text("Paste a link to share with your friends")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                
                VStack(spacing: 16) {
                    TextField("https://example.com", text: $linkText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.body)
                        .foregroundColor(.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.cardBackground)
                                .stroke(Color.divider.opacity(0.5), lineWidth: 1)
                        )
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button(action: {
                        shareLink()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Share Link")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient.primaryGradient
                                .cornerRadius(12)
                        )
                        .shadow(color: .primaryBrand.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(HapticButtonStyle(haptic: .medium, sound: .tap))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            Spacer()
        }
        .background(Color.background)
    }
    
    private func shareLink() {
        let trimmedLink = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLink.isEmpty else { return }
        
        onLinkSelected?(trimmedLink)
        dismiss()
    }
    
    private func loadContent() {
        isLoading = true
        
        Task {
            await loadUserPosts()
            await loadSavedPlaces()
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadUserPosts() async {
        do {
            guard let currentUser = Clerk.shared.user else {
                posts = []
                return
            }
            
            // Load user's posts from backend
            let backendPosts = try await BackendService.shared.getPostsByUser(userId: currentUser.id)
            
            // Convert backend posts to Post model
            await MainActor.run {
                posts = backendPosts.compactMap { backendPost in
                    Post.from(backendPost: backendPost, author: nil)
                }
            }
            
            print("✅ EnhancedPostPickerView: Loaded \(posts.count) posts for sharing")
            
        } catch {
            print("❌ EnhancedPostPickerView: Failed to load user posts: \(error)")
            await MainActor.run {
                posts = []
            }
        }
    }
    
    private func loadSavedPlaces() async {
        // TODO: Implement saved places loading
        // For now, using mock data
        await MainActor.run {
            savedPlaces = []
        }
    }
}

// MARK: - Place Share Card
struct PlaceShareCard: View {
    let place: Place
    
    var body: some View {
        HStack(spacing: 12) {
            // Place image placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient.primaryGradient.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "location.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.primaryBrand)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                if let address = place.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    
                    Text("4.5")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                    
                    Text("• Restaurant")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            
            Spacer()
            
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 16))
                .foregroundColor(.primaryBrand)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Empty States
struct EmptyPostsStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Circle()
                .fill(LinearGradient.primaryGradient.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundColor(.primaryBrand)
                )
            
            VStack(spacing: 8) {
                Text("No Posts Yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("Create some posts to share them with friends!")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
    }
}

struct EmptyPlacesStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Circle()
                .fill(LinearGradient.primaryGradient.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "location")
                        .font(.system(size: 32))
                        .foregroundColor(.primaryBrand)
                )
            
            VStack(spacing: 8) {
                Text("No Saved Places")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("Save some places to share them with friends!")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Skeleton Views
struct PlaceCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .shimmer(isAnimating: $isAnimating)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 12)
                    .shimmer(isAnimating: $isAnimating)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 180, height: 10)
                    .shimmer(isAnimating: $isAnimating)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 8)
                    .shimmer(isAnimating: $isAnimating)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview
#Preview {
    EnhancedPostPickerView(
        onPostSelected: { _ in },
        onPlaceSelected: { _ in },
        onLinkSelected: { _ in }
    )
}
