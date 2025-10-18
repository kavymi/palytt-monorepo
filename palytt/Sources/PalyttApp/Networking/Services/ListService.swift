//
//  ListService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Protocol

protocol ListServiceProtocol {
    func createList(name: String, description: String?, isPrivate: Bool) async throws -> PostList
    func getUserLists(userId: String) async throws -> [PostList]
    func updateList(listId: String, name: String?, description: String?, isPrivate: Bool?) async throws -> PostList
    func deleteList(listId: String) async throws -> Bool
    func addPostToList(listId: String, postId: String) async throws -> Bool
    func removePostFromList(listId: String, postId: String) async throws -> Bool
}

// MARK: - Service Implementation

@MainActor
final class ListService: ListServiceProtocol {
    
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    convenience init(baseURL: URL) {
        let apiClient = APIClient(baseURL: baseURL)
        self.init(apiClient: apiClient)
    }
    
    // MARK: - Create List
    
    func createList(name: String, description: String?, isPrivate: Bool = false) async throws -> PostList {
        print("📋 ListService: Creating list '\(name)'")
        
        let request = CreateListRequest(
            name: name,
            description: description,
            isPrivate: isPrivate
        )
        
        let response = try await apiClient.request(
            path: "trpc/lists.create",
            method: .post,
            parameters: request,
            responseType: CreateListResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to create list")
        }
        
        print("✅ ListService: Successfully created list")
        return PostList.from(listDTO: response.list)
    }
    
    // MARK: - Get User Lists
    
    func getUserLists(userId: String) async throws -> [PostList] {
        print("📋 ListService: Getting lists for user \(userId)")
        
        let request = GetUserListsRequest(userId: userId)
        
        let response = try await apiClient.request(
            path: "trpc/lists.getUserLists",
            method: .get,
            parameters: request,
            responseType: GetUserListsResponse.self
        )
        
        print("✅ ListService: Retrieved \(response.lists.count) lists")
        return response.lists.map { PostList.from(listDTO: $0) }
    }
    
    // MARK: - Update List
    
    func updateList(listId: String, name: String?, description: String?, isPrivate: Bool?) async throws -> PostList {
        print("✏️ ListService: Updating list \(listId)")
        
        let request = UpdateListRequest(
            listId: listId,
            name: name,
            description: description,
            isPrivate: isPrivate
        )
        
        let response = try await apiClient.request(
            path: "trpc/lists.update",
            method: .post,
            parameters: request,
            responseType: UpdateListResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to update list")
        }
        
        print("✅ ListService: Successfully updated list")
        return PostList.from(listDTO: response.list)
    }
    
    // MARK: - Delete List
    
    func deleteList(listId: String) async throws -> Bool {
        print("🗑️ ListService: Deleting list \(listId)")
        
        let request = DeleteListRequest(listId: listId)
        
        let response = try await apiClient.request(
            path: "trpc/lists.delete",
            method: .post,
            parameters: request,
            responseType: DeleteListResponse.self
        )
        
        print("✅ ListService: Successfully deleted list")
        return response.success
    }
    
    // MARK: - Add Post to List
    
    func addPostToList(listId: String, postId: String) async throws -> Bool {
        print("➕ ListService: Adding post \(postId) to list \(listId)")
        
        let request = AddPostToListRequest(listId: listId, postId: postId)
        
        let response = try await apiClient.request(
            path: "trpc/lists.addPost",
            method: .post,
            parameters: request,
            responseType: AddPostToListResponse.self
        )
        
        print("✅ ListService: Successfully added post to list")
        return response.success
    }
    
    // MARK: - Remove Post from List
    
    func removePostFromList(listId: String, postId: String) async throws -> Bool {
        print("➖ ListService: Removing post \(postId) from list \(listId)")
        
        let request = RemovePostFromListRequest(listId: listId, postId: postId)
        
        let response = try await apiClient.request(
            path: "trpc/lists.removePost",
            method: .post,
            parameters: request,
            responseType: RemovePostFromListResponse.self
        )
        
        print("✅ ListService: Successfully removed post from list")
        return response.success
    }
}

// MARK: - Mock Implementation for Testing

#if DEBUG
final class MockListService: ListServiceProtocol {
    var mockLists: [PostList] = []
    var mockList: PostList?
    var shouldFail = false
    var mockError: APIError = .networkError(URLError(.notConnectedToInternet))
    var mockSuccess = true
    
    func createList(name: String, description: String?, isPrivate: Bool) async throws -> PostList {
        if shouldFail { throw mockError }
        return mockList ?? createMockList()
    }
    
    func getUserLists(userId: String) async throws -> [PostList] {
        if shouldFail { throw mockError }
        return mockLists
    }
    
    func updateList(listId: String, name: String?, description: String?, isPrivate: Bool?) async throws -> PostList {
        if shouldFail { throw mockError }
        return mockList ?? createMockList()
    }
    
    func deleteList(listId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockSuccess
    }
    
    func addPostToList(listId: String, postId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockSuccess
    }
    
    func removePostFromList(listId: String, postId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockSuccess
    }
    
    private func createMockList() -> PostList {
        return PostList(
            id: UUID(),
            convexId: nil,
            userId: UUID(),
            name: "Mock List",
            description: "A mock list for testing",
            isPrivate: false,
            postsCount: 0,
            posts: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
#endif

