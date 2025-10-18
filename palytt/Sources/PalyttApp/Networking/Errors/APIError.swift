//
//  APIError.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

/// Standardized API error types for the application
enum APIError: LocalizedError, Equatable {
    // Network Errors
    case networkError(URLError)
    case connectionLost
    case timeout
    
    // Server Errors
    case serverError(statusCode: Int, message: String?)
    case internalServerError
    case serviceUnavailable
    
    // Client Errors
    case badRequest(message: String?)
    case unauthorized
    case forbidden
    case notFound(resource: String?)
    case conflict(message: String?)
    case tooManyRequests
    
    // Data Errors
    case decodingError(DecodingError)
    case encodingError(EncodingError)
    case invalidResponse
    case invalidData
    
    // Business Logic Errors
    case validationError(errors: [String])
    case resourceLimitExceeded(limit: String)
    case operationNotAllowed(reason: String)
    
    // Authentication Errors
    case tokenExpired
    case invalidToken
    case authenticationRequired
    
    // Unknown
    case unknown(Error)
    
    // MARK: - LocalizedError
    
    var errorDescription: String? {
        switch self {
        // Network Errors
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .connectionLost:
            return "Connection lost. Please check your internet connection."
        case .timeout:
            return "Request timed out. Please try again."
            
        // Server Errors
        case .serverError(let code, let message):
            return message ?? "Server error (\(code))"
        case .internalServerError:
            return "An internal server error occurred. Please try again later."
        case .serviceUnavailable:
            return "Service is currently unavailable. Please try again later."
            
        // Client Errors
        case .badRequest(let message):
            return message ?? "Invalid request"
        case .unauthorized:
            return "Please sign in to continue"
        case .forbidden:
            return "You don't have permission to perform this action"
        case .notFound(let resource):
            return resource != nil ? "\(resource!) not found" : "The requested resource was not found"
        case .conflict(let message):
            return message ?? "A conflict occurred with the current state"
        case .tooManyRequests:
            return "Too many requests. Please try again later"
            
        // Data Errors
        case .decodingError(let error):
            return "Invalid data received from server: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response received from server"
        case .invalidData:
            return "Invalid data format"
            
        // Business Logic Errors
        case .validationError(let errors):
            return errors.isEmpty ? "Validation failed" : errors.joined(separator: "\n")
        case .resourceLimitExceeded(let limit):
            return "You've exceeded the \(limit) limit"
        case .operationNotAllowed(let reason):
            return reason
            
        // Authentication Errors
        case .tokenExpired:
            return "Your session has expired. Please sign in again"
        case .invalidToken:
            return "Invalid authentication token"
        case .authenticationRequired:
            return "Authentication required to perform this action"
            
        // Unknown
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .networkError(let error):
            return error.localizedDescription
        case .decodingError(let error):
            return error.localizedDescription
        case .encodingError(let error):
            return error.localizedDescription
        case .unknown(let error):
            return error.localizedDescription
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .connectionLost, .timeout:
            return "Check your internet connection and try again"
        case .unauthorized, .tokenExpired, .authenticationRequired:
            return "Please sign in to continue"
        case .tooManyRequests:
            return "Wait a few moments before trying again"
        case .serviceUnavailable, .internalServerError:
            return "Please try again in a few moments"
        default:
            return nil
        }
    }
    
    // MARK: - Equatable
    
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError(let lError), .networkError(let rError)):
            return lError.code == rError.code
        case (.connectionLost, .connectionLost),
             (.timeout, .timeout),
             (.internalServerError, .internalServerError),
             (.serviceUnavailable, .serviceUnavailable),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.invalidResponse, .invalidResponse),
             (.invalidData, .invalidData),
             (.tokenExpired, .tokenExpired),
             (.invalidToken, .invalidToken),
             (.authenticationRequired, .authenticationRequired),
             (.tooManyRequests, .tooManyRequests):
            return true
        case (.serverError(let lCode, let lMsg), .serverError(let rCode, let rMsg)):
            return lCode == rCode && lMsg == rMsg
        case (.badRequest(let lMsg), .badRequest(let rMsg)):
            return lMsg == rMsg
        case (.notFound(let lRes), .notFound(let rRes)):
            return lRes == rRes
        case (.conflict(let lMsg), .conflict(let rMsg)):
            return lMsg == rMsg
        case (.validationError(let lErrors), .validationError(let rErrors)):
            return lErrors == rErrors
        case (.resourceLimitExceeded(let lLimit), .resourceLimitExceeded(let rLimit)):
            return lLimit == rLimit
        case (.operationNotAllowed(let lReason), .operationNotAllowed(let rReason)):
            return lReason == rReason
        default:
            return false
        }
    }
}

// MARK: - Error Mapping

extension APIError {
    /// Map HTTP status code to APIError
    static func from(statusCode: Int, message: String? = nil) -> APIError {
        switch statusCode {
        case 400:
            return .badRequest(message: message)
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound(resource: nil)
        case 409:
            return .conflict(message: message)
        case 429:
            return .tooManyRequests
        case 500:
            return .internalServerError
        case 503:
            return .serviceUnavailable
        case 400..<500:
            return .serverError(statusCode: statusCode, message: message)
        case 500..<600:
            return .serverError(statusCode: statusCode, message: message)
        default:
            return .unknown(NSError(domain: "APIError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message ?? "Unknown error"]))
        }
    }
    
    /// Map generic Error to APIError
    static func from(_ error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timeout
            case .notConnectedToInternet, .networkConnectionLost:
                return .connectionLost
            default:
                return .networkError(urlError)
            }
        }
        
        if let decodingError = error as? DecodingError {
            return .decodingError(decodingError)
        }
        
        if let encodingError = error as? EncodingError {
            return .encodingError(encodingError)
        }
        
        return .unknown(error)
    }
}

// MARK: - Analytics Integration

extension APIError {
    /// Error code for analytics tracking
    var analyticsCode: String {
        switch self {
        case .networkError:
            return "network_error"
        case .connectionLost:
            return "connection_lost"
        case .timeout:
            return "timeout"
        case .serverError(let code, _):
            return "server_error_\(code)"
        case .internalServerError:
            return "internal_server_error"
        case .serviceUnavailable:
            return "service_unavailable"
        case .badRequest:
            return "bad_request"
        case .unauthorized:
            return "unauthorized"
        case .forbidden:
            return "forbidden"
        case .notFound:
            return "not_found"
        case .conflict:
            return "conflict"
        case .tooManyRequests:
            return "too_many_requests"
        case .decodingError:
            return "decoding_error"
        case .encodingError:
            return "encoding_error"
        case .invalidResponse:
            return "invalid_response"
        case .invalidData:
            return "invalid_data"
        case .validationError:
            return "validation_error"
        case .resourceLimitExceeded:
            return "resource_limit_exceeded"
        case .operationNotAllowed:
            return "operation_not_allowed"
        case .tokenExpired:
            return "token_expired"
        case .invalidToken:
            return "invalid_token"
        case .authenticationRequired:
            return "authentication_required"
        case .unknown:
            return "unknown_error"
        }
    }
    
    /// Whether this error should be reported to error tracking
    var shouldReport: Bool {
        switch self {
        case .unauthorized, .forbidden, .notFound, .validationError:
            return false // User errors, don't report
        case .timeout, .connectionLost:
            return false // Network conditions, don't report
        default:
            return true // Server/unexpected errors, report
        }
    }
}

