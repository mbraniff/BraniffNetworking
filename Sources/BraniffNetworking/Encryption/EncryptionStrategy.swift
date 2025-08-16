//
//  File.swift
//  BraniffNetworking
//
//  Created by Matthew Braniff on 3/8/25.
//

import Foundation

public struct EncryptionError: Error {
    public enum Reason {
        case unknown
        case noStrategy
        case encryptionFailure(CFError)
        case canNotValidate
        case couldNotDecrypt(data: Data)
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
        case .canNotValidate:
            return "Can't validate data received"
        case .couldNotDecrypt:
            return "Can't decrypte data received"
        }
    }
}

public protocol EncryptionStrategy {
    func encrypt(data: Data) throws -> Data
    func decrypt(data: Data) throws -> Data
}
