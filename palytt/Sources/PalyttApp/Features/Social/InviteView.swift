//
//  InviteView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI

// MARK: - Invite View

struct InviteView: View {
    @StateObject private var viewModel = InviteViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var selectedInviteOption: InviteOption = .general
    @State private var showingReferrals = false
    @State private var referralCode: String = ""
    @State private var codeCopied = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Referral Code Section (NEW)
                    referralCodeSection
                    
                    // Header Section
                    headerSection
                    
                    // Invite Options
                    inviteOptionsSection
                    
                    // Stats Section
                    if viewModel.inviteStats.totalInvites > 0 {
                        statsSection
                    }
                    
                    // Share Buttons
                    shareButtonsSection
                    
                    // View All Referrals Link
                    viewReferralsLink
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.background)
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }
                    .foregroundColor(.primaryText)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: viewModel.getShareContent(for: selectedInviteOption))
            }
            .sheet(isPresented: $showingReferrals) {
                ReferralsView()
            }
            .sheet(isPresented: $viewModel.showNativeMessagesComposer) {
                if let delegate = viewModel.messageComposeDelegate {
                    NativeMessageComposer(
                        messageContent: viewModel.getMessageContent(for: .messages),
                        delegate: delegate
                    )
                }
            }
            .sheet(isPresented: $viewModel.showNativeEmailComposer) {
                if let delegate = viewModel.mailComposeDelegate {
                    NativeMailComposer(
                        messageContent: viewModel.getMessageContent(for: .email),
                        delegate: delegate
                    )
                }
            }
            .sheet(isPresented: $viewModel.showContactsPicker) {
                if let delegate = viewModel.contactPickerDelegate {
                    NativeContactPicker(delegate: delegate)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadInviteStats()
                }
            }
        }
    }
    
    // MARK: - Referral Code Section
    
    @ViewBuilder
    private var referralCodeSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Referral Code")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Text(referralCode.isEmpty ? "Loading..." : referralCode)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.primaryBrand)
                }
                
                Spacer()
                
                Button(action: {
                    HapticManager.shared.impact(.light)
                    if !referralCode.isEmpty {
                        UIPasteboard.general.string = referralCode
                        codeCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            codeCopied = false
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                        Text(codeCopied ? "Copied" : "Copy")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(codeCopied ? Color.green : Color.primaryBrand)
                    .cornerRadius(8)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardBackground)
            )
        }
        .task {
            do {
                let response = try await BackendService.shared.getReferralCode()
                referralCode = response.code
            } catch {
                print("❌ Failed to load referral code: \(error)")
            }
        }
    }
    
    // MARK: - View Referrals Link
    
    @ViewBuilder
    private var viewReferralsLink: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            showingReferrals = true
        }) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.primaryBrand)
                
                Text("View Referral Statistics")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardBackground)
            )
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Icon with invitation animation
            ZStack {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.primaryBrand)
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            VStack(spacing: 8) {
                Text("Share the Food Love")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text("Invite your friends to discover amazing food experiences together on Palytt")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
    }
    
    // MARK: - Invite Options Section
    
    @ViewBuilder
    private var inviteOptionsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Invitation Types")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(InviteOption.allCases, id: \.self) { option in
                    InviteOptionCard(
                        option: option,
                        isSelected: selectedInviteOption == option,
                        onTap: {
                            HapticManager.shared.impact(.light)
                            selectedInviteOption = option
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Stats Section
    
    @ViewBuilder
    private var statsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Invite Stats")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Invites Sent",
                    value: "\(viewModel.inviteStats.totalInvites)",
                    icon: "paperplane.fill",
                    color: .matchaGreen
                )
                
                StatCard(
                    title: "Friends Joined",
                    value: "\(viewModel.inviteStats.friendsJoined)",
                    icon: "person.2.fill",
                                                    color: .matchaGreen
                )
            }
        }
    }
    
    // MARK: - Share Buttons Section
    
    @ViewBuilder
    private var shareButtonsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Share Options")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Native Share Button (for selected option)
                if selectedInviteOption.isNativeMethod && viewModel.isNativeMethodAvailable(for: selectedInviteOption) {
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        viewModel.triggerNativeInvite(for: selectedInviteOption)
                    }) {
                        HStack {
                            Image(systemName: selectedInviteOption.icon)
                                .font(.title3)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use Native \(selectedInviteOption.title)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text("Opens \(selectedInviteOption.title.lowercased()) app directly")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.primaryBrand, .primaryBrand.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }
                
                // Universal Share Button
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.primaryBrand)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share Anywhere")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                            
                            Text("Use iOS share sheet for more options")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primaryBrand.opacity(0.2), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                
                // Copy Link Button
                Button(action: {
                    HapticManager.shared.impact(.light)
                    viewModel.copyInviteLink(for: selectedInviteOption)
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                            .font(.title3)
                            .foregroundColor(.secondaryText)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Copy Invite Link")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                            
                            Text("Copy link to clipboard")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                        
                        if viewModel.showCopyConfirmation {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.divider, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Invite Option Card

struct InviteOptionCard: View {
    let option: InviteOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primaryBrand)
                
                VStack(spacing: 4) {
                    Text(option.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primaryText)
                    
                    Text(option.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.primaryBrand : Color.cardBackground)
                    .stroke(
                        isSelected ? Color.clear : Color.divider,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground)
                .stroke(Color.divider, lineWidth: 1)
        )
    }
}

// MARK: - Quick Share Button

struct QuickShareButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primaryBrand)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.primaryBrand.opacity(0.1))
                    )
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
            }
        }
        .buttonStyle(HapticButtonStyle(haptic: .light))
    }
}

// MARK: - Preview

#Preview {
    InviteView()
        .environmentObject(MockAppState())
} 