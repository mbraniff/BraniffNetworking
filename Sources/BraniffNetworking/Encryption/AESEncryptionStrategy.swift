//
//  AESEncryptionStrategy.swift
//  BraniffNetworking
//
//  Created by Matthew Braniff on 3/8/25.
//

import Foundation
import CryptoKit

@available(iOS 13.0.0, *)
public struct AESEncryptionStrategy: EncryptionStrategy {
    public var publicKey: SecKey
    public func encrypt(data: Data) throws -> Data {
        var error: Unmanaged<CFError>?
        let symmetricKey = SymmetricKey(size: .bits256)
        
        let paramPayload = try AES.GCM.seal(data, using: symmetricKey)
        
        guard let encryptedKey = SecKeyCreateEncryptedData(publicKey, .rsaEncryptionPKCS1, symmetricKey.withUnsafeBytes { Data($0) } as CFData, nil) as? Data,
              let encryptedIV = SecKeyCreateEncryptedData(publicKey, .rsaEncryptionPKCS1, paramPayload.nonce.withUnsafeBytes { Data($0) } as CFData, nil) as? Data,
              let encryptedTag = SecKeyCreateEncryptedData(publicKey, .rsaEncryptionPKCS1, paramPayload.tag as CFData, &error) as? Data else {
            if let error = error?.takeUnretainedValue() {
                throw EncryptionError(reason: .encryptionFailure(error))
            }
            throw EncryptionError(reason: .unknown)
        }
        
        return try JSONSerialization.data(withJSONObject: ["Key": encryptedKey.base64EncodedString(),
                                                           "IV": encryptedIV.base64EncodedString(),
                                                           "Tag": encryptedTag.base64EncodedString(),
                                                           "Data": paramPayload.ciphertext.base64EncodedString()])
    }
    
    public func decrypt(data: Data) throws -> Data {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: String],
              let base64DataString = payload["Data"],
              let rawData = Data(base64Encoded: base64DataString),
              let base64SignatureString = payload["Signature"],
              let signatureData = Data(base64Encoded: base64SignatureString) else { throw EncryptionError(reason: .couldNotDecrypt(data: data)) }
        
        let hash = Data(SHA256.hash(data: rawData))
        guard SecKeyVerifySignature(publicKey, .rsaSignatureDigestPKCS1v15SHA256, hash as NSData, signatureData as NSData, nil) else { throw EncryptionError(reason: .canNotValidate) }
        
        return rawData
    }
}

@available(iOS 13.0.0, *)
public extension EncryptionStrategy where Self == AESEncryptionStrategy {
    static func aes(publicKey: SecKey) -> AESEncryptionStrategy { AESEncryptionStrategy(publicKey: publicKey) }
}
