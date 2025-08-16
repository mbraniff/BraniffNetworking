//
//  RequestOperation.swift
//  BraniffNetworking
//
//  Created by Matthew Braniff on 8/15/25.
//

import Foundation

class RequestOperation<R: BNRequest>: Operation {
    private let request: R
    private let client: BNClient
    private var result: Result<R.ResponseType, Error>?
    
    init(request: R, client: BNClient) {
        self.request = request
        self.client = client
        super.init()
    }
    
    override func main() {
        guard !isCancelled else {
            result = .failure(CancellationError())
            return
        }
        
        // Run the async _perform method synchronously
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                let response = try await client._perform(request: request)
                result = .success(response)
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
    }
    
    // Method to get the result after completion
    func getResult() throws -> R.ResponseType {
        guard let result = result else {
            throw CancellationError() // Fallback for cancelled or unexecuted operations
        }
        return try result.get()
    }
}
