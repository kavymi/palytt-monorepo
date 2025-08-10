//
//  UserAvatar.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Kingfisher

// MARK: - User Avatar Component
struct UserAvatar: View {
    let user: User
    let size: CGFloat
    let showBorder: Bool
    let borderColor: Color
    let borderWidth: CGFloat
    
    init(
        user: User,
        size: CGFloat = 40,
        showBorder: Bool = false,
        borderColor: Color = .primaryBrand,
        borderWidth: CGFloat = 2
    ) {
        self.user = user
        self.size = size
        self.showBorder = showBorder
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
    
    var body: some View {
        Group {
            if let avatarURL = user.avatarURL {
                KFImage(avatarURL)
                    .placeholder {
                        UserInitialsView(
                            user: user,
                            size: size
                        )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                UserInitialsView(
                    user: user,
                    size: size
                )
            }
        }
        .overlay(
            showBorder ? Circle()
                .stroke(borderColor, lineWidth: borderWidth)
                .frame(width: size, height: size) : nil
        )
    }
}

// MARK: - User Initials View
struct UserInitialsView: View {
    let user: User
    let size: CGFloat
    
    private var initials: String {
        let name = user.displayName.isEmpty ? user.username : user.displayName
        let components = name.components(separatedBy: .whitespaces)
        
        if components.count >= 2 {
            // First letter of first name + first letter of last name
            let firstInitial = String(components[0].prefix(1))
            let lastInitial = String(components[1].prefix(1))
            return (firstInitial + lastInitial).uppercased()
        } else {
            // First two letters of the single name
            return String(name.prefix(2)).uppercased()
        }
    }
    
    private var fontSize: Font {
        switch size {
        case 0..<30:
            return .caption2
        case 30..<40:
            return .caption
        case 40..<60:
            return .subheadline
        case 60..<80:
            return .headline
        case 80..<100:
            return .title2
        case 100..<120:
            return .title
        default:
            return .largeTitle
        }
    }
    
    private var backgroundGradient: LinearGradient {
        // Create a consistent color based on user ID for personality
        let colors = [
            [Color.primaryBrand, Color.matchaGreen],
            [Color.blue, Color.purple],
            [Color.orange, Color.red],
            [Color.green, Color.teal],
            [Color.purple, Color.pink],
            [Color.indigo, Color.blue],
            [Color.mint, Color.green],
            [Color.yellow, Color.orange]
        ]
        
        let hashValue = abs(user.id.hashValue)
        let colorIndex = hashValue % colors.count
        
        return LinearGradient(
            colors: colors[colorIndex],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundGradient)
                .frame(width: size, height: size)
            
            Text(initials)
                .font(fontSize)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Backend User Avatar (for BackendUser type)
struct BackendUserAvatar: View {
    let user: BackendUser
    let size: CGFloat
    let showBorder: Bool
    let borderColor: Color
    let borderWidth: CGFloat
    
    init(
        user: BackendUser,
        size: CGFloat = 40,
        showBorder: Bool = false,
        borderColor: Color = .primaryBrand,
        borderWidth: CGFloat = 2
    ) {
        self.user = user
        self.size = size
        self.showBorder = showBorder
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
    
    private var initials: String {
        let name = user.displayName ?? user.username ?? "U"
        let components = name.components(separatedBy: .whitespaces)
        
        if components.count >= 2 {
            let firstInitial = String(components[0].prefix(1))
            let lastInitial = String(components[1].prefix(1))
            return (firstInitial + lastInitial).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    private var fontSize: Font {
        switch size {
        case 0..<30:
            return .caption2
        case 30..<40:
            return .caption
        case 40..<60:
            return .subheadline
        case 60..<80:
            return .headline
        case 80..<100:
            return .title2
        case 100..<120:
            return .title
        default:
            return .largeTitle
        }
    }
    
    private var backgroundGradient: LinearGradient {
        // Create a consistent color based on clerkId for personality
        let colors = [
            [Color.primaryBrand, Color.matchaGreen],
            [Color.blue, Color.purple],
            [Color.orange, Color.red],
            [Color.green, Color.teal],
            [Color.purple, Color.pink],
            [Color.indigo, Color.blue],
            [Color.mint, Color.green],
            [Color.yellow, Color.orange]
        ]
        
        let hashValue = abs(user.clerkId.hashValue)
        let colorIndex = hashValue % colors.count
        
        return LinearGradient(
            colors: colors[colorIndex],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        Group {
            if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                KFImage(url)
                    .placeholder {
                        initialsView
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                initialsView
            }
        }
        .overlay(
            showBorder ? Circle()
                .stroke(borderColor, lineWidth: borderWidth)
                .frame(width: size, height: size) : nil
        )
    }
    
    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(backgroundGradient)
                .frame(width: size, height: size)
            
            Text(initials)
                .font(fontSize)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Convenience Extensions
extension UserAvatar {
    // Predefined sizes for common use cases
    static func small(user: User) -> UserAvatar {
        UserAvatar(user: user, size: 24)
    }
    
    static func medium(user: User) -> UserAvatar {
        UserAvatar(user: user, size: 40)
    }
    
    static func large(user: User) -> UserAvatar {
        UserAvatar(user: user, size: 80)
    }
    
    static func extraLarge(user: User) -> UserAvatar {
        UserAvatar(user: user, size: 120)
    }
}

extension BackendUserAvatar {
    static func small(user: BackendUser) -> BackendUserAvatar {
        BackendUserAvatar(user: user, size: 24)
    }
    
    static func medium(user: BackendUser) -> BackendUserAvatar {
        BackendUserAvatar(user: user, size: 40)
    }
    
    static func large(user: BackendUser) -> BackendUserAvatar {
        BackendUserAvatar(user: user, size: 80)
    }
    
    static func extraLarge(user: BackendUser) -> BackendUserAvatar {
        BackendUserAvatar(user: user, size: 120)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            UserAvatar.small(user: MockData.currentUser)
            UserAvatar.medium(user: MockData.currentUser)
            UserAvatar.large(user: MockData.currentUser)
        }
        
        HStack(spacing: 16) {
            UserAvatar(user: MockData.currentUser, size: 40, showBorder: true)
            UserAvatar(user: MockData.previewUser, size: 60, showBorder: true, borderColor: .orange)
            UserAvatar(user: MockData.adminUser, size: 80, showBorder: true, borderColor: .red)
        }
        
        // Test with user without avatar URL
        UserAvatar(
            user: User(
                email: "test@example.com",
                username: "testuser",
                displayName: "Test User"
            ),
            size: 60
        )
    }
    .padding()
} 