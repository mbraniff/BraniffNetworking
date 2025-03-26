//
//  File.swift
//  BraniffNetworking
//
//  Created by Matthew Braniff on 3/8/25.
//

import Foundation

internal struct EncryptionError: Error {
    enum Reason {
        case unknown
        case noStrategy
        case encryptionFailure(CFError)
    }
    var reason: Reason
    
    var localizedDescription: String {
        switch self.reason {
        case .unknown:
            return "Unknown encryption error"
        case .noStrategy:
            return "No strategy set for encryption"
        case let .encryptionFailure(error):
            return error.localizedDescription
        }
    }
}

public protocol EncryptionStrategy {
    func encrypt(data: Data) throws -> Data
    func decrypt(data: Data) throws -> Data
}
