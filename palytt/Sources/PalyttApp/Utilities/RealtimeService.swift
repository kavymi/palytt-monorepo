//
//  RealtimeService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import SwiftUI
import Network
import Combine

// MARK: - Real-time Service

@MainActor
class RealtimeService: ObservableObject {
    static let shared = RealtimeService()
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var liveUpdates: [LiveUpdate] = []
    @Published var activeUsers: Set<String> = []
    @Published var isReconnecting = false
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private var heartbeatTimer: Timer?
    private var reconnectTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private let apiConfig = APIConfigurationManager.shared
    private var baseURL: String {
        return apiConfig.currentWebSocketURL
    }
    private let maxReconnectAttempts = 5
    private var reconnectAttempts = 0
    private var isIntentionalDisconnect = false
    
    // Network monitoring
    private let monitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: configuration)
        
        setupNetworkMonitoring()
        setupAppStateObservers()
    }
    
    // MARK: - Public Methods
    
    func connect() async {
        guard connectionStatus != .connected else { return }
        
        print("🔌 RealtimeService: Attempting to connect...")
        connectionStatus = .connecting
        
        do {
            await createWebSocketConnection()
        } catch {
            print("❌ RealtimeService: Connection failed: \(error)")
            connectionStatus = .disconnected
            await scheduleReconnect()
        }
    }
    
    func disconnect() {
        print("🔌 RealtimeService: Disconnecting...")
        isIntentionalDisconnect = true
        cleanupConnection()
        connectionStatus = .disconnected
    }
    
    func sendLiveUpdate(_ update: LiveUpdate) async {
        guard connectionStatus == .connected else {
            print("⚠️ RealtimeService: Cannot send update, not connected")
            return
        }
        
        do {
            let message = RealtimeMessage(type: .liveUpdate, data: [
                "updateType": update.type.rawValue,
                "data": update.data
            ])
            
            let data = try JSONEncoder().encode(message)
            let webSocketMessage = URLSessionWebSocketTask.Message.data(data)
            try await webSocketTask?.send(webSocketMessage)
            
            print("📤 RealtimeService: Sent live update: \(update.type)")
        } catch {
            print("❌ RealtimeService: Failed to send update: \(error)")
            await handleConnectionError(error)
        }
    }
    
    func subscribeToUpdates(for types: Set<UpdateType>) async {
        let subscriptionMessage = RealtimeMessage(
            type: .subscribe,
            data: ["updateTypes": types.map { $0.rawValue }]
        )
        await sendMessage(subscriptionMessage)
    }
    
    func markUserAsActive() async {
        let heartbeatMessage = RealtimeMessage(
            type: .heartbeat,
            data: ["status": "active", "timestamp": "\(Date().timeIntervalSince1970)"]
        )
        await sendMessage(heartbeatMessage)
    }
    
    // MARK: - Private Methods
    
    private func createWebSocketConnection() async throws {
        guard let url = URL(string: "\(baseURL)/ws") else {
            throw RealtimeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        
        // Add authentication headers
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start listening for messages
        await startListening()
        
        // Send initial authentication message
        await sendAuthenticationMessage()
        
        // Start heartbeat
        startHeartbeat()
        
        connectionStatus = .connected
        reconnectAttempts = 0
        
        print("✅ RealtimeService: Connected successfully")
    }
    
    private func startListening() async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            let message = try await webSocketTask.receive()
            await processMessage(message)
            
            // Continue listening if still connected
            if connectionStatus == .connected {
                await startListening()
            }
        } catch {
            print("❌ RealtimeService: Receive error: \(error)")
            await handleConnectionError(error)
        }
    }
    
    private func processMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            await processTextMessage(text)
        case .data(let data):
            await processDataMessage(data)
        @unknown default:
            print("⚠️ RealtimeService: Unknown message type received")
        }
    }
    
    private func processTextMessage(_ text: String) async {
        guard let data = text.data(using: .utf8) else { return }
        await processDataMessage(data)
    }
    
    private func processDataMessage(_ data: Data) async {
        do {
            let realtimeMessage = try JSONDecoder().decode(RealtimeMessage.self, from: data)
            await handleRealtimeMessage(realtimeMessage)
        } catch {
            print("❌ RealtimeService: Failed to decode message: \(error)")
        }
    }
    
    private func handleRealtimeMessage(_ message: RealtimeMessage) async {
        print("📥 RealtimeService: Received message: \(message.type)")
        
        switch message.type {
        case .liveUpdate:
            await handleLiveUpdate(message.data)
        case .userPresence:
            await handleUserPresence(message.data)
        case .notification:
            await handleRealtimeNotification(message.data)
        case .error:
            await handleServerError(message.data)
        case .pong:
            print("💓 RealtimeService: Heartbeat acknowledged")
        default:
            print("⚠️ RealtimeService: Unhandled message type: \(message.type)")
        }
    }
    
    private func handleLiveUpdate(_ data: [String: String]) async {
        guard let updateTypeString = data["type"],
              let updateType = UpdateType(rawValue: updateTypeString) else {
            return
        }
        
        let liveUpdate = LiveUpdate(
            id: UUID().uuidString,
            type: updateType,
            data: data,
            timestamp: Date()
        )
        
        liveUpdates.append(liveUpdate)
        
        // Keep only recent updates
        if liveUpdates.count > 100 {
            liveUpdates.removeFirst()
        }
        
        // Notify observers
        NotificationCenter.default.post(
            name: NSNotification.Name("RealtimeLiveUpdate"),
            object: liveUpdate
        )
        
        // Trigger haptic feedback for important updates
        if updateType.isImportant {
            HapticManager.shared.impact(.light)
        }
    }
    
    private func handleUserPresence(_ data: [String: String]) async {
        guard let userIds = data["activeUsers"]?.components(separatedBy: ",") else { return }
        activeUsers = Set(userIds)
        
        NotificationCenter.default.post(
            name: NSNotification.Name("RealtimeUserPresence"),
            object: activeUsers
        )
    }
    
    private func handleRealtimeNotification(_ data: [String: String]) async {
        // Handle real-time notifications
        NotificationCenter.default.post(
            name: NSNotification.Name("RealtimeNotification"),
            object: data
        )
        
        // Play notification sound and haptic feedback
        // SoundManager.shared.playNotificationSound()
    }
    
    private func handleServerError(_ data: [String: String]) async {
        if let errorMessage = data["message"] {
            print("❌ RealtimeService: Server error: \(errorMessage)")
        }
    }
    
    private func sendMessage(_ message: RealtimeMessage) async {
        guard connectionStatus == .connected else {
            print("⚠️ RealtimeService: Cannot send message, not connected")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            let webSocketMessage = URLSessionWebSocketTask.Message.data(data)
            try await webSocketTask?.send(webSocketMessage)
        } catch {
            print("❌ RealtimeService: Failed to send message: \(error)")
            await handleConnectionError(error)
        }
    }
    
    private func sendAuthenticationMessage() async {
        guard let token = await getAuthToken() else { return }
        
        let authMessage = RealtimeMessage(
            type: .authenticate,
            data: ["token": token]
        )
        await sendMessage(authMessage)
    }
    
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.sendHeartbeat()
            }
        }
    }
    
    private func sendHeartbeat() async {
        let heartbeatMessage = RealtimeMessage(
            type: .ping,
            data: ["timestamp": "\(Date().timeIntervalSince1970)"]
        )
        await sendMessage(heartbeatMessage)
    }
    
    private func handleConnectionError(_ error: Error) async {
        print("❌ RealtimeService: Connection error: \(error)")
        
        cleanupConnection()
        connectionStatus = .disconnected
        
        if !isIntentionalDisconnect {
            await scheduleReconnect()
        }
    }
    
    private func scheduleReconnect() async {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("❌ RealtimeService: Max reconnect attempts reached")
            return
        }
        
        isReconnecting = true
        reconnectAttempts += 1
        
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0) // Exponential backoff, max 30s
        
        print("🔄 RealtimeService: Scheduling reconnect in \(delay) seconds (attempt \(reconnectAttempts))")
        
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if !isIntentionalDisconnect {
            await connect()
        }
        
        isReconnecting = false
    }
    
    private func cleanupConnection() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                if path.status == .satisfied && self?.connectionStatus == .disconnected {
                    print("🌐 RealtimeService: Network available, attempting to reconnect")
                    await self?.connect()
                } else if path.status != .satisfied {
                    print("🌐 RealtimeService: Network unavailable")
                    self?.connectionStatus = .disconnected
                }
            }
        }
        monitor.start(queue: networkQueue)
    }
    
    private func setupAppStateObservers() {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    if self?.connectionStatus == .disconnected {
                        await self?.connect()
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.markUserAsActive()
                }
            }
            .store(in: &cancellables)
    }
    
    private func getAuthToken() async -> String? {
        // Mock token for now - would integrate with actual auth
        return "mock_jwt_token"
    }
}

// MARK: - Data Models

enum ConnectionStatus: String, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case reconnecting = "reconnecting"
    
    var displayName: String {
        switch self {
        case .disconnected: return "Offline"
        case .connecting: return "Connecting..."
        case .connected: return "Live"
        case .reconnecting: return "Reconnecting..."
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .reconnecting: return .blue
        }
    }
}

struct RealtimeMessage: Codable {
    let id: String
    let type: MessageType
    let data: [String: String]
    let timestamp: Date
    
    init(type: MessageType, data: [String: String]) {
        self.id = UUID().uuidString
        self.type = type
        self.data = data
        self.timestamp = Date()
    }
}

enum MessageType: String, Codable {
    case authenticate = "authenticate"
    case subscribe = "subscribe"
    case unsubscribe = "unsubscribe"
    case liveUpdate = "liveUpdate"
    case userPresence = "userPresence"
    case notification = "notification"
    case ping = "ping"
    case pong = "pong"
    case heartbeat = "heartbeat"
    case error = "error"
}

struct LiveUpdate: Identifiable {
    let id: String
    let type: UpdateType
    let data: [String: String]
    let timestamp: Date
}

enum UpdateType: String, CaseIterable {
    case newPost = "newPost"
    case newLike = "newLike"
    case newComment = "newComment"
    case newFollower = "newFollower"
    case newMessage = "newMessage"
    case postUpdated = "postUpdated"
    case userStatusChanged = "userStatusChanged"
    case achievementUnlocked = "achievementUnlocked"
    
    var isImportant: Bool {
        switch self {
        case .newMessage, .newFollower, .achievementUnlocked:
            return true
        default:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .newPost: return "New Post"
        case .newLike: return "New Like"
        case .newComment: return "New Comment"
        case .newFollower: return "New Follower"
        case .newMessage: return "New Message"
        case .postUpdated: return "Post Updated"
        case .userStatusChanged: return "User Status Changed"
        case .achievementUnlocked: return "Achievement Unlocked"
        }
    }
    
    var icon: String {
        switch self {
        case .newPost: return "photo"
        case .newLike: return "heart.fill"
        case .newComment: return "bubble.left"
        case .newFollower: return "person.badge.plus"
        case .newMessage: return "message.fill"
        case .postUpdated: return "pencil"
        case .userStatusChanged: return "person.crop.circle"
        case .achievementUnlocked: return "trophy.fill"
        }
    }
}

enum RealtimeError: Error {
    case invalidURL
    case authenticationFailed
    case connectionTimeout
    case serverError(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .authenticationFailed:
            return "Authentication failed"
        case .connectionTimeout:
            return "Connection timeout"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// MARK: - Real-time Connection Status View

struct RealtimeStatusView: View {
    @StateObject private var realtimeService = RealtimeService.shared
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(realtimeService.connectionStatus.color)
                .frame(width: 8, height: 8)
                .scaleEffect(realtimeService.connectionStatus == .connected ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), 
                          value: realtimeService.connectionStatus == .connected)
            
            Text(realtimeService.connectionStatus.displayName)
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onTapGesture {
            if realtimeService.connectionStatus == .disconnected {
                Task {
                    await realtimeService.connect()
                }
            }
        }
    }
}

// MARK: - Live Updates Feed View

struct LiveUpdatesFeedView: View {
    @StateObject private var realtimeService = RealtimeService.shared
    @State private var showAllUpdates = false
    
    var recentUpdates: [LiveUpdate] {
        Array(realtimeService.liveUpdates.suffix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Updates")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                RealtimeStatusView()
                
                if !recentUpdates.isEmpty {
                    Button(showAllUpdates ? "Show Less" : "Show All") {
                        withAnimation(.spring()) {
                            showAllUpdates.toggle()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.primaryBrand)
                }
            }
            
            if recentUpdates.isEmpty {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.secondaryText)
                    
                    Text("No live updates yet")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else {
                let updatesToShow = showAllUpdates ? realtimeService.liveUpdates : recentUpdates
                
                LazyVStack(spacing: 8) {
                    ForEach(updatesToShow, id: \.id) { update in
                        LiveUpdateCard(update: update)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct LiveUpdateCard: View {
    let update: LiveUpdate
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: update.type.icon)
                .font(.subheadline)
                .foregroundColor(update.type.isImportant ? .primaryBrand : .secondaryText)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(update.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
                
                if let message = update.data["message"] {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Text(update.timestamp, style: .relative)
                .font(.caption2)
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview("Realtime Status") {
    RealtimeStatusView()
}

#Preview("Live Updates Feed") {
    LiveUpdatesFeedView()
} 