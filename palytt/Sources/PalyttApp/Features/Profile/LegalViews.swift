//
//  LegalViews.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import SafariServices
#if os(iOS)
import UIKit
#endif

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Terms of Service")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.appPrimaryText)
                        
                        Text("Effective Date: January 17, 2025")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                    }
                    
                    Divider()
                    
                    // MARK: - Intellectual Property Rights Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("INTELLECTUAL PROPERTY RIGHTS")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.appPrimaryText)
                        
                        Text("1. Palytt Ownership")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimaryText)
                        
                        Text("All software, designs, content, trademarks, and intellectual property in the Palytt app are owned by Palytt Inc. and protected by copyright, trademark, and trade secret laws. Users receive only a limited license to use the service, not ownership of any intellectual property.")
                            .font(.body)
                            .foregroundColor(.appSecondaryText)
                        
                        Text("2. User Content License")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimaryText)
                        
                        Text("Users retain ownership of their photos, posts, and content. By using Palytt, users grant us a limited, non-exclusive license to use, display, and distribute their content for platform operations. Users warrant they own or have rights to all content they share.")
                            .font(.body)
                            .foregroundColor(.appSecondaryText)
                        
                        Text("3. Copyright Infringement")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimaryText)
                        
                        Text("Palytt respects intellectual property rights. We have DMCA-compliant takedown procedures and enforce a repeat offender policy. If you believe your copyright has been infringed, please contact us immediately.")
                            .font(.body)
                            .foregroundColor(.appSecondaryText)
                    }
                    
                    Divider()
                    
                    legalSection(
                        title: "1. Acceptance of Terms",
                        content: "By downloading, installing, or using Palytt, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our service."
                    )
                    
                    legalSection(
                        title: "2. Description of Service",
                        content: "Palytt is a social platform that allows users to discover, share, and review food experiences. Our service includes features for posting photos, writing reviews, finding restaurants, and connecting with other food enthusiasts."
                    )
                    
                    legalSection(
                        title: "3. User Accounts and Registration",
                        content: """
                        • You must provide accurate and complete information when creating an account
                        • You are responsible for maintaining the security of your account
                        • You must be at least 13 years old to use Palytt
                        • One account per person is permitted
                        """
                    )
                    
                    legalSection(
                        title: "4. User Content and Conduct",
                        content: """
                        You agree to use Palytt responsibly and not to:
                        • Post illegal, harmful, or offensive content
                        • Violate intellectual property rights
                        • Spam or harass other users
                        • Share false or misleading information
                        • Upload content that infringes on others' privacy
                        """
                    )
                    
                    legalSection(
                        title: "5. Content License",
                        content: "By posting content on Palytt, you grant us a non-exclusive, royalty-free license to use, display, and distribute your content in connection with our service. You retain ownership of your content."
                    )
                    
                    legalSection(
                        title: "6. Privacy and Data Protection",
                        content: "Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information."
                    )
                    
                    legalSection(
                        title: "7. Intellectual Property",
                        content: "Palytt and all related trademarks, logos, and content are owned by Palytt Inc. You may not use our intellectual property without permission."
                    )
                    
                    legalSection(
                        title: "8. Termination",
                        content: "We may suspend or terminate your account if you violate these terms. You may delete your account at any time through the app settings."
                    )
                    
                    legalSection(
                        title: "9. Disclaimers",
                        content: """
                        Palytt is provided "as is" without warranties of any kind. We do not guarantee:
                        • Continuous, uninterrupted access to our service
                        • Accuracy of restaurant information or user reviews
                        • Availability of specific features
                        """
                    )
                    
                    legalSection(
                        title: "10. Limitation of Liability",
                        content: "To the maximum extent permitted by law, Palytt shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of our service."
                    )
                    
                    legalSection(
                        title: "11. Contact Information",
                        content: """
                        If you have questions about these Terms of Service, please contact us:
                        
                        Email: legal@palytt.com
                        Address: Palytt Inc., 123 Tech Street, San Francisco, CA 94105
                        """
                    )
                    
                    Text("By continuing to use Palytt, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.")
                        .font(.footnote)
                        .foregroundColor(.appSecondaryText)
                        .padding(.top, 20)
                        .italic()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("COPYRIGHT NOTICE")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.appPrimaryText)
                        
                        Text("© 2025 Palytt Inc. All rights reserved.")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimaryText)
                        
                        Text("Palytt and the Palytt logo are trademarks of Palytt Inc. All content and software are protected by copyright law. Unauthorized copying, distribution, or use is strictly prohibited.")
                            .font(.body)
                            .foregroundColor(.appSecondaryText)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
        }
    }
    
    @ViewBuilder
    private func legalSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.appPrimaryText)
            
            Text(content)
                .font(.body)
                .foregroundColor(.appPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privacy Policy")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.appPrimaryText)
                        
                        Text("Effective Date: January 17, 2025")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                        
                        Text("This Privacy Policy explains how Palytt collects, uses, and protects your personal information.")
                            .font(.body)
                            .foregroundColor(.appPrimaryText)
                    }
                    
                    legalSection(
                        title: "1. Information We Collect",
                        content: """
                        We collect information you provide directly:
                        • Account information (name, email, username)
                        • Profile information (bio, profile photo)
                        • Content you post (photos, reviews, comments)
                        • Communication with other users
                        
                        We also collect information automatically:
                        • Usage data and app interactions
                        • Device information (model, OS version)
                        • Location data (with your permission)
                        • Log data (IP address, access times)
                        """
                    )
                    
                    legalSection(
                        title: "2. How We Use Your Information",
                        content: """
                        We use your information to:
                        • Provide and improve our service
                        • Personalize your experience
                        • Enable social features and connections
                        • Send notifications and updates
                        • Ensure safety and security
                        • Comply with legal obligations
                        """
                    )
                    
                    legalSection(
                        title: "3. Information Sharing",
                        content: """
                        We may share your information:
                        • With other users (profile and public content)
                        • With service providers who help operate our platform
                        • When required by law or to protect rights and safety
                        • In connection with business transfers
                        
                        We do not sell your personal information to third parties.
                        """
                    )
                    
                    legalSection(
                        title: "4. Location Information",
                        content: "We collect location data only with your explicit permission. You can disable location sharing in your device settings at any time. Location data helps us provide location-based features like nearby restaurant recommendations."
                    )
                    
                    legalSection(
                        title: "5. Data Security",
                        content: "We implement appropriate security measures to protect your information, including encryption, secure servers, and access controls. However, no system is completely secure, and we cannot guarantee absolute security."
                    )
                    
                    legalSection(
                        title: "6. Your Privacy Rights",
                        content: """
                        You have the right to:
                        • Access and review your personal information
                        • Correct inaccurate information
                        • Delete your account and associated data
                        • Control privacy settings and data sharing
                        • Opt out of certain communications
                        """
                    )
                    
                    legalSection(
                        title: "7. Children's Privacy",
                        content: "Palytt is not intended for children under 13. We do not knowingly collect personal information from children under 13. If we become aware of such collection, we will delete the information promptly."
                    )
                    
                    legalSection(
                        title: "8. International Data Transfers",
                        content: "Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place to protect your information during such transfers."
                    )
                    
                    legalSection(
                        title: "9. Changes to This Policy",
                        content: "We may update this Privacy Policy from time to time. We will notify you of significant changes through the app or by email. Your continued use constitutes acceptance of the updated policy."
                    )
                    
                    legalSection(
                        title: "10. Contact Us",
                        content: """
                        If you have questions about this Privacy Policy or want to exercise your privacy rights:
                        
                        Email: privacy@palytt.com
                        Address: Palytt Inc., 123 Tech Street, San Francisco, CA 94105
                        """
                    )
                    
                    Text("Your privacy matters to us. We are committed to protecting your personal information and being transparent about our data practices.")
                        .font(.footnote)
                        .foregroundColor(.appSecondaryText)
                        .padding(.top, 20)
                        .italic()
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func legalSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.appPrimaryText)
            
            Text(content)
                .font(.body)
                .foregroundColor(.appPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    
                    // App Logo and Info
                    VStack(spacing: 16) {
                        Image("palytt-logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        VStack(spacing: 8) {
                            Text("Palytt")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.appPrimaryText)
                            
                            Text("Discover. Share. Savor.")
                                .font(.headline)
                                .foregroundColor(.appSecondaryText)
                            
                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.caption)
                                .foregroundColor(.appTertiaryText)
                        }
                    }
                    
                    // App Description
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About Palytt")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimaryText)
                        
                        Text("Palytt is your ultimate food discovery companion. Connect with fellow food enthusiasts, discover amazing restaurants, share your culinary adventures, and build a community around your love for great food.")
                            .font(.body)
                            .foregroundColor(.appPrimaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Features Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimaryText)
                        
                        featureRow(icon: "camera.fill", title: "Food Photography", description: "Capture and share stunning food photos")
                        featureRow(icon: "location.fill", title: "Restaurant Discovery", description: "Find amazing restaurants near you")
                        featureRow(icon: "person.2.fill", title: "Social Features", description: "Connect with food lovers worldwide")
                        featureRow(icon: "star.fill", title: "Reviews & Ratings", description: "Share honest reviews and ratings")
                        featureRow(icon: "map.fill", title: "Interactive Maps", description: "Explore food hotspots on the map")
                    }
                    
                    // Legal Links
                    VStack(spacing: 12) {
                        NavigationLink(destination: TermsOfServiceView()) {
                            legalLinkRow(title: "Terms of Service")
                        }
                        
                        NavigationLink(destination: PrivacyPolicyView()) {
                            legalLinkRow(title: "Privacy Policy")
                        }
                    }
                    
                    // Attribution Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Acknowledgments")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimaryText)
                        
                        Text("Palytt is built with love using SwiftUI and powered by modern cloud technologies. We thank the open-source community for their contributions.")
                            .font(.body)
                            .foregroundColor(.appSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Contact Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Contact")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimaryText)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email: support@palytt.com")
                                .font(.body)
                                .foregroundColor(.appPrimaryText)
                            
                            Text("Website: www.palytt.com")
                                .font(.body)
                                .foregroundColor(.appPrimaryText)
                        }
                    }
                    
                    // Copyright and IP Protection Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Copyright & Intellectual Property")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimaryText)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("© 2025 Palytt Inc. All rights reserved.")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.appPrimaryText)
                            
                            Text("Palytt™ and the Palytt logo are trademarks of Palytt Inc.")
                                .font(.body)
                                .foregroundColor(.appPrimaryText)
                            
                            Text("All software, designs, content, and intellectual property are protected by copyright, trademark, and trade secret laws. Unauthorized copying, distribution, or use is strictly prohibited.")
                                .font(.body)
                                .foregroundColor(.appSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("Users retain ownership of their content but grant Palytt a license for platform operations. For copyright inquiries or DMCA notices, contact legal@palytt.com")
                                .font(.caption)
                                .foregroundColor(.appTertiaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        }
                    }
                    
                    // Legal Compliance Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Legal Compliance")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimaryText)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• DMCA Compliant Content Management")
                                .font(.body)
                                .foregroundColor(.appSecondaryText)
                            
                            Text("• Privacy Law Compliance (GDPR, CCPA)")
                                .font(.body)
                                .foregroundColor(.appSecondaryText)
                            
                            Text("• App Store Review Guidelines Certified")
                                .font(.body)
                                .foregroundColor(.appSecondaryText)
                            
                            Text("• International Copyright Protection")
                                .font(.body)
                                .foregroundColor(.appSecondaryText)
                        }
                    }
                    
                    // Copyright
                    Text("© 2025 Palytt Inc. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.appTertiaryText)
                        .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.primaryBrand)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimaryText)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func legalLinkRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.primaryBrand)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.appTertiaryText)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Disclaimer View
struct DisclaimerView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Disclaimer")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.appPrimaryText)
                        
                        Text("Important information about using Palytt")
                            .font(.headline)
                            .foregroundColor(.appSecondaryText)
                    }
                    
                    disclaimerSection(
                        title: "User-Generated Content",
                        content: "All reviews, ratings, and photos on Palytt are provided by users. While we strive to maintain quality, we cannot guarantee the accuracy, completeness, or reliability of user-generated content. Always use your own judgment when making dining decisions."
                    )
                    
                    disclaimerSection(
                        title: "Restaurant Information",
                        content: "Restaurant details including hours, menu items, prices, and contact information are provided for convenience but may not always be current. We recommend verifying information directly with restaurants before visiting."
                    )
                    
                    disclaimerSection(
                        title: "Health and Dietary Considerations",
                        content: "Palytt is not a substitute for professional dietary or medical advice. If you have food allergies, dietary restrictions, or health concerns, always consult with restaurants directly and seek professional medical guidance."
                    )
                    
                    disclaimerSection(
                        title: "Location-Based Services",
                        content: "Location features are provided for convenience and may not always be precise. Do not rely solely on our app for navigation or emergency situations. Use official mapping services for critical location needs."
                    )
                    
                    disclaimerSection(
                        title: "Third-Party Services",
                        content: "Palytt may integrate with third-party services (maps, payment processors, etc.). We are not responsible for the availability, accuracy, or content of third-party services."
                    )
                    
                    disclaimerSection(
                        title: "Service Availability",
                        content: "While we strive to maintain continuous service, Palytt may experience temporary interruptions for maintenance, updates, or technical issues. We do not guarantee uninterrupted access to our services."
                    )
                    
                    disclaimerSection(
                        title: "Age Restrictions",
                        content: "Users must be at least 13 years old to use Palytt. Users under 18 should have parental supervision when using location-based features or meeting other users."
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Contact for Issues")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimaryText)
                        
                        Text("If you encounter any issues or have concerns about content on Palytt, please contact us at support@palytt.com or use the reporting features within the app.")
                            .font(.body)
                            .foregroundColor(.appPrimaryText)
                    }
                    
                    Text("By using Palytt, you acknowledge that you have read and understood this disclaimer and agree to use the service responsibly.")
                        .font(.footnote)
                        .foregroundColor(.appSecondaryText)
                        .padding(.top, 20)
                        .italic()
                }
                .padding()
            }
            .navigationTitle("Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func disclaimerSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.appPrimaryText)
            
            Text(content)
                .font(.body)
                .foregroundColor(.appPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Previews
#Preview("Terms of Service") {
    TermsOfServiceView()
}

#Preview("Privacy Policy") {
    PrivacyPolicyView()
}

#Preview("About") {
    AboutView()
}

#Preview("Disclaimer") {
    DisclaimerView()
} 