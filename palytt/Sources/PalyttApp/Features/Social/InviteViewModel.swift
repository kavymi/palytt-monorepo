//
//  InviteViewModel.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Foundation
import MessageUI
import ContactsUI
import UIKit

// MARK: - Invite Option

enum InviteOption: String, CaseIterable {
    case general = "general"
    case messages = "messages"
    case email = "email"
    case contacts = "contacts"
    case foodie = "foodie"
    
    var title: String {
        switch self {
        case .general:
            return "General"
        case .messages:
            return "Messages"
        case .email:
            return "Email"
        case .contacts:
            return "Contacts"
        case .foodie:
            return "Foodie"
        }
    }
    
    var description: String {
        switch self {
        case .general:
            return "Share via any app"
        case .messages:
            return "Send via text message"
        case .email:
            return "Send via email"
        case .contacts:
            return "Invite from contacts"
        case .foodie:
            return "For food enthusiasts"
        }
    }
    
    var icon: String {
        switch self {
        case .general:
            return "square.and.arrow.up"
        case .messages:
            return "message.fill"
        case .email:
            return "mail.fill"
        case .contacts:
            return "person.2.fill"
        case .foodie:
            return "fork.knife"
        }
    }
    
    var isNativeMethod: Bool {
        switch self {
        case .messages, .email, .contacts:
            return true
        case .general, .foodie:
            return false
        }
    }
}

// MARK: - Invite Stats

struct InviteStats {
    let totalInvites: Int
    let friendsJoined: Int
    let conversionRate: Double
    
    static let empty = InviteStats(totalInvites: 0, friendsJoined: 0, conversionRate: 0.0)
}

// MARK: - Backend Response Models

struct InviteStatsResponse: Codable {
    let totalInvites: Int
    let friendsJoined: Int
    let conversionRate: Double
}

struct TrackInvitationResponse: Codable {
    let success: Bool
    let invitationId: String?
}

// MARK: - Invite Content

struct InviteContent {
    let title: String
    let message: String
    let url: String
    let image: UIImage?
    
    var shareItems: [Any] {
        var items: [Any] = [message, URL(string: url)].compactMap { $0 }
        if let image = image {
            items.append(image)
        }
        return items
    }
}

// MARK: - Invite View Model

@MainActor
class InviteViewModel: ObservableObject {
    @Published var inviteStats = InviteStats.empty
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCopyConfirmation = false
    @Published var showNativeMessagesComposer = false
    @Published var showNativeEmailComposer = false
    @Published var showContactsPicker = false
    @Published var selectedContacts: [CNContact] = []
    
    private let backendService = BackendService.shared
    
    // Native UI delegates
    var messageComposeDelegate: MessageComposeDelegate?
    var mailComposeDelegate: MailComposeDelegate?
    var contactPickerDelegate: ContactPickerDelegate?
    
    init() {
        setupDelegates()
    }
    
    private func setupDelegates() {
        messageComposeDelegate = MessageComposeDelegate { [weak self] result in
            self?.handleMessageComposeResult(result)
        }
        
        mailComposeDelegate = MailComposeDelegate { [weak self] result in
            self?.handleMailComposeResult(result)
        }
        
        contactPickerDelegate = ContactPickerDelegate { [weak self] contacts in
            self?.handleSelectedContacts(contacts)
        }
    }
    
    // MARK: - App Information
    
    private var appStoreURL: String {
        // Replace with actual App Store URL when available
        "https://apps.apple.com/app/palytt/id123456789"
    }
    
    private var deepLinkURL: String {
        "palytt://invite"
    }
    
    private var referralCode: String {
        // Generate referral code based on current user
        if let userId = AppState.shared.currentUser?.clerkId {
            return String(userId.prefix(8).uppercased())
        }
        return "PALYTT"
    }
    
    // MARK: - Public Methods
    
    func loadInviteStats() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let userId = AppState.shared.currentUser?.clerkId else {
                inviteStats = InviteStats.empty
                isLoading = false
                return
            }
            
            let response = try await backendService.performTRPCQuery<InviteStatsResponse>(
                procedure: "invitations.getInviteStats",
                input: ["userId": userId]
            )
            
            inviteStats = InviteStats(
                totalInvites: response.totalInvites,
                friendsJoined: response.friendsJoined,
                conversionRate: response.conversionRate
            )
        } catch {
            print("❌ Failed to load invite stats: \(error)")
            errorMessage = "Failed to load invite stats: \(error.localizedDescription)"
            // Use mock data as fallback
            inviteStats = InviteStats(
                totalInvites: 0,
                friendsJoined: 0,
                conversionRate: 0.0
            )
        }
        
        isLoading = false
    }
    
    func getShareContent(for option: InviteOption) -> [Any] {
        let content = generateInviteContent(for: option)
        return content.shareItems
    }
    
    func copyInviteLink(for option: InviteOption) {
        let content = generateInviteContent(for: option)
        
        UIPasteboard.general.string = content.url
        
        // Show confirmation
        showCopyConfirmation = true
        HapticManager.shared.impact(.success)
        
        // Hide confirmation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showCopyConfirmation = false
        }
        
        // Track the invite action
        Task {
            await trackInviteAction(type: "copy_link", option: option)
        }
    }
    
    // MARK: - Native iOS Integration
    
    func triggerNativeInvite(for option: InviteOption) {
        switch option {
        case .messages:
            if MFMessageComposeViewController.canSendText() {
                showNativeMessagesComposer = true
            } else {
                errorMessage = "Messages not available on this device"
            }
        case .email:
            if MFMailComposeViewController.canSendMail() {
                showNativeEmailComposer = true
            } else {
                errorMessage = "Email not configured on this device"
            }
        case .contacts:
            showContactsPicker = true
        case .general, .foodie:
            // Use standard share sheet
            break
        }
        
        // Track the invite action
        Task {
            await trackInviteAction(type: "native_invite", option: option)
        }
    }
    
    func isNativeMethodAvailable(for option: InviteOption) -> Bool {
        switch option {
        case .messages:
            return MFMessageComposeViewController.canSendText()
        case .email:
            return MFMailComposeViewController.canSendMail()
        case .contacts:
            return true // Contacts are always available
        case .general, .foodie:
            return true
        }
    }
    
    func getMessageContent(for option: InviteOption) -> (subject: String?, body: String) {
        let content = generateInviteContent(for: option)
        
        switch option {
        case .messages:
            return (subject: nil, body: content.message)
        case .email:
            return (subject: content.title, body: content.message)
        default:
            return (subject: content.title, body: content.message)
        }
    }
    
    func sendInviteToContacts(_ contacts: [CNContact], option: InviteOption) async {
        for contact in contacts {
            // Extract phone numbers and emails
            let phoneNumbers = contact.phoneNumbers.compactMap { $0.value.stringValue }
            let emailAddresses = contact.emailAddresses.compactMap { $0.value as String }
            
            // Track invitation for each contact method
            for phoneNumber in phoneNumbers {
                await trackInviteAction(type: "contact_sms", option: option, recipient: phoneNumber)
            }
            
            for email in emailAddresses {
                await trackInviteAction(type: "contact_email", option: option, recipient: email)
            }
        }
        
        // Show success message
        showCopyConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showCopyConfirmation = false
        }
    }
    
    // MARK: - Private Methods
    
    private func generateInviteContent(for option: InviteOption) -> InviteContent {
        let currentUser = AppState.shared.currentUser
        let userName = currentUser?.displayName ?? currentUser?.username ?? "Your friend"
        
        let baseMessage: String
        let title: String
        
        switch option {
        case .general:
            title = "Join me on Palytt!"
            baseMessage = """
            Hey! I've been using Palytt to discover amazing food spots and share my food adventures. 
            
            Join me and let's explore the best food experiences together! 🍴✨
            
            Use my referral code: \(referralCode)
            """
            
        case .messages:
            title = "Palytt Invite"
            baseMessage = """
            Hey! Check out Palytt - I've been discovering amazing food spots with it! 🍕🍜
            
            Download it and use code \(referralCode) when you sign up!
            """
            
        case .email:
            title = "You're invited to join Palytt!"
            baseMessage = """
            Hi there!
            
            I wanted to share something cool with you - I've been using Palytt to discover incredible food experiences and connect with fellow food lovers!
            
            Palytt helps you:
            • Discover hidden gem restaurants and cafes
            • Share your food adventures with photos and reviews
            • Connect with friends who love good food
            • Get personalized recommendations based on your taste
            
            I think you'd really enjoy it! Use my referral code \(referralCode) when you sign up.
            
            Hope to see you there!
            \(userName)
            """
            
        case .foodie:
            title = "Join the Palytt Food Community!"
            baseMessage = """
            🍽️ Calling all food lovers! 🍽️
            
            I've found the perfect app for us foodies - Palytt! It's where I discover amazing restaurants, share my food adventures, and connect with people who appreciate great food as much as we do.
            
            Join me on this delicious journey! Use referral code: \(referralCode)
            
            Let's explore the culinary world together! 👨‍🍳👩‍🍳
            """
        }
        
        let fullMessage = "\(baseMessage)\n\n\(appStoreURL)"
        
        return InviteContent(
            title: title,
            message: fullMessage,
            url: "\(appStoreURL)?ref=\(referralCode)",
            image: generateShareImage(for: option)
        )
    }
    
    private func generateShareImage(for option: InviteOption) -> UIImage? {
        // Generate a simple share image
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background gradient
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.systemOrange.cgColor,
                    UIColor.systemPink.cgColor
                ] as CFArray,
                locations: [0.0, 1.0]
            )
            
            if let gradient = gradient {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
            
            // App name
            let appName = "Palytt"
            let font = UIFont.systemFont(ofSize: 48, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            
            let text = NSAttributedString(string: appName, attributes: attributes)
            let textSize = text.size()
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2 - 20,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect)
            
            // Subtitle
            let subtitle = "Discover Amazing Food"
            let subtitleFont = UIFont.systemFont(ofSize: 16, weight: .medium)
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            
            let subtitleText = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
            let subtitleSize = subtitleText.size()
            let subtitleRect = CGRect(
                x: (size.width - subtitleSize.width) / 2,
                y: textRect.maxY + 10,
                width: subtitleSize.width,
                height: subtitleSize.height
            )
            
            subtitleText.draw(in: subtitleRect)
        }
    }
    
    private func trackInviteAction(type: String, option: InviteOption, recipient: String? = nil) async {
        guard let userId = AppState.shared.currentUser?.clerkId else { return }
        
        do {
            let response = try await backendService.performTRPCMutation<TrackInvitationResponse>(
                procedure: "invitations.trackInvitation",
                input: [
                    "senderId": userId,
                    "type": mapInviteTypeToBackend(type: type),
                    "platform": option.rawValue,
                    "referralCode": referralCode,
                    "recipient": recipient ?? ""
                ]
            )
            
            if response.success {
                print("✅ Tracked invite action: \(type) for \(option.rawValue)")
            }
        } catch {
            print("❌ Failed to track invite action: \(error)")
        }
    }
    
    private func mapInviteTypeToBackend(type: String) -> String {
        switch type {
        case "copy_link":
            return "link_copy"
        case "share_sheet", "native_invite":
            return "share_sheet"
        case "message_sent", "contact_sms":
            return "messages"
        case "email_sent", "contact_email":
            return "email"
        default:
            return type
        }
    }
    
    // MARK: - Native UI Handlers
    
    func handleMessageComposeResult(_ result: MessageComposeResult) {
        showNativeMessagesComposer = false
        switch result {
        case .cancelled:
            print("Message compose cancelled")
        case .failed:
            errorMessage = "Failed to send message"
        case .sent:
            HapticManager.shared.impact(.success)
            Task {
                await trackInviteAction(type: "message_sent", option: .messages)
            }
        @unknown default:
            print("Unknown message compose result")
        }
    }
    
    func handleMailComposeResult(_ result: MFMailComposeResult) {
        showNativeEmailComposer = false
        switch result {
        case .cancelled:
            print("Mail compose cancelled")
        case .failed:
            errorMessage = "Failed to send email"
        case .saved:
            print("Mail saved to drafts")
        case .sent:
            HapticManager.shared.impact(.success)
            Task {
                await trackInviteAction(type: "email_sent", option: .email)
            }
        @unknown default:
            print("Unknown mail compose result")
        }
    }
    
    func handleSelectedContacts(_ contacts: [CNContact]) {
        selectedContacts = contacts
        showContactsPicker = false
        
        // Process selected contacts
        Task {
            await sendInviteToContacts(contacts, option: .contacts)
        }
    }
}

// MARK: - Native UI Delegates

class MessageComposeDelegate: NSObject, MFMessageComposeViewControllerDelegate {
    private let completion: (MessageComposeResult) -> Void
    
    init(completion: @escaping (MessageComposeResult) -> Void) {
        self.completion = completion
    }
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        completion(result)
        controller.dismiss(animated: true)
    }
}

class MailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
    private let completion: (MFMailComposeResult) -> Void
    
    init(completion: @escaping (MFMailComposeResult) -> Void) {
        self.completion = completion
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        completion(result)
        controller.dismiss(animated: true)
    }
}

class ContactPickerDelegate: NSObject, CNContactPickerDelegate {
    private let completion: ([CNContact]) -> Void
    
    init(completion: @escaping ([CNContact]) -> Void) {
        self.completion = completion
    }
    
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
        completion(contacts)
    }
    
    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        completion([])
    }
}

// MARK: - Native UI Controllers

struct NativeMessageComposer: UIViewControllerRepresentable {
    let messageContent: (subject: String?, body: String)
    let delegate: MessageComposeDelegate
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = delegate
        controller.body = messageContent.body
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
}

struct NativeMailComposer: UIViewControllerRepresentable {
    let messageContent: (subject: String?, body: String)
    let delegate: MailComposeDelegate
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = delegate
        if let subject = messageContent.subject {
            controller.setSubject(subject)
        }
        controller.setMessageBody(messageContent.body, isHTML: false)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

struct NativeContactPicker: UIViewControllerRepresentable {
    let delegate: ContactPickerDelegate
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let controller = CNContactPickerViewController()
        controller.delegate = delegate
        controller.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0 OR emailAddresses.@count > 0")
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
}

// Note: ShareSheet is defined in SavedView.swift - using that shared definition 