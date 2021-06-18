//
//  KMLog.swift
//  Kitemetrics
//
//  Created by Kitemetrics on 2/24/17.
//  Copyright © 2021 Kitemetrics. All rights reserved.
//

import Foundation

enum KMLog {
    
    static func p(_ message: String) {
        if KMUserDefaults.isDebug() {
            print("Kitemetrics: " + message)
        }
    }
    
    static func forcePrint(_ message: String) {
        print("Kitemetrics: " + message)
    }
    
}
