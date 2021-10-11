//
//  KMLog.swift
//  Kitemetrics
//
//  Created by Kitemetrics on 2/24/17.
//  Copyright © 2021 Kitemetrics. All rights reserved.
//

import Foundation
import SwiftyBeaver

enum KMLog {
    
    static private let logger = SwiftyBeaver.self
    
    ///Setup logging
    static func setupLogging() {
        //SwiftyBeaver
        let platform = SBPlatformDestination(appID: "XWx2Jv",
                                             appSecret: "freh8gasmVEwctxraf1ouxwlqodidz5U",
                                             encryptionKey: "usvtXgrwjw71rtvhpjvaaqesmrodmevm") // log to cloud
        let console = ConsoleDestination()  // log to Xcode Console
        let file = FileDestination()  // log to default swiftybeaver.log file
        console.format = "$DHH:mm:ss.SSS$d $C$L$c $M"
        file.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $C$L$c $M"
        platform.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $C$L$c $M"
        KMLog.logger.addDestination(platform)
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
