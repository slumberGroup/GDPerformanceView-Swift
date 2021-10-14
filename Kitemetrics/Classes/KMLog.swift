//
//  KMLog.swift
//  Kitemetrics
//
//  Created by Kitemetrics on 2/24/17.
//  Copyright © 2021 Kitemetrics. All rights reserved.
//

import Foundation
import SwiftyBeaver

@objc
open class SwiftyBeaverCloudLoggingConfig: NSObject {
    let appID: String
    let appSecret: String
    let encryptionKey: String
    
    public init(appID: String, appSecret: String, encryptionKey: String) {
        self.appID = appID
        self.appSecret = appSecret
        self.encryptionKey = encryptionKey
    }
}

enum KMLog {
    
    static private let logger = SwiftyBeaver.self
    
    ///Setup logging
    static func setupLogging(config: SwiftyBeaverCloudLoggingConfig? = nil) {
        //SwiftyBeaver
        if let config = config {
            let platform = SBPlatformDestination(appID: config.appID,
                                                 appSecret: config.appSecret,
                                                 encryptionKey: config.encryptionKey) // log to cloud
            platform.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $C$L$c $M"
            KMLog.logger.addDestination(platform)
        }
        
        let console = ConsoleDestination()  // log to Xcode Console
        let file = FileDestination()  // log to default swiftybeaver.log file
        console.format = "$DHH:mm:ss.SSS$d $C$L$c $M"
        file.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $C$L$c $M"
        KMLog.logger.addDestination(console)
        KMLog.logger.addDestination(file)
    }
    
    static func p(_ message: String) {
        if KMUserDefaults.isDebug() {
            print("Kitemetrics: " + message)
            KMLog.logger.debug(message)
        }
    }
    
    static func forcePrint(_ message: String) {
        print("Kitemetrics: " + message)
    }
    
}
