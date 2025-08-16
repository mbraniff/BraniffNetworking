//
//  BNBaseService.swift
//
//
//  Created by Matthew Braniff on 1/26/25.
//

import Foundation
import OSLog

public enum BNServiceError: Error {
    case unknown
    case urlError
    case decodingError
    case cancelled
}

@available(iOS 14.0.0, *)
open class BNBaseService {
    internal var logger = Logger.networkError
    internal var sender: BNRequestSender
    
    public init(client: BNClient) {
        self.sender = client
    }
    
    public func queueRequest<R: BNRequest>(_ request: R) async -> Result<R.ResponseType, BNServiceError> {
        do {
            return try await .success(self.sender.perform(request: request))
        } catch let e as URLError {
            self.logger.error("Failed to process URL for request: \(String(describing: R.self))\n\(dump(e))")
            return .failure(.urlError)
        } catch let e as DecodingError {
            self.logger.error("Failed to decode response for request: \(String(describing: R.self))\nReason: \(e.failureReason ?? e.localizedDescription)")
            return .failure(.decodingError)
        } catch let e as CancellationError {
            self.logger.error("Failed to perform request(\(String(describing: R.self)) because it was cancelled")
            return .failure(.cancelled)
        } catch let e {
            self.logger.error("Unknown error occured while performing request: \(String(describing: R.self))\nDescription: \(e.localizedDescription)")
        }
        return .failure(.unknown)
    }
    
    public func queueRequest<R: BNRequest>(_ request: R, completion: ((Result<R.ResponseType, BNServiceError>) -> Void)?) {
        Task {
            do {
                let response = try await self.sender.perform(request: request)
                completion?(.success(response))
                return
            } catch let e as URLError {
                logger.error("Failed to process URL for request: \(String(describing: R.self))\n\(dump(e))")
                completion?(.failure(.urlError))
                return
            } catch let e as DecodingError {
                logger.error("Failed to decode response for request: \(String(describing: R.self))\nReason: \(e.failureReason ?? e.localizedDescription)")
                completion?(.failure(.decodingError))
                return
            } catch let e as CancellationError {
                self.logger.error("Failed to perform request(\(String(describing: R.self)) because it was cancelled")
                completion?(.failure(.cancelled))
                return
            } catch let e {
                logger.error("Unknown error occured while performing request: \(String(describing: R.self))\nDescription: \(e.localizedDescription)")
            }
            completion?(.failure(.unknown))
        }
    }
}
