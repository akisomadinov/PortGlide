import Foundation

enum SSHCommands {
    static func checkConfig(for profile: ServerProfile) -> [String] {
        ["-G", profile.sshAlias]
    }

    static func checkAccess(for profile: ServerProfile) -> [String] {
        ["-o", "BatchMode=yes", "-o", "ConnectTimeout=8", profile.sshAlias, "true"]
    }

    static func proxy(for profile: ServerProfile) -> [String] {
        [
            "-N", "-D", "127.0.0.1:\(profile.proxyPort)",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=4",
            "-o", "TCPKeepAlive=yes",
            "-o", "ExitOnForwardFailure=yes",
            profile.sshAlias
        ]
    }

    static func rdp(for profile: ServerProfile) -> [String] {
        let forwarding = "127.0.0.1:\(profile.rdpLocalPort):\(profile.rdpTargetHost):\(profile.rdpTargetPort)"
        return [
            "-N", "-L", forwarding,
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=4",
            "-o", "TCPKeepAlive=yes",
            "-o", "ExitOnForwardFailure=yes",
            profile.sshAlias
        ]
    }

    static func checkRemoteRDP(for profile: ServerProfile) -> [String] {
        let command = "timeout 5 nc -z -w 3 \(profile.rdpTargetHost) \(profile.rdpTargetPort)"
        return ["-o", "BatchMode=yes", "-o", "ConnectTimeout=8", profile.sshAlias, command]
    }

    static func remoteVPNStatus(for profile: ServerProfile) -> [String] {
        [
            "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", profile.sshAlias,
            "/bin/systemctl is-active \(profile.remoteVPNService)"
        ]
    }

    static func startRemoteVPN(for profile: ServerProfile) -> [String] {
        remoteVPNAction("start", profile: profile)
    }

    static func stopRemoteVPN(for profile: ServerProfile) -> [String] {
        remoteVPNAction("stop", profile: profile)
    }

    static func updateRemoteVPNCredentials(for profile: ServerProfile, instance: String) -> [String] {
        [
            "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", profile.sshAlias,
            "sudo -n /usr/local/sbin/portglide-openvpn-credentials \(instance)"
        ]
    }

    private static func remoteVPNAction(_ action: String, profile: ServerProfile) -> [String] {
        [
            "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", profile.sshAlias,
            "sudo -n /bin/systemctl \(action) \(profile.remoteVPNService)"
        ]
    }
}
