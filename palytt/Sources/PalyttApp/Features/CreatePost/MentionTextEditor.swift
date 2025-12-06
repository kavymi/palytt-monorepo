//
//  MentionTextEditor.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Mention Text Editor

/// A text editor that supports @mentions and #hashtags with autocomplete
struct MentionTextEditor: View {
    @Binding var text: String
    @Binding var mentions: [Mention]
    let placeholder: String
    let minHeight: CGFloat
    
    @StateObject private var viewModel = MentionTextEditorViewModel()
    @FocusState private var isFocused: Bool
    
    init(
        text: Binding<String>,
        mentions: Binding<[Mention]>,
        placeholder: String = "Share your thoughts...",
        minHeight: CGFloat = 120
    ) {
        self._text = text
        self._mentions = mentions
        self.placeholder = placeholder
        self.minHeight = minHeight
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Autocomplete suggestions
            if viewModel.showSuggestions && !viewModel.suggestions.isEmpty {
                MentionAutocompleteView(
                    suggestions: viewModel.suggestions,
                    isLoading: viewModel.isSearching,
                    onSelect: { suggestion in
                        insertMention(suggestion)
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Text editor with attributed text display
            ZStack(alignment: .topLeading) {
                // Placeholder
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.tertiaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
                
                // Text editor
                TextEditor(text: $text)
                    .focused($isFocused)
                    .frame(minHeight: minHeight)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .onChange(of: text) { oldValue, newValue in
                        handleTextChange(oldValue: oldValue, newValue: newValue)
                    }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showSuggestions)
    }
    
    // MARK: - Private Methods
    
    private func handleTextChange(oldValue: String, newValue: String) {
        // Detect mention context
        let cursorPosition = newValue.count // Simplified - assumes cursor at end
        
        if let context = MentionDetector.getCurrentMentionContext(text: newValue, cursorPosition: cursorPosition) {
            viewModel.currentContext = context
            
            if context.isSearchable {
                viewModel.showSuggestions = true
                Task {
                    await viewModel.searchSuggestions(context: context)
                }
            } else {
                viewModel.showSuggestions = false
            }
        } else {
            viewModel.showSuggestions = false
            viewModel.currentContext = nil
        }
        
        // Update mentions array based on text changes
        updateMentionsForTextChange(oldValue: oldValue, newValue: newValue)
    }
    
    private func insertMention(_ suggestion: MentionSuggestion) {
        guard let context = viewModel.currentContext else { return }
        
        // Calculate the range to replace (from trigger to current position)
        let triggerPosition = context.triggerPosition
        let currentPosition = text.count
        
        // Create the mention text
        let mentionText = suggestion.type.prefix + suggestion.displayText
        
        // Replace the partial mention with the full mention
        let startIndex = text.index(text.startIndex, offsetBy: triggerPosition)
        let endIndex = text.index(text.startIndex, offsetBy: min(currentPosition, text.count))
        
        text.replaceSubrange(startIndex..<endIndex, with: mentionText + " ")
        
        // Create and add the mention
        let newMention = Mention(
            type: suggestion.type,
            text: suggestion.displayText,
            targetId: suggestion.targetId,
            range: MentionRange(
                start: triggerPosition,
                end: triggerPosition + mentionText.count
            )
        )
        
        mentions.append(newMention)
        
        // Hide suggestions
        viewModel.showSuggestions = false
        viewModel.currentContext = nil
        viewModel.suggestions = []
        
        // Haptic feedback
        HapticManager.shared.impact(.light)
    }
    
    private func updateMentionsForTextChange(oldValue: String, newValue: String) {
        // If text was deleted, check if any mentions were affected
        if newValue.count < oldValue.count {
            // Remove mentions that were deleted or partially deleted
            mentions.removeAll { mention in
                let mentionEnd = mention.range.end
                let mentionStart = mention.range.start
                
                // Check if the mention was affected by deletion
                return mentionEnd > newValue.count || mentionStart >= newValue.count
            }
            
            // Adjust ranges of remaining mentions if needed
            // (This is a simplified version - a full implementation would track exact cursor position)
        }
    }
}

// MARK: - View Model

@MainActor
class MentionTextEditorViewModel: ObservableObject {
    @Published var suggestions: [MentionSuggestion] = []
    @Published var showSuggestions = false
    @Published var isSearching = false
    @Published var currentContext: MentionContext?
    
    private let backendService = BackendService.shared
    private var searchTask: Task<Void, Never>?
    
    func searchSuggestions(context: MentionContext) async {
        // Cancel previous search
        searchTask?.cancel()
        
        searchTask = Task {
            isSearching = true
            
            // Debounce
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            
            guard !Task.isCancelled else { return }
            
            if context.isHashtag {
                // Search hashtags (could be from trending or recent)
                await searchHashtags(query: context.query)
            } else {
                // Search users and places
                await searchUsersAndPlaces(query: context.query)
            }
            
            isSearching = false
        }
    }
    
    private func searchUsersAndPlaces(query: String) async {
        var newSuggestions: [MentionSuggestion] = []
        
        // Search users
        do {
            let users = try await backendService.searchUsers(query: query, limit: 5)
            let userSuggestions = users.map { user in
                MentionSuggestion(
                    id: user.clerkId,
                    type: .user,
                    displayText: user.username ?? "user",
                    subtitle: user.displayName,
                    avatarURL: user.avatarUrl != nil ? URL(string: user.avatarUrl!) : nil,
                    targetId: user.clerkId
                )
            }
            newSuggestions.append(contentsOf: userSuggestions)
        } catch {
            print("❌ MentionTextEditor: Failed to search users: \(error)")
        }
        
        // Search places (using existing place search)
        do {
            let places = try await backendService.searchPlaces(query: query, latitude: nil, longitude: nil, limit: 3)
            let placeSuggestions = places.map { place in
                MentionSuggestion(
                    id: place.placeId ?? UUID().uuidString,
                    type: .place,
                    displayText: place.name,
                    subtitle: place.address,
                    avatarURL: nil,
                    targetId: place.placeId ?? UUID().uuidString
                )
            }
            newSuggestions.append(contentsOf: placeSuggestions)
        } catch {
            print("❌ MentionTextEditor: Failed to search places: \(error)")
        }
        
        suggestions = newSuggestions
    }
    
    private func searchHashtags(query: String) async {
        // For hashtags, we can suggest trending or recent hashtags
        // For now, just create suggestions based on the query
        let commonFoodHashtags = [
            "foodie", "foodporn", "yummy", "delicious", "tasty",
            "breakfast", "lunch", "dinner", "brunch", "snack",
            "coffee", "tea", "dessert", "healthy", "vegan",
            "glutenfree", "organic", "homemade", "restaurant", "cafe"
        ]
        
        let matchingHashtags = commonFoodHashtags.filter { 
            $0.lowercased().hasPrefix(query.lowercased()) 
        }
        
        suggestions = matchingHashtags.prefix(5).map { tag in
            MentionSuggestion.hashtag(tag: tag)
        }
    }
}

// MARK: - Mention Autocomplete View

struct MentionAutocompleteView: View {
    let suggestions: [MentionSuggestion]
    let isLoading: Bool
    let onSelect: (MentionSuggestion) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading && suggestions.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions) { suggestion in
                            MentionSuggestionChip(
                                suggestion: suggestion,
                                onTap: {
                                    onSelect(suggestion)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(12, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
    }
}

// MARK: - Mention Suggestion Chip

struct MentionSuggestionChip: View {
    let suggestion: MentionSuggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Avatar or icon
                if let avatarURL = suggestion.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(suggestion.type.color.opacity(0.2))
                            .overlay(
                                Image(systemName: suggestion.type.icon)
                                    .font(.caption)
                                    .foregroundColor(suggestion.type.color)
                            )
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(suggestion.type.color.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: suggestion.type.icon)
                                .font(.caption)
                                .foregroundColor(suggestion.type.color)
                        )
                }
                
                // Text
                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.type.prefix + suggestion.displayText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                    
                    if let subtitle = suggestion.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(suggestion.type.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""
        @State private var mentions: [Mention] = []
        
        var body: some View {
            VStack {
                MentionTextEditor(
                    text: $text,
                    mentions: $mentions,
                    placeholder: "What's on your mind? Tag @friends or #topics"
                )
                .padding()
                
                Text("Mentions: \(mentions.count)")
                    .foregroundColor(.secondaryText)
                
                ForEach(mentions) { mention in
                    Text(mention.displayText)
                        .foregroundColor(mention.type.color)
                }
            }
            .background(Color.background)
        }
    }
    
    return PreviewWrapper()
}

