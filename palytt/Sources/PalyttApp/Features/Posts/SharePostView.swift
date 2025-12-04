//
//  SharePostView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI

// MARK: - Share Post View

struct SharePostView: View {
    let post: Post
    @StateObject private var shareService = ShareService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDestination: ShareDestination?
    @State private var isSharing = false
    @State private var shareSuccessful = false
    @State private var linkCopied = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preview Card
                PostShareCard(post: post)
                    .scaleEffect(0.6)
                    .frame(height: 300)
                
                // Share Destinations
                VStack(alignment: .leading, spacing: 12) {
                    Text("Share to")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(ShareDestination.allCases) { destination in
                            shareButton(for: destination)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .background(Color.appBackground)
            .navigationTitle("Share Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
            .overlay {
                if shareService.isGeneratingImage || isSharing {
                    loadingOverlay
                }
            }
            .alert("Link Copied!", isPresented: $linkCopied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The post link has been copied to your clipboard")
            }
            .alert("Share Error", isPresented: .constant(shareService.shareError != nil)) {
                Button("OK", role: .cancel) {
                    shareService.shareError = nil
                }
            } message: {
                if let error = shareService.shareError {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Share Button
    
    private func shareButton(for destination: ShareDestination) -> some View {
        Button(action: {
            handleShare(to: destination)
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(destination.color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: destination.icon)
                        .font(.title2)
                        .foregroundColor(destination.color)
                }
                
                Text(destination.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .disabled(!destination.isAvailable && destination != .copyLink && destination != .more)
        .opacity(destination.isAvailable || destination == .copyLink || destination == .more ? 1.0 : 0.5)
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                
                Text(shareService.isGeneratingImage ? "Generating..." : "Sharing...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardBackground)
            )
        }
    }
    
    // MARK: - Handle Share
    
    private func handleShare(to destination: ShareDestination) {
        HapticManager.shared.impact(.medium)
        selectedDestination = destination
        
        switch destination {
        case .instagram:
            shareToInstagram()
            
        case .copyLink:
            shareService.copyPostLink(postId: post.convexId)
            linkCopied = true
            
        case .more:
            shareViaSystemSheet()
            
        default:
            // For other platforms, use system share sheet
            shareViaSystemSheet()
        }
    }
    
    private func shareToInstagram() {
        shareService.generateShareableImage(for: post) { image in
            guard let image = image else {
                shareService.shareError = "Failed to generate share image"
                return
            }
            
            isSharing = true
            shareService.shareToInstagramStories(image: image) { success, error in
                isSharing = false
                if let error = error {
                    shareService.shareError = error
                } else if success {
                    shareSuccessful = true
                    dismiss()
                }
            }
        }
    }
    
    private func shareViaSystemSheet() {
        shareService.generateShareableImage(for: post) { image in
            guard let image = image else {
                // Fall back to text-only share
                let text = shareService.getShareText(for: post)
                shareService.shareViaSystemSheet(image: UIImage(), text: text, from: nil)
                return
            }
            
            let text = shareService.getShareText(for: post)
            shareService.shareViaSystemSheet(image: image, text: text, from: nil)
        }
    }
}

// MARK: - Preview

#Preview {
    SharePostView(post: Post(
        userId: UUID(),
        author: User(
            id: UUID(),
            email: "preview@example.com",
            username: "previewuser",
            displayName: "Preview User",
            clerkId: "preview_clerk_id"
        ),
        caption: "This is a preview post for testing the share view.",
        mediaURLs: [URL(string: "https://picsum.photos/400/400")!],
        location: Location(
            latitude: 37.7749,
            longitude: -122.4194,
            address: "San Francisco, CA",
            city: "San Francisco",
            country: "USA"
        ),
        likesCount: 42,
        commentsCount: 5
    ))
}

