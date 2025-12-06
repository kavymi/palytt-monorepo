//
//  ShopReviewForm.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Kingfisher

// MARK: - Enhanced Reviews Section

/// Enhanced reviews section with rating breakdown and write review CTA
struct EnhancedShopReviewsView: View {
    let shop: Shop
    let reviews: [ShopReview]
    @State private var showWriteReview = false
    
    private var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }
    
    private var ratingDistribution: [Int: Int] {
        var distribution: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        for review in reviews {
            distribution[review.rating, default: 0] += 1
        }
        return distribution
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "star.bubble.fill")
                    .foregroundColor(.primaryBrand)
                    .font(.title3)
                
                Text("Reviews")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                if !reviews.isEmpty {
                    Text("\(reviews.count) reviews")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            
            // Rating Overview
            if !reviews.isEmpty {
                RatingOverviewCard(
                    averageRating: averageRating,
                    totalReviews: reviews.count,
                    distribution: ratingDistribution
                )
            }
            
            // Write Review Button
            WriteReviewButton(onTap: {
                showWriteReview = true
                HapticManager.shared.impact(.medium)
            })
            
            // Reviews List
            if reviews.isEmpty {
                EmptyReviewsView()
            } else {
                VStack(spacing: 12) {
                    ForEach(reviews.prefix(5)) { review in
                        EnhancedReviewCard(review: review)
                    }
                    
                    if reviews.count > 5 {
                        Button(action: {
                            // Navigate to all reviews
                        }) {
                            HStack {
                                Text("View all \(reviews.count) reviews")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .foregroundColor(.primaryBrand)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primaryBrand.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showWriteReview) {
            WriteReviewSheet(shop: shop)
        }
    }
}

// MARK: - Rating Overview Card

struct RatingOverviewCard: View {
    let averageRating: Double
    let totalReviews: Int
    let distribution: [Int: Int]
    
    var body: some View {
        HStack(spacing: 20) {
            // Average Rating
            VStack(spacing: 4) {
                Text(String(format: "%.1f", averageRating))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: starIcon(for: star, rating: averageRating))
                            .foregroundColor(.warning)
                            .font(.caption)
                    }
                }
                
                Text("\(totalReviews) reviews")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .frame(width: 100)
            
            // Rating Bars
            VStack(spacing: 4) {
                ForEach((1...5).reversed(), id: \.self) { rating in
                    RatingBar(
                        rating: rating,
                        count: distribution[rating] ?? 0,
                        total: totalReviews
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func starIcon(for position: Int, rating: Double) -> String {
        if Double(position) <= rating {
            return "star.fill"
        } else if Double(position) - 0.5 <= rating {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

// MARK: - Rating Bar

struct RatingBar: View {
    let rating: Int
    let count: Int
    let total: Int
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(rating)")
                .font(.caption2)
                .foregroundColor(.secondaryText)
                .frame(width: 12)
            
            Image(systemName: "star.fill")
                .font(.system(size: 8))
                .foregroundColor(.warning)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.warning)
                        .frame(width: geometry.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)
            
            Text("\(count)")
                .font(.caption2)
                .foregroundColor(.secondaryText)
                .frame(width: 24, alignment: .trailing)
        }
    }
}

// MARK: - Write Review Button

struct WriteReviewButton: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .font(.subheadline)
                
                Text("Write a Review")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color.primaryBrand, Color.primaryBrand.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.primaryBrand.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Empty Reviews View

struct EmptyReviewsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No reviews yet")
                .font(.headline)
                .foregroundColor(.primaryText)
            
            Text("Be the first to share your experience!")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Enhanced Review Card

struct EnhancedReviewCard: View {
    let review: ShopReview
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                // Avatar
                Circle()
                    .fill(Color.primaryBrand.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(review.authorName.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryBrand)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.authorName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    
                    HStack(spacing: 4) {
                        // Stars
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= review.rating ? "star.fill" : "star")
                                    .foregroundColor(.warning)
                                    .font(.system(size: 10))
                            }
                        }
                        
                        Text("•")
                            .foregroundColor(.tertiaryText)
                            .font(.caption)
                        
                        // Date
                        Text(formatDate(review.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
                
                Spacer()
            }
            
            // Review Text
            Text(review.text)
                .font(.subheadline)
                .foregroundColor(.primaryText)
                .lineLimit(isExpanded ? nil : 3)
                .animation(.easeInOut, value: isExpanded)
            
            // Show more/less
            if review.text.count > 150 {
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Text(isExpanded ? "Show less" : "Show more")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryBrand)
                }
            }
            
            // Helpful button
            HStack {
                Button(action: {
                    HapticManager.shared.impact(.light)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup")
                            .font(.caption)
                        Text("Helpful")
                            .font(.caption)
                    }
                    .foregroundColor(.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Write Review Sheet

struct WriteReviewSheet: View {
    let shop: Shop
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int = 0
    @State private var reviewText = ""
    @State private var isSubmitting = false
    @FocusState private var isTextFocused: Bool
    
    private var canSubmit: Bool {
        rating > 0 && !reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Shop Info
                    HStack(spacing: 12) {
                        if let imageUrl = shop.featuredImageURL {
                            KFImage(imageUrl)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "storefront")
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shop.name)
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            
                            Text(shop.location.address)
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                    
                    // Rating Selection
                    VStack(spacing: 12) {
                        Text("How would you rate your experience?")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        HStack(spacing: 16) {
                            ForEach(1...5, id: \.self) { star in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        rating = star
                                    }
                                    HapticManager.shared.impact(.light)
                                }) {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.system(size: 36))
                                        .foregroundColor(star <= rating ? .warning : .gray.opacity(0.3))
                                        .scaleEffect(star <= rating ? 1.1 : 1.0)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        if rating > 0 {
                            Text(ratingDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                    
                    // Review Text
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tell us about your experience")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        ZStack(alignment: .topLeading) {
                            if reviewText.isEmpty {
                                Text("Share what you loved, the food, service, atmosphere...")
                                    .foregroundColor(.tertiaryText)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                            
                            TextEditor(text: $reviewText)
                                .focused($isTextFocused)
                                .frame(minHeight: 150)
                                .padding(12)
                                .scrollContentBackground(.hidden)
                        }
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        
                        HStack {
                            Spacer()
                            Text("\(reviewText.count)/500")
                                .font(.caption)
                                .foregroundColor(reviewText.count > 500 ? .error : .secondaryText)
                        }
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                }
                .padding()
            }
            .background(Color.background)
            .navigationTitle("Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: submitReview) {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Submit")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                    .foregroundColor(canSubmit ? .primaryBrand : .gray)
                }
            }
        }
    }
    
    private var ratingDescription: String {
        switch rating {
        case 1: return "Poor - Not recommended"
        case 2: return "Fair - Below average"
        case 3: return "Good - Average experience"
        case 4: return "Very Good - Above average"
        case 5: return "Excellent - Highly recommended!"
        default: return ""
        }
    }
    
    private func submitReview() {
        isSubmitting = true
        HapticManager.shared.impact(.medium)
        
        // TODO: Submit review to backend
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            HapticManager.shared.impact(.success)
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        EnhancedShopReviewsView(
            shop: Shop(
                name: "The Best Restaurant",
                location: Location(
                    latitude: 37.7749,
                    longitude: -122.4194,
                    address: "123 Main St",
                    city: "San Francisco",
                    country: "USA"
                ),
                hours: BusinessHours.defaultHours,
                rating: 4.5
            ),
            reviews: [
                ShopReview(
                    id: "1",
                    authorName: "Sarah K.",
                    rating: 5,
                    text: "Amazing food and great atmosphere! The pasta was absolutely divine and the service was impeccable. Will definitely be coming back!",
                    createdAt: Date().addingTimeInterval(-86400)
                ),
                ShopReview(
                    id: "2",
                    authorName: "Mike T.",
                    rating: 4,
                    text: "Good food, friendly service. The desserts are incredible!",
                    createdAt: Date().addingTimeInterval(-172800)
                ),
                ShopReview(
                    id: "3",
                    authorName: "Emily R.",
                    rating: 5,
                    text: "Best brunch spot in town!",
                    createdAt: Date().addingTimeInterval(-259200)
                )
            ]
        )
        .padding()
    }
    .background(Color.background)
}

