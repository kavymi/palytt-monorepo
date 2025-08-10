//
//  SkeletonLoader.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Base Skeleton Loader
struct SkeletonLoader: View {
    @State private var isAnimating = false
    
    let cornerRadius: CGFloat
    let animationSpeed: Double
    
    init(cornerRadius: CGFloat = 8, animationSpeed: Double = 1.5) {
        self.cornerRadius = cornerRadius
        self.animationSpeed = animationSpeed
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.4),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: isAnimating ? 200 : -200)
                    .animation(
                        Animation.linear(duration: animationSpeed)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                    .clipped()
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Enhanced Post Card Skeleton
struct PostCardSkeleton: View {
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author Header Skeleton
            authorHeaderSkeleton
            
            // Media Skeleton with enhanced animation
            mediaSkeletonView
            
            // Interaction Bar Skeleton
            interactionBarSkeleton
            
            // Caption Skeleton
            captionSkeletonView
            
            // Rating Skeleton
            ratingSkeletonView
            
            // Timestamp Skeleton
            timestampSkeleton
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .scaleEffect(pulseScale)
        .onAppear {
            startPulseAnimation()
        }
    }
    
    private var authorHeaderSkeleton: some View {
        HStack {
            // Avatar Skeleton
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.6), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            Animation.linear(duration: 2.0).repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                SkeletonLoader(cornerRadius: 6)
                    .frame(width: 120, height: 14)
                
                SkeletonLoader(cornerRadius: 4)
                    .frame(width: 80, height: 10)
            }
            
            Spacer()
            
            SkeletonLoader(cornerRadius: 4)
                .frame(width: 16, height: 16)
        }
    }
    
    private var mediaSkeletonView: some View {
        ZStack {
            SkeletonLoader(cornerRadius: 16)
                .frame(height: 350)
            
            // Overlay shimmer effect
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        center: UnitPoint(x: isAnimating ? 1.2 : -0.2, y: 0.5),
                        startRadius: 10,
                        endRadius: 100
                    )
                )
                .animation(
                    Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Photo placeholder icon
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .opacity(isAnimating ? 0.3 : 0.6)
                .animation(
                    Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
    }
    
    private var interactionBarSkeleton: some View {
        HStack(spacing: 16) {
            // Rating skeleton
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: "star")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.3))
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: isAnimating
                        )
                }
            }
            
            Spacer()
            
            // Interaction buttons skeleton
            ForEach(0..<3, id: \.self) { index in
                HStack(spacing: 4) {
                    SkeletonLoader(cornerRadius: 10)
                        .frame(width: 20, height: 20)
                    SkeletonLoader(cornerRadius: 6)
                        .frame(width: 20, height: 12)
                }
                .opacity(isAnimating ? 0.6 : 0.3)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                    value: isAnimating
                )
            }
        }
        .font(.system(size: 20))
        .padding(.top, 8)
    }
    
    private var captionSkeletonView: some View {
        VStack(alignment: .leading, spacing: 4) {
            SkeletonLoader(cornerRadius: 6)
                .frame(height: 12)
            
            SkeletonLoader(cornerRadius: 6)
                .frame(width: 200, height: 12)
            
            SkeletonLoader(cornerRadius: 6)
                .frame(width: 150, height: 12)
        }
    }
    
    private var ratingSkeletonView: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                SkeletonLoader(cornerRadius: 6)
                    .frame(width: 12, height: 12)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
            SkeletonLoader(cornerRadius: 4)
                .frame(width: 30, height: 12)
        }
    }
    
    private var timestampSkeleton: some View {
        HStack {
            SkeletonLoader(cornerRadius: 4)
                .frame(width: 60, height: 10)
            Spacer()
        }
    }
    
    private func startPulseAnimation() {
        isAnimating = true
        
        // Subtle pulse effect
        withAnimation(
            Animation.easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.02
        }
    }
}

// MARK: - Enhanced Map Loading Skeleton
struct MapLoadingSkeleton: View {
    @State private var animationOffset: CGFloat = -100
    @State private var pulseOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Base map background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
            
            // Animated map grid
            VStack(spacing: 20) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 20) {
                        ForEach(0..<3, id: \.self) { col in
                            Circle()
                                .fill(Color.primaryBrand.opacity(pulseOpacity))
                                .frame(width: 8, height: 8)
                                .scaleEffect(pulseOpacity + 0.5)
                                .animation(
                                    Animation.easeInOut(duration: 1.5)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(row + col) * 0.2),
                                    value: pulseOpacity
                                )
                        }
                    }
                }
            }
            
            // Scanning line effect
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.primaryBrand.opacity(0.3), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 2)
                .offset(x: animationOffset)
                .animation(
                    Animation.linear(duration: 2.0).repeatForever(autoreverses: false),
                    value: animationOffset
                )
            
            // Loading text
            VStack {
                Spacer()
                
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.primaryBrand)
                    
                    Text("Loading food spots...")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding()
                .background(Color.cardBackground.opacity(0.9))
                .cornerRadius(20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            animationOffset = 100
            pulseOpacity = 0.8
        }
    }
}

// MARK: - Search Results Skeleton
struct SearchResultSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail skeleton
            SkeletonLoader(cornerRadius: 8)
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLoader(cornerRadius: 6)
                    .frame(width: 150, height: 14)
                
                SkeletonLoader(cornerRadius: 4)
                    .frame(width: 100, height: 10)
                
                SkeletonLoader(cornerRadius: 4)
                    .frame(width: 80, height: 10)
            }
            
            Spacer()
            
            SkeletonLoader(cornerRadius: 6)
                .frame(width: 30, height: 20)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Comments Section Skeleton
struct CommentsSectionSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { index in
                CommentSkeletonRow()
                    .opacity(1.0 - (Double(index) * 0.15)) // Fade effect
            }
        }
        .padding(.horizontal)
    }
}

struct CommentSkeletonRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 6) {
                // Username
                SkeletonLoader(cornerRadius: 4)
                    .frame(width: 80, height: 12)
                
                // Comment text
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonLoader(cornerRadius: 4)
                        .frame(height: 10)
                    
                    SkeletonLoader(cornerRadius: 4)
                        .frame(width: 120, height: 10)
                }
                
                // Timestamp
                SkeletonLoader(cornerRadius: 3)
                    .frame(width: 50, height: 8)
            }
            
            Spacer()
        }
    }
}

// MARK: - Create Post Steps Skeleton
struct CreatePostStepSkeleton: View {
    let step: Int
    
    var body: some View {
        VStack(spacing: 20) {
            switch step {
            case 0:
                cameraStepSkeleton
            case 1:
                detailsStepSkeleton
            case 2:
                locationStepSkeleton
            default:
                EmptyView()
            }
        }
    }
    
    private var cameraStepSkeleton: some View {
        VStack(spacing: 16) {
            // Camera preview skeleton
            ZStack {
                SkeletonLoader(cornerRadius: 20)
                    .frame(height: 400)
                
                Image(systemName: "camera")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.4))
            }
            
            // Capture button skeleton
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 70, height: 70)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                )
        }
    }
    
    private var detailsStepSkeleton: some View {
        VStack(spacing: 16) {
            // Title field skeleton
            SkeletonLoader(cornerRadius: 12)
                .frame(height: 50)
            
            // Caption field skeleton
            SkeletonLoader(cornerRadius: 12)
                .frame(height: 120)
            
            // Rating skeleton
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonLoader(cornerRadius: 8)
                        .frame(width: 30, height: 30)
                }
            }
        }
    }
    
    private var locationStepSkeleton: some View {
        VStack(spacing: 16) {
            // Search bar skeleton
            SkeletonLoader(cornerRadius: 12)
                .frame(height: 50)
            
            // Map skeleton
            MapLoadingSkeleton()
                .frame(height: 200)
            
            // Location suggestions skeleton
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack {
                        SkeletonLoader(cornerRadius: 6)
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            SkeletonLoader(cornerRadius: 4)
                                .frame(width: 150, height: 12)
                            
                            SkeletonLoader(cornerRadius: 3)
                                .frame(width: 100, height: 10)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Profile Grid Skeleton
struct ProfileGridSkeleton: View {
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2)
        ], spacing: 2) {
            ForEach(0..<9, id: \.self) { _ in
                SkeletonLoader()
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Profile Header Skeleton
struct ProfileHeaderSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            // Profile Picture
            SkeletonLoader()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            
            VStack(spacing: 8) {
                // Username
                SkeletonLoader()
                    .frame(width: 120, height: 20)
                
                // Bio
                SkeletonLoader()
                    .frame(width: 200, height: 14)
                
                SkeletonLoader()
                    .frame(width: 150, height: 14)
            }
            
            // Edit Profile Button
            SkeletonLoader()
                .frame(width: 100, height: 32)
                .cornerRadius(16)
        }
        .padding()
    }
}

// MARK: - Grid Item Skeleton
struct GridItemSkeleton: View {
    var body: some View {
        SkeletonLoader()
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(8)
    }
}

// MARK: - Message Bubble Skeleton (moved to ChatView.swift)
// struct MessageBubbleSkeleton is defined in ChatView.swift to avoid duplication

// MARK: - List Card Skeleton (already exists, but enhanced)
struct ListCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                SkeletonLoader(cornerRadius: 6)
                    .frame(width: 120, height: 16)
                
                Spacer()
                
                SkeletonLoader(cornerRadius: 4)
                    .frame(width: 30, height: 12)
            }
            
            // Description
            VStack(alignment: .leading, spacing: 4) {
                SkeletonLoader(cornerRadius: 4)
                    .frame(height: 10)
                
                SkeletonLoader(cornerRadius: 4)
                    .frame(width: 150, height: 10)
            }
            
            // Image grid
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonLoader(cornerRadius: 8)
                        .aspectRatio(1, contentMode: .fill)
                }
            }
            .frame(height: 60)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Loading View (defined in LoadingView.swift)
// struct LoadingView is defined in LoadingView.swift to avoid duplication

// MARK: - Preview
#Preview("Post Card Skeleton") {
    PostCardSkeleton()
        .padding()
}

#Preview("Map Loading Skeleton") {
    MapLoadingSkeleton()
        .frame(height: 300)
        .padding()
}

#Preview("Loading View") {
    LoadingView()
} 