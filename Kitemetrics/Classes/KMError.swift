//
//  KMError.swift
//  Kitemetrics
//
//  Created by Kitemetrics on 11/1/16.
//  Copyright © 2021 Kitemetrics. All rights reserved.
//

import Foundation

enum KMError {
    
    static let errorMessagesToIgnore = [
        "Error sending request. The Internet connection appears to be offline.",
        "Error sending request. The network connection was lost.",
        "Error sending request. An SSL error has occurred and a secure connection to the server cannot be made."
    ]
    
    static func logAsNSError(_ error: Error) {
        let nsError = error as NSError
        logErrorMessage(nsError.description)
    }
    
    static func logError(_ error: Error, sendToServer: Bool = true) {
        if sendToServer {
            KMError.logAsNSError(error)
        } else {
            KMError.logErrorMessage(error.localizedDescription, sendToServer: sendToServer)
        }
    }
    
    static func logErrorMessage(_ errorMessage: String, sendToServer: Bool = true) {
        KMLog.p("========== Kitemetrics ERROR: " + errorMessage)
        if sendToServer {
            if errorMessagesToIgnore.contains(errorMessage) == false {
                Kitemetrics.shared.postError(errorMessage, isInternal: true)
            }
        }
    }
    
    static func printError(_ errorMessage: String) {
        KMLog.forcePrint("========== Kitemetrics ERROR: " + errorMessage)
    }
    
    static func printWarning(_ errorMessage: String) {
        KMLog.forcePrint("========== Kitemetrics WARNING: " + errorMessage)
    }
    
    
}
