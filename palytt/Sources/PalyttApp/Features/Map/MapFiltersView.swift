//
//  MapFiltersView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

struct MapFiltersView: View {
    @Binding var isPresented: Bool
    @ObservedObject var mapViewModel: MapViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Filter Type Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Show Posts From")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        VStack(spacing: 12) {
                            MapFilterOptionRow(
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
                            
                            MapFilterOptionRow(
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
                            
                            MapFilterOptionRow(
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
                    
                    // Distance Filter Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Distance Range")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Within \(Int(mapViewModel.maxDistance)) km")
                                    .font(.subheadline)
                                    .foregroundColor(.secondaryText)
                                Spacer()
                                Text(mapViewModel.maxDistance == 1000 ? "Unlimited" : "\(Int(mapViewModel.maxDistance)) km")
                                    .font(.caption)
                                    .foregroundColor(.primaryBrand)
                            }
                            
                            Slider(
                                value: $mapViewModel.maxDistance,
                                in: 1...1000,
                                step: 1
                            ) {
                                Text("Distance")
                            }
                            .accentColor(.primaryBrand)
                        }
                    }
                    
                    Divider()
                    
                    // Time Filter Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Post Age")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        VStack(spacing: 12) {
                            MapFilterOptionRow(
                                title: "Today",
                                subtitle: "Posts from the last 24 hours",
                                icon: "clock",
                                isSelected: mapViewModel.timeFilter == .today,
                                action: {
                                    mapViewModel.timeFilter = .today
                                }
                            )
                            
                            MapFilterOptionRow(
                                title: "This Week",
                                subtitle: "Posts from the last 7 days",
                                icon: "calendar",
                                isSelected: mapViewModel.timeFilter == .thisWeek,
                                action: {
                                    mapViewModel.timeFilter = .thisWeek
                                }
                            )
                            
                            MapFilterOptionRow(
                                title: "This Month",
                                subtitle: "Posts from the last 30 days",
                                icon: "calendar.badge.clock",
                                isSelected: mapViewModel.timeFilter == .thisMonth,
                                action: {
                                    mapViewModel.timeFilter = .thisMonth
                                }
                            )
                            
                            MapFilterOptionRow(
                                title: "All Time",
                                subtitle: "All posts ever created",
                                icon: "infinity",
                                isSelected: mapViewModel.timeFilter == .allTime,
                                action: {
                                    mapViewModel.timeFilter = .allTime
                                }
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Category Filter Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Food Categories")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(FoodCategory.allCases, id: \.self) { category in
                                MapCategoryFilterChip(
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
                    
                    // Reset Filters Button
                    Button(action: {
                        mapViewModel.resetFilters()
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
            .navigationTitle("Map Filters")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isPresented = false
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
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
#else
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.primaryBrand)
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button(action: {
                        isPresented = false
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
            .background(Color.background)
        }
        .onDisappear {
            // Apply filters when the sheet is dismissed
            Task {
                await mapViewModel.applyFilters()
            }
        }
    }
}

// MARK: - Filter Option Row
struct MapFilterOptionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .primaryBrand : .tertiaryText)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .primaryBrand : .tertiaryText)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Category Filter Chip
struct MapCategoryFilterChip: View {
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

// MARK: - Food Category Enum
enum FoodCategory: String, CaseIterable {
    case american = "american"
    case asian = "asian"
    case coffee = "coffee"
    case dessert = "dessert"
    case fastFood = "fast_food"
    case healthy = "healthy"
    case indian = "indian"
    case italian = "italian"
    case mexican = "mexican"
    case streetFood = "street_food"
    case vegan = "vegan"
    case vegetarian = "vegetarian"
    
    var displayName: String {
        switch self {
        case .american: return "American"
        case .asian: return "Asian"
        case .coffee: return "Coffee"
        case .dessert: return "Dessert"
        case .fastFood: return "Fast Food"
        case .healthy: return "Healthy"
        case .indian: return "Indian"
        case .italian: return "Italian"
        case .mexican: return "Mexican"
        case .streetFood: return "Street Food"
        case .vegan: return "Vegan"
        case .vegetarian: return "Vegetarian"
        }
    }
    
    var icon: String {
        switch self {
        case .american: return "🍔"
        case .asian: return "🍜"
        case .coffee: return "☕"
        case .dessert: return "🍰"
        case .fastFood: return "🍟"
        case .healthy: return "🥗"
        case .indian: return "🍛"
        case .italian: return "🍝"
        case .mexican: return "🌮"
        case .streetFood: return "🍡"
        case .vegan: return "🌱"
        case .vegetarian: return "🥬"
        }
    }
}

// MARK: - Time Filter Enum
enum TimeFilter: String, CaseIterable {
    case today = "today"
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    case allTime = "all_time"
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .allTime: return "All Time"
        }
    }
} 

// MARK: - SwiftUI Previews
#Preview("Map Filters View") {
    @Previewable @State var isPresented = true
    
    NavigationStack {
        MapFiltersView(
            isPresented: $isPresented,
            mapViewModel: MapViewModel()
        )
    }
}

#Preview("Filter Option Row - Selected") {
    VStack(spacing: 12) {
                                    MapFilterOptionRow(
            title: "Following Only",
            subtitle: "Posts from users you follow",
            icon: "person.badge.plus",
            isSelected: true,
            action: {}
        )
        
        MapFilterOptionRow(
            title: "All Users",
            subtitle: "Posts from all users",
            icon: "globe",
            isSelected: false,
            action: {}
        )
    }
    .padding()
}

#Preview("Map Filters - Dark Mode") {
    @Previewable @State var isPresented = true
    
    NavigationStack {
        MapFiltersView(
            isPresented: $isPresented,
            mapViewModel: MapViewModel()
        )
    }
    .preferredColorScheme(.dark)
} 