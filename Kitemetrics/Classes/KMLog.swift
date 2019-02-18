//
//  KMLog.swift
//  Kitemetrics
//
//  Created by Kitefaster on 2/24/17.
//  Copyright © 2019 Kitefaster, LLC. All rights reserved.
//

import Foundation

class KMLog {
    
    static let debug = false
    
    static func p(_ message: String) {
        if KMLog.debug {
            print(message)
        }
    }
    
    static func forcePrint(_ message: String) {
        print(message)
    }
}
