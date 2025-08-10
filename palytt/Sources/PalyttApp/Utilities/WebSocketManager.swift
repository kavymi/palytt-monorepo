//
//  WebSocketManager.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import Combine

@MainActor
class WebSocketManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let messageSubject = PassthroughSubject<WebSocketMessage, Never>()
    
    enum ConnectionStatus {
        case disconnected, connecting, connected, error(Error)
    }
    
    struct WebSocketMessage: Codable {
        let type: String
        let chatroomId: String?
        let messageId: String?
        let senderId: String?
        let text: String?
        
        enum CodingKeys: CodingKey {
            case type, chatroomId, messageId, senderId, text
        }
    }
    
    override init() {
        super.init()
        setupURLSession()
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func connect(to url: URL) {
        guard webSocketTask == nil else { return }
        
        connectionStatus = .connecting
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
        
        // Send ping every 30 seconds to keep connection alive
        scheduleHeartbeat()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionStatus = .disconnected
        isConnected = false
    }
    
    func send(message: WebSocketMessage) async throws {
        guard let webSocketTask = webSocketTask else {
            throw WebSocketError.notConnected
        }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let message = URLSessionWebSocketTask.Message.data(data)
        
        try await webSocketTask.send(message)
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                switch result {
                case .success(let message):
                    await self.handleIncomingMessage(message)
                    // Continue receiving
                    self.receiveMessage()
                    
                case .failure(let error):
                    print("❌ WebSocket receive error: \(error)")
                    self.handleConnectionError(error)
                }
            }
        }
    }
    
    private func handleIncomingMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .data(let data):
            do {
                let decoder = JSONDecoder()
                let wsMessage = try decoder.decode(WebSocketMessage.self, from: data)
                messageSubject.send(wsMessage)
            } catch {
                print("❌ Failed to decode WebSocket message: \(error)")
            }
            
        case .string(let text):
            if let data = text.data(using: .utf8) {
                await handleIncomingMessage(.data(data))
            }
            
        @unknown default:
            print("❌ Unknown WebSocket message type")
        }
    }
    
    private func handleConnectionError(_ error: Error) {
        connectionStatus = .error(error)
        isConnected = false
        
        // Implement exponential backoff reconnection
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if case .error = connectionStatus {
                // Attempt reconnection logic here
            }
        }
    }
    
    private func scheduleHeartbeat() {
        Task {
            while webSocketTask != nil && isConnected {
                await withCheckedContinuation { continuation in
                    webSocketTask?.sendPing { error in
                        if let error = error {
                            print("❌ Heartbeat failed: \(error)")
                        }
                        continuation.resume()
                    }
                }
                
                try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
    }
    
    var messagePublisher: AnyPublisher<WebSocketMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    
    deinit {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
}

extension WebSocketManager: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @MainActor in
            isConnected = true
            connectionStatus = .connected
            print("✅ WebSocket connected with protocol: \(`protocol` ?? "none")")
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor in
            isConnected = false
            connectionStatus = .disconnected
            print("🔌 WebSocket disconnected with code: \(closeCode.rawValue)")
        }
    }
}

enum WebSocketError: Error {
    case notConnected
    case invalidMessage
    case encodingFailed
} 