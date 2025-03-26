//
//  Logging.swift
//  BraniffNetworking
//
//  Created by Matthew Braniff on 3/6/25.
//

import OSLog

@available(iOS 14.0.0, *)
extension Logger {
    private static var subsystem: String = "Braniff.Logging"
    
    static let networkError = Logger(subsystem: Self.subsystem, category: "NetworkError")
    static let bnLogs = Logger(subsystem: Self.subsystem, category: "Logs")
}
