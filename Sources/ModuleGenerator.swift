import Foundation

struct ModuleGenerator {
    let moduleName: String
    let template: ModuleTemplate
    let workspaceRoot: String
    let verbose: Bool
    let dryRun: Bool

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
        try generatePrivateBuildFile() // MARK: First test without templates!!!!
        try generatePublicBuildFile()

        // Generate Swift files based on template
        try generateTemplateFiles()

        // Update main BUILD.bazel
        try updateMainBuildFile()

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
        let publicDir = "\(workspaceRoot)/\(moduleName)Public/Sources"

        log("📁 Creating directories:")
        log("   \(privateDir)")
        log("   \(publicDir)")

        if !dryRun {
            try fileManager.createDirectory(atPath: privateDir, withIntermediateDirectories: true)
            try fileManager.createDirectory(atPath: publicDir, withIntermediateDirectories: true)
        }
    }

    // MARK: BUILD File Generation
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

    private func updateMainBuildFile() throws {
        let buildFilePath = "\(workspaceRoot)/BUILD.bazel"

        guard fileManager.fileExists(atPath: buildFilePath) else {
            log("⚠️  Warning: BUILD.bazel not found. Please manually add dependencies.")
            return
        }

        let content = try String(contentsOfFile: buildFilePath)

        // Find the AppLib deps section and add new dependencies
        let newDependencies = """
        "//\(moduleName):\(moduleName)",
        "//\(moduleName)Public:\(moduleName)Public",
        """

        // Find focused_targets section and add new targets
        let newFocusedTargets = """
        "//\(moduleName):\(moduleName)",
        "//\(moduleName)Public:\(moduleName)Public",
        """

        var updatedContent = content
        var wasUpdated = false

        // Add to dependencies (look for a deps parameter)

        if content.contains("deps = [") {
            updatedContent = updatedContent.replacingOccurrences(
                of: "focused_targets = [",
                with: "focused_targets = [\n        \(newFocusedTargets)"
            )
            wasUpdated = true
        }

        if wasUpdated {
            log("📝 Updating BUILD.bazel with new dependencies")

            if !dryRun {
                try updatedContent.write(toFile: buildFilePath, atomically: true, encoding: .utf8)
            }
        } else {
            log("⚠️  Warning: Could not auto-update BUILD.bazel. Please manually add:")
            log("   Dependencies: \(newDependencies)")
            log("   Focused targets: \(newFocusedTargets)")
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
