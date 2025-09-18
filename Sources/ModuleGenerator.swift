import Foundation

struct ModuleGenerator {
    let moduleName: String
    let template: ModuleTemplate
    let workspaceRoot: String
    let verbose: Bool
    let dryRun: Bool
    let generatePair: Bool

    private let fileManager = FileManager.default

    func generate() throws {
        log("🔍 Validating Bazel workspace...")
        try validateBazelWorkspace()

        if dryRun {
            log("🏃 DRY RUN MODE - No files will be created")
        }

        log("🚀 Generating \(template.rawValue) module pair for '\(moduleName)'...")

        // Create directories
        try createDirectories()

        // Generate BUILD.bazel files
        if generatePair {
            try generatePrivateBuildFile()
            try generatePublicBuildFile()
        } else {
            try generateSingleBuildFile()
        }

        // Generate Swift files based on template
        if generatePair {
            try generateTemplateFiles()
        } else {
            let content = SwiftTemplates.singleImplementation(moduleName: moduleName, template: template)
            let filePath = "\(workspaceRoot)/\(moduleName)/Sources/\(moduleName).swift"
            log("📝 Generating \(filePath)")
            if !dryRun {
                try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            }
        }

        // Update main BUILD.bazel
        if generatePair {
            try updateMainBuildFile(privateDep: moduleName,
                                    publicDep: moduleName)

        } else {
            try updateMainBuildFile(privateDep: moduleName, publicDep: nil)
        }

        printSuccessMessage()
    }

    private func validateBazelWorkspace() throws {
        let moduleBazelPath = "\(workspaceRoot)/MODULE.bazel"
        let buildBazelPath = "\(workspaceRoot)/BUILD.bazel"
        let workspacePath = "\(workspaceRoot)/WORKSPACE"
        let workspaceBazelPath = "\(workspaceRoot)/WORKSPACE.bazel"

        // Check for bzlmod (MODULE.bazel) - new approach & recommended
        let hasModuleBazel = fileManager.fileExists(atPath: moduleBazelPath)

        // Check for legacy WORKSPACE files
        let hasWorkspace = fileManager.fileExists(atPath: workspacePath) || fileManager.fileExists(atPath: workspaceBazelPath)

        // Check for root BUILD file
        let hasBuildFile = fileManager.fileExists(atPath: buildBazelPath)

        // MUST HAVE either MODULE.bazel or WORKSPACE + BUILD.bazel
        guard (hasModuleBazel || hasWorkspace) && hasBuildFile else {
            var errorMessage = """
            ❌ ERROR: Not a valid Bazel workspace!
            
            This tool must be run from the root of a Bazel workspace.
            
            Missing required files:
            """

            if !hasModuleBazel && !hasWorkspace {
                errorMessage += "\n • MODULE.bazel (Bzlmod - recommended) OR WORKSPACE/WORKSPACE.bazel (legacy)"
            }

            if !hasBuildFile {
                errorMessage += "\n  • BUILD.bazel (root build file)"
            }

            errorMessage += """
            Expected workspace structure:
              ├── MODULE.bazel (or WORKSPACE)
              ├── BUILD.bazel
              ├── Sources/
              └── (your existing modules)
            
            Please navigate to your Bazel workspace root and try again.
            """

            throw ModuleGeneratorError.invalidWorkspace(errorMessage)
        }

        // Additional assert: check if BUILD.bazel looks like our expected format
        let buildContent = try String(contentsOfFile: buildBazelPath)

        // Look if this is an iOS project
        let hasIOSContent = buildContent.contains("ios_application") ||
        buildContent.contains("swift_library") ||
        buildContent.contains("rules_apple") ||
        buildContent.contains("rules_swift")

        if !hasIOSContent {
            log("⚠️  Warning: BUILD.bazel doesn't appear to be an iOS Bazel project.")
            log("   This tool is designed for iOS projects using rules_apple and rules_swift.")
            log("   Continuing anyway, but you may need to manually adjust the generated files.")
        }

        // Check if we'd overwrite existing modules
        let privateModulePath = "\(workspaceRoot)/\(moduleName)"
        let publicModulePath = "\(workspaceRoot)/\(moduleName)Public"

        if fileManager.fileExists(atPath: privateModulePath) {
            throw ModuleGeneratorError.moduleExists("Module '\(moduleName)' already exists at \(privateModulePath)")
        }

        if fileManager.fileExists(atPath: publicModulePath) {
            throw ModuleGeneratorError.moduleExists("Module '\(moduleName)Public' already exists at \(publicModulePath)")
        }

        log("✅ Valid Bazel workspace detected")
        if hasModuleBazel {
            log("   Using Bzlmod (MODULE.bazel) - excellent choice! 🎉")
        } else {
            log("   Using legacy WORKSPACE - consider migrating to Bzlmod")
        }
    }

    private func createDirectories() throws {
        let privateDir = "\(workspaceRoot)/\(moduleName)/Sources"
        log("📁 Creating directory: \(privateDir)")

        if !dryRun {
            try fileManager.createDirectory(atPath: privateDir, withIntermediateDirectories: true)
        }

        if generatePair {
            let publicDir = "\(workspaceRoot)/\(moduleName)Public/Sources"
            log("📁 Creating directory: \(publicDir)")
            if !dryRun {
                try fileManager.createDirectory(atPath: publicDir, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: BUILD File Generation

    private func generateSingleBuildFile() throws {
        let content = BuildFileTemplates.singleBuildFile(moduleName: moduleName)
        let filePath = "\(workspaceRoot)/\(moduleName)/BUILD.bazel"

        log("📝 Generating \(filePath)")
        if !dryRun {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        }
    }

    private func generatePrivateBuildFile() throws {
        let content = BuildFileTemplates.privateBuildFile(moduleName: moduleName)
        let filePath = "\(workspaceRoot)/\(moduleName)/BUILD.bazel"

        log("📝 Generating \(filePath)")

        if !dryRun {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        }
    }

    private func generatePublicBuildFile() throws {
        let content = BuildFileTemplates.publicBuildFile(moduleName: moduleName)
        let filePath = "\(workspaceRoot)/\(moduleName)Public/BUILD.bazel"

        log("📝 Generating \(filePath)")

        if !dryRun {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        }
    }

    // MARK: Swift File Generation
    private func generateTemplateFiles() throws {
        let publicContent = SwiftTemplates.publicInterface(
            moduleName: moduleName,
            template: template
        )

        let privateContent = SwiftTemplates.privateImplementation(
            moduleName: moduleName,
            template: template
        )

        let publicFilePath = "\(workspaceRoot)/\(moduleName)Public/Sources/\(moduleName)Providing.swift"
        let privateFilePath = "\(workspaceRoot)/\(moduleName)/Sources/\(moduleName)Impl.swift"

        log("📝 Generating Swift files:")
        log("   \(publicFilePath)")
        log("   \(privateFilePath)")

        if !dryRun {
            try publicContent.write(toFile: publicFilePath, atomically: true, encoding: .utf8)
            try privateContent.write(toFile: privateFilePath, atomically: true, encoding: .utf8)
        }
    }

    private func updateMainBuildFile(privateDep: String, publicDep: String?) throws {
        let buildFilePath = "\(workspaceRoot)/BUILD.bazel"
        guard fileManager.fileExists(atPath: buildFilePath) else {
            log("⚠️  Warning: BUILD.bazel not found. Please manually add dependencies.")
            return
        }

        let originalContent = try String(contentsOfFile: buildFilePath)
        let lines = originalContent.components(separatedBy: .newlines)

        let privateLabel = "\"//\(privateDep):\(privateDep)\","

        var wantedEntries: [String] = [privateLabel]
        var publicLabel: String?
        if let publicDep = publicDep {
            publicLabel = "\"//\(publicDep)Public:\(publicDep)Public\","
            if let publicLabel = publicLabel {
                wantedEntries.append(publicLabel)
            }
        }

        // 1) Find topmost swift_library rule in the root BUILD.bazel
        var swiftLibRanges: [(start: Int, end: Int)] = []
        for i in 0..<lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("swift_library(") {
                if let r = findParenthesesRange(in: lines, startingAt: i) {
                    swiftLibRanges.append(r)
                }
            }
        }

        guard let topSwiftLib = swiftLibRanges.min(by: { $0.start < $1.start }) else {
            // No swift_library found -> fallback to patch
            log("⚠️  No swift_library found in root BUILD.bazel. Writing suggested patch.")
            try writePatchOrPrint(privateLabel: privateLabel, publicLabel: publicLabel ?? "")
            return
        }

        var updatedLines = lines
        var didChange = false
        for i in topSwiftLib.start...topSwiftLib.end {
            if updatedLines[i].contains("deps") && updatedLines[i].contains("=") {
                if let (listStart, listEnd) = findBracketedRange(in: updatedLines, startingAt: i) {
                    if insertEntriesIntoList(lines: &updatedLines, startLine: listStart, endLine: listEnd, entries: wantedEntries) {
                        didChange = true
                    }
                }
                break
            }
        }

        if !didChange {
            let snippet = updatedLines[topSwiftLib.start...topSwiftLib.end].joined(separator: "\n")
            // If both labels are already somewhere in the swift_library, nothing to do.
            if generatePair {
                if snippet.contains(privateLabel) || snippet.contains(publicLabel!) {
                    log("No changes needed; labels already present in top swift_library.")
                    return
                }
            } else {
                if snippet.contains(privateLabel) {
                    log("No changes needed; labels already present in top swift_library.")
                    return
                }
            }

            var prevIdx = topSwiftLib.end - 1
            while prevIdx >= topSwiftLib.start &&
                  updatedLines[prevIdx].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                prevIdx -= 1
            }
            if prevIdx >= topSwiftLib.start {
                let trimmed = updatedLines[prevIdx].trimmingCharacters(in: .whitespaces)
                if !trimmed.hasSuffix(",") {
                    updatedLines[prevIdx] = updatedLines[prevIdx] + ","
                }
            }

            let closingLine = updatedLines[topSwiftLib.end]
            let indentPrefix = String(closingLine.prefix { $0 == " " || $0 == "\t" })
            let innerIndent = indentPrefix + "    "
            var depsBlock: [String] = []
            if generatePair {
                depsBlock = [
                    indentPrefix + "deps = [",
                    innerIndent + privateLabel,
                    innerIndent + publicLabel!,
                    indentPrefix + "],"
                ]
            } else {
                depsBlock = [
                    indentPrefix + "deps = [",
                    innerIndent + privateLabel,
                    indentPrefix + "],"
                ]
            }

            updatedLines.insert(contentsOf: depsBlock, at: topSwiftLib.end)
            didChange = true
        }

        if didChange {
            log("📝 Updating BUILD.bazel (top swift_library deps)")
            if dryRun {
                showDiff(original: lines, updated: updatedLines)
                return
            } else {
                try backupFile(at: buildFilePath)
                let newContents = updatedLines.joined(separator: "\n")
                try newContents.write(toFile: buildFilePath, atomically: true, encoding: .utf8)
                log("✅ BUILD.bazel updated (top swift_library).")
                return
            }
        }

        // MARK: Fallback mechanism: nothing changed (relatively rare)
        log("⚠️  Could not modify BUILD.bazel automatically. Writing suggested patch.")
        try writePatchOrPrint(privateLabel: privateLabel, publicLabel: publicLabel)
    }

    private func findParenthesesRange(in lines: [String], startingAt startIndex: Int) -> (start: Int, end: Int)? {
        var depth = 0
        for i in startIndex..<lines.count {
            let line = lines[i]
            for ch in line {
                if ch == "(" {
                    depth += 1
                } else if ch == ")" {
                    depth -= 1
                    if depth == 0 {
                        return (startIndex, i)
                    }
                }
            }
        }
        return nil
    }

    private func findBracketedRange(in lines: [String], startingAt startIndex: Int) -> (start: Int, end: Int)? {
        var depth = 0
        var startLine: Int? = nil
        for i in startIndex..<lines.count {
            let line = lines[i]
            for ch in line {
                if ch == "[" {
                    if startLine == nil { startLine = i }
                    depth += 1
                } else if ch == "]" {
                    depth -= 1
                    if depth == 0, let s = startLine {
                        return (s, i)
                    }
                }
            }
        }
        return nil
    }

    private func insertEntriesIntoList(lines: inout [String], startLine: Int, endLine: Int, entries: [String]) -> Bool {

        let snippet = lines[startLine...endLine].joined(separator: "\n")
        var anyMissing = false
        for e in entries {
            if !snippet.contains(e) { anyMissing = true; break }
        }
        if !anyMissing { return false }


        let closingLine = lines[endLine]
        let indentPrefix = String(closingLine.prefix { $0 == " " || $0 == "\t" })
        let padding = indentPrefix + "    "

        var insertLines: [String] = []
        for e in entries {
            if snippet.contains(e) { continue }
            insertLines.append(padding + e)
        }
        if insertLines.isEmpty { return false }

        lines.insert(contentsOf: insertLines, at: endLine)
        return true
    }

    private func showDiff(original: [String], updated: [String]) {
        let maxIndex = max(original.count, updated.count)
        var firstDiff: Int? = nil
        for i in 0..<maxIndex {
            let o = i < original.count ? original[i] : nil
            let n = i < updated.count ? updated[i] : nil
            if o != n { firstDiff = i; break }
        }
        guard let start = firstDiff else {
            log("No changes to BUILD.bazel (dry run).")
            return
        }

        var lastDiff = start
        var i = maxIndex - 1
        while i >= 0 {
            let o = i < original.count ? original[i] : nil
            let n = i < updated.count ? updated[i] : nil
            if o != n { lastDiff = i; break }
            i -= 1
        }

        let contextStart = max(0, start - 3)
        let contextEnd = min(maxIndex - 1, lastDiff + 3)

        print("\n--- BUILD.bazel (preview) ---\n")
        for idx in contextStart...contextEnd {
            let o = idx < original.count ? original[idx] : ""
            let n = idx < updated.count ? updated[idx] : ""
            if o != n {
                print("- \(o)")
                print("+ \(n)")
            } else {
                print("  \(o)")
            }
        }
        print("\n--- end preview ---\n")
    }

    private func backupFile(at path: String) throws {
        let dateFormatter = ISO8601DateFormatter()
        let stamp = dateFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupPath = "\(path).modjool.bak.\(stamp)"
        if fileManager.fileExists(atPath: backupPath) {
            try? fileManager.removeItem(atPath: backupPath)
        }
        try fileManager.copyItem(atPath: path, toPath: backupPath)
        log("💾 Backup of BUILD.bazel written to: \(backupPath)")
    }

    private func writePatchOrPrint(privateLabel: String, publicLabel: String?) throws {
        var patch: String

        if generatePair {
            patch = """
        # Modjool suggested snippet - add these to the swift_library deps in your root BUILD.bazel:
        deps = [
            \(privateLabel)
            \(publicLabel!)
        ]
        """
        } else {
            patch = """
        # Modjool suggested snippet - add these to the swift_library deps in your root BUILD.bazel:
        deps = [
            \(privateLabel)
        ]
        """
        }
        let patchPath = "\(workspaceRoot)/BUILD.bazel.modjool.patch"
        if dryRun {
            print("\n--- Suggested BUILD.bazel patch ---\n")
            print(patch)
        } else {
            try patch.write(toFile: patchPath, atomically: true, encoding: .utf8)
            log("📄 Patch written to: \(patchPath)")
        }
    }

    private func printSuccessMessage() {
        if dryRun {
            print("\n🏃 DRY RUN COMPLETE - Here's what would be generated:")
        } else {
            print("\n✅ Module '\(moduleName)' generated successfully!")
        }

        print("📁 Created:")
        print("   - \(moduleName)/BUILD.bazel")
        print("   - \(moduleName)/Sources/\(moduleName)Impl.swift")
        print("   - \(moduleName)Public/BUILD.bazel")
        print("   - \(moduleName)Public/Sources/\(moduleName)Providing.swift")

        if !dryRun {
            print("📝 Updated:")
            print("   - BUILD.bazel (dependencies)")
            print("   - BUILD.bazel (focused_targets)")
        }

        print("\n🎯 Next steps:")
        print("   1. Implement your protocols in \(moduleName)Public/Sources/")
        print("   2. Implement your classes in \(moduleName)/Sources/")
        print("   3. Run: bazel run //:xcodeproj")

        print("\n💡 Template used: \(template.description)")
    }

    private func log(_ message: String) {
        if verbose || dryRun {
            print(message)
        }
    }
}

enum ModuleGeneratorError: Error, CustomStringConvertible {
    case invalidWorkspace(String)
    case moduleExists(String)
    case fileSystemError(String)

    var description: String {
        switch self {
        case .invalidWorkspace(let message):
            return message
        case .moduleExists(let message):
            return "❌ ERROR: \(message)"
        case .fileSystemError(let message):
            return "❌ File System Error: \(message)"
        }
    }
}
