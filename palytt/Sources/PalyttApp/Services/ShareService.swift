//
//  ShareService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation
import UIKit
import SwiftUI

// MARK: - Share Destination

enum ShareDestination: String, CaseIterable, Identifiable {
    case instagram = "Instagram Stories"
    case facebook = "Facebook"
    case twitter = "Twitter/X"
    case messages = "Messages"
    case copyLink = "Copy Link"
    case more = "More Options"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .instagram: return "camera.fill"
        case .facebook: return "bubble.left.fill"
        case .twitter: return "at"
        case .messages: return "message.fill"
        case .copyLink: return "link"
        case .more: return "ellipsis"
        }
    }
    
    var color: Color {
        switch self {
        case .instagram: return Color(red: 0.89, green: 0.32, blue: 0.55)  // Instagram gradient-ish
        case .facebook: return Color(red: 0.26, green: 0.40, blue: 0.70)
        case .twitter: return Color.black
        case .messages: return Color.green
        case .copyLink: return Color.gray
        case .more: return Color.secondaryText
        }
    }
    
    var urlScheme: String? {
        switch self {
        case .instagram: return "instagram-stories://share"
        case .facebook: return "fb://publish"
        case .twitter: return "twitter://post"
        case .messages: return "sms:"
        case .copyLink, .more: return nil
        }
    }
    
    var isAvailable: Bool {
        guard let scheme = urlScheme,
              let url = URL(string: scheme) else {
            return true  // copyLink and more are always available
        }
        return UIApplication.shared.canOpenURL(url)
    }
}

// MARK: - Share Service

@MainActor
class ShareService: ObservableObject {
    static let shared = ShareService()
    
    @Published var isGeneratingImage = false
    @Published var generatedImage: UIImage?
    @Published var shareError: String?
    
    private init() {}
    
    /// Generate a shareable card image for a post
    func generateShareableImage(for post: Post, completion: @escaping (UIImage?) -> Void) {
        isGeneratingImage = true
        
        // Create the share card view
        let shareCardView = PostShareCard(post: post)
        
        // Render the view to an image
        let controller = UIHostingController(rootView: shareCardView)
        let targetSize = CGSize(width: 375, height: 500)  // Standard share card size
        
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.backgroundColor = .clear
        
        // Force layout
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        
        // Render to image
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let image = renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        
        generatedImage = image
        isGeneratingImage = false
        completion(image)
    }
    
    /// Share to Instagram Stories
    func shareToInstagramStories(image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        guard let imageData = image.pngData() else {
            completion(false, "Failed to convert image")
            return
        }
        
        // Check if Instagram is installed
        guard let instagramURL = URL(string: "instagram-stories://share") else {
            completion(false, "Instagram not installed")
            return
        }
        
        guard UIApplication.shared.canOpenURL(instagramURL) else {
            completion(false, "Instagram not installed")
            return
        }
        
        // Copy image to pasteboard
        let pasteboardItems: [[String: Any]] = [[
            "com.instagram.sharedSticker.stickerImage": imageData,
            "com.instagram.sharedSticker.backgroundTopColor": "#FFFFFF",
            "com.instagram.sharedSticker.backgroundBottomColor": "#FFFFFF"
        ]]
        
        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5)  // 5 minutes
        ]
        
        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)
        
        // Open Instagram Stories
        UIApplication.shared.open(instagramURL) { success in
            completion(success, success ? nil : "Failed to open Instagram")
        }
    }
    
    /// Share via system share sheet
    func shareViaSystemSheet(image: UIImage, text: String, from viewController: UIViewController?) {
        let activityItems: [Any] = [image, text]
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // Exclude some activity types if needed
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact
        ]
        
        if let vc = viewController {
            vc.present(activityVC, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    /// Copy post link to clipboard
    func copyPostLink(postId: String) {
        let link = "https://palytt.app/post/\(postId)"
        UIPasteboard.general.string = link
    }
    
    /// Get share text for a post
    func getShareText(for post: Post) -> String {
        var text = "Check out this dish on Palytt!"
        
        if let title = post.title, !title.isEmpty {
            text = "Check out \(title) on Palytt!"
        }
        
        if let shop = post.shop {
            text += " at \(shop.name)"
        }
        
        text += "\n\nhttps://palytt.app/post/\(post.convexId)"
        
        return text
    }
}

// MARK: - Post Share Card View

struct PostShareCard: View {
    let post: Post
    
    var body: some View {
        VStack(spacing: 0) {
            // Post Image
            if let imageURL = post.mediaURLs.first {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 375, height: 300)
                .clipped()
            } else {
                Rectangle()
                    .fill(LinearGradient.primaryGradient)
                    .frame(width: 375, height: 300)
            }
            
            // Post Info
            VStack(alignment: .leading, spacing: 12) {
                // Title
                if let title = post.title {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                        .lineLimit(2)
                }
                
                // Location/Shop
                if let shop = post.shop {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundColor(.primaryBrand)
                        Text(shop.name)
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }
                }
                
                // Rating
                if let rating = post.rating {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: Double(index) <= rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                // Palytt Branding
                HStack {
                    Text("Shared via")
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                    
                    Text("Palytt")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryBrand)
                }
                .padding(.top, 8)
            }
            .padding(16)
            .frame(width: 375, alignment: .leading)
            .background(Color.cardBackground)
        }
        .frame(width: 375, height: 500)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview {
    PostShareCard(post: Post(
        userId: UUID(),
        author: User(
            id: UUID(),
            email: "preview@example.com",
            username: "previewuser",
            displayName: "Preview User",
            clerkId: "preview_clerk_id"
        ),
        caption: "This is a preview post for testing the share card.",
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
    .padding()
    .background(Color.appBackground)
}

