//
//  MentionText.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI

// MARK: - Mention Text View

/// A text view that renders mentions (@users, @places, #hashtags) as tappable links
struct MentionText: View {
    let text: String
    let mentions: [Mention]
    let font: Font
    let textColor: Color
    let lineLimit: Int?
    let onMentionTap: ((Mention) -> Void)?
    
    @EnvironmentObject var appState: AppState
    
    init(
        text: String,
        mentions: [Mention] = [],
        font: Font = .body,
        textColor: Color = .primaryText,
        lineLimit: Int? = nil,
        onMentionTap: ((Mention) -> Void)? = nil
    ) {
        self.text = text
        self.mentions = mentions
        self.font = font
        self.textColor = textColor
        self.lineLimit = lineLimit
        self.onMentionTap = onMentionTap
    }
    
    var body: some View {
        if mentions.isEmpty {
            // No mentions - render plain text with auto-detected mentions
            renderAutoDetectedText()
        } else {
            // Render with provided mentions
            renderWithMentions()
        }
    }
    
    // MARK: - Rendering
    
    @ViewBuilder
    private func renderAutoDetectedText() -> some View {
        let detectedMentions = MentionDetector.detectMentions(in: text)
        
        if detectedMentions.isEmpty {
            // No mentions detected - plain text
            Text(text)
                .font(font)
                .foregroundColor(textColor)
                .lineLimit(lineLimit)
        } else {
            // Build attributed text with detected mentions
            buildTappableText(detectedMentions: detectedMentions)
        }
    }
    
    @ViewBuilder
    private func renderWithMentions() -> some View {
        buildTappableText(mentions: mentions)
    }
    
    @ViewBuilder
    private func buildTappableText(detectedMentions: [DetectedMention]) -> some View {
        let attributedText = buildAttributedString(detectedMentions: detectedMentions)
        
        Text(attributedText)
            .font(font)
            .lineLimit(lineLimit)
            .environment(\.openURL, OpenURLAction { url in
                _ = handleURL(url)
                return .handled
            })
    }
    
    @ViewBuilder
    private func buildTappableText(mentions: [Mention]) -> some View {
        let attributedText = buildAttributedString(mentions: mentions)
        
        Text(attributedText)
            .font(font)
            .lineLimit(lineLimit)
            .environment(\.openURL, OpenURLAction { url in
                _ = handleURL(url)
                return .handled
            })
    }
    
    // MARK: - Attributed String Building
    
    private func buildAttributedString(detectedMentions: [DetectedMention]) -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = textColor
        
        // Sort mentions by position (reverse order to not affect indices)
        let sortedMentions = detectedMentions.sorted { $0.range.start > $1.range.start }
        
        for detected in sortedMentions {
            guard let startIndex = result.index(result.startIndex, offsetByCharacters: detected.range.start),
                  let endIndex = result.index(result.startIndex, offsetByCharacters: detected.range.end) else {
                continue
            }
            
            let range = startIndex..<endIndex
            let mentionType: MentionType = detected.isHashtag ? .hashtag : .user
            
            // Style the mention
            result[range].foregroundColor = mentionType.color
            result[range].underlineStyle = .single
            
            // Add link for tapping
            if let url = URL(string: "\(mentionType.deepLinkScheme)\(detected.text)") {
                result[range].link = url
            }
        }
        
        return result
    }
    
    private func buildAttributedString(mentions: [Mention]) -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = textColor
        
        // Sort mentions by position (reverse order to not affect indices)
        let sortedMentions = mentions.sorted { $0.range.start > $1.range.start }
        
        for mention in sortedMentions {
            guard mention.range.start >= 0,
                  mention.range.end <= text.count,
                  let startIndex = result.index(result.startIndex, offsetByCharacters: mention.range.start),
                  let endIndex = result.index(result.startIndex, offsetByCharacters: mention.range.end) else {
                continue
            }
            
            let range = startIndex..<endIndex
            
            // Style the mention
            result[range].foregroundColor = mention.type.color
            result[range].underlineStyle = .single
            
            // Add link for tapping
            if let url = mention.deepLinkURL {
                result[range].link = url
            }
        }
        
        return result
    }
    
    // MARK: - URL Handling
    
    private func handleURL(_ url: URL) -> OpenURLAction.Result {
        // Parse the deep link
        if let destination = DeepLinkRouter.shared.parseURL(url) {
            // Find the corresponding mention if we have one
            if let mention = findMention(for: url) {
                onMentionTap?(mention)
            }
            
            // Navigate using the deep link router
            DeepLinkRouter.shared.navigate(to: destination, appState: appState)
            
            // Haptic feedback
            HapticManager.shared.impact(.light)
            
            return .handled
        }
        
        return .systemAction
    }
    
    private func findMention(for url: URL) -> Mention? {
        guard let urlString = url.absoluteString.removingPercentEncoding else { return nil }
        
        return mentions.first { mention in
            mention.deepLinkURL?.absoluteString == urlString
        }
    }
}

// MARK: - AttributedString Index Extension

extension AttributedString {
    func index(_ index: AttributedString.Index, offsetByCharacters offset: Int) -> AttributedString.Index? {
        var currentIndex = index
        var remainingOffset = offset
        
        while remainingOffset > 0 {
            guard currentIndex < self.endIndex else { return nil }
            currentIndex = self.index(afterCharacter: currentIndex)
            remainingOffset -= 1
        }
        
        return currentIndex
    }
}

// MARK: - Caption Text View

/// A convenience view for rendering post captions with mentions
struct CaptionText: View {
    let caption: String
    let mentions: [Mention]
    let lineLimit: Int?
    let onMentionTap: ((Mention) -> Void)?
    
    init(
        caption: String,
        mentions: [Mention] = [],
        lineLimit: Int? = nil,
        onMentionTap: ((Mention) -> Void)? = nil
    ) {
        self.caption = caption
        self.mentions = mentions
        self.lineLimit = lineLimit
        self.onMentionTap = onMentionTap
    }
    
    var body: some View {
        MentionText(
            text: caption,
            mentions: mentions,
            font: .body,
            textColor: .primaryText,
            lineLimit: lineLimit,
            onMentionTap: onMentionTap
        )
    }
}

// MARK: - Comment Text View

/// A convenience view for rendering comments with mentions
struct CommentText: View {
    let authorUsername: String
    let content: String
    let mentions: [Mention]
    let onAuthorTap: (() -> Void)?
    let onMentionTap: ((Mention) -> Void)?
    
    init(
        authorUsername: String,
        content: String,
        mentions: [Mention] = [],
        onAuthorTap: (() -> Void)? = nil,
        onMentionTap: ((Mention) -> Void)? = nil
    ) {
        self.authorUsername = authorUsername
        self.content = content
        self.mentions = mentions
        self.onAuthorTap = onAuthorTap
        self.onMentionTap = onMentionTap
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Author username (tappable)
            Button(action: { onAuthorTap?() }) {
                Text(authorUsername)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Comment content with mentions
            MentionText(
                text: content,
                mentions: mentions,
                font: .subheadline,
                textColor: .primaryText,
                onMentionTap: onMentionTap
            )
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        // Plain text
        MentionText(
            text: "This is plain text without any mentions.",
            font: .body,
            textColor: .primaryText
        )
        
        // Auto-detected mentions
        MentionText(
            text: "Hey @john check out this place! #foodie #yummy",
            font: .body,
            textColor: .primaryText
        )
        
        // With explicit mentions
        MentionText(
            text: "Loved this spot with @sarah! #brunch",
            mentions: [
                Mention.user(
                    username: "sarah",
                    userId: "user123",
                    range: MentionRange(start: 21, end: 27)
                ),
                Mention.hashtag(
                    tag: "brunch",
                    range: MentionRange(start: 29, end: 36)
                )
            ],
            font: .body,
            textColor: .primaryText
        )
        
        // Caption style
        CaptionText(
            caption: "Amazing food at @thecafe! Highly recommend the avocado toast. #breakfast #healthy",
            lineLimit: 2
        )
        
        // Comment style
        CommentText(
            authorUsername: "foodlover",
            content: "This looks so good! @chef you need to try this place"
        )
    }
    .padding()
    .background(Color.background)
    .environmentObject(AppState())
}

