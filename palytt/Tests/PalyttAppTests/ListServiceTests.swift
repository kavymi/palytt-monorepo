//
//  ListServiceTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import PalyttApp

@MainActor
final class ListServiceTests: XCTestCase {
    
    var sut: ListService!
    var mockAPIClient: MockAPIClient!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = ListService(apiClient: mockAPIClient)
    }
    
    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        super.tearDown()
    }
    
    // MARK: - Create List Tests
    
    func testCreateList_Success() async throws {
        // Given
        let mockList = createMockListDTO(name: "My Favorites")
        let response = CreateListResponse(success: true, list: mockList)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let list = try await sut.createList(name: "My Favorites", description: "Best places", isPrivate: false)
        
        // Then
        XCTAssertEqual(list.name, "My Favorites")
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/lists.create")
    }
    
    // MARK: - Get User Lists Tests
    
    func testGetUserLists_Success() async throws {
        // Given
        let mockLists = [createMockListDTO(name: "List 1"), createMockListDTO(name: "List 2")]
        let response = GetUserListsResponse(lists: mockLists, total: 2)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let lists = try await sut.getUserLists(userId: "user123")
        
        // Then
        XCTAssertEqual(lists.count, 2)
    }
    
    // MARK: - Update List Tests
    
    func testUpdateList_Success() async throws {
        // Given
        let mockList = createMockListDTO(name: "Updated List")
        let response = UpdateListResponse(success: true, list: mockList)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let list = try await sut.updateList(listId: "list123", name: "Updated List", description: nil, isPrivate: nil)
        
        // Then
        XCTAssertEqual(list.name, "Updated List")
    }
    
    // MARK: - Delete List Tests
    
    func testDeleteList_Success() async throws {
        // Given
        let response = DeleteListResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.deleteList(listId: "list123")
        
        // Then
        XCTAssertTrue(success)
    }
    
    // MARK: - Add/Remove Post Tests
    
    func testAddPostToList_Success() async throws {
        // Given
        let response = AddPostToListResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.addPostToList(listId: "list123", postId: "post456")
        
        // Then
        XCTAssertTrue(success)
    }
    
    func testRemovePostFromList_Success() async throws {
        // Given
        let response = RemovePostFromListResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.removePostFromList(listId: "list123", postId: "post456")
        
        // Then
        XCTAssertTrue(success)
    }
    
    // MARK: - Helper Methods
    
    private func createMockListDTO(name: String) -> ListDTO {
        return ListDTO(
            id: UUID().uuidString,
            userId: "user123",
            name: name,
            description: "Test description",
            isPrivate: false,
            postsCount: 0,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            posts: nil
        )
    }
}

