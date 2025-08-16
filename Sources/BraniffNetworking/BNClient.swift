//
//  Client.swift
//
//
//  Created by Matthew Braniff on 1/26/25.
//

import Foundation
import CryptoKit
import OSLog
import BraniffNetworking

@available(iOS 13.0.0, *)
protocol BNRequestSender: AnyObject {
    func perform<R: BNRequest>(request: R) async throws -> R.ResponseType
}

public protocol BNRequestFailureHandler: AnyObject {
    func encryptionFailure(_ request: any BNRequest, _ reason: EncryptionError.Reason)
    func handleURLError(_ code: URLError.Code)
    func decodingFailure(_ request: any BNRequest, data: Data)
}

@available(iOS 14.0.0, *)
public final class BNClient: BNRequestSender {
    public class Config {
        var url: URL
        public var encryptionStrategy: EncryptionStrategy?
        var defaultRequestTimeout: TimeInterval
        var failureHandler: BNRequestFailureHandler?
        var serial: Bool
        
        public init(url: URL, encryptionStrategy: EncryptionStrategy? = nil, defaultRequestTimeout: TimeInterval = 60, failureHandler: BNRequestFailureHandler? = nil, serial: Bool = false) {
            self.url = url
            self.encryptionStrategy = encryptionStrategy
            self.defaultRequestTimeout = defaultRequestTimeout
            self.failureHandler = failureHandler
            self.serial = serial
        }
    }
    private var logger = Logger.bnLogs
    private lazy var mainSession: URLSession = URLSession(configuration: .default)
    private var config: Config
    private lazy var serialQueue = {
        var operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        return operationQueue
    }()
    
    public init(config: Config) {
        self.config = config
    }
    
    public func flush() {
        guard config.serial else { return }
        
        self.serialQueue.cancelAllOperations()
    }
    
    public func perform<R: BNRequest>(request: R) async throws -> R.ResponseType {
        guard config.serial else { return try await _perform(request: request) }
    
        return try await withCheckedThrowingContinuation { continuation in
            let operation = RequestOperation(request: request, client: self)
            
            operation.completionBlock = { [weak operation] in
                do {
                    guard let operation else {
                        continuation.resume(throwing: BNServiceError.unknown)
                        return
                    }
                    
                    let result = try operation.getResult()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            self.serialQueue.addOperation(operation)
        }
        
    }
    
    internal func _perform<R: BNRequest>(request: R) async throws -> R.ResponseType {
        let url = self.config.url.appendingPathComponent(request.endpoint)
        var urlRequest = URLRequest(url: url, timeoutInterval: self.config.defaultRequestTimeout)
        request.configureRequest(urlRequest: &urlRequest)
        urlRequest.httpMethod = request.method.name
        
        self.logRequest(urlRequest)
        
        if request.encrypted {
            guard self.config.encryptionStrategy != nil else { throw EncryptionError(reason: .noStrategy) }
            logger.info("Encrypting request body for \(String(describing: R.self))")
            try self.encrypt(&urlRequest)
        }
        
        var data: Data
        do {
            (data, _) = try await mainSession.data(for: urlRequest)
        } catch let e as URLError {
            config.failureHandler?.handleURLError(e.code)
            throw e
        }
        
        if request.encrypted {
            guard self.config.encryptionStrategy != nil else { throw EncryptionError(reason: .noStrategy) }
            logger.info("Decrypting response for \(String(describing: R.self))")
            do {
                data = try self.decrypt(data)
            } catch let e as EncryptionError {
                config.failureHandler?.encryptionFailure(request, e.reason)
                throw e
            }
        }
        
        self.logResponse(data)
        
        let decoder = JSONDecoder()
        
        var requestResponse: R.ResponseType
        do {
            requestResponse = try decoder.decode(R.ResponseType.self, from: data)
        } catch let e as DecodingError {
            config.failureHandler?.decodingFailure(request, data: data)
            throw e
        }
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
