//
//  HapticManager.swift
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
import AudioToolbox
#endif

// MARK: - Haptic Manager
class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // MARK: - Haptic Feedback Types
    enum HapticType {
        case light
        case medium
        case heavy
        case success
        case warning
        case error
        case selection
    }
    
    // MARK: - Sound Types
    enum SoundType {
        case tap
        case like
        case save
        case success
        case error
    }
    
    // MARK: - Haptic Feedback
    func haptic(_ type: HapticType) {
        #if os(iOS)
        DispatchQueue.main.async {
            switch type {
            case .light:
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
            case .medium:
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
            case .heavy:
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                
            case .success:
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
                
            case .warning:
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.warning)
                
            case .error:
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
                
            case .selection:
                let selectionFeedback = UISelectionFeedbackGenerator()
                selectionFeedback.selectionChanged()
            }
        }
        #endif
    }
    
    // MARK: - System Sounds
    func playSound(_ type: SoundType) {
        #if os(iOS)
        DispatchQueue.main.async {
            let soundID: SystemSoundID
            
            switch type {
            case .tap:
                soundID = 1104 // Tock sound
            case .like:
                soundID = 1103 // Pop sound
            case .save:
                soundID = 1105 // Peek sound
            case .success:
                soundID = 1054 // Mail sent sound
            case .error:
                soundID = 1053 // Error sound
            }
            
            AudioServicesPlaySystemSound(soundID)
        }
        #endif
    }
    
    // MARK: - Combined Feedback
    func impact(_ type: HapticType, sound: SoundType? = nil) {
        haptic(type)
        if let sound = sound {
            playSound(sound)
        }
      }
}

// MARK: - SwiftUI Button Extension
extension View {
    func hapticFeedback(_ type: HapticManager.HapticType, sound: HapticManager.SoundType? = nil) -> some View {
        self.onTapGesture {
            HapticManager.shared.impact(type, sound: sound)
        }
    }
}

// MARK: - Button Modifier
struct HapticButtonStyle: ButtonStyle {
    let hapticType: HapticManager.HapticType
    let soundType: HapticManager.SoundType?
    
    init(haptic: HapticManager.HapticType = .light, sound: HapticManager.SoundType? = .tap) {
        self.hapticType = haptic
        self.soundType = sound
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    HapticManager.shared.impact(hapticType, sound: soundType)
                }
            }
    }
} 