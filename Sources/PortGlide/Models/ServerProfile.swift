import Foundation

struct ServerProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var flag: String
    var sshAlias: String
    var proxyPort: Int
    var rdpLocalPort: Int
    var rdpTargetHost: String
    var rdpTargetPort: Int
    var remoteVPNService: String
    var vpnConfigPath: String

    init(
        id: UUID = UUID(),
        name: String,
        flag: String,
        sshAlias: String,
        proxyPort: Int,
        rdpLocalPort: Int,
        rdpTargetHost: String,
        rdpTargetPort: Int = 3389,
        remoteVPNService: String = "",
        vpnConfigPath: String = ""
    ) {
        self.id = id
        self.name = name
        self.flag = flag
        self.sshAlias = sshAlias
        self.proxyPort = proxyPort
        self.rdpLocalPort = rdpLocalPort
        self.rdpTargetHost = rdpTargetHost
        self.rdpTargetPort = rdpTargetPort
        self.remoteVPNService = remoteVPNService
        self.vpnConfigPath = vpnConfigPath
    }

    static let example = ServerProfile(
        name: "Example VPS",
        flag: "🌐",
        sshAlias: "my-vps",
        proxyPort: 1089,
        rdpLocalPort: 13389,
        rdpTargetHost: "10.0.0.10",
        remoteVPNService: "openvpn-client@client"
    )

    func validated() throws -> ServerProfile {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ProfileValidationError.emptyName }
        guard Self.matches(sshAlias, pattern: #"^[A-Za-z0-9._-]+$"#) else {
            throw ProfileValidationError.invalidSSHAlias
        }
        guard (1024...65535).contains(proxyPort), (1024...65535).contains(rdpLocalPort) else {
            throw ProfileValidationError.invalidLocalPort
        }
        guard proxyPort != rdpLocalPort else { throw ProfileValidationError.duplicateLocalPort }
        guard Self.matches(rdpTargetHost, pattern: #"^[A-Za-z0-9._:-]+$"#) else {
            throw ProfileValidationError.invalidTargetHost
        }
        guard (1...65535).contains(rdpTargetPort) else {
            throw ProfileValidationError.invalidTargetPort
        }
        if !remoteVPNService.isEmpty,
           !Self.matches(remoteVPNService, pattern: #"^[A-Za-z0-9@_.-]+$"#) {
            throw ProfileValidationError.invalidServiceName
        }

        var copy = self
        copy.name = trimmedName
        copy.sshAlias = sshAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.rdpTargetHost = rdpTargetHost.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.remoteVPNService = remoteVPNService.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.vpnConfigPath = vpnConfigPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }

    private static func matches(_ value: String, pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    var remoteVPNInstance: String? {
        let prefix = "openvpn-client@"
        guard remoteVPNService.hasPrefix(prefix) else { return nil }
        let instance = String(remoteVPNService.dropFirst(prefix.count))
        guard !instance.isEmpty,
              Self.matches(instance, pattern: #"^[A-Za-z0-9_.-]+$"#) else { return nil }
        return instance
    }
}

enum ProfileValidationError: LocalizedError, Equatable {
    case emptyName
    case invalidSSHAlias
    case invalidLocalPort
    case duplicateLocalPort
    case invalidTargetHost
    case invalidTargetPort
    case invalidServiceName

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Укажите название страны."
        case .invalidSSHAlias: return "SSH alias может содержать только буквы, цифры, точку, _ и -."
        case .invalidLocalPort: return "Локальные порты должны быть в диапазоне 1024…65535."
        case .duplicateLocalPort: return "Для proxy и RDP нужны разные локальные порты."
        case .invalidTargetHost: return "Некорректный адрес RDP target."
        case .invalidTargetPort: return "RDP target port должен быть в диапазоне 1…65535."
        case .invalidServiceName: return "Некорректное имя удалённого VPN-сервиса."
        }
    }
}
