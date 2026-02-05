//
//  File.swift
//  tag
//
//  Created by Mark Edmunds on 2/1/26.
//

import Foundation
import ObjCTag
import AppKit

struct FolderPropertyManager{
    var url: URL
    
    func hasCustomIcon() throws -> Bool {
        let keys: Set<URLResourceKey> = Set([.customIconKey])
        
        let customIconKey = try url.resourceValues(forKeys: keys)
        if customIconKey.customIcon != nil{
            return true
        }else{
            return false
        }
    }
    
    func getCustonIcon() throws -> NSImage? {
        let keys: Set<URLResourceKey> = Set([.customIconKey])
        
        let customIconKey = try url.resourceValues(forKeys: keys)
        guard let customIcon = customIconKey.customIcon else {
            return nil
        }
        return customIcon
    }
}
