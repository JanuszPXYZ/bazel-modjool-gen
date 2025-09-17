import Foundation

struct BuildFileTemplates {
    static func privateBuildFile(moduleName: String) -> String {
        return """
        load("@rules_swift//swift:swift.bzl", "swift_library")
        
        swift_library(
            name = "\(moduleName)",
            module_name = "\(moduleName)",
            srcs = glob(["Sources/*.swift"]),
            deps = ["//\(moduleName)Public:\(moduleName)Public"],
            visibility = [
                "//:__pkg__", # Only main target can see the implementation
                # Uncomment if you want to add test packages that need access
                # "//\(moduleName)Tests:__pkg__",
        ],
        )
        """
    }

    static func publicBuildFile(moduleName: String) -> String {
        return """
        load("@rules_swift//swift:swift.bzl", "swift_library")

        swift_library(
            name = "\(moduleName)Public",
            module_name = "\(moduleName)Public",
            srcs = glob(["Sources/*.swift"]),
            visibility = ["//visibility:public"],  # Anyone can import this
        )
        """
    }
}

struct SwiftTemplates {
    static func publicInterface(moduleName: String, template: ModuleTemplate) -> String {
        switch template {
        case .feature:
            return featurePublicTemplate(moduleName: moduleName)
        case .service:
            return servicePublicTemplate(moduleName: moduleName)
        case .utility:
            return utilityPublicTemplate(moduleName: moduleName)
        case .viewModel:
            return viewModelPublicTemplate(moduleName: moduleName)
        }
    }

    static func privateImplementation(moduleName: String, template: ModuleTemplate) -> String {
        switch template {
        case .feature:
            return featurePrivateTemplate(moduleName: moduleName)
        case .service:
            return servicePrivateTemplate(moduleName: moduleName)
        case .utility:
            return utilityPrivateTemplate(moduleName: moduleName)
        case .viewModel:
            return viewModelPrivateTemplate(moduleName: moduleName)
        }
    }


    private static func featurePublicTemplate(moduleName: String) -> String {
        return """
        import Foundation
        import UIKit
        
        /// Public protocol for \(moduleName) module
        /// Other modules can depend on this interface
        public protocol \(moduleName)Providing {
            func create\(moduleName)ViewController() -> UIViewController
        }
        
        /// Public configuration for \(moduleName) feature
        public struct \(moduleName)Configuration {
            public let title: String
            public let isDebugMode: Bool
        
            public init(title: String: "\(moduleName), isDebugMode: Bool = false) {
                self.title = title
                self.isDebugMode = isDebugMode
            }
        }
        """
    }

    private static func featurePrivateTemplate(moduleName: String) -> String {
        return """
   import Foundation
   import UIKit
   import \(moduleName)Public
   
   /// Internal implementation of \(moduleName)
   /// Only the main app can instantiate this class
   public class \(moduleName)Impl: \(moduleName)Providing {
       
       private let configuration: \(moduleName)Configuration
       
       public init(configuration: \(moduleName)Configuration = \(moduleName)Configuration()) {
           self.configuration = configuration
       }
       
       // MARK: - \(moduleName)Providing Implementation
       
       public func make\(moduleName)ViewController() -> UIViewController {
           return \(moduleName)ViewController(configuration: configuration)
       }
       
       public func makeDetailViewController(with configuration: \(moduleName)Configuration) -> UIViewController {
           return \(moduleName)DetailViewController(configuration: configuration)
       }
   }
   
   // MARK: - Internal View Controllers
   
   /// Main view controller for \(moduleName) feature
   internal class \(moduleName)ViewController: UIViewController {
       
       private let configuration: \(moduleName)Configuration
       
       init(configuration: \(moduleName)Configuration) {
           self.configuration = configuration
           super.init(nibName: nil, bundle: nil)
       }
       
       required init?(coder: NSCoder) {
           fatalError("init(coder:) has not been implemented")
       }
       
       override func viewDidLoad() {
           super.viewDidLoad()
           setupUI()
       }
       
       private func setupUI() {
           view.backgroundColor = .systemBackground
           title = configuration.title
           
           // TODO: Add your UI setup here
           let label = UILabel()
           label.text = "\\(configuration.title) Feature"
           label.textAlignment = .center
           label.font = .systemFont(ofSize: 24, weight: .bold)
           label.translatesAutoresizingMaskIntoConstraints = false
           
           view.addSubview(label)
           NSLayoutConstraint.activate([
               label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
               label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
           ])
           
           if configuration.isDebugMode {
               let debugLabel = UILabel()
               debugLabel.text = "DEBUG MODE"
               debugLabel.textColor = .red
               debugLabel.font = .systemFont(ofSize: 12)
               debugLabel.translatesAutoresizingMaskIntoConstraints = false
               
               view.addSubview(debugLabel)
               NSLayoutConstraint.activate([
                   debugLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                   debugLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8)
               ])
           }
       }
   }
   
   /// Detail view controller for \(moduleName) feature
   internal class \(moduleName)DetailViewController: UIViewController {
       
       private let configuration: \(moduleName)Configuration
       
       init(configuration: \(moduleName)Configuration) {
           self.configuration = configuration
           super.init(nibName: nil, bundle: nil)
       }
       
       required init?(coder: NSCoder) {
           fatalError("init(coder:) has not been implemented")
       }
       
       override func viewDidLoad() {
           super.viewDidLoad()
           setupUI()
       }
       
       private func setupUI() {
           view.backgroundColor = .systemGroupedBackground
           title = "\\(configuration.title) Details"
           
           // TODO: Add your detail UI here
           let stackView = UIStackView()
           stackView.axis = .vertical
           stackView.spacing = 16
           stackView.translatesAutoresizingMaskIntoConstraints = false
           
           let titleLabel = UILabel()
           titleLabel.text = configuration.title
           titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
           titleLabel.textAlignment = .center
           
           let detailLabel = UILabel()
           detailLabel.text = "This is the detail view for \\(configuration.title)"
           detailLabel.font = .systemFont(ofSize: 16)
           detailLabel.textAlignment = .center
           detailLabel.numberOfLines = 0
           
           stackView.addArrangedSubview(titleLabel)
           stackView.addArrangedSubview(detailLabel)
           
           view.addSubview(stackView)
           NSLayoutConstraint.activate([
               stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
               stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
               stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
               stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
           ])
       }
   }
   """
    }

    private static func servicePublicTemplate(moduleName: String) -> String {
        return """
   import Foundation
   import Combine
   
   /// Public protocol for \(moduleName) service
   /// Other modules can depend on this interface for business logic
   public protocol \(moduleName)Providing {
       /// Performs the main operation of this service
       func performOperation(with parameters: \(moduleName)Parameters) async throws -> \(moduleName)Result
       
       /// Gets the current state of the service
       func getCurrentState() -> \(moduleName)State
       
       /// Observable state changes
       var statePublisher: AnyPublisher<\(moduleName)State, Never> { get }
   }
   
   /// Parameters for service operations
   public struct \(moduleName)Parameters {
       public let identifier: String
       public let options: [String: Any]
       
       public init(identifier: String, options: [String: Any] = [:]) {
           self.identifier = identifier
           self.options = options
       }
   }
   
   /// Result of service operations
   public struct \(moduleName)Result {
       public let success: Bool
       public let data: Data?
       public let message: String?
       
       public init(success: Bool, data: Data? = nil, message: String? = nil) {
           self.success = success
           self.data = data
           self.message = message
       }
   }
   
   /// Service state
   public enum \(moduleName)State {
       case idle
       case loading
       case loaded(Data)
       case error(Error)
   }
   
   /// Public errors that other modules might handle
   public enum \(moduleName)Error: Error {
       case invalidParameters
       case networkError
       case authenticationRequired
       case unknown(String)
   }
   """
    }

    private static func servicePrivateTemplate(moduleName: String) -> String {
        return """
   import Foundation
   import Combine
   import \(moduleName)Public
   
   /// Internal implementation of \(moduleName) service
   /// Only the main app can instantiate this class
   public class \(moduleName)Impl: \(moduleName)Providing {
       
       private let stateSubject = CurrentValueSubject<\(moduleName)State, Never>(.idle)
       private let networkManager: NetworkManager
       
       public var statePublisher: AnyPublisher<\(moduleName)State, Never> {
           stateSubject.eraseToAnyPublisher()
       }
       
       public init(networkManager: NetworkManager = NetworkManager()) {
           self.networkManager = networkManager
       }
       
       // MARK: - \(moduleName)Providing Implementation
       
       public func performOperation(with parameters: \(moduleName)Parameters) async throws -> \(moduleName)Result {
           stateSubject.send(.loading)
           
           do {
               // TODO: Implement your service logic here
               let result = try await performInternalOperation(with: parameters)
               stateSubject.send(.loaded(result))
               
               return \(moduleName)Result(
                   success: true,
                   data: result,
                   message: "Operation completed successfully"
               )
               
           } catch {
               stateSubject.send(.error(error))
               throw \(moduleName)Error.unknown(error.localizedDescription)
           }
       }
       
       public func getCurrentState() -> \(moduleName)State {
           return stateSubject.value
       }
       
       // MARK: - Internal Operations
       
       private func performInternalOperation(with parameters: \(moduleName)Parameters) async throws -> Data {
           // TODO: Implement your actual service logic
           // This is a placeholder implementation
           
           guard !parameters.identifier.isEmpty else {
               throw \(moduleName)Error.invalidParameters
           }
           
           // Simulate async work
           try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
           
           // Return mock data
           let mockResponse = [
               "id": parameters.identifier,
               "status": "success",
               "timestamp": Date().timeIntervalSince1970
           ]
           
           return try JSONSerialization.data(withJSONObject: mockResponse)
       }
   }
   
   // MARK: - Internal Supporting Classes
   
   /// Internal network manager - only accessible within this module
   internal class NetworkManager {
       
       func performRequest(url: URL) async throws -> Data {
           // TODO: Implement actual networking
           let (data, _) = try await URLSession.shared.data(from: url)
           return data
       }
   }
   """
    }

    private static func utilityPublicTemplate(moduleName: String) -> String {
        return """
    import Foundation

    /// Public utilities for \(moduleName)
    /// Other modules can use these helper functions
    public struct \(moduleName) {
        
        /// Performs common utility operation
        public static func performUtilityOperation(on input: String) -> String {
            return "Processed: \\(input)"
        }
        
        /// Validates input data
        public static func validate(_ data: \(moduleName)Data) -> Bool {
            return !data.value.isEmpty
        }
    }

    /// Public data structure for utility operations
    public struct \(moduleName)Data {
        public let value: String
        public let metadata: [String: Any]
        
        public init(value: String, metadata: [String: Any] = [:]) {
            self.value = value
            self.metadata = metadata
}
"""
    }

    private static func utilityPrivateTemplate(moduleName: String) -> String {
        return ""
    }

    private static func viewModelPublicTemplate(moduleName: String) -> String {
        return ""
    }

    private static func viewModelPrivateTemplate(moduleName: String) -> String {
        return ""
    }
}
