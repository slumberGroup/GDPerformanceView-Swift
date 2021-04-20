//
//  KMError.swift
//  Kitemetrics
//
//  Created by Kitemetrics on 11/1/16.
//  Copyright © 2021 Kitemetrics. All rights reserved.
//

import Foundation

class KMError {
    
    static let errorMessagesToIgnore = [
        "Error sending request. The Internet connection appears to be offline.",
        "Error sending request. The network connection was lost.",
        "Error sending request. An SSL error has occurred and a secure connection to the server cannot be made."
    ]
    
    class func logAsNSError(_ error: Error) {
        let nsError = error as NSError
        logErrorMessage(nsError.description)
    }
    
    class func logError(_ error: Error, sendToServer: Bool = true) {
        if sendToServer {
            KMError.logAsNSError(error)
        } else {
            KMError.logErrorMessage(error.localizedDescription, sendToServer: sendToServer)
        }
    }
    
    class func logErrorMessage(_ errorMessage: String, sendToServer: Bool = true) {
        KMLog.p("========== Kitemetrics ERROR: " + errorMessage)
        if sendToServer {
            if errorMessagesToIgnore.contains(errorMessage) == false {
                Kitemetrics.shared.postError(errorMessage, isInternal: true)
            }
        }
    }
    
    class func printError(_ errorMessage: String) {
        KMLog.forcePrint("========== Kitemetrics ERROR: " + errorMessage)
    }
    
    class func printWarning(_ errorMessage: String) {
        KMLog.forcePrint("========== Kitemetrics WARNING: " + errorMessage)
    }
    
    
}
