//
//  File.swift
//  BraniffNetworking
//
//  Created by Matthew Braniff on 3/6/25.
//

#if canImport(Combine)
import Foundation
import Combine

@available(iOS 14.0.0, *)
extension BNBaseService {
    public func queueRequestPublisher<R: BNRequest>(_ request: R) -> AnyPublisher<R.ResponseType, BNServiceError> {
        let subject = PassthroughSubject<R.ResponseType, BNServiceError>()
        
        Task { [subject] in
            do {
                let requestSender = BNBaseService.defaultSender
                let response = try await requestSender.perform(request: request)
                subject.send(response)
                return
            } catch let e as URLError {
                logger.error("Failed to process URL for request: \(String(describing: R.self))\n\(dump(e))")
            } catch let e as DecodingError {
                logger.error("Failed to decode response for request: \(String(describing: R.self))\nReason: \(e.failureReason ?? e.localizedDescription)")
            } catch let e {
                logger.error("Unknown error occured while performing request: \(String(describing: R.self))\nDescription: \(e.localizedDescription)")
            }
            subject.send(completion: .failure(BNServiceError()))
        }
        return subject.first().eraseToAnyPublisher()
    }
}
#endif
