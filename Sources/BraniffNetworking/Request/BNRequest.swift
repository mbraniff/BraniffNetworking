//
//  BNRequest.swift
//  BraniffNetworking
//
//  Created by Matthew Braniff on 3/8/25.
//

import Foundation

public enum BNRequestMethod {
    case get
    case post
    case put
    case delete
}

@available(iOS 13.0.0, *)
public protocol BNRequest {
    associatedtype ResponseType: Decodable
    var endpoint: String { get }
    var method: BNRequestMethod { get }
    var encrypted: Bool { get }
    func configureRequest(urlRequest: inout URLRequest)
}

@available(iOS 13.0.0, *)
extension BNRequest {
    var method: BNRequestMethod { .get }
    var encrypted: Bool { true }
}
