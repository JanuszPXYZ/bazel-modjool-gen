import ArgumentParser
import Foundation

@main
struct BazelModjoolGen: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "BazelModjoolGen",
        abstract: "🚀 Generate Bazel Swift modules with public/private architecture",
        discussion: """
      This tool generates a pair of Swift modules for Bazel projects.
      
      • ModuleName/ (private implementation - only visible to the main app)
      • ModuleNamePublic/ (public protocols - visible to all modules)
      
      Perfect for dependency injection and modular iOS architecture!
      
      Examples:
        bazel-modjool-gen UserProfile
        bazel-modjool-gen PaymentService --template=service
        bazel-modjool-gen NotificationCenter --dry-run
      """,
        version: "1.0.0"
    )

    @Argument(help: "Name of the module to generate (e.g., UserProfile, PaymentService")
    var moduleName: String

    @Flag(name: [.customShort("g"), .customLong("generatePair")],
          help: "Generate both a private and public module (default is single module)")
    var generatePair: Bool = false

    @Option(name: .shortAndLong, help: "Template type to use")
    var template: ModuleTemplate = .feature

    @Flag(name: .shortAndLong, help: "Show what would be generated without creating files")
    var dryRun = false

    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose = false

    @Option(help: "Path to Bazel workspace root")
    var workspace: String = "."

    func run() throws {
        try validateModuleName()

        // Create and run the generator
        let generator = ModuleGenerator(
            moduleName: moduleName,
            template: template,
            workspaceRoot: workspace,
            verbose: verbose,
            dryRun: dryRun,
            generatePair: generatePair
        )

        try generator.generate()
    }

    private func validateModuleName() throws {
        guard !moduleName.isEmpty else {
            throw ValidationError("Module name cannot be empty")
        }

        guard moduleName.first?.isUppercase == true else {
            throw ValidationError("Module name must start with an uppercase letter (e.g., UserProfile)")
        }

        guard moduleName.allSatisfy( {$0.isLetter || $0.isNumber }) else {
            throw ValidationError("Module name must contain only letters and numbers")
        }

        let reservedNames = ["Foundation", "UIKit", "SwiftUI", "Combine", "CoreData"]
        guard !reservedNames.contains(moduleName) else {
            throw ValidationError("'\(moduleName)' is a reserved system framework name")
        }
    }
}

enum ModuleTemplate: String, CaseIterable, ExpressibleByArgument {
    case feature = "feature"
    case service = "service"
    case utility = "utility"
    case viewModel = "viewmodel"

    var description: String {
        switch self {
        case .feature:
            return "Feature module with ViewControllers and UI components"
        case .service:
            return "Service module for business logic and data access"
        case .utility:
            return "Utility module with helper functions and extensions"
        case .viewModel:
            return "ViewModel module for MVVM architecture"
        }
    }
}
