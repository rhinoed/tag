//
//  TagManager.swift
//  tag
//
//  Created by Mark Edmunds on 1/27/26.
//

import Foundation
import AppKit
import ObjCTag

struct TagManager{
    
    static func getURL(for path: String) throws -> URL {
        var isDirectory: ObjCBool = false
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path){

            return URL(fileURLWithPath: path, isDirectory: false)
        }else if fileManager.fileExists(atPath: path, isDirectory: &isDirectory){
            return URL(fileURLWithPath: path, isDirectory: true)
        }else {
            throw TagManagerError.invalidPath("\(path) does not exist")
        }
    }
    
    static func getTags(for url: URL) throws -> URLResourceValues{
        let keys: Set<URLResourceKey> = [.tagNamesKey]
        return try url.resourceValues(forKeys: keys)
    }
    
    static func getTags(for path: String) throws -> [String] {
        let url = try TagManager.getURL(for: path)
        let keys: Set<URLResourceKey> = [.tagNamesKey]
        let resourceValues: URLResourceValues
        do{
            resourceValues = try url.resourceValues(forKeys: keys)
        }catch {
            throw error
        }
        if let tags = resourceValues.tagNames {
            
            return tags
        }else{
            return []
        }
    }
    
    static func setTags(_ tags: [String], on path: String, replace: Bool = false) throws {
        var existingTags = try TagManager.getTags(for: path)
        if replace {
            existingTags.removeAll()
        }
        existingTags.append(contentsOf: tags.filter({ !existingTags.contains($0) }))
        do {
            var url = try TagManager.getURL(for: path)
            var values = URLResourceValues()
            if #available(macOS 26.0, *) {
                values.tagNames = existingTags
            } else {
                // Fallback on earlier versions
                let objCManager = ObjCTag()
                objCManager.operationMode = .add
                objCManager.urls = [try TagManager.getURL(for: path)]
                objCManager.tags = getTagNameSetFor(tags: existingTags)
                objCManager.performOperation()
            }
            try url.setResourceValues(values)
        } catch {
            throw error
        }
    }
    
    static func match(tags: [String], in paths: [String]) throws -> [URL] {
        var matches: [URL] = []
        let fileManager = FileManager.default
        let tagsToMatch = Set(tags)
        let matchAny = tags.contains("*")
        
        for path in paths {
            // path is file
        guard fileManager.enumerator(at: URL(filePath: path), includingPropertiesForKeys: [.tagNamesKey])?.nextObject() != nil else {
            if matchAny || tagsToMatch.isSubset(of: try! getTags(for: path)) {
                matches.append(URL(fileURLWithPath: path))
            }
                continue
            }
            try enumerate(in: path)
//            let rootURL = try getURL(for: path)
//            let objcManager = ObjCTag()
//            objcManager.operationMode = .match
//            objcManager.tags = getTagNameSetFor(tags: tags)
//            objcManager.urls = [rootURL]
//            objcManager.enterDirectories = true
//            objcManager.recurseDirectories = true
//            objcManager.performOperation()
//            if let matched = objcManager.matched{
//                matches = matched as! [URL]
//            }
            // Function to check a single URL
//            func check(_ url: URL) {
//                do {
//                    let resourceValues = try url.resourceValues(forKeys: [.tagNamesKey])
//                    let fileTags = Set(resourceValues.tagNames ?? [])
//                    
//                    if matchAny {
//                        if !fileTags.isEmpty {
//                            matches.append(url.path)
//                        }
//                    } else {
//                        if !tagsToMatch.isEmpty && tagsToMatch.isSubset(of: fileTags) {
//                            matches.append(url.path)
//                        }
//                    }
//                } catch {
//                    // Ignore errors accessing resources
//                }
//            }
//            
//            // Check the root path itself
//            check(rootURL)
//            
//            // Recurse if it's a directory
//            let keys: [URLResourceKey] = [.tagNamesKey, .isDirectoryKey]
//            if let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: keys, options: []) {
//                for case let fileURL as URL in enumerator {
//                    check(fileURL)
//                }
//            }
        }
        return matches
    }
    
    static func enumerate(in paths: [String]) throws -> [String] {
        var allTags: Set<String> = []
        let fileManager = FileManager.default
        
        for path in paths {
            let rootURL = try getURL(for: path)
            
            func collect(_ url: URL) {
                if let resourceValues = try? url.resourceValues(forKeys: [.tagNamesKey]),
                   let tags = resourceValues.tagNames {
                    allTags.formUnion(tags)
                }
            }
            
            collect(rootURL)
            
            let keys: [URLResourceKey] = [.tagNamesKey]
            if let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: keys, options: []) {
                for case let fileURL as URL in enumerator {
                    collect(fileURL)
                }
            }
        }
        return Array(allTags).sorted()
    }
    
    static func removeTag(_ tag: String, from path: String) throws {
        var existingTags = try TagManager.getTags(for: path)
        existingTags.removeAll(where: { $0 == tag })
        do {
            var url = try TagManager.getURL(for: path)
            var values = URLResourceValues()
            if #available(macOS 26.0, *) {
                values.tagNames = existingTags
            } else {
                // Fallback on earlier version
                let objCManager = ObjCTag()
                objCManager.operationMode = .remove
                objCManager.urls = [try TagManager.getURL(for: path)]
                objCManager.tags = getTagNameSetFor(tags: [tag])
                objCManager.performOperation()
            }
            //var existingResource: URLResourceValues = try TagManager.getTags(for: url)
            try url.setResourceValues(values)
        } catch {
            throw error
        }
    }
    
    static func getTagNameSetFor(tags strings: [String]) -> Set<TagName> {
        guard !strings.isEmpty else { return [] }
        return Set(strings.compactMap { tag in
            TagName(tag: tag)
        })
    }
}


enum TagManagerError: Swift.Error {
    case invalidPath(String)
    case noResourceValues(String)
    case noTagsFound(String)
    case unableToSetTags(String)
    case unableToRemoveTag(String)
}

