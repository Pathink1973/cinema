// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Cinema", platforms: [.macOS(.v14)], products: [.executable(name: "Cinema", targets: ["Cinema"])], targets: [.executableTarget(name: "Cinema", resources: [.copy("Resources")]), .testTarget(name: "CinemaTests", dependencies: ["Cinema"])])
