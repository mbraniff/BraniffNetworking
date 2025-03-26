//
//  RSAEncryptionStrategy.swift
//  BraniffNetworking
//
//  Created by Matthew Braniff on 3/8/25.
//

import Foundation
import CryptoKit

public struct RSAEncryptionStrategy: EncryptionStrategy {
    var publicKey: SecKey
    public func encrypt(data: Data) throws -> Data {
        var error: Unmanaged<CFError>?
        let encryptedData = SecKeyCreateEncryptedData(publicKey, .rsaEncryptionPKCS1, data as CFData, &error)
        
        guard let encryptedData, error == nil else {
            if let error = error?.takeUnretainedValue() {
                throw EncryptionError(reason: .encryptionFailure(error))
            }
            throw EncryptionError(reason: .unknown)
        }
        return encryptedData as Data
    }
    
    public func decrypt(data: Data) throws -> Data {
        var error: Unmanaged<CFError>?
        let decryptedData = SecKeyCreateDecryptedData(publicKey, .rsaEncryptionPKCS1, data as CFData, &error)
        
        guard let decryptedData, error == nil else {
            if let error = error?.takeUnretainedValue() {
                throw EncryptionError(reason: .encryptionFailure(error))
            }
            throw EncryptionError(reason: .unknown)
        }
        return decryptedData as Data
    }
}

public extension EncryptionStrategy where Self == RSAEncryptionStrategy {
    static func rsa(publicKey: SecKey) -> RSAEncryptionStrategy { RSAEncryptionStrategy(publicKey: publicKey) }
}
