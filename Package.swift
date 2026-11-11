// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "EmulatorDomain", platforms: [.macOS(.v13)], products: [.library(name: "EmulatorDomain", targets: ["EmulatorDomain"])], targets: [.target(name: "EmulatorDomain", path: "App/Domain"), .testTarget(name: "EmulatorDomainTests", dependencies: ["EmulatorDomain"], path: "Tests/Domain")])
