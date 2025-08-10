//
//  FollowersListView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Followers List View
struct FollowersListView: View {
    let userId: String
    let userName: String
    @StateObject private var viewModel = SocialListViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.users.isEmpty {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading followers...")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.users.isEmpty && !viewModel.isLoading {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.system(size: 50))
                            .foregroundColor(.tertiaryText)
                        
                        Text("No Followers Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                        
                        Text("When people follow \(userName), they'll appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Users list
                    List {
                        ForEach(viewModel.users, id: \.clerkId) { user in
                            UserRowView(user: user)
                                .listRowBackground(Color.cardBackground)
                                .listRowSeparatorTint(Color.divider)
                        }
                        
                        // Load more indicator
                        if viewModel.hasMore && !viewModel.isLoading {
                            HStack {
                                Spacer()
                                Button("Load More") {
                                    Task {
                                        await viewModel.loadMore()
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.primaryBrand)
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
                
                // Error message
                if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            Task {
                                await viewModel.loadFollowers(for: userId)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.primaryBrand)
                    }
                    .padding()
                    .background(Color.cardBackground)
                }
            }
            .navigationTitle("Followers")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                #endif
            }
            .background(Color.background)
        }
        .task {
            await viewModel.loadFollowers(for: userId)
        }
    }
}

// MARK: - Following List View
struct FollowingListView: View {
    let userId: String
    let userName: String
    @StateObject private var viewModel = SocialListViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.users.isEmpty {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading following...")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.users.isEmpty && !viewModel.isLoading {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.tertiaryText)
                        
                        Text("Not Following Anyone")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                        
                        Text("When \(userName) follows people, they'll appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Users list
                    List {
                        ForEach(viewModel.users, id: \.clerkId) { user in
                            UserRowView(user: user)
                                .listRowBackground(Color.cardBackground)
                                .listRowSeparatorTint(Color.divider)
                        }
                        
                        // Load more indicator
                        if viewModel.hasMore && !viewModel.isLoading {
                            HStack {
                                Spacer()
                                Button("Load More") {
                                    Task {
                                        await viewModel.loadMore()
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.primaryBrand)
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
                
                // Error message
                if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            Task {
                                await viewModel.loadFollowing(for: userId)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.primaryBrand)
                    }
                    .padding()
                    .background(Color.cardBackground)
                }
            }
            .navigationTitle("Following")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                #endif
            }
            .background(Color.background)
        }
        .task {
            await viewModel.loadFollowing(for: userId)
        }
    }
}

// MARK: - Preview Data
#Preview("Followers") {
    FollowersListView(userId: "user_123", userName: "John Doe")
        .environmentObject(MockAppState())
}

#Preview("Following") {
    FollowingListView(userId: "user_123", userName: "John Doe")
        .environmentObject(MockAppState())
}