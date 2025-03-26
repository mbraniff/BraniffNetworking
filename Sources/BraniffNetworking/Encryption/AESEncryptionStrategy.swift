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
        guard let aesObject = try JSONSerialization.jsonObject(with: data) as? [String: String],
              let keyString = aesObject["Key"],
              let keyData = Data(base64Encoded: keyString),
              let key = SecKeyCreateDecryptedData(publicKey, .rsaEncryptionPKCS1, keyData as CFData, nil),
              let inputVectorString = aesObject["IV"],
              let inputVectorData = Data(base64Encoded: inputVectorString),
              let inputVector = SecKeyCreateDecryptedData(publicKey, .rsaEncryptionPKCS1, inputVectorData as CFData, nil),
              let tagString = aesObject["Tag"],
              let tagData = Data(base64Encoded: tagString),
              let tag = SecKeyCreateDecryptedData(publicKey, .rsaEncryptionPKCS1, tagData as CFData, nil),
              let dataString = aesObject["Data"],
              let data = Data(base64Encoded: dataString) else { throw EncryptionError(reason: .unknown) }
        let symmetricKey = SymmetricKey(data: key as Data)
        let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: inputVector as Data), ciphertext: data, tag: tag as Data)
        
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
//            if let string = String(data: decryptedData, encoding: .utf8), let data = Data(base64Encoded: string.trimmingCharacters(in: ["\""])) {
//                return data
//            }
        return decryptedData
    }
}

@available(iOS 13.0.0, *)
public extension EncryptionStrategy where Self == AESEncryptionStrategy {
    static func aes(publicKey: SecKey) -> AESEncryptionStrategy { AESEncryptionStrategy(publicKey: publicKey) }
}
