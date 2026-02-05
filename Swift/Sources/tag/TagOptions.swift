//
//  File.swift
//  tag
//
//  Created by Mark Edmunds on 2/1/26.
//

import Foundation
import ArgumentParser


struct TagOptions: ParsableArguments {
    @Option(name: .customLong("tag"), help: "Tag to add or remove depending on the subcommand used.") var tags: [String] = []
    @Argument var paths: [String] = ["."]
}
