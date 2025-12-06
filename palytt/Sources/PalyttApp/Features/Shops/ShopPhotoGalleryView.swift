//
//  ShopPhotoGalleryView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Kingfisher

// MARK: - Shop Photo Gallery View

/// Displays a horizontal scrolling gallery of photos from related posts
struct ShopPhotoGalleryView: View {
    let posts: [Post]
    let shopName: String
    @State private var selectedPhotoIndex: Int?
    @State private var showFullScreen = false
    
    private var allPhotos: [PhotoItem] {
        var photos: [PhotoItem] = []
        for post in posts {
            for (index, url) in post.mediaURLs.enumerated() {
                photos.append(PhotoItem(
                    id: "\(post.id.uuidString)-\(index)",
                    url: url,
                    postId: post.id,
                    authorName: post.author.displayName,
                    caption: post.caption
                ))
            }
        }
        return photos
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.primaryBrand)
                    .font(.title3)
                
                Text("Photos")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                if allPhotos.count > 6 {
                    Button(action: {
                        // Navigate to full gallery
                        showFullScreen = true
                        selectedPhotoIndex = 0
                    }) {
                        Text("See all \(allPhotos.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primaryBrand)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Photo Grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(allPhotos.prefix(10).enumerated()), id: \.element.id) { index, photo in
                        PhotoThumbnail(
                            photo: photo,
                            onTap: {
                                selectedPhotoIndex = index
                                showFullScreen = true
                                HapticManager.shared.impact(.light)
                            }
                        )
                    }
                    
                    // "More" card if there are more photos
                    if allPhotos.count > 10 {
                        MorePhotosCard(
                            remainingCount: allPhotos.count - 10,
                            onTap: {
                                selectedPhotoIndex = 0
                                showFullScreen = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenPhotoGallery(
                photos: allPhotos,
                selectedIndex: selectedPhotoIndex ?? 0,
                shopName: shopName
            )
        }
    }
}

// MARK: - Photo Item Model

struct PhotoItem: Identifiable {
    let id: String
    let url: URL
    let postId: UUID
    let authorName: String
    let caption: String
}

// MARK: - Photo Thumbnail

struct PhotoThumbnail: View {
    let photo: PhotoItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            KFImage(photo.url)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - More Photos Card

struct MorePhotosCard: View {
    let remainingCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                VStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.primaryBrand)
                    
                    Text("+\(remainingCount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryBrand)
                    
                    Text("more")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Full Screen Photo Gallery

struct FullScreenPhotoGallery: View {
    let photos: [PhotoItem]
    let selectedIndex: Int
    let shopName: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    init(photos: [PhotoItem], selectedIndex: Int, shopName: String) {
        self.photos = photos
        self.selectedIndex = selectedIndex
        self.shopName = shopName
        self._currentIndex = State(initialValue: selectedIndex)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Photo Pager
            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    FullScreenPhotoView(photo: photo)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(shopName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("\(currentIndex + 1) of \(photos.count)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Share button
                    Button(action: {
                        // Share action
                        HapticManager.shared.impact(.light)
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                // Photo Info
                if currentIndex < photos.count {
                    let photo = photos[currentIndex]
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                            Text(photo.authorName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        
                        if !photo.caption.isEmpty {
                            Text(photo.caption)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Full Screen Photo View

struct FullScreenPhotoView: View {
    let photo: PhotoItem
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            KFImage(photo.url)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, 1), 4)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            if scale < 1.0 {
                                withAnimation(.spring()) {
                                    scale = 1.0
                                }
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            lastOffset = offset
                            if scale <= 1 {
                                withAnimation(.spring()) {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        if scale > 1 {
                            scale = 1
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2
                        }
                    }
                }
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    let mockPosts = [
        Post(
            userId: UUID(),
            author: User(
                id: UUID(),
                email: "test@test.com",
                username: "foodie",
                displayName: "Food Lover"
            ),
            caption: "Amazing brunch at this place!",
            mediaURLs: [
                URL(string: "https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445")!,
                URL(string: "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38")!
            ],
            location: Location(latitude: 37.7749, longitude: -122.4194, address: "123 Main St", city: "San Francisco", country: "USA")
        ),
        Post(
            userId: UUID(),
            author: User(
                id: UUID(),
                email: "test2@test.com",
                username: "chef",
                displayName: "Chef Mike"
            ),
            caption: "The pasta here is incredible",
            mediaURLs: [
                URL(string: "https://images.unsplash.com/photo-1481070555726-e2fe8357725c")!
            ],
            location: Location(latitude: 37.7749, longitude: -122.4194, address: "456 Oak Ave", city: "San Francisco", country: "USA")
        )
    ]
    
    ScrollView {
        ShopPhotoGalleryView(posts: mockPosts, shopName: "The Best Restaurant")
            .padding()
    }
    .background(Color.background)
}

