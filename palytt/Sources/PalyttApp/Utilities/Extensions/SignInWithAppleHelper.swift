//
//  SignInWithAppleHelper.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import AuthenticationServices
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - Sign In With Apple Helper

@MainActor
class SignInWithAppleHelper: NSObject, ObservableObject {
    
    static func getAppleIdCredential() async throws -> ASAuthorizationAppleIDCredential {
        return try await withCheckedThrowingContinuation { continuation in
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.email, .fullName]
            request.nonce = UUID().uuidString // Setting the nonce is mandatory
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
    }
}

// MARK: - Apple Sign In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    private let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>
    
    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation.resume(throwing: AppleSignInError.invalidCredential)
            return
        }
        
        continuation.resume(returning: credential)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("Unable to find a suitable presentation anchor")
        }
        return window
        #else
        // macOS uses NSWindow as ASPresentationAnchor
        guard let window = NSApplication.shared.windows.first else {
            fatalError("Unable to find a suitable presentation anchor")
        }
        return window
        #endif
    }
}

// MARK: - Apple Sign In Errors

enum AppleSignInError: LocalizedError {
    case invalidCredential
    case noWindow
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Unable to get Apple ID credential"
        case .noWindow:
            return "Unable to find presentation window"
        }
    }
} 