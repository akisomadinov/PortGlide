// swift-tools-version: 5.10

import Foundation
import PackageDescription

let localFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let localLibraries = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
let needsLocalTestingPath = ProcessInfo.processInfo.environment["CI"] != "true"
    && FileManager.default.fileExists(atPath: "\(localFrameworks)/Testing.framework")

let testSwiftSettings: [SwiftSetting] = needsLocalTestingPath
    ? [.unsafeFlags(["-F", localFrameworks])]
    : []

let testLinkerSettings: [LinkerSetting] = needsLocalTestingPath
    ? [.unsafeFlags([
        "-F", localFrameworks,
        "-framework", "Testing",
        "-Xlinker", "-rpath", "-Xlinker", localFrameworks,
        "-Xlinker", "-rpath", "-Xlinker", localLibraries
    ])]
    : []

let package = Package(
    name: "PortGlide",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PortGlide", targets: ["PortGlide"])
    ],
    targets: [
        .executableTarget(name: "PortGlide"),
        .testTarget(
            name: "PortGlideTests",
            dependencies: ["PortGlide"],
            swiftSettings: testSwiftSettings,
            linkerSettings: testLinkerSettings
        )
    ],
    swiftLanguageVersions: [.v5]
)
