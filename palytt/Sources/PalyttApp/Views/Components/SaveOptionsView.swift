//
//  SaveOptionsView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Clerk

struct SaveOptionsView: View {
    let post: Post
    @Binding var isSaved: Bool
    let onListSelected: ((SavedList?) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var userLists: [SavedList] = []
    @State private var showCreateList = false
    @State private var newListName = ""
    @State private var selectedLists: Set<String> = []
    
    init(post: Post, isSaved: Binding<Bool>, onListSelected: ((SavedList?) -> Void)? = nil) {
        self.post = post
        self._isSaved = isSaved
        self.onListSelected = onListSelected
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Collect to")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Button(action: { showCreateList = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.green)
                            .clipShape(Circle())
                        
                        Text("New Collection")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Lists
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(userLists) { list in
                        CollectionRow(
                            list: list,
                            isSelected: selectedLists.contains(list.id),
                            onTap: {
                                if selectedLists.contains(list.id) {
                                    selectedLists.remove(list.id)
                                } else {
                                    selectedLists.insert(list.id)
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                        
                        if list.id != userLists.last?.id {
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
            
            // Confirm Button
            VStack(spacing: 0) {
                Divider()
                
                Button(action: saveToLists) {
                    Text("Confirm")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .disabled(selectedLists.isEmpty)
                .opacity(selectedLists.isEmpty ? 0.6 : 1.0)
            }
            .background(Color.background)
        }
        .background(Color.background)
        .sheet(isPresented: $showCreateList) {
            CreateSaveListView(onListCreated: { list in
                userLists.append(list)
                selectedLists.insert(list.id)
            })
        }
        .onAppear {
            loadUserLists()
        }
    }
    
    private func getCurrentUserId() -> String? {
        // For now, return a placeholder. In a real app, this would get the current user's ID
        // from your authentication system (e.g., Clerk, AppState, etc.)
        return "current-user-id"
    }
    
    private func loadUserLists() {
        Task {
            do {
                guard let currentUserId = Clerk.shared.user?.id else {
                    print("⚠️ SaveOptionsView: No current user ID available")
                    await MainActor.run {
                        userLists = [createDefaultList()]
                    }
                    return
                }
                
                let backendLists = try await BackendService.shared.getUserLists(userId: currentUserId)
                
                // Convert BackendList to SavedList model
                await MainActor.run {
                    userLists = backendLists.map { backendList in
                        SavedList(
                            id: UUID().uuidString,
                            convexId: backendList._id,
                            name: backendList.name,
                            description: backendList.description,
                            coverImageURL: nil as URL?,
                            userId: "current-user", // Will be updated with proper user ID
                            postIds: [],
                            isPrivate: backendList.isPrivate,
                            createdAt: Date(timeIntervalSince1970: Double(backendList.createdAt) / 1000),
                            updatedAt: Date(timeIntervalSince1970: Double(backendList.updatedAt) / 1000)
                        )
                    }
                    
                    // If no lists exist, create a default list
                    if userLists.isEmpty {
                        userLists = [createDefaultList()]
                        // Also create the default list on the backend
                        createDefaultListOnBackend()
                    }
                    
                    print("✅ SaveOptionsView: Loaded \(userLists.count) user lists")
                }
                
            } catch {
                print("❌ SaveOptionsView: Failed to load user lists: \(error)")
                await MainActor.run {
                    userLists = [createDefaultList()]
                }
            }
        }
    }
    
    private func createDefaultList() -> SavedList {
        return SavedList(
            name: "Saved Posts",
            description: "Your default collection of saved posts",
            userId: getCurrentUserId() ?? "unknown-user",
            isPrivate: false
        )
    }
    
    private func createDefaultListOnBackend() {
        Task {
            do {
                guard Clerk.shared.user?.id != nil else {
                    print("⚠️ SaveOptionsView: No current user ID for creating default list")
                    return
                }
                
                let response = try await BackendService.shared.createList(
                    name: "Saved Posts",
                    description: "Your default collection of saved posts",
                    isPrivate: false
                )
                
                if response.success {
                    print("✅ SaveOptionsView: Successfully created default list on backend")
                    // Reload the lists to get the backend ID
                    loadUserLists()
                } else {
                    print("❌ SaveOptionsView: Failed to create default list on backend")
                }
            } catch {
                print("❌ SaveOptionsView: Error creating default list on backend: \(error)")
            }
        }
    }
    
    private func saveToLists() {
        // Save to selected lists
        isSaved = !selectedLists.isEmpty
        
        // Notify callback with the first selected list
        if let firstListId = selectedLists.first,
           let list = userLists.first(where: { $0.id == firstListId }) {
            onListSelected?(list)
        } else {
            onListSelected?(nil)
        }
        
        // Actually save the post to the selected lists via API
        if !post.convexId.isEmpty {
            let postConvexId = post.convexId
            Task {
                for listId in selectedLists {
                    if let list = userLists.first(where: { $0.id == listId }) {
                        do {
                            let success = try await BackendService.shared.addPostToList(
                                listId: list.convexId ?? "", 
                                postId: postConvexId
                            )
                            if success {
                                print("✅ SaveOptionsView: Successfully added post to list: \(list.name)")
                            }
                        } catch {
                            print("❌ SaveOptionsView: Failed to add post to list \(list.name): \(error)")
                        }
                    }
                }
            }
        }
        
        dismiss()
    }
}

// MARK: - Collection Row
struct CollectionRow: View {
    let list: SavedList
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(list.name)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primaryText)
                        
                        if list.name.lowercased() == "saved posts" {
                            Text("Default")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("\(list.postCount) models")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                // Checkbox
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.green : Color.clear)
                    .frame(width: 24, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create List View
struct CreateSaveListView: View {
    let onListCreated: (SavedList) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var listName = ""
    @State private var listDescription = ""
    @State private var isPrivate = false
    
    private func getCurrentUserId() -> String? {
        // For now, return a placeholder. In a real app, this would get the current user's ID
        // from your authentication system (e.g., Clerk, AppState, etc.)
        return "current-user-id"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List Name", text: $listName)
                    TextField("Description (optional)", text: $listDescription)
                }
                
                Section {
                    Toggle("Private List", isOn: $isPrivate)
                } footer: {
                    Text("Private lists are only visible to you")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            .navigationTitle("Create New List")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let newList = SavedList(
                            name: listName,
                            description: listDescription.isEmpty ? nil : listDescription,
                            userId: getCurrentUserId() ?? "unknown-user",
                            isPrivate: isPrivate
                        )
                        onListCreated(newList)
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                    .disabled(listName.isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newList = SavedList(
                            name: listName,
                            description: listDescription.isEmpty ? nil : listDescription,
                            userId: getCurrentUserId() ?? "unknown-user",
                            isPrivate: isPrivate
                        )
                        onListCreated(newList)
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                    .disabled(listName.isEmpty)
                }
                #endif
            }
        }
    }
}

// MARK: - SwiftUI Previews
#Preview("Save Options - With Lists") {
    @Previewable @State var isSaved = false
    let _ = [
        SavedList(name: "Favorite Restaurants", description: "My go-to dining spots", userId: "user1", isPrivate: false),
        SavedList(name: "Coffee Shops", description: "Best coffee in the city", userId: "user1", isPrivate: false),
        SavedList(name: "Date Night", description: "Romantic dinner ideas", userId: "user1", isPrivate: true)
    ]
    
    SaveOptionsView(
        post: MockData.generatePreviewPosts()[0],
        isSaved: $isSaved
    )
    .onAppear {
        // Simulate loaded lists for preview
    }
}

#Preview("Save Options - Empty Lists") {
    @Previewable @State var isSaved = false
    
    SaveOptionsView(
        post: MockData.generatePreviewPosts()[1],
        isSaved: $isSaved
    )
}

#Preview("Create List View") {
    CreateSaveListView { list in
        print("Created list: \(list.name)")
    }
}

#Preview("List Selection Row - Selected") {
    let mockList = SavedList(
        name: "Favorite Restaurants",
        description: "My go-to dining spots",
        userId: "user1",
        isPrivate: false
    )
    
    VStack(spacing: 12) {
        CollectionRow(list: mockList, isSelected: true) { }
        CollectionRow(list: mockList, isSelected: false) { }
    }
    .padding()
} 