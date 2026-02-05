// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import Foundation
import ObjCTag

@main
struct Tag: ParsableCommand {
    static let configuration: CommandConfiguration = CommandConfiguration(
        commandName: "tag",
        abstract: "Commmand line to list, add, or remove tags on files and directories.",
        discussion: "",
        subcommands: [List.self, Remove.self, Add.self, Match.self, Enumerate.self, Completion.self],
        defaultSubcommand: List.self
    )
    
    mutating func run() throws {
        
    }
}

struct List: ParsableCommand{
    static let configuration: CommandConfiguration = CommandConfiguration(
        commandName: "list",
        abstract: "List all tags applied to the current directory.",
    
    )
    @Argument var paths: [String] = ["."]
    mutating func run() throws {
        for path in paths {
            let tags = try TagManager.getTags(for: path)
            if !tags.isEmpty {
                for tag in tags {
                    print("\(tag)")
                }
            }else{
                print("No tags found.")
            }
        }
    }
}

struct Remove: ParsableCommand{
    static let configuration: CommandConfiguration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove a tag from the current directory.",
        discussion: "This command can be used to remove a specific set of tag(s) or to remove all tags from a file or directory."
    )
    @OptionGroup var tagOptions: TagOptions
    @Flag(name: .shortAndLong, help: "Delete all tags from the current file or directory.") var all: Bool = false
    mutating func run() throws {
        if !tagOptions.tags.isEmpty && !all {
            for tag in tagOptions.tags {
                for path in tagOptions.paths{
                    try TagManager.removeTag(tag, from: path)
                }
            }
        }else if !tagOptions.tags.isEmpty && all{
            for path in tagOptions.paths{
                let tags = try TagManager.getTags(for: path)
                for tag in tags{
                    try TagManager.removeTag(tag, from: path)
                }
            }
        }else {
            print("No tags marked for removal.")
        }
    }
}

struct Add: ParsableCommand{
    static let configuration: CommandConfiguration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a tag to the current file or directory.",
        discussion: "This command can be used to add a specific set of tag(s) or to add a tag to a file or directory."
    )
    @OptionGroup var tagOptions: TagOptions
    //@Option(name: .customLong("tag"), help: "Tag to add.") var tags: [String] = []
    @Flag(name: .shortAndLong, help: "Replace all existing tags if any are present") var replacingAll: Bool = false
    //@Argument var paths: [String] = ["."]
    
    mutating func run() throws {
        for path in tagOptions.paths{
            do{
                try TagManager.setTags(tagOptions.tags, on: path, replace: replacingAll)
            }catch{
                throw error
            }
        }
        
    }
}

struct Enumerate: ParsableCommand{
    static let configuration: CommandConfiguration = CommandConfiguration(
        commandName: "enumerate",
        abstract: "Enumerate all tags across all files and directories in a given path or paths.",
        discussion: "This command can be used to enumerate all tags across all files and directories in a given path or paths."
    )
    @Argument var paths: [String] = ["."]
    
    mutating func run() throws {
        let tags = try TagManager.enumerate(in: paths)
        if tags.isEmpty {
            print("No tags found.")
        } else {
            for tag in tags {
                print("\(tag)")
            }
        }
    }
}

struct Match: ParsableCommand{
    static let configuration: CommandConfiguration = CommandConfiguration(
        commandName: "match",
        abstract: "List all files and directories that have a given tag or set of tags.",
        discussion: "This command can be used to list all files and directories that have a given tag."
    )
    @Option(name: .customLong("tag"), help: "Tag to match.") var tags: [String] = []
    @Argument var paths: [String] = ["."]
    
    mutating func run() throws {
        let matches = try TagManager.match(tags: tags, in: paths)
        if matches.isEmpty {
            print("No matches found.")
        } else {
            for match in matches {
                print("\(match)")
            }
        }
    }
}

struct Completion: ParsableCommand{
    static let configuration: CommandConfiguration = CommandConfiguration(
        commandName: "completion",
        abstract: "Generate a completion script for your text editor.",
        discussion: "This command can be used to generate a completion script for your text editor."
    )
    mutating func run() throws {
        // Check for completion script file
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: "/usr/local/share/zsh/site-functions/_tag"){
            // create file _tag
            let templateString = Tag.completionScript(for: .zsh)
            let templateData = templateString.data(using: .utf8)!
            fileManager.createFile(atPath: "/usr/local/share/zsh/site-functions/_tag", contents: templateData, attributes: nil)
        }
    }
}


