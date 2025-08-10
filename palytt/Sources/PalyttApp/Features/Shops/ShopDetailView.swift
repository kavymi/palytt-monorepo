//
//  ShopDetailView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import MapKit
import Kingfisher

// MARK: - Shop Detail View
struct ShopDetailView: View {
    let shop: Shop
    @StateObject private var viewModel = ShopDetailViewModel()
    @State private var showDirections = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header Image
                ShopHeaderView(shop: shop)
                
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Info
                    ShopBasicInfoView(shop: shop)
                    
                    // Hours
                    if let hours = shop.businessHours {
                        ShopHoursView(hours: hours)
                    }
                    
                    // Action Buttons
                    ShopActionButtonsView(shop: shop, showDirections: $showDirections)
                    
                    // Related Posts
                    if !viewModel.relatedPosts.isEmpty {
                        ShopPostsView(posts: viewModel.relatedPosts)
                    }
                    
                    // Reviews Section
                    ShopReviewsView(shop: shop, reviews: viewModel.reviews)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(shop.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDirections) {
            ShopDirectionsView(shop: shop)
        }
        .task {
            await viewModel.loadShopDetails(for: shop)
        }
    }
}

// MARK: - Shop Header View
struct ShopHeaderView: View {
    let shop: Shop
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageUrl = shop.imageUrl {
                KFImage(imageUrl)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "storefront")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
            
            // Gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 100)
            
            // Shop name overlay
            VStack(alignment: .leading) {
                Text(shop.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let rating = shop.rating {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                        Text("\(rating, specifier: "%.1f")")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Shop Basic Info View
struct ShopBasicInfoView: View {
    let shop: Shop
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let description = shop.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondaryText)
            }
            
            if let address = shop.location.address {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.primaryBrand)
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }
            
            if let phone = shop.phone {
                HStack {
                    Image(systemName: "phone")
                        .foregroundColor(.primaryBrand)
                    Text(phone)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }
            
            if let website = shop.website {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.primaryBrand)
                    Text(website.absoluteString)
                        .font(.subheadline)
                        .foregroundColor(.primaryBrand)
                }
            }
            
            if let priceLevel = shop.priceLevel {
                HStack {
                    Image(systemName: "dollarsign.circle")
                        .foregroundColor(.primaryBrand)
                    Text(String(repeating: "$", count: priceLevel))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                }
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Shop Hours View
struct ShopHoursView: View {
    let hours: BusinessHours
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hours")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                HourRow(day: "Monday", open: hours.mondayOpen, close: hours.mondayClose)
                HourRow(day: "Tuesday", open: hours.tuesdayOpen, close: hours.tuesdayClose)
                HourRow(day: "Wednesday", open: hours.wednesdayOpen, close: hours.wednesdayClose)
                HourRow(day: "Thursday", open: hours.thursdayOpen, close: hours.thursdayClose)
                HourRow(day: "Friday", open: hours.fridayOpen, close: hours.fridayClose)
                HourRow(day: "Saturday", open: hours.saturdayOpen, close: hours.saturdayClose)
                HourRow(day: "Sunday", open: hours.sundayOpen, close: hours.sundayClose)
            }
        }
    }
}

struct HourRow: View {
    let day: String
    let open: String?
    let close: String?
    
    var body: some View {
        HStack {
            Text(day)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            if let open = open, let close = close {
                Text("\(open) - \(close)")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            } else {
                Text("Closed")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Shop Action Buttons View
struct ShopActionButtonsView: View {
    let shop: Shop
    @Binding var showDirections: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                showDirections = true
            }) {
                HStack {
                    Image(systemName: "location")
                    Text("Directions")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.primaryBrand)
                .foregroundColor(.white)
                .font(.subheadline)
                .fontWeight(.medium)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            if let phone = shop.phone {
                Button(action: {
                    if let url = URL(string: "tel:\(phone)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "phone")
                        Text("Call")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.shopsPlaces)
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            if let website = shop.website {
                Button(action: {
                    UIApplication.shared.open(website)
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Website")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

// MARK: - Shop Posts View
struct ShopPostsView: View {
    let posts: [Post]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Posts")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(posts.prefix(5)) { post in
                        NavigationLink(destination: PostDetailView(post: post)) {
                            AsyncImage(url: post.imageUrls.first) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Shop Reviews View
struct ShopReviewsView: View {
    let shop: Shop
    let reviews: [ShopReview]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reviews")
                .font(.headline)
                .fontWeight(.semibold)
            
            if reviews.isEmpty {
                Text("No reviews yet")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            } else {
                ForEach(reviews.prefix(3)) { review in
                    ShopReviewCard(review: review)
                }
                
                if reviews.count > 3 {
                    Button("View All Reviews") {
                        // TODO: Navigate to all reviews
                    }
                    .font(.subheadline)
                    .foregroundColor(.primaryBrand)
                }
            }
        }
    }
}

struct ShopReviewCard: View {
    let review: ShopReview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(review.authorName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
            }
            
            Text(review.text)
                .font(.caption)
                .foregroundColor(.secondaryText)
                .lineLimit(3)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Shop Directions View
struct ShopDirectionsView: View {
    let shop: Shop
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Map(coordinateRegion: .constant(MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: shop.location.latitude,
                    longitude: shop.location.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )), annotationItems: [shop]) { shop in
                MapMarker(coordinate: CLLocationCoordinate2D(
                    latitude: shop.location.latitude,
                    longitude: shop.location.longitude
                ), tint: .red)
            }
            .navigationTitle("Directions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Open in Maps") {
                        let coordinate = CLLocationCoordinate2D(
                            latitude: shop.location.latitude,
                            longitude: shop.location.longitude
                        )
                        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                        mapItem.name = shop.name
                        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                    }
                }
            }
        }
    }
}

// MARK: - Shop Detail View Model
@MainActor
class ShopDetailViewModel: ObservableObject {
    @Published var relatedPosts: [Post] = []
    @Published var reviews: [ShopReview] = []
    @Published var isLoading = false
    
    private let backendService = BackendService.shared
    
    func loadShopDetails(for shop: Shop) async {
        isLoading = true
        
        // Load related posts for this location
        await loadRelatedPosts(for: shop)
        
        // Load reviews (mock for now)
        await loadReviews(for: shop)
        
        isLoading = false
    }
    
    private func loadRelatedPosts(for shop: Shop) async {
        do {
            // Search for posts near this shop's location
            let backendPosts = try await backendService.searchPosts(
                query: shop.name,
                latitude: shop.location.latitude,
                longitude: shop.location.longitude,
                radius: 100, // 100 meters
                limit: 10
            )
            
            relatedPosts = backendPosts.map { Post.from(backendPost: $0) }
        } catch {
            print("❌ Failed to load related posts: \(error)")
            relatedPosts = []
        }
    }
    
    private func loadReviews(for shop: Shop) async {
        // Mock reviews for now - in a real app, this would come from backend
        reviews = [
            ShopReview(
                id: "1",
                authorName: "Sarah K.",
                rating: 5,
                text: "Amazing food and great atmosphere! Highly recommend the pasta dishes.",
                createdAt: Date()
            ),
            ShopReview(
                id: "2",
                authorName: "Mike T.",
                rating: 4,
                text: "Good food, friendly service. The desserts are incredible!",
                createdAt: Date()
            )
        ]
    }
}

// MARK: - Shop Review Model
struct ShopReview: Identifiable {
    let id: String
    let authorName: String
    let rating: Int
    let text: String
    let createdAt: Date
}

#Preview {
    NavigationStack {
        ShopDetailView(shop: Shop(
            name: "Sample Restaurant",
            description: "A beautiful restaurant with amazing food and great atmosphere",
            location: Location(
                latitude: 37.7749,
                longitude: -122.4194,
                address: "123 Main St, San Francisco, CA 94102"
            ),
            rating: 4.5,
            priceLevel: 3,
            phone: "+1-555-123-4567",
            website: URL(string: "https://example.com"),
            businessHours: BusinessHours.defaultHours,
            imageUrl: URL(string: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4")
        ))
    }
} 