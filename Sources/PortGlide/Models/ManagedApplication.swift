import Foundation

struct ManagedApplication: Identifiable, Hashable {
    let id: String
    let name: String
    let binaryPath: String
    let bundleIdentifier: String
    let systemImage: String

    static let supported: [ManagedApplication] = [
        ManagedApplication(
            id: "codex",
            name: "Codex",
            binaryPath: "/Applications/Codex.app/Contents/MacOS/Codex",
            bundleIdentifier: "com.openai.codex",
            systemImage: "chevron.left.forwardslash.chevron.right"
        ),
        ManagedApplication(
            id: "claude",
            name: "Claude Desktop",
            binaryPath: "/Applications/Claude.app/Contents/MacOS/Claude",
            bundleIdentifier: "com.anthropic.claudefordesktop",
            systemImage: "sparkles"
        ),
        ManagedApplication(
            id: "code",
            name: "Visual Studio Code",
            binaryPath: "/Applications/Visual Studio Code.app/Contents/MacOS/Code",
            bundleIdentifier: "com.microsoft.VSCode",
            systemImage: "curlybraces"
        ),
        ManagedApplication(
            id: "cursor",
            name: "Cursor",
            binaryPath: "/Applications/Cursor.app/Contents/MacOS/Cursor",
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            systemImage: "cursorarrow"
        ),
        ManagedApplication(
            id: "kiro",
            name: "Kiro",
            binaryPath: "/Applications/Kiro.app/Contents/MacOS/Kiro",
            bundleIdentifier: "dev.kiro.desktop",
            systemImage: "wand.and.stars"
        )
    ]

    static func proxyEnvironment(
        for profile: ServerProfile,
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var environment = base
        let proxyURL = "socks5h://127.0.0.1:\(profile.proxyPort)"
        environment["ALL_PROXY"] = proxyURL
        environment["HTTPS_PROXY"] = proxyURL
        environment["HTTP_PROXY"] = proxyURL
        environment["all_proxy"] = proxyURL
        environment["https_proxy"] = proxyURL
        environment["http_proxy"] = proxyURL
        environment["NO_PROXY"] = "localhost,127.0.0.1,::1,*.local"
        environment["no_proxy"] = "localhost,127.0.0.1,::1,*.local"
        return environment
    }

    static func launchArguments(for profile: ServerProfile) -> [String] {
        ["--proxy-server=socks5://127.0.0.1:\(profile.proxyPort)"]
    }
}
