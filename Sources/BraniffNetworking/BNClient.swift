//
//  Client.swift
//
//
//  Created by Matthew Braniff on 1/26/25.
//

import Foundation
import CryptoKit
import OSLog

@available(iOS 13.0.0, *)
protocol BNRequestSender: AnyObject {
    func perform<R: BNRequest>(request: R) async throws -> R.ResponseType
}

@available(iOS 14.0.0, *)
public final class BNClient: BNRequestSender {
    public struct Config {
        var url: URL
        var encryptionStrategy: EncryptionStrategy?
        var defaultRequestTimeout: TimeInterval
        
        public init(url: URL, encryptionStrategy: EncryptionStrategy? = nil, defaultRequestTimeout: TimeInterval = 60) {
            self.url = url
            self.encryptionStrategy = encryptionStrategy
            self.defaultRequestTimeout = defaultRequestTimeout
        }
    }
    private var logger = Logger.bnLogs
    private lazy var mainSession: URLSession = URLSession(configuration: .default)
    private var config: Config!
    
    internal static var shared: BNClient = BNClient()
    
    public func perform<R: BNRequest>(request: R) async throws -> R.ResponseType {
        let url = self.config.url.appendingPathComponent(request.endpoint)
        var urlRequest = URLRequest(url: url, timeoutInterval: self.config.defaultRequestTimeout)
        request.configureRequest(urlRequest: &urlRequest)
        
        self.logRequest(urlRequest)
        
        if request.encrypted {
            guard self.config.encryptionStrategy != nil else { throw EncryptionError(reason: .noStrategy) }
            logger.info("Encrypting request body for \(String(describing: R.self))")
            try self.encrypt(&urlRequest)
        }
        
        var (data, _) = try await mainSession.data(for: urlRequest)
        
        if request.encrypted {
            guard self.config.encryptionStrategy != nil else { throw EncryptionError(reason: .noStrategy) }
            logger.info("Decrypting response for \(String(describing: R.self))")
            data = try self.decrypt(data)
        }
        
        self.logResponse(data)
        
        let decoder = JSONDecoder()
        
        let requestResponse = try decoder.decode(R.ResponseType.self, from: data)
        return requestResponse
    }
    
    private func logRequest(_ request: URLRequest) {
        logger.info("""
        Processing Request: \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")
        
        Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")
        """
        )
    }
    
    private func logResponse(_ response: Data) {
        logger.info("""
        Received Response Body:
        \(String(data: response, encoding: .utf8) ?? "")
        """
        )
    }
    
    public static func configure(_ config: Config) {
        self.shared.config = config
    }
}

// Encryption Implementation
@available(iOS 14.0.0, *)
extension BNClient {
    private func encrypt(_ urlRequest: inout URLRequest) throws {
        guard let body = urlRequest.httpBody, let encryptionStrategy = self.config.encryptionStrategy else { return }
        let encryptedData = try encryptionStrategy.encrypt(data: body)
        urlRequest.httpBody = encryptedData
    }
    
    private func decrypt(_ data: Data) throws -> Data {
        guard let encryptionStrategy = self.config.encryptionStrategy else { throw EncryptionError(reason: .noStrategy) }
        let decryptedData = try encryptionStrategy.decrypt(data: data)
        return decryptedData
    }
}
