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

public protocol BNRequestFailureHandler: AnyObject {
    func encryptionFailure(_ request: any BNRequest, _ reason: EncryptionError.Reason)
    func handleURLError(_ code: URLError.Code)
    func decodingFailure(_ request: any BNRequest, data: Data)
}

@available(iOS 14.0.0, *)
public final class BNClient: BNRequestSender, @unchecked Sendable {
    public class Config {
        var url: URL
        public var encryptionStrategy: EncryptionStrategy?
        var defaultRequestTimeout: TimeInterval
        var failureHandler: BNRequestFailureHandler?
        var decoder: JSONDecoder
        var loggingEnabled: Bool
        
        public init(
            url: URL,
            encryptionStrategy: EncryptionStrategy? = nil,
            defaultRequestTimeout: TimeInterval = 60,
            failureHandler: BNRequestFailureHandler? = nil,
            decoder: JSONDecoder? = nil,
            loggingEnabled: Bool = true
        ) {
            self.url = url
            self.encryptionStrategy = encryptionStrategy
            self.defaultRequestTimeout = defaultRequestTimeout
            self.failureHandler = failureHandler
            self.decoder = decoder ?? JSONDecoder()
            self.loggingEnabled = loggingEnabled
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
    private lazy var concurrentQueue = OperationQueue()
    internal var queueSemaphore = DispatchSemaphore(value: 1)
    
    public init(config: Config) {
        self.config = config
    }
    
    public func flush() {
        self.concurrentQueue.cancelAllOperations()
        self.serialQueue.cancelAllOperations()
        self.queueSemaphore = DispatchSemaphore(value: 1)
    }
    
    public func perform<R: BNRequest>(request: R) async throws -> R.ResponseType {
        guard request.serial else { return try await performAsync(request: request) }
    
        return try await performSerial(request: request)
    }
    
    internal func performAsync<R: BNRequest>(request: R) async throws -> R.ResponseType {
        return try await withCheckedThrowingContinuation { continuation in
            concurrentQueue.addOperation {
                self.queueSemaphore.wait()
                self.queueSemaphore.signal()
                Task {
                    do {
                        continuation.resume(returning: try await self._perform(request: request))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    internal func performSerial<R: BNRequest>(request: R) async throws -> R.ResponseType {
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
        
        Task {
            await self.logRequest(urlRequest)
        }
        
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
        
        Task {
            await self.logResponse(data)
        }
        
        let decoder = self.config.decoder
        
        var requestResponse: R.ResponseType
        do {
            requestResponse = try decoder.decode(R.ResponseType.self, from: data)
        } catch let e as DecodingError {
            config.failureHandler?.decodingFailure(request, data: data)
            throw e
        }
        return requestResponse
    }
    
    @concurrent
    private func logRequest(_ request: URLRequest) async {
        logger.info("""
        Processing Request: \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")
        
        Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")
        """
        )
    }
    
    @concurrent
    private func logResponse(_ response: Data) async {
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
