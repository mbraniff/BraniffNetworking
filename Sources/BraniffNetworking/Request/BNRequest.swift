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
    
    var name: String {
        switch self {
        case .delete:
            return "DELETE"
        case .get:
            return "GET"
        case .post:
            return "POST"
        case .put:
            return "PUT"
        }
    }
}

@available(iOS 13.0.0, *)
public protocol BNRequest {
    associatedtype ResponseType: Decodable
    var endpoint: String { get }
    var method: BNRequestMethod { get }
    var encrypted: Bool { get }
    var serial: Bool { get }
    func configureRequest(urlRequest: inout URLRequest)
}

@available(iOS 13.0.0, *)
public extension BNRequest {
    var method: BNRequestMethod { .get }
    var encrypted: Bool { true }
    var serial: Bool { false }
    
    func dataForParameters(_ parameters: [String: Any]) -> Data? {
        return try? JSONSerialization.data(withJSONObject: parameters)
    }
}
