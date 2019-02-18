//
//  KMString.swift
//  Kitemetrics
//
//  Created by Kitefaster on 11/2/16.
//  Copyright © 2019 Kitefaster, LLC. All rights reserved.
//

import Foundation


extension String {
    
    func truncate(_ length: Int) -> String {
        if self.count > length {
            let index = self.index(self.startIndex, offsetBy: length)
            let newString = String(self[...index])
            return newString
        }
        
        return self
    }
    
}
