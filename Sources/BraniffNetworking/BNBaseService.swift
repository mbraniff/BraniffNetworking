//
//  BNBaseService.swift
//
//
//  Created by Matthew Braniff on 1/26/25.
//

import Foundation
import OSLog

public struct BNServiceError: Error {}

@available(iOS 14.0.0, *)
open class BNBaseService {
    internal var logger = Logger.networkError
    
    public init(){}
    
    public func queueRequest<R: BNRequest>(_ request: R) async -> Result<R.ResponseType, BNServiceError> {
        do {
            let requestSender = BNClient.shared
            return try await .success(requestSender.perform(request: request))
        } catch let e as URLError {
            self.logger.error("Failed to process URL for request: \(String(describing: R.self))\n\(dump(e))")
        } catch let e as DecodingError {
            self.logger.error("Failed to decode response for request: \(String(describing: R.self))\nReason: \(e.failureReason ?? e.localizedDescription)")
        } catch let e {
            self.logger.error("Unknown error occured while performing request: \(String(describing: R.self))\nDescription: \(e.localizedDescription)")
        }
        return .failure(BNServiceError())
    }
    
    public func queueRequest<R: BNRequest>(_ request: R, completion: ((Result<R.ResponseType, BNServiceError>) -> Void)?) {
        Task {
            do {
                let requestSender = BNClient.shared
                let response = try await requestSender.perform(request: request)
                completion?(.success(response))
                return
            } catch let e as URLError {
                logger.error("Failed to process URL for request: \(String(describing: R.self))\n\(dump(e))")
            } catch let e as DecodingError {
                logger.error("Failed to decode response for request: \(String(describing: R.self))\nReason: \(e.failureReason ?? e.localizedDescription)")
            } catch let e {
                logger.error("Unknown error occured while performing request: \(String(describing: R.self))\nDescription: \(e.localizedDescription)")
            }
            completion?(.failure(BNServiceError()))
        }
    }
}

@available(iOS 14.0.0, *)
extension BNBaseService {
    private static var _defaultSender: BNRequestSender?
    private static var lock = DispatchQueue(label: "BNBaseServie.lock")
    
    internal static var defaultSender: BNRequestSender {
        get {
            lock.sync {
                guard let sender = self._defaultSender else { fatalError("Client not set before intializing service") }
                return sender
            }
        }
    }
    
    public static func setDefaultClient(_ client: BNClient) {
        self._defaultSender = client
    }
}
