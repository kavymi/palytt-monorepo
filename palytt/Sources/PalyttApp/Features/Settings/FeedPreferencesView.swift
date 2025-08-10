//
//  FeedPreferencesView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

struct FeedPreferencesView: View {
    @StateObject private var locationService = LocationBasedFeedService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingLocationSettings = false
    @State private var tempPreferences: LocationBasedFeedService.FeedPreferences
    
    init() {
        _tempPreferences = State(initialValue: LocationBasedFeedService.shared.feedPreferences)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Location Settings Section
                Section("Location Settings") {
                    NavigationLink(destination: LocationFeedSettingsView()) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.primaryBrand)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Location Feed Settings")
                                    .font(.body)
                                    .foregroundColor(.primaryText)
                                
                                Text("Configure distance and location preferences")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Toggle("Location Notifications", isOn: $tempPreferences.enableLocationNotifications)
                        .tint(.primaryBrand)
                }
                
                // Feed Content Section
                Section("Feed Content") {
                    Toggle("Show Following Only", isOn: $tempPreferences.showFollowingOnly)
                        .tint(.primaryBrand)
                    
                    Toggle("Show Friends Only", isOn: $tempPreferences.showFriendsOnly)
                        .tint(.primaryBrand)
                    
                    // Sort Options
                    Picker("Sort By", selection: $tempPreferences.sortBy) {
                        ForEach(LocationBasedFeedService.SortOption.allCases, id: \.self) { option in
                            Label(option.displayName, systemImage: option.icon)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Distance Settings Section
                Section("Distance Settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Maximum Distance")
                                .font(.body)
                                .foregroundColor(.primaryText)
                            
                            Spacer()
                            
                            Text(tempPreferences.maxDistance >= 1000 ? "No Limit" : "\(Int(tempPreferences.maxDistance)) km")
                                .font(.caption)
                                .foregroundColor(.primaryBrand)
                                .fontWeight(.semibold)
                        }
                        
                        Slider(
                            value: $tempPreferences.maxDistance,
                            in: 1...1000,
                            step: 1
                        ) {
                            Text("Distance")
                        }
                        .tint(.primaryBrand)
                        
                        HStack {
                            Text("1 km")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            Spacer()
                            
                            Text("No Limit")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Food Categories Section
                Section("Food Categories") {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Select your preferred food categories")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            Spacer()
                            
                            Button(tempPreferences.enabledCategories.count == FoodCategory.allCases.count ? "None" : "All") {
                                if tempPreferences.enabledCategories.count == FoodCategory.allCases.count {
                                    tempPreferences.enabledCategories.removeAll()
                                } else {
                                    tempPreferences.enabledCategories = Set(FoodCategory.allCases)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.primaryBrand)
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(FoodCategory.allCases, id: \.self) { category in
                                FoodCategoryChip(
                                    category: category,
                                    isSelected: tempPreferences.enabledCategories.contains(category)
                                ) {
                                    if tempPreferences.enabledCategories.contains(category) {
                                        tempPreferences.enabledCategories.remove(category)
                                    } else {
                                        tempPreferences.enabledCategories.insert(category)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Time Filter Section
                Section("Time Filter") {
                    Picker("Show Posts From", selection: $tempPreferences.timeFilter) {
                        ForEach(TimeFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName)
                                .tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Auto-Refresh Section
                Section("Auto-Refresh") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Refresh Interval")
                                .font(.body)
                                .foregroundColor(.primaryText)
                            
                            Spacer()
                            
                            Text(formatRefreshInterval(tempPreferences.autoRefreshInterval))
                                .font(.caption)
                                .foregroundColor(.primaryBrand)
                                .fontWeight(.semibold)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { tempPreferences.autoRefreshInterval },
                                set: { tempPreferences.autoRefreshInterval = $0 }
                            ),
                            in: 60...1800,
                            step: 60
                        ) {
                            Text("Refresh Interval")
                        }
                        .tint(.primaryBrand)
                        
                        HStack {
                            Text("1 min")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            Spacer()
                            
                            Text("30 min")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Reset Section
                Section {
                    Button("Reset to Defaults") {
                        tempPreferences = LocationBasedFeedService.FeedPreferences()
                        HapticManager.shared.impact(.light)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Feed Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        locationService.updatePreferences(tempPreferences)
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                    .fontWeight(.semibold)
                }
            }
        }
        .background(Color.background)
    }
    
    private func formatRefreshInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes == 1 {
            return "1 minute"
        } else {
            return "\(minutes) minutes"
        }
    }
}

// MARK: - Food Category Chip
struct FoodCategoryChip: View {
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

// MARK: - Preview
#Preview {
    FeedPreferencesView()
        .environmentObject(LocationBasedFeedService.shared)
} 