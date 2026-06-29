import Testing
@testable import PortGlide

@Test func exampleProfileIsValid() throws {
    let profile = try ServerProfile.example.validated()
    #expect(profile.sshAlias == "my-vps")
    #expect(profile.proxyPort == 1089)
    #expect(profile.rdpLocalPort == 13389)
}

@Test func rejectsInjectedAlias() {
    var profile = ServerProfile.example
    profile.sshAlias = "my-vps; rm -rf /"
    #expect(throws: ProfileValidationError.invalidSSHAlias) {
        try profile.validated()
    }
}

@Test func rejectsInjectedServiceName() {
    var profile = ServerProfile.example
    profile.remoteVPNService = "openvpn; reboot"
    #expect(throws: ProfileValidationError.invalidServiceName) {
        try profile.validated()
    }
}

@Test func proxyArgumentsAreSeparateAndUseProfileAlias() {
    let arguments = SSHCommands.proxy(for: .example)
    #expect(Array(arguments.prefix(3)) == ["-N", "-D", "127.0.0.1:1089"])
    #expect(arguments.last == "my-vps")
}

@Test func rdpArgumentsUseExplicitForward() {
    let arguments = SSHCommands.rdp(for: .example)
    #expect(arguments.contains("127.0.0.1:13389:10.0.0.10:3389"))
    #expect(arguments.last == "my-vps")
}

@Test func remoteVPNStartAndStopAreIndependentCommands() {
    let start = SSHCommands.startRemoteVPN(for: .example)
    let stop = SSHCommands.stopRemoteVPN(for: .example)
    #expect(start.last == "sudo -n /bin/systemctl start openvpn-client@client")
    #expect(stop.last == "sudo -n /bin/systemctl stop openvpn-client@client")
    #expect(!start.joined(separator: " ").contains("13389"))
    #expect(!start.joined(separator: " ").contains("rdp"))
}

@Test func remoteVPNCredentialCommandContainsNoCredentialValues() {
    let profile = ServerProfile.example
    #expect(profile.remoteVPNInstance == "client")
    let arguments = SSHCommands.updateRemoteVPNCredentials(for: profile, instance: "client")
    #expect(arguments.last == "sudo -n /usr/local/sbin/portglide-openvpn-credentials client")
    #expect(!arguments.joined(separator: " ").contains("password"))
}

@Test func managedApplicationsReceiveSelectedProxyWithoutShell() {
    let environment = ManagedApplication.proxyEnvironment(for: .example, base: [:])
    #expect(environment["ALL_PROXY"] == "socks5h://127.0.0.1:1089")
    #expect(environment["NO_PROXY"] == "localhost,127.0.0.1,::1,*.local")
    #expect(ManagedApplication.launchArguments(for: .example) == ["--proxy-server=socks5://127.0.0.1:1089"])
    #expect(ManagedApplication.supported.map(\.id).contains("codex"))
    let codex = ManagedApplication.supported.first(where: { $0.id == "codex" })!
    #expect(codex.bundleIdentifier == "com.openai.codex")
}

@Test func warningStateKeepsRunningApplicationDisabled() {
    #expect(ConnectionState.warning("SOCKS5 выключен").isActive)
}

@Test func managedApplicationStateFollowsProcessAndProxy() {
    let closed = ManagedApplicationStateResolver.resolve(
        isRunning: false,
        launchedThroughProfile: true,
        proxyIsActive: true,
        profileName: "Example"
    )
    #expect(closed == .ready("Готово к запуску"))

    let disconnected = ManagedApplicationStateResolver.resolve(
        isRunning: true,
        launchedThroughProfile: true,
        proxyIsActive: false,
        profileName: "Example"
    )
    #expect(disconnected == .warning("Открыто, но SOCKS5 выключен"))

    let external = ManagedApplicationStateResolver.resolve(
        isRunning: true,
        launchedThroughProfile: false,
        proxyIsActive: true,
        profileName: "Example"
    )
    #expect(external == .active("Открыто вне PortGlide"))
}
