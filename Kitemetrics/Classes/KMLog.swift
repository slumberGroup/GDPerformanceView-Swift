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
        
    static func p(_ message: String) {
        if KMUserDefaults.isDebug() == true {
            print("Kitemetrics: " + message)
            KMLog.logger.debug(message)
        }
    }
    
    static func forcePrint(_ message: String) {
        print("Kitemetrics: " + message)
    }
    
}