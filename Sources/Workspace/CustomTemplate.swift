/*
 This source file is part of the Swift.org open source project
 
 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception
 
 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Create an initial template package.
public final class CustomTemplate {
    
    /// Where to crerate the new package.
    let destinationPath: String
    
    /// Where to get the template.
    let sourcePath: String 
    
    /// Package name
    let pkgName: String 
    
    /// Create an instance that can create a package with given arguments.
    public init(name: String, sourcePath: String, destinationPath: String) throws {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.pkgName = name
    }
    
    /// Copy contents of the sourcePath to the destinationPath. 
    public func copy() throws {
        let fileManager = FileManager.default
        do {
            let fileList = try fileManager.contentsOfDirectory(atPath: sourcePath)
            try? fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
            
            // Get the list of all targets froms Sources dir.
            let targetList = try fileManager.contentsOfDirectory(atPath: "\(sourcePath)/Sources/")
            // Determine what the old package name was.
            let sourceDirList = sourcePath.components(separatedBy: "/").filter{$0 != ""}
            let originalPackageName = sourceDirList[sourceDirList.count-1]
            
            for fileName in fileList {
                try? fileManager.copyItem(atPath: "\(sourcePath)/\(fileName)", toPath: "\(destinationPath)/\(fileName)")
                var isDirectory = ObjCBool(true)
                _ = FileManager.default.fileExists(atPath: "\(sourcePath)/\(fileName)", isDirectory: &isDirectory)
                if fileName == "Package.swift" {
                    // Make changes to manifest.
                    try amendManifestTargets(targets: targetList, manifest: "\(destinationPath)/\(fileName)", sourcePath: sourcePath)
                    // Change the package name from the old to new one in the new manifest. 
                    searchAndReplace(pattern: originalPackageName, replacement: pkgName, file: "\(destinationPath)/\(fileName)")
                }
                if !isDirectory.boolValue {
                    // Replace the package name.
                    searchAndReplace(pattern: "__PACKAGE_NAME__", replacement: pkgName, file: "\(destinationPath)/\(fileName)")
                    searchAndReplace(pattern: "__TARGET_NAME__", replacement: pkgName, file: "\(destinationPath)/\(fileName)")
                } 
            }
            
            // Make changes to test directory based on what's in manifest. 
            try addTargetsTests(fileManager: fileManager, sourcePath: sourcePath, targets: targetList, originalPackageName: originalPackageName, destinationPath: destinationPath)
                
        } catch {
            print("\nError. Cannot copy template into destination\n")
        }
    }

    /// Function to create all needed directories in Tests and Sources. 
    public func addTargetsTests(fileManager:FileManager, sourcePath: String, targets: [String], originalPackageName: String, destinationPath: String) throws {
        for target in targets {
            do {
                if target == originalPackageName {
                    // Create test directories for the targets.
                    try fileManager.moveItem(atPath: "\(destinationPath)/Tests/\(originalPackageName)Tests", toPath: "\(destinationPath)/Tests/\(pkgName)Tests")
                    try fileManager.moveItem(atPath: "\(destinationPath)/Tests/\(pkgName)Tests/\(originalPackageName)Tests.swift", toPath: "\(destinationPath)/Tests/\(pkgName)Tests/\(pkgName)Tests.swift")
                    continue
                }
                // Create test directories for the targets.
                try fileManager.copyItem(atPath: "\(sourcePath)/Tests/\(originalPackageName)Tests", toPath: "\(destinationPath)/Tests/\(target)Tests")
                try fileManager.moveItem(atPath: "\(destinationPath)/Tests/\(target)Tests/\(originalPackageName)Tests.swift", toPath: "\(destinationPath)/Tests/\(target)Tests/\(target)Tests.swift")
                // Get rid of mentions of the old package name.
                searchAndReplace(pattern: originalPackageName, replacement: target, file: "\(destinationPath)/Tests/\(target)Tests/\(target)Tests.swift")
                searchAndReplace(pattern: originalPackageName, replacement: target, file: "\(destinationPath)/Tests/\(target)Tests/XCTestManifests.swift")
            } catch {
                print ("Could not copy directory: \(error)")
            }
        }    
        do {
            // Changes the main target to new package name
            try fileManager.moveItem(atPath: "\(destinationPath)/Sources/\(originalPackageName)", toPath: "\(destinationPath)/Sources/\(pkgName)")
            try fileManager.moveItem(atPath: "\(destinationPath)/Sources/\(pkgName)/\(originalPackageName).swift", toPath: "\(destinationPath)/Sources/\(pkgName)/\(pkgName).swift")
            searchAndReplace(pattern: originalPackageName, replacement: pkgName, file: "\(destinationPath)/Tests/LinuxMain.swift")
        }
        catch {
            print("Files could not be renamed: \(error)")
        }
    }
    
    /// Conduct all replacements for the manifest file.
    public func amendManifestTargets(targets: [String], manifest: String, sourcePath: String) throws {
        let manifestContents = try String(contentsOfFile: manifest, encoding: String.Encoding.utf8)
        guard let indexOf = manifestContents.range(of: ".target(")?.lowerBound else {
            print("Missing target outline in template")
            return 
        }
        var newString = manifestContents[..<indexOf]
        for target in targets {
            let writeString = """

                    .target(
                        name: "\(target)",
                        dependencies: []),
                    .testTarget(
                        name: "\(target)Tests",
                        dependencies: ["\(target)"]),
            """
            newString += writeString 
            
        }
        newString += """
            
            ]
        )
        """
        
        do {
            try newString.write(toFile: manifest, atomically: false, encoding: String.Encoding.utf8)
        } catch {
                print("Failed to read or write text from \(manifest)")
        }
    }
    
    /// Search for pattern in file and replace it. 
    public func searchAndReplace(pattern: String, replacement: String, file: String) {     
        do {
            let original = try String(contentsOfFile: file, encoding: String.Encoding.utf8)
            let newText = original.replacingOccurrences(of: pattern, with: replacement)
            try newText.write(toFile: file, atomically: false, encoding: String.Encoding.utf8)
        } catch {
            print("Failed to read or write text from \(file)")
        }
    }
}
