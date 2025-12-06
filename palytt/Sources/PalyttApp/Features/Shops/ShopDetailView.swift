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
    @State private var isSaved = false
    @State private var showShareSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Enhanced Header with save/share buttons
                EnhancedShopHeaderView(
                    shop: shop,
                    isSaved: $isSaved,
                    onShare: { showShareSheet = true }
                )
                
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Info Card
                    ShopBasicInfoView(shop: shop)
                    
                    // Action Buttons
                    ShopActionButtonsView(shop: shop, showDirections: $showDirections)
                    
                    // Photo Gallery (from related posts)
                    if !viewModel.relatedPosts.isEmpty {
                        ShopPhotoGalleryView(
                            posts: viewModel.relatedPosts,
                            shopName: shop.name
                        )
                    }
                    
                    // Menu Section
                    if let menu = shop.menu, !menu.isEmpty {
                        ShopMenuSection(menu: menu)
                    }
                    
                    // Hours Section
                    if let hours = shop.hours {
                        EnhancedShopHoursView(hours: hours)
                    }
                    
                    // Enhanced Reviews Section
                    EnhancedShopReviewsView(shop: shop, reviews: viewModel.reviews)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color.background)
        .navigationTitle(shop.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDirections) {
            ShopDirectionsView(shop: shop)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shop.name, shop.location.address ?? ""])
        }
        .task {
            await viewModel.loadShopDetails(for: shop)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Enhanced Shop Header View
struct EnhancedShopHeaderView: View {
    let shop: Shop
    @Binding var isSaved: Bool
    let onShare: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background Image
            if let imageUrl = shop.imageUrl {
                KFImage(imageUrl)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 280)
                    .clipped()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.primaryBrand.opacity(0.3), Color.coffeeDark.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 280)
                    .overlay(
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
            
            // Gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.8), Color.black.opacity(0.3), Color.clear]),
                startPoint: .bottom,
                endPoint: .top
            )
            
            // Content overlay
            VStack(alignment: .leading, spacing: 12) {
                // Action buttons at top
                HStack {
                    Spacer()
                    
                    // Save button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isSaved.toggle()
                        }
                        HapticManager.shared.impact(.medium)
                    }) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.title3)
                            .foregroundColor(isSaved ? .primaryBrand : .white)
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    
                    // Share button
                    Button(action: {
                        onShare()
                        HapticManager.shared.impact(.light)
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Shop info
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(shop.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // Verified badge
                        if shop.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blueAccent)
                                .font(.title3)
                        }
                    }
                    
                    // Rating and price
                    HStack(spacing: 16) {
                        if let rating = shop.rating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.warning)
                                    .font(.subheadline)
                                
                                Text(String(format: "%.1f", rating))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                if shop.reviewsCount > 0 {
                                    Text("(\(shop.reviewsCount))")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        
                        // Price range
                        Text(shop.priceRange.displayText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                        
                        // Cuisine types
                        if !shop.cuisineTypes.isEmpty {
                            Text("•")
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(shop.cuisineTypes.prefix(2).joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .frame(height: 280)
    }
}

// MARK: - Shop Header View (Legacy)
struct ShopHeaderView: View {
    let shop: Shop
    
    var body: some View {
        EnhancedShopHeaderView(
            shop: shop,
            isSaved: .constant(false),
            onShare: {}
        )
    }
}

// MARK: - Shop Basic Info View
struct ShopBasicInfoView: View {
    let shop: Shop
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Description
            if let description = shop.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondaryText)
                    .lineSpacing(4)
            }
            
            // Info Items
            VStack(spacing: 12) {
                // Address
                if let address = shop.location.address, !address.isEmpty {
                    InfoRow(
                        icon: "location.fill",
                        iconColor: .primaryBrand,
                        title: "Address",
                        value: address,
                        isLink: false
                    )
                }
                
                // Phone
                if let phone = shop.phoneNumber, !phone.isEmpty {
                    InfoRow(
                        icon: "phone.fill",
                        iconColor: .success,
                        title: "Phone",
                        value: phone,
                        isLink: true,
                        action: {
                            if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                }
                
                // Website
                if let website = shop.website {
                    InfoRow(
                        icon: "globe",
                        iconColor: .blueAccent,
                        title: "Website",
                        value: website.host ?? website.absoluteString,
                        isLink: true,
                        action: {
                            UIApplication.shared.open(website)
                        }
                    )
                }
                
                // Cuisine Types
                if !shop.cuisineTypes.isEmpty {
                    InfoRow(
                        icon: "fork.knife",
                        iconColor: .milkTea,
                        title: "Cuisine",
                        value: shop.cuisineTypes.joined(separator: ", "),
                        isLink: false
                    )
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let isLink: Bool
    var action: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
                
                if isLink, let action = action {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        action()
                    }) {
                        Text(value)
                            .font(.subheadline)
                            .foregroundColor(.primaryBrand)
                            .lineLimit(1)
                    }
                } else {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.primaryText)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if isLink {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Enhanced Shop Hours View
struct EnhancedShopHoursView: View {
    let hours: BusinessHours
    @State private var isExpanded = false
    
    private var isCurrentlyOpen: Bool {
        // Simplified check - in production, use actual time comparison
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        
        // Check if within typical business hours (9 AM - 10 PM)
        return hour >= 9 && hour < 22
    }
    
    private var currentDayIndex: Int {
        let calendar = Calendar.current
        return calendar.component(.weekday, from: Date()) - 1 // 0 = Sunday
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.primaryBrand)
                    .font(.title3)
                
                Text("Hours")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                // Open/Closed Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(isCurrentlyOpen ? Color.success : Color.error)
                        .frame(width: 8, height: 8)
                    
                    Text(isCurrentlyOpen ? "Open Now" : "Closed")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isCurrentlyOpen ? .success : .error)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isCurrentlyOpen ? Color.success.opacity(0.1) : Color.error.opacity(0.1))
                )
            }
            
            // Hours List
            VStack(spacing: 0) {
                EnhancedHourRow(day: "Sunday", hours: hours.sunday, isToday: currentDayIndex == 0)
                EnhancedHourRow(day: "Monday", hours: hours.monday, isToday: currentDayIndex == 1)
                EnhancedHourRow(day: "Tuesday", hours: hours.tuesday, isToday: currentDayIndex == 2)
                EnhancedHourRow(day: "Wednesday", hours: hours.wednesday, isToday: currentDayIndex == 3)
                EnhancedHourRow(day: "Thursday", hours: hours.thursday, isToday: currentDayIndex == 4)
                EnhancedHourRow(day: "Friday", hours: hours.friday, isToday: currentDayIndex == 5)
                EnhancedHourRow(day: "Saturday", hours: hours.saturday, isToday: currentDayIndex == 6)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct EnhancedHourRow: View {
    let day: String
    let hours: BusinessHours.DayHours
    let isToday: Bool
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                if isToday {
                    Circle()
                        .fill(Color.primaryBrand)
                        .frame(width: 6, height: 6)
                }
                
                Text(day)
                    .font(.subheadline)
                    .fontWeight(isToday ? .semibold : .regular)
                    .foregroundColor(isToday ? .primaryText : .secondaryText)
            }
            .frame(width: 110, alignment: .leading)
            
            Spacer()
            
            if hours.isClosed {
                Text("Closed")
                    .font(.subheadline)
                    .foregroundColor(.error)
            } else {
                Text("\(hours.open) - \(hours.close)")
                    .font(.subheadline)
                    .fontWeight(isToday ? .medium : .regular)
                    .foregroundColor(isToday ? .primaryText : .secondaryText)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(isToday ? Color.primaryBrand.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Legacy Shop Hours View
struct ShopHoursView: View {
    let hours: BusinessHours
    
    var body: some View {
        EnhancedShopHoursView(hours: hours)
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
// ShopReview is now defined in Shop.swift

#Preview {
    NavigationStack {
        ShopDetailView(shop: Shop(
            id: UUID(),
            name: "The Cozy Café",
            description: "A beautiful café with amazing coffee and great atmosphere. Perfect for working or catching up with friends.",
            location: Location(
                latitude: 37.7749,
                longitude: -122.4194,
                address: "123 Main St, San Francisco, CA 94102"
            ),
            phoneNumber: "+1-555-123-4567",
            website: URL(string: "https://example.com"),
            hours: BusinessHours.defaultHours,
            cuisineTypes: ["Coffee", "Brunch"],
            drinkTypes: ["Coffee", "Tea"],
            priceRange: .moderate,
            rating: 4.5,
            reviewsCount: 128,
            photosCount: 45,
            menu: [
                MenuItem(
                    name: "Avocado Toast",
                    description: "Fresh avocado on sourdough",
                    price: 12.99,
                    category: "Breakfast",
                    dietaryInfo: [.vegetarian, .vegan],
                    isPopular: true
                ),
                MenuItem(
                    name: "Latte",
                    description: "Espresso with steamed milk",
                    price: 5.99,
                    category: "Drinks",
                    isPopular: true
                )
            ],
            ownerId: nil,
            isVerified: true,
            featuredImageURL: URL(string: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4")
        ))
    }
} 