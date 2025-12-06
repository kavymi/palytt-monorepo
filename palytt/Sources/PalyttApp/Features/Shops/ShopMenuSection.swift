//
//  ShopMenuSection.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Kingfisher

// MARK: - Shop Menu Section

/// Displays the shop's menu items grouped by category
struct ShopMenuSection: View {
    let menu: [MenuItem]
    @State private var selectedCategory: String?
    @State private var expandedCategories: Set<String> = []
    
    private var categories: [String] {
        Array(Set(menu.map { $0.category })).sorted()
    }
    
    private var popularItems: [MenuItem] {
        menu.filter { $0.isPopular }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "menucard.fill")
                    .foregroundColor(.primaryBrand)
                    .font(.title3)
                
                Text("Menu")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Text("\(menu.count) items")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            // Popular Items Section
            if !popularItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.warning)
                            .font(.subheadline)
                        
                        Text("Popular")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(popularItems) { item in
                                PopularMenuItemCard(item: item)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            
            // Category Pills
            if categories.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryPill(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            onTap: { selectedCategory = nil }
                        )
                        
                        ForEach(categories, id: \.self) { category in
                            CategoryPill(
                                title: category,
                                isSelected: selectedCategory == category,
                                onTap: { selectedCategory = category }
                            )
                        }
                    }
                }
            }
            
            // Menu Items by Category
            if let selected = selectedCategory {
                // Show only selected category
                MenuCategorySection(
                    category: selected,
                    items: menu.filter { $0.category == selected },
                    isExpanded: true,
                    onToggle: {}
                )
            } else {
                // Show all categories
                ForEach(categories, id: \.self) { category in
                    MenuCategorySection(
                        category: category,
                        items: menu.filter { $0.category == category },
                        isExpanded: expandedCategories.contains(category),
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedCategories.contains(category) {
                                    expandedCategories.remove(category)
                                } else {
                                    expandedCategories.insert(category)
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .onAppear {
            // Expand first category by default
            if let first = categories.first {
                expandedCategories.insert(first)
            }
        }
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            onTap()
        }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.primaryBrand : Color.gray.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Menu Category Section

struct MenuCategorySection: View {
    let category: String
    let items: [MenuItem]
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category Header
            Button(action: onToggle) {
                HStack {
                    Text(category)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    
                    Text("(\(items.count))")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Items
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        MenuItemRow(item: item)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Menu Item Row

struct MenuItemRow: View {
    let item: MenuItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Item Image (if available)
            if let imageURL = item.imageURL {
                KFImage(imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Item Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                    
                    if item.isPopular {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.warning)
                    }
                    
                    Spacer()
                    
                    Text(formatPrice(item.price))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryBrand)
                }
                
                if let description = item.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
                
                // Dietary badges
                if !item.dietaryInfo.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.dietaryInfo, id: \.self) { dietary in
                            DietaryBadge(preference: dietary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }
}

// MARK: - Popular Menu Item Card

struct PopularMenuItemCard: View {
    let item: MenuItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            ZStack(alignment: .topTrailing) {
                if let imageURL = item.imageURL {
                    KFImage(imageURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 80)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .foregroundColor(.gray)
                        )
                }
                
                // Popular badge
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.warning)
                    .clipShape(Circle())
                    .padding(4)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text(formatPrice(item.price))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryBrand)
            }
        }
        .frame(width: 120)
    }
    
    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }
}

// MARK: - Dietary Badge

struct DietaryBadge: View {
    let preference: DietaryPreference
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: preference.icon)
                .font(.system(size: 8))
            
            Text(preference.shortName)
                .font(.system(size: 9))
                .fontWeight(.medium)
        }
        .foregroundColor(preference.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(preference.color.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Dietary Preference Extension

extension DietaryPreference {
    var sfIcon: String {
        switch self {
        case .vegetarian: return "leaf.fill"
        case .vegan: return "leaf.circle.fill"
        case .glutenFree: return "g.circle.fill"
        case .dairyFree: return "drop.fill"
        case .nutFree: return "exclamationmark.triangle.fill"
        case .halal: return "checkmark.seal.fill"
        case .kosher: return "star.fill"
        case .keto: return "flame.fill"
        case .paleo: return "figure.walk"
        case .pescatarian: return "fish.fill"
        }
    }
    
    var shortName: String {
        switch self {
        case .vegetarian: return "VEG"
        case .vegan: return "VGN"
        case .glutenFree: return "GF"
        case .dairyFree: return "DF"
        case .nutFree: return "NF"
        case .halal: return "HAL"
        case .kosher: return "KOS"
        case .keto: return "KETO"
        case .paleo: return "PALEO"
        case .pescatarian: return "PESC"
        }
    }
    
    var color: Color {
        switch self {
        case .vegetarian, .vegan: return .green
        case .glutenFree, .dairyFree: return .orange
        case .nutFree: return .red
        case .halal, .kosher: return .purple
        case .keto, .paleo: return .blue
        case .pescatarian: return .cyan
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        ShopMenuSection(menu: [
            MenuItem(
                name: "Avocado Toast",
                description: "Fresh avocado on sourdough with cherry tomatoes and microgreens",
                price: 14.99,
                category: "Breakfast",
                dietaryInfo: [.vegetarian, .vegan],
                isPopular: true
            ),
            MenuItem(
                name: "Eggs Benedict",
                description: "Poached eggs on English muffin with hollandaise",
                price: 16.99,
                category: "Breakfast",
                isPopular: true
            ),
            MenuItem(
                name: "Caesar Salad",
                description: "Romaine lettuce, parmesan, croutons, caesar dressing",
                price: 12.99,
                category: "Salads",
                dietaryInfo: [.glutenFree]
            ),
            MenuItem(
                name: "Grilled Salmon",
                description: "Atlantic salmon with seasonal vegetables",
                price: 24.99,
                category: "Mains",
                dietaryInfo: [.glutenFree, .dairyFree]
            ),
            MenuItem(
                name: "Chocolate Lava Cake",
                description: "Warm chocolate cake with vanilla ice cream",
                price: 9.99,
                category: "Desserts",
                isPopular: true
            )
        ])
        .padding()
    }
    .background(Color.background)
}

