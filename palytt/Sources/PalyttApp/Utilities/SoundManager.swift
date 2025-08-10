//
//  SoundManager.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import AVFoundation
import SwiftUI
import Combine

// MARK: - Sound Manager
@MainActor
class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    @Published var isSoundEnabled = true
    @Published var soundVolume: Float = 0.7
    @Published var isInitialized = false
    
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var audioSession: AVAudioSession
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Sound Categories
    enum SoundEffect: String, CaseIterable {
        // UI Interactions
        case buttonTap = "button_tap"
        case buttonPress = "button_press"
        case swipeAction = "swipe_action"
        case tabSwitch = "tab_switch"
        case modalPresent = "modal_present"
        case modalDismiss = "modal_dismiss"
        
        // Social Actions
        case like = "like_heart"
        case unlike = "unlike"
        case comment = "comment_sent"
        case share = "share_action"
        case follow = "follow_user"
        case unfollow = "unfollow_user"
        
        // Content Actions
        case photoCapture = "photo_capture"
        case postCreated = "post_created"
        case postSaved = "post_saved"
        case photoSwipe = "photo_swipe"
        
        // Notifications
        case notification = "notification_received"
        case messageReceived = "message_received"
        case achievementUnlocked = "achievement_unlocked"
        case friendRequest = "friend_request"
        
        // System Actions
        case success = "success_chime"
        case error = "error_tone"
        case warning = "warning_tone"
        case confirmation = "confirmation"
        
        // Navigation
        case pageFlip = "page_flip"
        case slideTransition = "slide_transition"
        case popTransition = "pop_transition"
        
        var fileName: String {
            return rawValue + ".mp3"
        }
        
        var category: SoundCategory {
            switch self {
            case .buttonTap, .buttonPress, .swipeAction, .tabSwitch, .modalPresent, .modalDismiss:
                return .ui
            case .like, .unlike, .comment, .share, .follow, .unfollow:
                return .social
            case .photoCapture, .postCreated, .postSaved, .photoSwipe:
                return .content
            case .notification, .messageReceived, .achievementUnlocked, .friendRequest:
                return .notification
            case .success, .error, .warning, .confirmation:
                return .system
            case .pageFlip, .slideTransition, .popTransition:
                return .navigation
            }
        }
    }
    
    enum SoundCategory {
        case ui, social, content, notification, system, navigation
        
        var volume: Float {
            switch self {
            case .ui: return 0.3
            case .social: return 0.5
            case .content: return 0.6
            case .notification: return 0.8
            case .system: return 0.7
            case .navigation: return 0.4
            }
        }
    }
    
    private init() {
        self.audioSession = AVAudioSession.sharedInstance()
        setupAudioSession()
        loadUserPreferences()
        preloadSounds()
    }
    
    // MARK: - Setup & Configuration
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            isInitialized = true
            print("🔊 SoundManager: Audio session initialized successfully")
        } catch {
            print("❌ SoundManager: Failed to setup audio session: \(error)")
            isInitialized = false
        }
    }
    
    private func loadUserPreferences() {
        isSoundEnabled = UserDefaults.standard.object(forKey: "sound_enabled") as? Bool ?? true
        soundVolume = UserDefaults.standard.object(forKey: "sound_volume") as? Float ?? 0.7
    }
    
    private func saveUserPreferences() {
        UserDefaults.standard.set(isSoundEnabled, forKey: "sound_enabled")
        UserDefaults.standard.set(soundVolume, forKey: "sound_volume")
    }
    
    // MARK: - Sound Loading & Management
    
    private func preloadSounds() {
        let soundEffects: [SoundEffect] = [.like, .comment, .notification, .buttonTap, .success, .error]
        
        for effect in soundEffects {
            loadSound(effect)
        }
        
        print("🎵 SoundManager: Preloaded \(soundEffects.count) essential sounds")
    }
    
    private func loadSound(_ effect: SoundEffect) {
        // First try to load from bundle
        if let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "mp3") {
            loadSoundFromURL(url, key: effect.rawValue)
            return
        }
        
        // Fallback to generating procedural sound
        generateProceduralSound(for: effect)
    }
    
    private func loadSoundFromURL(_ url: URL, key: String) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayers[key] = player
            print("✅ Loaded sound: \(key)")
        } catch {
            print("❌ Failed to load sound \(key): \(error)")
            // Generate fallback sound
            if let effect = SoundEffect(rawValue: key) {
                generateProceduralSound(for: effect)
            }
        }
    }
    
    // MARK: - Procedural Sound Generation
    
    private func generateProceduralSound(for effect: SoundEffect) {
        let soundData = generateSoundData(for: effect)
        
        do {
            let player = try AVAudioPlayer(data: soundData)
            player.prepareToPlay()
            audioPlayers[effect.rawValue] = player
            print("🎼 Generated procedural sound: \(effect.rawValue)")
        } catch {
            print("❌ Failed to create procedural sound for \(effect.rawValue): \(error)")
        }
    }
    
    private func generateSoundData(for effect: SoundEffect) -> Data {
        let sampleRate: Double = 44100
        let duration: Double = 0.3
        let samples = Int(sampleRate * duration)
        
        var audioData = Data()
        
        switch effect {
        case .like:
            // Pleasant ascending tone
            audioData = generateTone(frequency: 523.25, duration: 0.1, sampleRate: sampleRate) // C5
            audioData.append(generateTone(frequency: 659.25, duration: 0.1, sampleRate: sampleRate)) // E5
            audioData.append(generateTone(frequency: 783.99, duration: 0.1, sampleRate: sampleRate)) // G5
            
        case .buttonTap:
            // Short click sound
            audioData = generateClick(duration: 0.05, sampleRate: sampleRate)
            
        case .success:
            // Success chime
            audioData = generateTone(frequency: 523.25, duration: 0.2, sampleRate: sampleRate)
            audioData.append(generateTone(frequency: 659.25, duration: 0.2, sampleRate: sampleRate))
            
        case .error:
            // Error buzz
            audioData = generateBuzz(frequency: 220, duration: 0.3, sampleRate: sampleRate)
            
        case .notification:
            // Gentle notification
            audioData = generateTone(frequency: 440, duration: 0.2, sampleRate: sampleRate)
            audioData.append(generateTone(frequency: 554.37, duration: 0.2, sampleRate: sampleRate))
            
        default:
            // Default gentle tone
            audioData = generateTone(frequency: 440, duration: 0.2, sampleRate: sampleRate)
        }
        
        return audioData
    }
    
    private func generateTone(frequency: Double, duration: Double, sampleRate: Double) -> Data {
        let samples = Int(sampleRate * duration)
        var audioData = Data()
        
        for i in 0..<samples {
            let time = Double(i) / sampleRate
            let amplitude = sin(2.0 * Double.pi * frequency * time) * 0.3
            let sample = Int16(amplitude * Double(Int16.max))
            
            withUnsafeBytes(of: sample.littleEndian) { bytes in
                audioData.append(contentsOf: bytes)
            }
        }
        
        return audioData
    }
    
    private func generateClick(duration: Double, sampleRate: Double) -> Data {
        let samples = Int(sampleRate * duration)
        var audioData = Data()
        
        for i in 0..<samples {
            let envelope = 1.0 - (Double(i) / Double(samples))
            let noise = Double.random(in: -1...1) * 0.1 * envelope
            let sample = Int16(noise * Double(Int16.max))
            
            withUnsafeBytes(of: sample.littleEndian) { bytes in
                audioData.append(contentsOf: bytes)
            }
        }
        
        return audioData
    }
    
    private func generateBuzz(frequency: Double, duration: Double, sampleRate: Double) -> Data {
        let samples = Int(sampleRate * duration)
        var audioData = Data()
        
        for i in 0..<samples {
            let time = Double(i) / sampleRate
            let wave = sin(2.0 * Double.pi * frequency * time)
            let distortion = wave > 0 ? 1.0 : -1.0
            let amplitude = distortion * 0.2
            let sample = Int16(amplitude * Double(Int16.max))
            
            withUnsafeBytes(of: sample.littleEndian) { bytes in
                audioData.append(contentsOf: bytes)
            }
        }
        
        return audioData
    }
    
    // MARK: - Public Methods
    
    func playSound(_ effect: SoundEffect, volume: Float? = nil) {
        guard isSoundEnabled, isInitialized else { return }
        
        let player = audioPlayers[effect.rawValue]
        
        if player == nil {
            // Try to load the sound if not already loaded
            loadSound(effect)
            // Try again with the newly loaded sound
            guard let newPlayer = audioPlayers[effect.rawValue] else {
                print("⚠️ Sound not available: \(effect.rawValue)")
                return
            }
            playAudioPlayer(newPlayer, effect: effect, volume: volume)
        } else {
            playAudioPlayer(player!, effect: effect, volume: volume)
        }
    }
    
    private func playAudioPlayer(_ player: AVAudioPlayer, effect: SoundEffect, volume: Float?) {
        // Calculate final volume
        let categoryVolume = effect.category.volume
        let userVolume = volume ?? soundVolume
        let finalVolume = categoryVolume * userVolume
        
        player.volume = finalVolume
        player.currentTime = 0
        player.play()
        
        print("🔊 Playing sound: \(effect.rawValue) at volume \(finalVolume)")
    }
    
    func setSoundEnabled(_ enabled: Bool) {
        isSoundEnabled = enabled
        saveUserPreferences()
    }
    
    func setSoundVolume(_ volume: Float) {
        soundVolume = max(0.0, min(1.0, volume))
        saveUserPreferences()
    }
    
    // MARK: - Integration with Haptics
    
    func playWithHaptic(_ effect: SoundEffect, hapticType: HapticManager.HapticType? = nil) {
        playSound(effect)
        
        // Only play haptics if enabled in settings
        if checkHapticsEnabled() {
            if let hapticType = hapticType {
                HapticManager.shared.haptic(hapticType)
            } else {
                // Default haptic based on sound category
                let defaultHaptic = getDefaultHaptic(for: effect.category)
                HapticManager.shared.haptic(defaultHaptic)
            }
        }
    }
    
    private func getDefaultHaptic(for category: SoundCategory) -> HapticManager.HapticType {
        switch category {
        case .ui: return .light
        case .social: return .medium
        case .content: return .medium
        case .notification: return .heavy
        case .system: return .heavy
        case .navigation: return .light
        }
    }
    
    // MARK: - Convenience Methods
    
    func playLikeSound() {
        guard checkSoundEnabled() else { return }
        playWithHaptic(.like, hapticType: .medium)
    }
    
    func playCommentSound() {
        guard checkSoundEnabled() else { return }
        playWithHaptic(.comment, hapticType: .light)
    }
    
    func playNotificationSound() {
        guard checkNotificationSoundEnabled() else { return }
        playWithHaptic(.notification, hapticType: .heavy)
    }
    
    func playButtonTapSound() {
        playWithHaptic(.buttonTap, hapticType: .light)
    }
    
    func playSuccessSound() {
        playWithHaptic(.success, hapticType: .success)
    }
    
    func playErrorSound() {
        playWithHaptic(.error, hapticType: .error)
    }
    
    // MARK: - Settings Management
    
    func getVolumeForCategory(_ category: SoundCategory) -> Float {
        return category.volume * soundVolume
    }
    
    func preloadEffect(_ effect: SoundEffect) {
        if audioPlayers[effect.rawValue] == nil {
            loadSound(effect)
        }
    }
    
    func unloadEffect(_ effect: SoundEffect) {
        audioPlayers.removeValue(forKey: effect.rawValue)
    }
    
    func clearCache() {
        audioPlayers.removeAll()
        preloadSounds()
    }
    
    // MARK: - Settings Integration
    
    /// Check if app sounds are enabled based on notification settings
    private func checkSoundEnabled() -> Bool {
        return NotificationSettings.shared.soundsEnabled && isSoundEnabled
    }
    
    /// Check if notification sounds specifically are enabled
    private func checkNotificationSoundEnabled() -> Bool {
        return NotificationSettings.shared.notificationSoundsEnabled && 
               NotificationSettings.shared.soundsEnabled && 
               isSoundEnabled
    }
    
    /// Check if haptics are enabled based on notification settings
    private func checkHapticsEnabled() -> Bool {
        return NotificationSettings.shared.hapticsEnabled
    }
}

// MARK: - SwiftUI Extensions

extension View {
    func soundEffect(_ effect: SoundManager.SoundEffect) -> some View {
        self.onTapGesture {
            SoundManager.shared.playSound(effect)
        }
    }
    
    func soundWithHaptic(_ effect: SoundManager.SoundEffect, haptic: HapticManager.HapticType = .light) -> some View {
        self.onTapGesture {
            SoundManager.shared.playWithHaptic(effect, hapticType: haptic)
        }
    }
}

// MARK: - Button Style with Sound

struct SoundButtonStyle: ButtonStyle {
    let soundEffect: SoundManager.SoundEffect
    let hapticType: HapticManager.HapticType
    
    init(sound: SoundManager.SoundEffect = .buttonTap, haptic: HapticManager.HapticType = .light) {
        self.soundEffect = sound
        self.hapticType = haptic
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    SoundManager.shared.playWithHaptic(soundEffect, hapticType: hapticType)
                }
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        Button("Like Sound") {
            SoundManager.shared.playLikeSound()
        }
        .buttonStyle(SoundButtonStyle(sound: .like, haptic: .medium))
        
        Button("Comment Sound") {
            SoundManager.shared.playCommentSound()
        }
        .buttonStyle(SoundButtonStyle(sound: .comment, haptic: .light))
        
        Button("Success Sound") {
            SoundManager.shared.playSuccessSound()
        }
        .buttonStyle(SoundButtonStyle(sound: .success, haptic: .success))
    }
    .padding()
} 