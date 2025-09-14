//
//  ExploreView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import MapKit
import CoreLocation

// MARK: - Post Cluster Models

struct PostCluster: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let posts: [MapPostAnnotation]
    let totalLikes: Int
    
    var representativePost: MapPostAnnotation {
        // Return the post with the most likes, or the first one
        return posts.max(by: { $0.likesCount < $1.likesCount }) ?? posts.first!
    }
    
    var title: String {
        if posts.count == 1 {
            return posts.first?.title ?? "Food Post"
        } else {
            return "\(posts.count) posts"
        }
    }
}

class PostClusterManager {
    static let shared = PostClusterManager()
    private init() {}
    
    // Cluster posts within 0.25 miles (approximately 402 meters) of each other
    func clusterPosts(_ posts: [MapPostAnnotation]) -> [PostCluster] {
        var clusters: [PostCluster] = []
        var processedPosts: Set<String> = []
        
        for post in posts {
            if processedPosts.contains(post.id) { continue }
            
            var clusterPosts: [MapPostAnnotation] = [post]
            processedPosts.insert(post.id)
            
            // Find all other posts within 0.25 miles
            for otherPost in posts {
                if processedPosts.contains(otherPost.id) { continue }
                
                let distance = CLLocation(latitude: post.coordinate.latitude, longitude: post.coordinate.longitude)
                    .distance(from: CLLocation(latitude: otherPost.coordinate.latitude, longitude: otherPost.coordinate.longitude))
                
                // 0.25 miles = 402.336 meters
                if distance <= 402.336 {
                    clusterPosts.append(otherPost)
                    processedPosts.insert(otherPost.id)
                }
            }
            
            // Calculate center coordinate for cluster
            let centerLat = clusterPosts.map { $0.coordinate.latitude }.reduce(0, +) / Double(clusterPosts.count)
            let centerLng = clusterPosts.map { $0.coordinate.longitude }.reduce(0, +) / Double(clusterPosts.count)
            let centerCoordinate = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng)
            
            // Calculate total likes
            let totalLikes = clusterPosts.reduce(0) { $0 + $1.likesCount }
            
            let cluster = PostCluster(
                coordinate: centerCoordinate,
                posts: clusterPosts,
                totalLikes: totalLikes
            )
            
            clusters.append(cluster)
        }
        
        return clusters
    }
}

struct ExploreView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ExploreViewModel()
    @StateObject private var mapViewModel = MapViewModel()
    @StateObject private var locationManager = LocationManager()
    
    @State private var selectedPost: MapPostAnnotation?
    @State private var selectedCluster: PostCluster?
    @State private var selectedShop: Shop?
    @State private var showingPostDetail = false
    @State private var showingClusterDetail = false
    @State private var showingShopDetail = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showFilters = false
    @State private var selectedTab = 0
    
    // Clustering state
    @State private var clusteredUserPosts: [PostCluster] = []
    @State private var clusteredFriendsPosts: [PostCluster] = []
    
    // UX Enhancement: Content type selection - Default to "Everything"
    @State private var contentType: MapContentType = .everything
    @State private var showContentPicker = false
    
    enum MapContentType: String, CaseIterable {
        case myPosts = "My Picks"
        case friendsPosts = "Friends' Picks"
        case everything = "All Picks"
        
        var icon: String {
            switch self {
            case .myPosts: return "person.crop.circle.fill"
            case .friendsPosts: return "person.2.fill"
            case .everything: return "globe"
            }
        }
        
        var color: Color {
            switch self {
            case .myPosts: return .orange
            case .friendsPosts: return .blue
            case .everything: return .purple
            }
        }
        
        var description: String {
            switch self {
            case .myPosts: return "Your food picks"
            case .friendsPosts: return "Picks from friends"
            case .everything: return "All picks on Palytt"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            mainContent
        }
        .sheet(isPresented: $showFilters) {
            UnifiedFiltersView(
                mapViewModel: mapViewModel,
                exploreViewModel: viewModel,
                contentType: contentType
            )
        }
        .sheet(isPresented: $showContentPicker) {
            ContentTypePickerSheet(
                selectedType: $contentType,
                isPresented: $showContentPicker
            )
        }
        .fullScreenCover(isPresented: $showingPostDetail) {
            if let selectedPost = selectedPost {
                PostDetailView(post: selectedPost.originalPost)
                    .environmentObject(appState)
            }
        }
        .fullScreenCover(isPresented: $showingClusterDetail) {
            clusterDetailView
        }
        .fullScreenCover(isPresented: $showingShopDetail) {
            shopDetailView
        }
        .onAppear {
            // Track screen view
            // AnalyticsManager.shared.trackScreenView("explore", properties: [
            //     "content_type": contentType.rawValue,
            //     "is_authenticated": appState.isAuthenticated
            // ])
            
            // Setup logic would go here
        }
        .onDisappear {
            // Cleanup logic would go here
        }
        .onChange(of: false) { _, _ in
            // Change listeners would go here
        }
        .task {
            print("🗺️ ExploreView: .task triggered - Loading initial content with contentType: \(contentType)")
            await loadInitialContent()
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        rawContent
            .background(Color.background)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationTitle("Palytt")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showContentPicker.toggle()
                        }
                        HapticManager.shared.impact(.light)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: contentType.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(contentType.rawValue)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.primaryBrand)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { 
                        HapticManager.shared.impact(.light)
                        showFilters = true 
                    }) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .foregroundColor(.primaryText)
                    }
                }
            }
    }
    
    @ViewBuilder
    private var rawContent: some View {
        VStack(spacing: 0) {
            // Tab Selector
            Picker("View Mode", selection: $selectedTab) {
                Text("Map").tag(0)
                Text("List").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            if selectedTab == 0 {
                UnifiedMapView()
            } else {
                ListView(viewModel: viewModel)
            }
        }
    }
    

    

    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: {
                HapticManager.shared.impact(.light)
                viewModel.toggleShowOnlyFavorites()
                Task {
                    await viewModel.applyFilters()
                }
            }) {
                Image(systemName: viewModel.showOnlyFavorites ? "heart.fill" : "heart")
                    .foregroundColor(viewModel.showOnlyFavorites ? .red : .primaryBrand)
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showFilters = true }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.primaryBrand)
            }
        }
        #else
        ToolbarItem(placement: .secondaryAction) {
            Button(action: {
                HapticManager.shared.impact(.light)
                viewModel.toggleShowOnlyFavorites()
                Task {
                    await viewModel.applyFilters()
                }
            }) {
                Image(systemName: viewModel.showOnlyFavorites ? "heart.fill" : "heart")
                    .foregroundColor(viewModel.showOnlyFavorites ? .red : .primaryBrand)
            }
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button(action: { showFilters = true }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.primaryBrand)
            }
        }
        #endif
    }
    

    
    @ViewBuilder
    private func configureModalPresentations() -> some View {
        self
            #if os(iOS)
            .fullScreenCover(isPresented: $showingPostDetail) {
                if let selectedPost = selectedPost {
                    PostDetailView(post: selectedPost.originalPost)
                        .environmentObject(appState)
                }
            }
            .fullScreenCover(isPresented: $showingClusterDetail) {
                clusterDetailView
            }
            .fullScreenCover(isPresented: $showingShopDetail) {
                shopDetailView
            }
            #else
            .sheet(isPresented: $showingPostDetail) {
                if let selectedPost = selectedPost {
                    PostDetailView(post: selectedPost.originalPost)
                        .environmentObject(appState)
                }
            }
            .sheet(isPresented: $showingClusterDetail) {
                clusterDetailView
            }
            .sheet(isPresented: $showingShopDetail) {
                shopDetailViewMacOS
            }
            #endif
    }
    
    @ViewBuilder
    private var clusterDetailView: some View {
        if let selectedCluster = selectedCluster {
            ClusterDetailView(
                cluster: selectedCluster,
                onPostSelected: { post in
                    selectedPost = post
                    showingClusterDetail = false
                    showingPostDetail = true
                },
                onDismiss: {
                    showingClusterDetail = false
                    self.selectedCluster = nil
                }
            )
            .environmentObject(appState)
        }
    }
    
    @ViewBuilder
    private var shopDetailView: some View {
        if let selectedShop = selectedShop {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Shop Details")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(selectedShop.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if let description = selectedShop.description {
                            Text(description)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Text("Shop details coming soon...")
                            .foregroundColor(.secondaryText)
                    }
                    .padding()
                }
                .navigationTitle(selectedShop.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            showingShopDetail = false
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var shopDetailViewMacOS: some View {
        if let selectedShop = selectedShop {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Shop Details")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(selectedShop.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if let description = selectedShop.description {
                            Text(description)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Text("Shop details coming soon...")
                            .foregroundColor(.secondaryText)
                    }
                    .padding()
                }
                .navigationTitle(selectedShop.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Close") {
                            showingShopDetail = false
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func configureSheets() -> some View {
        self
            .sheet(isPresented: $showFilters) {
                UnifiedFiltersView(
                    mapViewModel: mapViewModel,
                    exploreViewModel: viewModel,
                    contentType: contentType
                )
            }

    }
    

    
    // MARK: - Helper Methods
    
    private func setupInitialLocation() {
        print("🗺️ ExploreView: .onAppear triggered - Requesting location permission")
        locationManager.requestLocationPermission()
        
        if let userLocation = locationManager.currentLocation {
            focusOnLocation(userLocation, immediate: false)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let userLocation = locationManager.currentLocation {
                    focusOnLocation(userLocation, immediate: false)
                }
            }
        }
    }
    
    private func focusOnLocation(_ location: CLLocation, immediate: Bool = false) {
        let duration = immediate ? 0.5 : 1.5
        print("🗺️ ExploreView: Focusing on location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        withAnimation(.easeInOut(duration: duration)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
    
    private func handleLocationChange(_ newLocation: CLLocation?) {
        guard let location = newLocation else { return }
        
        print("🗺️ ExploreView: Location updated to: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        withAnimation(.easeInOut(duration: 1.0)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
        
        Task {
            print("🗺️ ExploreView: Reloading content for new location")
            await loadContentForCurrentLocation()
        }
    }
    
    private func handleContentTypeChange(_ newType: MapContentType) {
        Task {
            await loadContentForType(newType)
            await updateCameraPosition()
        }
    }
    
    private func handleSelectionChange(_ isSelected: Bool) {
        if isSelected {
            appState.hideTabBar()
        } else {
            appState.showTabBar()
        }
    }
    
    // MARK: - Unified Map View
    
    @ViewBuilder
    private func UnifiedMapView() -> some View {
        ZStack {
            // Main Map
            Map(position: $cameraPosition) {
                // User's current location indicator
                if let userLocation = locationManager.currentLocation {
                    Annotation("You are here", coordinate: userLocation.coordinate) {
                        UserLocationIndicator()
                    }
                }
                
                // User's Own Posts (Clustered)
                if contentType == .myPosts || contentType == .everything {
                    ForEach(clusteredUserPosts, id: \.id) { cluster in
                        Annotation(
                            cluster.title,
                            coordinate: cluster.coordinate
                        ) {
                            if cluster.posts.count == 1 {
                                UserPostPin(
                                    mapPost: cluster.posts.first!,
                                    isSelected: selectedPost?.id == cluster.posts.first!.id,
                                    isOwnPost: true
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedPost = cluster.posts.first!
                                        selectedCluster = nil
                                        selectedShop = nil
                                    }
                                }
                            } else {
                                ClusterPin(
                                    cluster: cluster,
                                    isSelected: selectedCluster?.id == cluster.id,
                                    isOwnPosts: true
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedCluster = cluster
                                        selectedPost = nil
                                        selectedShop = nil
                                        showingClusterDetail = true
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Friends' Posts (Clustered)
                if contentType == .friendsPosts || contentType == .everything {
                    ForEach(clusteredFriendsPosts, id: \.id) { cluster in
                        Annotation(
                            cluster.title,
                            coordinate: cluster.coordinate
                        ) {
                            if cluster.posts.count == 1 {
                                UserPostPin(
                                    mapPost: cluster.posts.first!,
                                    isSelected: selectedPost?.id == cluster.posts.first!.id,
                                    isOwnPost: false
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedPost = cluster.posts.first!
                                        selectedCluster = nil
                                        selectedShop = nil
                                    }
                                }
                            } else {
                                ClusterPin(
                                    cluster: cluster,
                                    isSelected: selectedCluster?.id == cluster.id,
                                    isOwnPosts: false
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedCluster = cluster
                                        selectedPost = nil
                                        selectedShop = nil
                                        showingClusterDetail = true
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Nearby Places
                if contentType == .everything {
                    ForEach(viewModel.nearbyShops) { shop in
                        Annotation(shop.name, coordinate: CLLocationCoordinate2D(
                            latitude: shop.location.latitude,
                            longitude: shop.location.longitude
                        )) {
                            ShopMapPin(
                                shop: shop,
                                isSelected: selectedShop?.id == shop.id
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedShop = shop
                                    selectedPost = nil
                                    selectedCluster = nil
                                }
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            
            // Location Focus Button (moved to bottom-right only)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    LocationFocusButton(locationManager: locationManager) { zoomLevel in
                        focusOnUserLocation(zoomLevel: zoomLevel)
                    }
                    .padding(.trailing)
                    .padding(.bottom, calculateLocationButtonPadding())
                }
            }
            
            // Bottom Content Area
            VStack {
                Spacer()
                
                // Post Preview Toast
                if let selectedPost = selectedPost {
                    PostPreviewToast(
                        mapPost: selectedPost,
                        onTap: {
                            showingPostDetail = true
                        },
                        onClose: {
                            withAnimation(.spring(response: 0.3)) {
                                self.selectedPost = nil
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, appState.isTabBarVisible ? 100 : 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Shop Preview Card
                if let selectedShop = selectedShop {
                    ShopPreviewCard(
                        shop: selectedShop,
                        viewModel: viewModel,
                        onTap: {
                            showingShopDetail = true
                        },
                        onClose: {
                            withAnimation(.spring(response: 0.3)) {
                                self.selectedShop = nil
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, appState.isTabBarVisible ? 80 : 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Loading Indicator
                if mapViewModel.isLoading || viewModel.isLoading {
                    LoadingIndicator(
                        message: contentType == .friendsPosts ? 
                            "Loading posts from friends..." :
                            "Finding nearby places..."
                    )
                    .padding(.bottom, 100)
                }
                
                // Bottom gesture area to show tabs when hidden
                if !appState.isTabBarVisible && selectedPost == nil && selectedShop == nil && selectedCluster == nil {
                    VStack {
                        Spacer()
                        
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 50)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                appState.showTabBar()
                            }
                            .overlay(
                                // Subtle indicator
                                VStack {
                                    Spacer()
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 4)
                                        .cornerRadius(2)
                                        .padding(.bottom, 20)
                                }
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var navigationTitle: String {
        switch contentType {
        case .myPosts:
            return "My Food Map"
        case .friendsPosts:
            return "Friends' Food Map"
        case .everything:
            return "Explore"
        }
    }
    
    @ViewBuilder
    private var quickActionButton: some View {
        switch contentType {
        case .myPosts:
            Button(action: {
                Task {
                    await mapViewModel.refreshUserPosts()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.primaryBrand)
            }
        case .friendsPosts:
            Button(action: {
                Task {
                    await mapViewModel.refreshPosts()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.primaryBrand)
            }
        case .everything:
            Button(action: {
                withAnimation(.spring(response: 0.5)) {
                    showContentPicker.toggle()
                }
            }) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.primaryBrand)
            }
        }
    }
    
    // MARK: - Functions
    
    private func loadInitialContent() async {
        print("🗺️ ExploreView: loadInitialContent called with contentType: \(contentType)")
        
        // Set initial camera to user's current location if available
        if let userLocation = locationManager.currentLocation {
            print("🗺️ ExploreView: Setting initial camera to user location: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
            await MainActor.run {
                withAnimation(.easeInOut(duration: 1.0)) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: userLocation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }
            }
        } else {
            print("🗺️ ExploreView: No user location available yet, requesting location and waiting...")
            // Request location permission and wait for it
            locationManager.requestLocationPermission()
            
            // Wait a bit for location to be available
            for attempt in 1...5 {
                try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 seconds
                if let userLocation = locationManager.currentLocation {
                    print("🗺️ ExploreView: Got user location on attempt \(attempt): \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            cameraPosition = .region(MKCoordinateRegion(
                                center: userLocation.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            ))
                        }
                    }
                    break
                }
            }
        }
        
        await loadContentForType(contentType)
        await updateCameraPosition()
    }
    
    private func loadContentForCurrentLocation() async {
        guard let userLocation = locationManager.currentLocation else { 
            print("🗺️ ExploreView: loadContentForCurrentLocation called but no location available")
            return 
        }
        
        print("🗺️ ExploreView: loadContentForCurrentLocation called for location: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
        
        // Update view models with current location
        await viewModel.loadNearbyShops(at: userLocation)
        
        // Load nearby places from Apple Maps based on filters
        await loadNearbyPlacesFromAppleMaps(at: userLocation)
        
        if contentType == .friendsPosts || contentType == .everything {
            await loadFollowingPosts()
            await MainActor.run {
                clusteredFriendsPosts = PostClusterManager.shared.clusterPosts(mapViewModel.mapPosts)
            }
        }
        
        if contentType == .myPosts || contentType == .everything {
            await loadUserPosts()
            await MainActor.run {
                clusteredUserPosts = PostClusterManager.shared.clusterPosts(mapViewModel.userOwnPosts)
            }
        }
        
        await updateCameraPosition()
    }
    
    private func loadNearbyPlacesFromAppleMaps(at location: CLLocation) async {
        guard contentType == .everything else { return }
        
        let request = MKLocalSearch.Request()
        
        // Build search query based on selected filters
        var searchTerms: [String] = []
        
        if !viewModel.selectedDrinks.isEmpty {
            let drinkTerms = viewModel.selectedDrinks.map { $0.rawValue.lowercased() }
            searchTerms.append(contentsOf: drinkTerms)
        }
        
        if !viewModel.selectedCuisines.isEmpty {
            let cuisineTerms = viewModel.selectedCuisines.map { $0.rawValue.lowercased() }
            searchTerms.append(contentsOf: cuisineTerms)
        }
        
        if !viewModel.selectedDesserts.isEmpty {
            let dessertTerms = viewModel.selectedDesserts.map { $0.rawValue.lowercased() }
            searchTerms.append(contentsOf: dessertTerms)
        }
        
        // Default search terms if no specific filters
        if searchTerms.isEmpty {
            searchTerms = ["restaurant", "cafe", "food", "dining"]
        }
        
        request.naturalLanguageQuery = searchTerms.joined(separator: " ")
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: viewModel.maxDistance * 1609.34, // Convert miles to meters
            longitudinalMeters: viewModel.maxDistance * 1609.34
        )
        
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            // Convert MKMapItems to Shop objects
            let nearbyShops = response.mapItems.compactMap { mapItem -> Shop? in
                guard let name = mapItem.name,
                      let location = mapItem.placemark.location else { return nil }
                
                return Shop(
                    id: UUID(),
                    name: name,
                    description: mapItem.placemark.title,
                    location: Location(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        address: mapItem.placemark.title ?? "",
                        city: mapItem.placemark.locality ?? "",
                        state: mapItem.placemark.administrativeArea ?? "",
                        country: "USA", // Default for Apple Maps results
                        postalCode: mapItem.placemark.postalCode ?? ""
                    ),
                    hours: BusinessHours(
                        monday: nil,
                        tuesday: nil,
                        wednesday: nil,
                        thursday: nil,
                        friday: nil,
                        saturday: nil,
                        sunday: nil
                    ),
                    cuisineTypes: [.american], // Default - could be enhanced with category mapping
                    drinkTypes: Array(viewModel.selectedDrinks),
                    priceRange: .moderate,
                    rating: 4.0, // Default - Apple Maps doesn't provide ratings
                    reviewsCount: 0,
                    photosCount: 0,
                    isVerified: false,
                    featuredImageURL: nil,
                    isFavorite: false
                )
            }
            
            await MainActor.run {
                // Merge with existing shops, avoiding duplicates
                let existingNames = Set(viewModel.nearbyShops.map { $0.name })
                let newShops = nearbyShops.filter { !existingNames.contains($0.name) }
                viewModel.nearbyShops.append(contentsOf: newShops)
            }
            
        } catch {
            print("🗺️ ExploreView: Error searching nearby places: \(error)")
        }
    }
    
    private func loadContentForType(_ type: MapContentType) async {
        print("🗺️ ExploreView: loadContentForType called with type: \(type)")
        
        switch type {
        case .myPosts:
            print("🗺️ ExploreView: Loading user's own posts only")
            await loadUserPosts()
            await MainActor.run {
                clusteredUserPosts = PostClusterManager.shared.clusterPosts(mapViewModel.userOwnPosts)
            }
        case .friendsPosts:
            print("🗺️ ExploreView: Loading friends posts only")
            await loadFollowingPosts()
            await MainActor.run {
                clusteredFriendsPosts = PostClusterManager.shared.clusterPosts(mapViewModel.mapPosts)
            }
        case .everything:
            print("🗺️ ExploreView: Loading everything - user posts, friends posts and nearby places")
            async let userPosts: Void = loadUserPosts()
            async let friendsPosts: Void = loadFollowingPosts()
            if let userLocation = locationManager.currentLocation {
                print("🗺️ ExploreView: Loading nearby shops with user location for 'everything' mode")
                async let shops: Void = viewModel.loadNearbyShops(at: userLocation)
                await userPosts
                await friendsPosts
                await shops
            } else {
                print("🗺️ ExploreView: Loading nearby shops without user location for 'everything' mode")
                async let shops: Void = viewModel.loadNearbyShops()
                await userPosts
                await friendsPosts
                await shops
            }
            
            // Cluster both user and friends posts for everything mode
            await MainActor.run {
                clusteredUserPosts = PostClusterManager.shared.clusterPosts(mapViewModel.userOwnPosts)
                clusteredFriendsPosts = PostClusterManager.shared.clusterPosts(mapViewModel.mapPosts)
            }
        }
    }
    
    private func loadFollowingPosts() async {
        guard let currentUser = appState.currentUser,
              let clerkId = currentUser.clerkId else { return }
        await mapViewModel.loadFollowingPosts(for: clerkId)
    }
    
    private func loadUserPosts() async {
        guard let currentUser = appState.currentUser,
              let clerkId = currentUser.clerkId else { return }
        await mapViewModel.loadUserPosts(for: clerkId)
    }
    
    private func updateCameraPosition() async {
        var coordinates: [CLLocationCoordinate2D] = []
        
        if contentType == .myPosts || contentType == .everything {
            coordinates.append(contentsOf: clusteredUserPosts.map { $0.coordinate })
        }
        
        if contentType == .friendsPosts || contentType == .everything {
            coordinates.append(contentsOf: clusteredFriendsPosts.map { $0.coordinate })
        }
        
        if contentType == .everything {
            coordinates.append(contentsOf: viewModel.nearbyShops.map { 
                CLLocationCoordinate2D(latitude: $0.location.latitude, longitude: $0.location.longitude)
            })
        }
        
        if !coordinates.isEmpty {
            let region = calculateRegion(for: coordinates)
            withAnimation(.easeInOut(duration: 1.0)) {
                cameraPosition = .region(region)
            }
        }
    }
    
    private func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLng = coordinates.map { $0.longitude }.min() ?? 0
        let maxLng = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.2),
            longitudeDelta: max(0.01, (maxLng - minLng) * 1.2)
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    private func focusOnUserLocation(zoomLevel: LocationZoomLevel = .normal) {
        guard let userLocation = locationManager.currentLocation else {
            print("🗺️ ExploreView: No user location available for focus")
            // Request location permission if not available
            locationManager.requestLocationPermission()
            return
        }
        
        HapticManager.shared.impact(.light)
        
        let span = zoomLevel.span
        withAnimation(.easeInOut(duration: 1.2)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: userLocation.coordinate,
                span: span
            ))
        }
        
        print("🗺️ ExploreView: Focused on user location with \(zoomLevel) zoom: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
    }
    
    enum LocationZoomLevel {
        case normal
        case close
        
        var span: MKCoordinateSpan {
            switch self {
            case .normal:
                return MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            case .close:
                return MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            }
        }
    }
    
    private func calculateLocationButtonPadding() -> CGFloat {
        let baseTabBarPadding: CGFloat = appState.isTabBarVisible ? 100 : 40
        let hasPreviewCards = selectedPost != nil || selectedShop != nil
        let previewCardPadding: CGFloat = hasPreviewCards ? 80 : 0
        
        return baseTabBarPadding + previewCardPadding
    }
}

// MARK: - Content Type Picker Sheet

struct ContentTypePickerSheet: View {
    @Binding var selectedType: ExploreView.MapContentType
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(ExploreView.MapContentType.allCases, id: \.self) { type in
                    Button(action: {
                        selectedType = type
                        HapticManager.shared.impact(.medium)
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: type.icon)
                                .foregroundColor(type.color)
                                .frame(width: 24)
                            
                            Text(type.rawValue)
                                .foregroundColor(.primaryText)
                            
                            Spacer()
                            
                            if selectedType == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(type.color)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Picks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
        }
    }
}

// MARK: - Content Type Picker

struct ContentTypePicker: View {
    @Binding var selectedType: ExploreView.MapContentType
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                // Header with title and close button
                HStack {
                    Text("What to show")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primaryText)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isExpanded = false
                        }
                        HapticManager.shared.impact(.light)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondaryText)
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Divider
                Divider()
                    .padding(.horizontal, 16)
                
                // Options
                VStack(spacing: 0) {
                    ForEach(ExploreView.MapContentType.allCases, id: \.self) { type in
                        ContentTypeExpandedButton(
                            type: type,
                            isSelected: selectedType == type
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedType = type
                                isExpanded = false
                            }
                            HapticManager.shared.impact(.medium)
                        }
                        .padding(.horizontal, 16)
                        
                        if type != ExploreView.MapContentType.allCases.last {
                            Divider()
                                .padding(.leading, 56)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
                // Collapsed state - compact button
                ContentTypeCollapsedButton(
                    type: selectedType
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                    HapticManager.shared.impact(.light)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: isExpanded ? 16 : 24)
                .fill(Color.cardBackground)
                .shadow(color: .black.opacity(0.15), radius: isExpanded ? 12 : 8, x: 0, y: isExpanded ? 6 : 4)
        )
        .scaleEffect(isExpanded ? 1.02 : 1.0)
    }
}

struct ContentTypeCollapsedButton: View {
    let type: ExploreView.MapContentType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Icon with colored background
                ZStack {
                    Circle()
                        .fill(type.color.opacity(0.15))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(type.color)
                }
                
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

struct ContentTypeExpandedButton: View {
    let type: ExploreView.MapContentType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? type.color : type.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? .white : type.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primaryText)
                    
                    Text(type.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(type.color)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enhanced Pins

struct UserPostPin: View {
    let mapPost: MapPostAnnotation
    let isSelected: Bool
    let isOwnPost: Bool
    let onTap: () -> Void
    
    // Always show heart count by default
    private var showHeartCount: Bool { true }
    
    private var pinColor: Color {
        isOwnPost ? .orange : .primaryBrand
    }
    
    private var shadowRadius: CGFloat {
        isSelected ? 8 : 4
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                // Post image with engagement overlay
                ZStack {
                    // Enhanced shadow ring
                    Circle()
                        .fill(pinColor.opacity(0.3))
                        .frame(width: isSelected ? 56 : 52, height: isSelected ? 56 : 52)
                        .blur(radius: 2)
                    
                    // Main post image circle
                    AsyncImage(url: URL(string: mapPost.imageUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(isOwnPost ? 
                                LinearGradient(colors: [.orange.opacity(0.8), .orange], startPoint: .topLeading, endPoint: .bottomTrailing) : 
                                LinearGradient.primaryGradient)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.white)
                                    .font(.system(size: isSelected ? 18 : 16))
                            )
                    }
                    .frame(width: isSelected ? 48 : 44, height: isSelected ? 48 : 44)
                    .clipShape(Circle())
                    .background(
                        Circle()
                            .fill(Color.white)
                            .frame(width: isSelected ? 52 : 48, height: isSelected ? 52 : 48)
                    )
                    .shadow(color: pinColor.opacity(0.4), radius: shadowRadius, x: 0, y: 2)
                    
                    // Enhanced heart count overlay
                    if showHeartCount && mapPost.likesCount > 0 {
                        VStack {
                            Spacer()
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: isSelected ? 9 : 8, weight: .bold))
                                    .foregroundColor(.red)
                                if mapPost.likesCount < 100 {
                                    Text("\(mapPost.likesCount)")
                                        .font(.system(size: isSelected ? 9 : 8, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Text("99+")
                                        .font(.system(size: isSelected ? 8 : 7, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, isSelected ? 5 : 4)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.8))
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            )
                            .offset(y: isSelected ? -3 : -2)
                        }
                    }
                    
                    // Enhanced crown icon for own posts
                    if isOwnPost {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: isSelected ? 18 : 16, height: isSelected ? 18 : 16)
                                            .shadow(color: .black.opacity(0.2), radius: 1)
                                    )
                                    .font(.system(size: isSelected ? 11 : 10))
                            }
                            Spacer()
                        }
                        .offset(x: isSelected ? 5 : 4, y: isSelected ? -5 : -4)
                    }
                }
                
                // Enhanced pin point with glow effect
                ZStack {
                    // Glow effect
                    Image(systemName: "arrowtriangle.down.fill")
                        .foregroundColor(pinColor.opacity(0.6))
                        .font(.system(size: isSelected ? 16 : 12))
                        .blur(radius: 2)
                    
                    // Main pin
                    Image(systemName: "arrowtriangle.down.fill")
                        .foregroundColor(pinColor)
                        .font(.system(size: isSelected ? 14 : 12))
                }
                .offset(y: -2)
                
                // Enhanced title display when selected
                if isSelected, let title = mapPost.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.cardBackground)
                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                        )
                        .lineLimit(1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Cluster Pin

struct ClusterPin: View {
    let cluster: PostCluster
    let isSelected: Bool
    let isOwnPosts: Bool
    let onTap: () -> Void
    
    private var pinColor: Color {
        isOwnPosts ? .orange : .primaryBrand
    }
    
    private var shadowRadius: CGFloat {
        isSelected ? 10 : 6
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack {
                    // Enhanced shadow ring with pulsing effect
                    Circle()
                        .fill(pinColor.opacity(0.4))
                        .frame(width: isSelected ? 72 : 64, height: isSelected ? 72 : 64)
                        .blur(radius: 3)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isSelected)
                    
                    // Main cluster circle with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isOwnPosts ? [.orange.opacity(0.9), .orange] : [.primaryBrand.opacity(0.9), .primaryBrand],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isSelected ? 60 : 56, height: isSelected ? 60 : 56)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: isSelected ? 64 : 60, height: isSelected ? 64 : 60)
                        )
                        .shadow(color: pinColor.opacity(0.5), radius: shadowRadius, x: 0, y: 3)
                    
                    // Multiple post images in a stack effect
                    ZStack {
                        // Background circles to create stacked effect
                        ForEach(0..<min(3, cluster.posts.count), id: \.self) { index in
                            let offset: CGFloat = CGFloat(index) * 3
                            
                            AsyncImage(url: URL(string: cluster.posts[index].imageUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(pinColor.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.white)
                                            .font(.system(size: 12))
                                    )
                            }
                            .frame(width: isSelected ? 36 : 32, height: isSelected ? 36 : 32)
                            .clipShape(Circle())
                            .offset(x: -offset, y: -offset)
                            .opacity(index == 0 ? 1.0 : 0.7)
                        }
                    }
                    
                    // Posts count badge
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.8))
                                    .frame(width: isSelected ? 26 : 24, height: isSelected ? 26 : 24)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                
                                Text("\(cluster.posts.count)")
                                    .font(.system(size: isSelected ? 12 : 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        Spacer()
                    }
                    .offset(x: isSelected ? 18 : 16, y: isSelected ? -18 : -16)
                    
                    // Total hearts count overlay
                    if cluster.totalLikes > 0 {
                        VStack {
                            Spacer()
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: isSelected ? 10 : 9, weight: .bold))
                                    .foregroundColor(.red)
                                if cluster.totalLikes < 100 {
                                    Text("\(cluster.totalLikes)")
                                        .font(.system(size: isSelected ? 10 : 9, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Text("99+")
                                        .font(.system(size: isSelected ? 9 : 8, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, isSelected ? 6 : 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.8))
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            )
                            .offset(y: isSelected ? -4 : -3)
                        }
                    }
                    
                    // Enhanced crown icon for own posts
                    if isOwnPosts {
                        VStack {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: isSelected ? 16 : 14, height: isSelected ? 16 : 14)
                                            .shadow(color: .black.opacity(0.2), radius: 1)
                                    )
                                    .font(.system(size: isSelected ? 10 : 9))
                                Spacer()
                            }
                            Spacer()
                        }
                        .offset(x: isSelected ? -18 : -16, y: isSelected ? -18 : -16)
                    }
                }
                
                // Enhanced pin point with glow effect
                ZStack {
                    // Glow effect
                    Image(systemName: "arrowtriangle.down.fill")
                        .foregroundColor(pinColor.opacity(0.6))
                        .font(.system(size: isSelected ? 18 : 14))
                        .blur(radius: 3)
                    
                    // Main pin
                    Image(systemName: "arrowtriangle.down.fill")
                        .foregroundColor(pinColor)
                        .font(.system(size: isSelected ? 16 : 14))
                }
                .offset(y: -3)
                
                // Enhanced title display when selected
                if isSelected {
                    Text(cluster.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.cardBackground)
                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                        )
                        .lineLimit(1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Cluster Detail View

struct ClusterDetailView: View {
    let cluster: PostCluster
    let onPostSelected: (MapPostAnnotation) -> Void
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with location info
                VStack(spacing: 8) {
                    Text("Posts in this area")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    
                    Text("\(cluster.posts.count) food posts • \(cluster.totalLikes) total ❤️")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Horizontal scrolling posts
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(cluster.posts, id: \.id) { post in
                            ClusterPostCard(post: post) {
                                onPostSelected(post)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                
                Spacer()
                
                // Close button
                Button(action: onDismiss) {
                    Text("Close")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient.primaryGradient)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.background)
            .navigationBarHidden(true)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 {
                        onDismiss()
                    }
                }
        )
    }
}

// MARK: - Cluster Post Card

struct ClusterPostCard: View {
    let post: MapPostAnnotation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Post image
                AsyncImage(url: URL(string: post.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(LinearGradient.primaryGradient.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.primaryBrand)
                                .font(.largeTitle)
                        )
                }
                .frame(width: 280, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    // Engagement overlay
                    VStack {
                        Spacer()
                        HStack {
                            // Hearts
                            if post.likesCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text("\(post.likesCount)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.7))
                                )
                            }
                            
                            Spacer()
                            
                            // Comments
                            if post.commentsCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "bubble.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("\(post.commentsCount)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.7))
                                )
                            }
                        }
                        .padding(12)
                    }
                )
                
                // Post info
                VStack(alignment: .leading, spacing: 8) {
                    // Author
                    HStack(spacing: 8) {
                        Circle()
                            .fill(LinearGradient.primaryGradient)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(post.authorDisplayName?.first ?? "U"))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.authorDisplayName ?? "Unknown User")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                            
                            Text(post.locationString)
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                    }
                    
                    // Post title/description
                    if let title = post.title, !title.isEmpty {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primaryText)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(width: 280)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.cardBackground)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ShopMapPin: View {
    let shop: Shop
    let isSelected: Bool
    let onTap: () -> Void
    
    private var pinColor: Color {
        .shopsPlaces
    }
    
    private var shadowRadius: CGFloat {
        isSelected ? 8 : 4
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack {
                    // Enhanced shadow ring
                    Circle()
                        .fill(pinColor.opacity(0.3))
                        .frame(width: isSelected ? 42 : 38, height: isSelected ? 42 : 38)
                        .blur(radius: 2)
                    
                    // Main shop circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [pinColor.opacity(0.9), pinColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isSelected ? 38 : 34, height: isSelected ? 38 : 34)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: isSelected ? 42 : 38, height: isSelected ? 42 : 38)
                        )
                        .shadow(color: pinColor.opacity(0.4), radius: shadowRadius, x: 0, y: 2)
                    
                    // Fork and knife icon
                    Image(systemName: "fork.knife")
                        .foregroundColor(.white)
                        .font(.system(size: isSelected ? 16 : 14, weight: .semibold))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    
                    // Enhanced favorite indicator
                    if shop.isFavorite {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: isSelected ? 18 : 16, height: isSelected ? 18 : 16)
                                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                    
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: isSelected ? 11 : 10, weight: .bold))
                                }
                            }
                            Spacer()
                        }
                        .offset(x: isSelected ? 14 : 12, y: isSelected ? -14 : -12)
                    }
                    
                    // Rating overlay for high-rated shops
                    if shop.rating >= 4.5 {
                        VStack {
                            Spacer()
                            HStack(spacing: 1) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: isSelected ? 8 : 7, weight: .bold))
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", shop.rating))
                                    .font(.system(size: isSelected ? 8 : 7, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, isSelected ? 4 : 3)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.8))
                                    .shadow(color: .black.opacity(0.3), radius: 1)
                            )
                            .offset(y: isSelected ? -2 : -1)
                        }
                    }
                }
                
                // Enhanced pin point with glow effect
                ZStack {
                    // Glow effect
                    Image(systemName: "arrowtriangle.down.fill")
                        .foregroundColor(pinColor.opacity(0.6))
                        .font(.system(size: isSelected ? 14 : 10))
                        .blur(radius: 2)
                    
                    // Main pin
                    Image(systemName: "arrowtriangle.down.fill")
                        .foregroundColor(pinColor)
                        .font(.system(size: isSelected ? 12 : 10))
                }
                .offset(y: -2)
                
                // Enhanced shop name display when selected
                if isSelected {
                    Text(shop.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.cardBackground)
                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                        )
                        .lineLimit(1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Enhanced Preview Cards

struct PostPreviewToast: View {
    let mapPost: MapPostAnnotation
    let onTap: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Post image
            AsyncImage(url: URL(string: mapPost.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(LinearGradient.primaryGradient.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.primaryBrand)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                // Author name
                Text(mapPost.authorDisplayName ?? "Unknown User")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                // Post title/food item
                if let title = mapPost.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                // Location
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                    
                    Text(mapPost.locationString)
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                }
                
                // Engagement stats
                HStack(spacing: 12) {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text("\(mapPost.likesCount)")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                    }
                    
                    HStack(spacing: 2) {
                        Image(systemName: "bubble")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                        Text("\(mapPost.commentsCount)")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            
            Spacer()
            
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onTapGesture {
            onTap()
        }
    }
}

struct ShopPreviewCard: View {
    let shop: Shop
    @ObservedObject var viewModel: ExploreViewModel
    let onTap: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Shop Image
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient.primaryGradient.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "fork.knife")
                        .foregroundColor(.shopsPlaces)
                        .font(.title3)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(shop.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                if let firstCuisine = shop.cuisineTypes.first {
                    Text(firstCuisine.rawValue)
                        .font(.caption)
                        .foregroundColor(.shopsPlaces)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    // Rating
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.warning)
                        Text(String(format: "%.1f", shop.rating))
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    
                    // Price
                    Text(shop.priceRange.symbol)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    // Status
                    if let hours = shop.hours.hoursForToday(), !hours.isClosed {
                        Text("Open")
                            .font(.caption2)
                            .foregroundColor(.success)
                    } else {
                        Text("Closed")
                            .font(.caption2)
                            .foregroundColor(.error)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                // Favorite button
                Button(action: {
                    HapticManager.shared.impact(.light)
                    viewModel.toggleFavorite(for: shop)
                }) {
                    Image(systemName: shop.isFavorite ? "heart.fill" : "heart")
                        .font(.subheadline)
                        .foregroundColor(shop.isFavorite ? .red : .secondaryText)
                }
                
                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .padding(6)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Loading Indicator

struct LoadingIndicator: View {
    let message: String
    
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.primaryBrand)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Unified Filters View

struct UnifiedFiltersView: View {
    @ObservedObject var mapViewModel: MapViewModel
    @ObservedObject var exploreViewModel: ExploreViewModel
    let contentType: ExploreView.MapContentType
    @Environment(\.dismiss) private var dismiss
    
    @ViewBuilder
    private var distanceFilterSection: some View {
        if contentType == .everything {
            VStack(alignment: .leading, spacing: 12) {
                Text("Distance")
                    .font(.headline)
                
                HStack {
                    Text("\(Int(exploreViewModel.maxDistance)) miles")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Slider(value: $exploreViewModel.maxDistance, in: 1...50, step: 1)
                        .tint(.primaryBrand)
                }
            }
            
            Divider()
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Distance filter (shown for everything)
                    distanceFilterSection
                    
                    // Post filters for friendsPosts and myPosts
                    if contentType == .friendsPosts || contentType == .myPosts {
                        // User Type Filter Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Show Posts From")
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            
                            VStack(spacing: 12) {
                                FilterOptionRow(
                                    title: "Following Only",
                                    subtitle: "Posts from users you follow",
                                    icon: "person.badge.plus",
                                    isSelected: mapViewModel.showFollowingOnly,
                                    action: {
                                        mapViewModel.showFollowingOnly = true
                                        mapViewModel.showFriendsOnly = false
                                        mapViewModel.showAllUsers = false
                                    }
                                )
                                
                                FilterOptionRow(
                                    title: "Friends Only", 
                                    subtitle: "Posts from your friends",
                                    icon: "person.2.fill",
                                    isSelected: mapViewModel.showFriendsOnly,
                                    action: {
                                        mapViewModel.showFollowingOnly = false
                                        mapViewModel.showFriendsOnly = true
                                        mapViewModel.showAllUsers = false
                                    }
                                )
                                
                                FilterOptionRow(
                                    title: "All Users",
                                    subtitle: "Posts from all users", 
                                    icon: "globe",
                                    isSelected: mapViewModel.showAllUsers,
                                    action: {
                                        mapViewModel.showFollowingOnly = false
                                        mapViewModel.showFriendsOnly = false
                                        mapViewModel.showAllUsers = true
                                    }
                                )
                            }
                        }
                        
                        Divider()
                        
                        // Time Filter Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Post Age")
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            
                            VStack(spacing: 12) {
                                FilterOptionRow(
                                    title: "Today",
                                    subtitle: "Posts from the last 24 hours",
                                    icon: "clock",
                                    isSelected: mapViewModel.timeFilter == .today,
                                    action: { mapViewModel.timeFilter = .today }
                                )
                                
                                FilterOptionRow(
                                    title: "This Week",
                                    subtitle: "Posts from the last 7 days", 
                                    icon: "calendar",
                                    isSelected: mapViewModel.timeFilter == .thisWeek,
                                    action: { mapViewModel.timeFilter = .thisWeek }
                                )
                                
                                FilterOptionRow(
                                    title: "This Month",
                                    subtitle: "Posts from the last 30 days",
                                    icon: "calendar.badge.clock", 
                                    isSelected: mapViewModel.timeFilter == .thisMonth,
                                    action: { mapViewModel.timeFilter = .thisMonth }
                                )
                                
                                FilterOptionRow(
                                    title: "All Time",
                                    subtitle: "All posts ever created",
                                    icon: "infinity",
                                    isSelected: mapViewModel.timeFilter == .allTime,
                                    action: { mapViewModel.timeFilter = .allTime }
                                )
                            }
                        }
                        
                        Divider()
                        
                        // Food Categories Section  
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Food Categories")
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(FoodCategory.allCases, id: \.self) { category in
                                    CategoryFilterChip(
                                        category: category,
                                        isSelected: mapViewModel.selectedCategories.contains(category),
                                        action: {
                                            if mapViewModel.selectedCategories.contains(category) {
                                                mapViewModel.selectedCategories.remove(category)
                                            } else {
                                                mapViewModel.selectedCategories.insert(category)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    // Place filters for everything
                    if contentType == .everything {
                        // Drinks filter for places
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Drinks")
                                .font(.headline)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(DrinkType.allCases, id: \.self) { drink in
                                    FilterChip(
                                        title: drink.rawValue,
                                        isSelected: exploreViewModel.selectedDrinks.contains(drink)
                                    ) {
                                        exploreViewModel.toggleDrink(drink)
                                    }
                                }
                            }
                        }
                        
                        // Cuisines filter for places
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cuisines")
                                .font(.headline)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(CuisineType.allCases, id: \.self) { cuisine in
                                    FilterChip(
                                        title: cuisine.rawValue,
                                        isSelected: exploreViewModel.selectedCuisines.contains(cuisine)
                                    ) {
                                        exploreViewModel.toggleCuisine(cuisine)
                                    }
                                }
                            }
                        }
                        
                        // Desserts filter for places
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Desserts")
                                .font(.headline)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(DessertType.allCases, id: \.self) { dessert in
                                    FilterChip(
                                        title: dessert.rawValue,
                                        isSelected: exploreViewModel.selectedDesserts.contains(dessert)
                                    ) {
                                        exploreViewModel.toggleDessert(dessert)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Reset button for all filter types
                    Button(action: {
                        if contentType == .friendsPosts || contentType == .myPosts {
                            mapViewModel.resetFilters()
                        } else {
                            exploreViewModel.resetFilters()
                        }
                    }) {
                        Text("Reset All Filters")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red, lineWidth: 0.5)
                            )
                    }
                    .padding(.top)
                }
                .padding()
            }
            .background(Color.background)
            .navigationTitle("Filters")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                        }
                        .foregroundColor(.primaryBrand)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        Task {
                            if contentType == .friendsPosts || contentType == .myPosts {
                                await mapViewModel.applyFilters()
                            } else if contentType == .everything {
                                await exploreViewModel.applyFilters()
                            }
                            dismiss()
                        }
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
#else
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Apply") {
                        Task {
                            if contentType == .friendsPosts || contentType == .myPosts {
                                await mapViewModel.applyFilters()
                            } else if contentType == .everything {
                                await exploreViewModel.applyFilters()
                            }
                            dismiss()
                        }
                    }
                    .foregroundColor(.primaryBrand)
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                        }
                        .foregroundColor(.primaryBrand)
                    }
                }
            }
#endif
        }
    }
}

// MARK: - Filter Components

struct FilterOptionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .primaryBrand : .secondaryText)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.primaryBrand)
                        .font(.system(size: 18))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(isSelected ? Color.primaryBrand.opacity(0.1) : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CategoryFilterChip: View {
    let category: FoodCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(category.icon)
                    .font(.caption)
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.primaryBrand : Color.cardBackground)
            )
            .foregroundColor(isSelected ? .white : .primaryText)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : Color.divider, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.primaryBrand : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primaryText)
                .cornerRadius(20)
        }
    }
}

// MARK: - List View
struct ListView: View {
    @ObservedObject var viewModel: ExploreViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.nearbyShops.isEmpty && viewModel.isLoading {
                    // Show skeleton loaders while loading
                    ForEach(0..<5, id: \.self) { _ in
                        ListCardSkeleton()
                    }
                } else {
                    ForEach(viewModel.nearbyShops) { shop in
                        NavigationLink(destination: Text("Shop details coming soon")) {
                            ShopListCard(shop: shop, viewModel: viewModel)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding()
        }
        .background(Color.background)
    }
}



// MARK: - Shop List Card
struct ShopListCard: View {
    let shop: Shop
    @ObservedObject var viewModel: ExploreViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Image with Favorite Button
            ZStack(alignment: .topTrailing) {
                if let imageURL = shop.featuredImageURL {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                ProgressView()
                            )
                    }
                    .frame(height: 150)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(LinearGradient.primaryGradient.opacity(0.3))
                        .frame(height: 150)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.largeTitle)
                                .foregroundColor(.primaryBrand)
                        )
                }
                
                // Favorite Button
                Button(action: {
                    HapticManager.shared.impact(.light)
                    viewModel.toggleFavorite(for: shop)
                }) {
                    Image(systemName: shop.isFavorite ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundColor(shop.isFavorite ? .red : .white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(12)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(shop.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if shop.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.matchaGreen)
                    }
                }
                
                HStack {
                    // Rating
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.warning)
                        Text(String(format: "%.1f", shop.rating))
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("(\(shop.reviewsCount))")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    
                    Text("•")
                        .foregroundColor(.tertiaryText)
                    
                    // Cuisine
                    Text(shop.cuisineTypes.first?.rawValue ?? "Restaurant")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Text("•")
                        .foregroundColor(.tertiaryText)
                    
                    // Price
                    Text(shop.priceRange.symbol)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                if let description = shop.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
                
                HStack {
                    Label(shop.location.city, systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.tertiaryText)
                    
                    Spacer()
                    
                    if let hours = shop.hours.hoursForToday(), !hours.isClosed {
                        Text("Open until \(hours.close)")
                            .font(.caption2)
                            .foregroundColor(.success)
                    } else {
                        Text("Closed")
                            .font(.caption2)
                            .foregroundColor(.error)
                    }
                }
            }
            .padding()
        }
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - View Model
@MainActor
class ExploreViewModel: ObservableObject {
    @Published var nearbyShops: [Shop] = []
    @Published var isLoading = false
    
    // Filters
    @Published var selectedDrinks: Set<DrinkType> = []
    @Published var selectedCuisines: Set<CuisineType> = []
    @Published var selectedDesserts: Set<DessertType> = []
    @Published var maxDistance: Double = 25
    @Published var showOnlyFavorites: Bool = false
    
    private var allShops: [Shop] = []
    
    func loadNearbyShops() async {
        isLoading = true
        
        do {
            // Search for general food/restaurant places
            let placeResults = try await BackendService.shared.searchPlaces(
                query: "restaurant food cafe", 
                latitude: nil, 
                longitude: nil, 
                radius: 25000, // 25km radius
                limit: 20
            )
            
            // Convert PlaceSearchResult to Shop objects
            let shops = placeResults.map { place in
                convertPlaceToShop(place)
            }
            
            allShops = shops
            nearbyShops = shops
            print("✅ ExploreViewModel: Loaded \(shops.count) shops from backend")
            
        } catch {
            print("❌ ExploreViewModel: Failed to load shops: \(error)")
            // Fallback to mock data if backend fails
            let shops: [Shop] = MockData.sampleShops
            allShops = shops
            nearbyShops = shops
        }
        
        isLoading = false
    }
    
    func loadNearbyShops(at location: CLLocation) async {
        isLoading = true
        
        print("🗺️ ExploreViewModel: Loading nearby shops at location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        do {
            // Search for food/restaurant places near user's location
            let placeResults = try await BackendService.shared.searchPlaces(
                query: "restaurant food cafe", 
                latitude: location.coordinate.latitude, 
                longitude: location.coordinate.longitude, 
                radius: Int(maxDistance * 1000), // Convert km to meters
                limit: 30
            )
            
            // Convert PlaceSearchResult to Shop objects
            let shops = placeResults.map { place in
                convertPlaceToShop(place)
            }
            
            allShops = shops
            nearbyShops = shops
            print("✅ ExploreViewModel: Loaded \(shops.count) nearby shops from backend")
            
        } catch {
            print("❌ ExploreViewModel: Failed to load nearby shops: \(error)")
            // Fallback to mock data if backend fails
            let shops: [Shop] = MockData.sampleShops
            allShops = shops
            nearbyShops = shops
        }
        
        isLoading = false
    }
    
    // Helper method to convert PlaceSearchResult to Shop
    private func convertPlaceToShop(_ place: BackendService.PlaceSearchResult) -> Shop {
        // Convert place types to cuisine types
        let cuisineTypes = convertPlaceTypesToCuisine(place.types)
        
        // Determine drink types based on place types and name
        let drinkTypes = determineDrinkTypes(from: place.types, name: place.name)
        
        // Determine price range from price level
        let priceRange = convertPriceLevelToPriceRange(place.priceLevel)
        
        // Create location object
        let location = Location(
            latitude: place.latitude,
            longitude: place.longitude,
            address: place.address,
            city: "", // Not available in place result
            state: nil,
            country: ""
        )
        
        return Shop(
            name: place.name,
            description: "Discover great food at \(place.name)",
            location: location,
            phoneNumber: nil, // Not available in place result
            website: nil, // Not available in place result
            hours: BusinessHours.defaultHours, // Use default hours
            cuisineTypes: cuisineTypes,
            drinkTypes: drinkTypes,
            priceRange: priceRange,
            rating: place.rating ?? 0.0,
            reviewsCount: 0, // Not available in place result
            photosCount: 0, // Not available in place result
            isVerified: false,
            featuredImageURL: place.photoUrl != nil ? URL(string: place.photoUrl!) : nil,
            isFavorite: false
        )
    }
    
    private func convertPlaceTypesToCuisine(_ types: [String]) -> [CuisineType] {
        var cuisineTypes: Set<CuisineType> = []
        
        for type in types {
            switch type.lowercased() {
            case "restaurant", "food", "meal_takeaway":
                cuisineTypes.insert(.fusion)
            case "cafe", "bakery":
                cuisineTypes.insert(.cafe)
            case "bar":
                cuisineTypes.insert(.fusion)
            case "meal_delivery":
                cuisineTypes.insert(.fusion)
            default:
                // For specific cuisine types, we'd need more sophisticated mapping
                cuisineTypes.insert(.fusion)
            }
        }
        
        return Array(cuisineTypes)
    }
    
    private func determineDrinkTypes(from types: [String], name: String) -> [DrinkType] {
        var drinkTypes: Set<DrinkType> = []
        
        let lowerName = name.lowercased()
        let lowerTypes = types.map { $0.lowercased() }
        
        // Determine drink types based on place types and name
        if lowerTypes.contains("cafe") || lowerName.contains("coffee") || lowerName.contains("cafe") {
            drinkTypes.insert(.coffee)
        }
        
        if lowerName.contains("tea") || lowerName.contains("matcha") {
            drinkTypes.insert(.tea)
        }
        
        if lowerTypes.contains("bar") || lowerName.contains("bar") {
            drinkTypes.insert(.tea) // Default to tea for bars since wine isn't available
        }
        
        if lowerName.contains("juice") || lowerName.contains("smoothie") {
            drinkTypes.insert(.freshJuice)
        }
        
        // Default to coffee if no specific drink type is determined
        if drinkTypes.isEmpty {
            drinkTypes.insert(.coffee)
        }
        
        return Array(drinkTypes)
    }
    
    private func convertPriceLevelToPriceRange(_ priceLevel: Int?) -> PriceRange {
        guard let level = priceLevel else { return .moderate }
        
        switch level {
        case 1:
            return .budget
        case 2:
            return .moderate
        case 3:
            return .expensive
        case 4:
            return .luxury
        default:
            return .moderate
        }
    }
    
    func toggleDrink(_ drink: DrinkType) {
        if selectedDrinks.contains(drink) {
            selectedDrinks.remove(drink)
        } else {
            selectedDrinks.insert(drink)
        }
    }
    
    func toggleCuisine(_ cuisine: CuisineType) {
        if selectedCuisines.contains(cuisine) {
            selectedCuisines.remove(cuisine)
        } else {
            selectedCuisines.insert(cuisine)
        }
    }
    
    func toggleDessert(_ dessert: DessertType) {
        if selectedDesserts.contains(dessert) {
            selectedDesserts.remove(dessert)
        } else {
            selectedDesserts.insert(dessert)
        }
    }
    
    func toggleShowOnlyFavorites() {
        showOnlyFavorites.toggle()
    }
    
    func toggleFavorite(for shop: Shop) {
        if let index = nearbyShops.firstIndex(where: { $0.id == shop.id }) {
            nearbyShops[index].isFavorite.toggle()
        }
        if let index = allShops.firstIndex(where: { $0.id == shop.id }) {
            allShops[index].isFavorite.toggle()
        }
    }
    
    func resetFilters() {
        selectedDrinks.removeAll()
        selectedCuisines.removeAll()
        selectedDesserts.removeAll()
        maxDistance = 25
        showOnlyFavorites = false
    }
    
    func applyFilters() async {
        isLoading = true
        
        var filteredShops = allShops
        
        // Apply favorite filter
        if showOnlyFavorites {
            filteredShops = filteredShops.filter { $0.isFavorite }
        }
        
        // Apply drink filter
        if !selectedDrinks.isEmpty {
            filteredShops = filteredShops.filter { shop in
                shop.drinkTypes.contains { selectedDrinks.contains($0) }
            }
        }
        
        // Apply cuisine filter
        if !selectedCuisines.isEmpty {
            filteredShops = filteredShops.filter { shop in
                shop.cuisineTypes.contains { selectedCuisines.contains($0) }
            }
        }
        
        // Apply dessert filter
        if !selectedDesserts.isEmpty {
            filteredShops = filteredShops.filter { shop in
                shop.dessertTypes.contains { selectedDesserts.contains($0) }
            }
        }
        
        // Distance filter would be applied here in a real app
        // For now, we'll just simulate the filtering delay
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        nearbyShops = filteredShops
        isLoading = false
    }
}

// MARK: - User Location Indicator

struct UserLocationIndicator: View {
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 32, height: 32)
                .scaleEffect(pulseScale)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: pulseScale
                )
            
            // Inner dot
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .onAppear {
            pulseScale = 1.4
        }
    }
}

// MARK: - Location Focus Button

struct LocationFocusButton: View {
    @ObservedObject var locationManager: LocationManager
    let onTap: (ExploreView.LocationZoomLevel) -> Void
    @State private var isPressed = false
    @State private var lastTapTime: Date = Date()
    
    var body: some View {
        Button(action: handleTap) {
            ZStack {
                Circle()
                    .fill(Color.cardBackground)
                    .frame(width: 48, height: 48)
                    .shadow(
                        color: .black.opacity(0.15), 
                        radius: isPressed ? 4 : 8, 
                        x: 0, 
                        y: isPressed ? 2 : 4
                    )
                
                Image(systemName: locationManager.currentLocation != nil ? "location.fill" : "location")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(locationManager.currentLocation != nil ? .success : .secondaryText)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .opacity(locationManager.authorizationStatus == .denied ? 0.5 : 1.0)
        .disabled(locationManager.authorizationStatus == .denied)
    }
    
    private func handleTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isPressed = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = false
            }
        }
        
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        if timeSinceLastTap < 0.5 {
            // Double tap detected - use close zoom
            onTap(.close)
            HapticManager.shared.impact(.medium)
        } else {
            // Single tap - use normal zoom
            onTap(.normal)
        }
        
        lastTapTime = now
    }
}

// MARK: - Preview Helpers

extension MapPostAnnotation {
    static var samplePosts: [MapPostAnnotation] {
        [
            MapPostAnnotation(
                id: "1",
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                title: "Amazing Ramen 🍜",
                authorDisplayName: "John Doe",
                authorAvatarUrl: nil,
                imageUrl: "https://example.com/ramen.jpg",
                locationString: "Downtown SF",
                likesCount: 15,
                commentsCount: 3,
                originalPost: Post(
                    userId: UUID(),
                    author: User(
                        id: UUID(),
                        email: "john@example.com",
                        username: "john_doe",
                        displayName: "John Doe",
                        clerkId: "user1"
                    ),
                    title: "Amazing Ramen 🍜",
                    caption: "Best ramen in the city!",
                    mediaURLs: [URL(string: "https://example.com/ramen.jpg")!],
                    location: Location(
                        latitude: 37.7749,
                        longitude: -122.4194,
                        address: "123 Geary St",
                        city: "San Francisco",
                        country: "USA"
                    ),
                    likesCount: 15,
                    commentsCount: 3
                )
            ),
            MapPostAnnotation(
                id: "2",
                coordinate: CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4196), // Very close to first post
                title: "Sushi Paradise 🍣",
                authorDisplayName: "Jane Smith",
                authorAvatarUrl: nil,
                imageUrl: "https://example.com/sushi.jpg",
                locationString: "Downtown SF",
                likesCount: 22,
                commentsCount: 7,
                originalPost: Post(
                    userId: UUID(),
                    author: User(
                        id: UUID(),
                        email: "jane@example.com",
                        username: "jane_smith",
                        displayName: "Jane Smith",
                        clerkId: "user2"
                    ),
                    title: "Sushi Paradise 🍣",
                    caption: "Fresh sushi downtown!",
                    mediaURLs: [URL(string: "https://example.com/sushi.jpg")!],
                    location: Location(
                        latitude: 37.7751,
                        longitude: -122.4196,
                        address: "125 Geary St",
                        city: "San Francisco",
                        country: "USA"
                    ),
                    likesCount: 22,
                    commentsCount: 7
                )
            ),
            MapPostAnnotation(
                id: "3",
                coordinate: CLLocationCoordinate2D(latitude: 37.7752, longitude: -122.4195), // Also very close - should cluster
                title: "Pizza Heaven 🍕",
                authorDisplayName: "Mike Johnson",
                authorAvatarUrl: nil,
                imageUrl: "https://example.com/pizza.jpg",
                locationString: "Downtown SF",
                likesCount: 8,
                commentsCount: 2,
                originalPost: Post(
                    userId: UUID(),
                    author: User(
                        id: UUID(),
                        email: "mike@example.com",
                        username: "mike_johnson",
                        displayName: "Mike Johnson",
                        clerkId: "user3"
                    ),
                    title: "Pizza Heaven 🍕",
                    caption: "Great pizza spot!",
                    mediaURLs: [URL(string: "https://example.com/pizza.jpg")!],
                    location: Location(
                        latitude: 37.7752,
                        longitude: -122.4195,
                        address: "127 Geary St",
                        city: "San Francisco",
                        country: "USA"
                    ),
                    likesCount: 8,
                    commentsCount: 2
                )
            ),
            MapPostAnnotation(
                id: "4",
                coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094), // Far from others - separate pin
                title: "Coffee Paradise ☕",
                authorDisplayName: "Sarah Wilson",
                authorAvatarUrl: nil,
                imageUrl: "https://example.com/coffee.jpg",
                locationString: "North Beach",
                likesCount: 12,
                commentsCount: 4,
                originalPost: Post(
                    userId: UUID(),
                    author: User(
                        id: UUID(),
                        email: "sarah@example.com",
                        username: "sarah_wilson",
                        displayName: "Sarah Wilson",
                        clerkId: "user4"
                    ),
                    title: "Coffee Paradise ☕",
                    caption: "Perfect morning coffee!",
                    mediaURLs: [URL(string: "https://example.com/coffee.jpg")!],
                    location: Location(
                        latitude: 37.7849,
                        longitude: -122.4094,
                        address: "456 Columbus Ave",
                        city: "San Francisco",
                        country: "USA"
                    ),
                    likesCount: 12,
                    commentsCount: 4
                )
            )
        ]
    }
}

// MARK: - View Extensions for ExploreView

private extension ExploreView {
    @ViewBuilder
    func applyNavigationTitle() -> some View {
        self
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationTitle("Palytt")
    }
    

    
    @ViewBuilder
    func applyModals() -> some View {
        self
            .sheet(isPresented: $showFilters) {
                UnifiedFiltersView(
                    mapViewModel: mapViewModel,
                    exploreViewModel: viewModel,
                    contentType: contentType
                )
            }

            .fullScreenCover(isPresented: $showingPostDetail) {
                if let selectedPost = selectedPost {
                    PostDetailView(post: selectedPost.originalPost)
                        .environmentObject(appState)
                }
            }
            .fullScreenCover(isPresented: $showingClusterDetail) {
                clusterDetailView
            }
            .fullScreenCover(isPresented: $showingShopDetail) {
                shopDetailView
            }
    }
    
    @ViewBuilder
    func applyLifecycleHandlers() -> some View {
        self
            .onAppear {
                // Setup logic would go here
            }
            .onDisappear {
                // Cleanup logic would go here
            }
    }
    
    @ViewBuilder
    func applyDataChangeListeners() -> some View {
        self
            .onChange(of: false) { _, _ in
                // Change listeners would go here
            }
    }
}

// MARK: - SwiftUI Previews with Rich Content
#Preview("Explore - Map View with Rich Data") {
    let mockState = MockAppState()
    // Load rich explore data
    mockState.homeViewModel.posts = MockData.generatePreviewPosts()
    
    return ExploreView()
        .environmentObject(mockState)
        .onAppear {
            print("🗺️ Explore Map loaded with \(mockState.homeViewModel.posts.count) posts for mapping")
        }
}

#Preview("Explore - List View with Shops") {
    let mockState = MockAppState()
    // Simulate rich shop data
    mockState.homeViewModel.posts = MockData.generatePreviewPosts()
    
    return ExploreView()
        .environmentObject(mockState)
        .onAppear {
            print("📍 Explore List loaded with nearby shops and places")
        }
}

#Preview("Explore - Dark Mode") {
    let mockState = MockAppState()
    mockState.homeViewModel.posts = MockData.generateTrendingPosts()
    
    return ExploreView()
        .environmentObject(mockState)
        .preferredColorScheme(.dark)
}

#Preview("Explore - Loading State") {
    let mockState = MockAppState()
    mockState.homeViewModel.isLoading = true
    mockState.homeViewModel.posts = []
    
    return ExploreView()
        .environmentObject(mockState)
} 
