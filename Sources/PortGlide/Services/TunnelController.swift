import AppKit
import Foundation

enum ConnectionState: Equatable {
    case idle
    case ready(String)
    case working(String)
    case active(String)
    case warning(String)
    case failed(String)

    var title: String {
        switch self {
        case .idle: return "Выключено"
        case let .ready(text), let .working(text), let .active(text),
             let .warning(text), let .failed(text): return text
        }
    }

    var isActive: Bool {
        switch self {
        case .active, .warning: return true
        default: return false
        }
    }

    var isWorking: Bool {
        if case .working = self { return true }
        return false
    }
}

struct ProfileConnectionState {
    var ssh: ConnectionState = .idle
    var proxy: ConnectionState = .idle
    var rdp: ConnectionState = .idle
    var remoteVPN: ConnectionState = .idle
    var localVPN: ConnectionState = .idle
}

enum ManagedApplicationStateResolver {
    static func resolve(
        isRunning: Bool,
        launchedThroughProfile: Bool,
        proxyIsActive: Bool,
        profileName: String
    ) -> ConnectionState {
        guard isRunning else { return .ready("Готово к запуску") }
        guard launchedThroughProfile else { return .active("Открыто вне PortGlide") }
        return proxyIsActive
            ? .active("Запущено через \(profileName)")
            : .warning("Открыто, но SOCKS5 выключен")
    }
}

@MainActor
final class TunnelController: ObservableObject {
    @Published private(set) var states: [ServerProfile.ID: ProfileConnectionState] = [:]
    @Published private(set) var applicationStates: [String: ConnectionState] = [:]

    private let runner = CommandRunner()
    private let credentialStore = VPNCredentialStore()
    private var launchedProcesses: [String: Process] = [:]
    private var launchedApplicationProfiles: [String: ServerProfile.ID] = [:]

    func state(for profile: ServerProfile) -> ProfileConnectionState {
        states[profile.id] ?? ProfileConnectionState()
    }

    func state(for application: ManagedApplication, profile: ServerProfile) -> ConnectionState {
        applicationStates[applicationKey(application, profile)] ?? .idle
    }

    func checkSSH(_ rawProfile: ServerProfile) async {
        await perform(rawProfile, keyPath: \.ssh, working: "Проверка SSH…") { profile in
            let config = try await self.runner.run("/usr/bin/ssh", arguments: SSHCommands.checkConfig(for: profile))
            guard !config.output.lowercased().contains("hostname \(profile.sshAlias.lowercased())") else {
                throw UserFacingError("SSH alias \(profile.sshAlias) не найден в ~/.ssh/config.")
            }
            _ = try await self.runner.run("/usr/bin/ssh", arguments: SSHCommands.checkAccess(for: profile))
            return .active("SSH доступен")
        }
    }

    func refresh(_ rawProfile: ServerProfile) async {
        await refreshConnectionStates(rawProfile)
        refreshApplicationStates(rawProfile)
    }

    func refreshConnectionStates(_ rawProfile: ServerProfile) async {
        guard let profile = try? rawProfile.validated() else { return }
        let proxyPID = await listenerPID(on: profile.proxyPort)
        let rdpPID = await listenerPID(on: profile.rdpLocalPort)
        let remoteVPNIsActive = state(for: profile).remoteVPN.isWorking
            ? nil
            : await refreshRemoteVPN(profile)
        if !state(for: profile).proxy.isWorking, let proxyPID {
            let arguments = await processArguments(pid: proxyPID)
            update(
                profile.id,
                \.proxy,
                matchesTunnel(arguments, profile: profile, marker: "-D")
                    ? .active("Работает · PID \(proxyPID)")
                    : .failed("Порт занят другим процессом · PID \(proxyPID)")
            )
        } else if !state(for: profile).proxy.isWorking {
            update(profile.id, \.proxy, .idle)
        }
        if !state(for: profile).rdp.isWorking, let rdpPID {
            let arguments = await processArguments(pid: rdpPID)
            if !matchesTunnel(arguments, profile: profile, marker: "-L") {
                update(profile.id, \.rdp, .failed("Порт занят другим процессом · PID \(rdpPID)"))
            } else if remoteVPNIsActive == false {
                update(profile.id, \.rdp, .warning("Туннель открыт, но OpenVPN выключен"))
            } else {
                update(profile.id, \.rdp, .active("Работает · PID \(rdpPID)"))
            }
        } else if !state(for: profile).rdp.isWorking {
            update(profile.id, \.rdp, .idle)
        }
    }

    func startProxy(_ rawProfile: ServerProfile) async {
        await perform(rawProfile, keyPath: \.proxy, working: "Запуск SOCKS5…") { profile in
            if let pid = await self.listenerPID(on: profile.proxyPort) {
                let args = await self.processArguments(pid: pid)
                guard self.matchesTunnel(args, profile: profile, marker: "-D") else {
                    throw UserFacingError("Порт \(profile.proxyPort) занят другим процессом PID \(pid).")
                }
                return .active("Уже работает · PID \(pid)")
            }
            let process = try self.runner.launch("/usr/bin/ssh", arguments: SSHCommands.proxy(for: profile))
            self.launchedProcesses[self.processKey(profile, "proxy")] = process
            let pid = try await self.waitForPort(profile.proxyPort, process: process)
            return .active("127.0.0.1:\(profile.proxyPort) · PID \(pid)")
        }
    }

    func stopProxy(_ rawProfile: ServerProfile) async {
        await stop(rawProfile, kind: "proxy", keyPath: \.proxy, port: rawProfile.proxyPort, marker: "-D")
    }

    func startRDP(_ rawProfile: ServerProfile) async {
        await perform(rawProfile, keyPath: \.rdp, working: "Запуск RDP-туннеля…") { profile in
            let remoteCheck = try await self.runner.run(
                "/usr/bin/ssh",
                arguments: SSHCommands.checkRemoteRDP(for: profile),
                requireSuccess: false
            )
            guard remoteCheck.status == 0 else {
                throw UserFacingError(
                    "RDP-компьютер недоступен через VPS. Включите OpenVPN и дождитесь статуса «Включено», затем повторите."
                )
            }

            if let pid = await self.listenerPID(on: profile.rdpLocalPort) {
                let args = await self.processArguments(pid: pid)
                guard self.matchesTunnel(args, profile: profile, marker: "-L") else {
                    throw UserFacingError("Порт \(profile.rdpLocalPort) занят другим процессом PID \(pid).")
                }
            } else {
                let process = try self.runner.launch("/usr/bin/ssh", arguments: SSHCommands.rdp(for: profile))
                self.launchedProcesses[self.processKey(profile, "rdp")] = process
                _ = try await self.waitForPort(profile.rdpLocalPort, process: process)
            }
            let pid = await self.listenerPID(on: profile.rdpLocalPort)
            return .active("127.0.0.1:\(profile.rdpLocalPort) · PID \(pid ?? 0)")
        }
    }

    func stopRDP(_ rawProfile: ServerProfile) async {
        await stop(rawProfile, kind: "rdp", keyPath: \.rdp, port: rawProfile.rdpLocalPort, marker: "-L")
    }

    func startRemoteVPN(_ rawProfile: ServerProfile) async {
        await perform(rawProfile, keyPath: \.remoteVPN, working: "Включение OpenVPN…") { profile in
            try self.requireRemoteVPNService(profile)
            do {
                _ = try await self.runner.run("/usr/bin/ssh", arguments: SSHCommands.startRemoteVPN(for: profile))
            } catch {
                throw self.friendlyVPNError(error, profile: profile)
            }
            try await Task.sleep(nanoseconds: 700_000_000)
            let result = try await self.runner.run(
                "/usr/bin/ssh",
                arguments: SSHCommands.remoteVPNStatus(for: profile),
                requireSuccess: false
            )
            guard result.status == 0 else {
                throw UserFacingError("OpenVPN не перешёл в active. Проверьте systemctl status \(profile.remoteVPNService) на VPS.")
            }
            return .active("Включено на \(profile.name)")
        }
    }

    func stopRemoteVPN(_ rawProfile: ServerProfile) async {
        await perform(rawProfile, keyPath: \.remoteVPN, working: "Выключение OpenVPN…") { profile in
            try self.requireRemoteVPNService(profile)
            do {
                _ = try await self.runner.run("/usr/bin/ssh", arguments: SSHCommands.stopRemoteVPN(for: profile))
            } catch {
                throw self.friendlyVPNError(error, profile: profile)
            }
            return .idle
        }
    }

    func storedVPNCredentials(for profile: ServerProfile) -> VPNCredentials? {
        try? credentialStore.load(profileID: profile.id)
    }

    func updateRemoteVPNCredentials(
        _ rawProfile: ServerProfile,
        username: String,
        password: String
    ) async -> Bool {
        update(rawProfile.id, \.remoteVPN, .working("Обновление доступа OpenVPN…"))
        do {
            let profile = try rawProfile.validated()
            let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanUsername.isEmpty, !password.isEmpty else {
                throw UserFacingError("Введите логин и новый пароль OpenVPN.")
            }
            guard !cleanUsername.contains("\n"), !cleanUsername.contains("\r"),
                  !password.contains("\n"), !password.contains("\r") else {
                throw UserFacingError("Логин и пароль не могут содержать перенос строки.")
            }
            guard cleanUsername.count <= 256, password.count <= 1024 else {
                throw UserFacingError("Логин или пароль слишком длинный.")
            }
            guard let instance = profile.remoteVPNInstance else {
                throw UserFacingError("Обновление доступа поддерживается для сервиса вида openvpn-client@имя.")
            }

            let payload = Data("\(cleanUsername)\n\(password)\n".utf8)
            do {
                _ = try await runner.run(
                    "/usr/bin/ssh",
                    arguments: SSHCommands.updateRemoteVPNCredentials(for: profile, instance: instance),
                    input: payload
                )
            } catch {
                throw friendlyVPNError(error, profile: profile)
            }

            try credentialStore.save(
                VPNCredentials(username: cleanUsername, password: password),
                profileID: profile.id
            )
            update(profile.id, \.remoteVPN, .active("Пароль обновлён · OpenVPN включён"))
            return true
        } catch {
            update(rawProfile.id, \.remoteVPN, .failed(error.localizedDescription))
            return false
        }
    }

    func openRDPClient(_ rawProfile: ServerProfile) async {
        update(rawProfile.id, \.rdp, .working("Проверка RDP-подключения…"))
        do {
            let profile = try rawProfile.validated()
            guard let pid = await listenerPID(on: profile.rdpLocalPort) else {
                throw UserFacingError("RDP-туннель выключен. Сначала нажмите «Включить».")
            }
            let arguments = await processArguments(pid: pid)
            guard matchesTunnel(arguments, profile: profile, marker: "-L") else {
                throw UserFacingError("Локальный RDP-порт занят другим процессом PID \(pid).")
            }
            let remoteCheck = try await runner.run(
                "/usr/bin/ssh",
                arguments: SSHCommands.checkRemoteRDP(for: profile),
                requireSuccess: false
            )
            guard remoteCheck.status == 0 else {
                throw UserFacingError(
                    "Связь с RDP-компьютером потеряна. Включите OpenVPN и повторно включите RDP-туннель."
                )
            }
            try openRDP(profile)
            update(profile.id, \.rdp, .active("Открыт RDP · PID \(pid)"))
        } catch {
            update(rawProfile.id, \.rdp, .failed(error.localizedDescription))
        }
    }

    func openLocalVPN(_ rawProfile: ServerProfile) async {
        await perform(rawProfile, keyPath: \.localVPN, working: "Открытие VPN-клиента…") { profile in
            guard !profile.vpnConfigPath.isEmpty else {
                throw UserFacingError("Сначала выберите .ovpn файл в настройках профиля.")
            }
            let url = URL(fileURLWithPath: profile.vpnConfigPath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw UserFacingError("VPN-файл не найден: \(url.path)")
            }
            guard NSWorkspace.shared.open(url) else {
                throw UserFacingError("macOS не нашла приложение для открытия .ovpn. Установите VPN-клиент.")
            }
            return .active("Профиль передан VPN-клиенту")
        }
    }

    func launch(_ application: ManagedApplication, through rawProfile: ServerProfile) async {
        let key = applicationKey(application, rawProfile)
        applicationStates[key] = .working("Запуск через proxy…")
        do {
            let profile = try rawProfile.validated()
            guard FileManager.default.isExecutableFile(atPath: application.binaryPath) else {
                throw UserFacingError("\(application.name) не найден в папке /Applications.")
            }
            guard let pid = await listenerPID(on: profile.proxyPort) else {
                throw UserFacingError("Сначала включите SOCKS5 Proxy для страны \(profile.name).")
            }
            let tunnelArguments = await processArguments(pid: pid)
            guard matchesTunnel(tunnelArguments, profile: profile, marker: "-D") else {
                throw UserFacingError("Порт \(profile.proxyPort) занят не туннелем выбранной страны.")
            }
            if isApplicationRunning(application) {
                throw UserFacingError(
                    "\(application.name) уже запущен. Закройте его вручную и повторите запуск — приложение не завершает программы с несохранённой работой."
                )
            }
            let process = try runner.launch(
                application.binaryPath,
                arguments: ManagedApplication.launchArguments(for: profile),
                environment: ManagedApplication.proxyEnvironment(for: profile)
            )
            launchedProcesses["app:\(application.id)"] = process
            launchedApplicationProfiles[application.id] = profile.id
            applicationStates[key] = .active("Запущено через \(profile.name)")
        } catch {
            applicationStates[key] = .failed(error.localizedDescription)
        }
    }

    private func perform(
        _ rawProfile: ServerProfile,
        keyPath: WritableKeyPath<ProfileConnectionState, ConnectionState>,
        working: String,
        operation: (ServerProfile) async throws -> ConnectionState
    ) async {
        update(rawProfile.id, keyPath, .working(working))
        do {
            let profile = try rawProfile.validated()
            update(profile.id, keyPath, try await operation(profile))
        } catch {
            update(rawProfile.id, keyPath, .failed(error.localizedDescription))
        }
    }

    private func stop(
        _ rawProfile: ServerProfile,
        kind: String,
        keyPath: WritableKeyPath<ProfileConnectionState, ConnectionState>,
        port: Int,
        marker: String
    ) async {
        await perform(rawProfile, keyPath: keyPath, working: "Остановка…") { profile in
            guard let pid = await self.listenerPID(on: port) else { return .idle }
            let arguments = await self.processArguments(pid: pid)
            guard self.matchesTunnel(arguments, profile: profile, marker: marker) else {
                throw UserFacingError("Порт \(port) занят чужим процессом PID \(pid). Приложение не будет его останавливать.")
            }
            _ = try await self.runner.run("/bin/kill", arguments: [String(pid)])
            self.launchedProcesses.removeValue(forKey: self.processKey(profile, kind))
            return .idle
        }
    }

    private func listenerPID(on port: Int) async -> Int32? {
        let result = try? await runner.run(
            "/usr/sbin/lsof",
            arguments: ["-nP", "-tiTCP:\(port)", "-sTCP:LISTEN"],
            requireSuccess: false
        )
        guard let first = result?.output.split(whereSeparator: \.isNewline).first else { return nil }
        return Int32(first.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func processArguments(pid: Int32) async -> String {
        let result = try? await runner.run(
            "/bin/ps",
            arguments: ["-p", String(pid), "-o", "args="],
            requireSuccess: false
        )
        return result?.output ?? ""
    }

    private func isApplicationRunning(_ application: ManagedApplication) -> Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: application.bundleIdentifier
        ).isEmpty
    }

    private func waitForPort(_ port: Int, process: Process) async throws -> Int32 {
        for _ in 0..<30 {
            if let pid = await listenerPID(on: port) { return pid }
            if !process.isRunning {
                throw UserFacingError("SSH завершился до открытия порта \(port). Проверьте alias, ключ и сеть.")
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        process.terminate()
        throw UserFacingError("SSH не открыл локальный порт \(port) за отведённое время.")
    }

    private func openRDP(_ profile: ServerProfile) throws {
        let text = RDPFile.contents(port: profile.rdpLocalPort)
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("portglide-\(profile.id.uuidString).rdp")
        try text.write(to: file, atomically: true, encoding: .utf8)
        guard NSWorkspace.shared.open(file) else {
            throw UserFacingError("Не удалось открыть RDP-клиент. Установите Windows App или Microsoft Remote Desktop.")
        }
    }

    private func processKey(_ profile: ServerProfile, _ kind: String) -> String {
        "\(profile.id.uuidString):\(kind)"
    }

    @discardableResult
    private func refreshRemoteVPN(_ profile: ServerProfile) async -> Bool {
        guard !profile.remoteVPNService.isEmpty else {
            update(profile.id, \.remoteVPN, .failed("Сервис не настроен"))
            return false
        }
        let result = try? await runner.run(
            "/usr/bin/ssh",
            arguments: SSHCommands.remoteVPNStatus(for: profile),
            requireSuccess: false
        )
        if result?.status == 0 {
            update(profile.id, \.remoteVPN, .active("Включено на \(profile.name)"))
            return true
        } else {
            update(profile.id, \.remoteVPN, .idle)
            return false
        }
    }

    private func requireRemoteVPNService(_ profile: ServerProfile) throws {
        guard !profile.remoteVPNService.isEmpty else {
            throw UserFacingError("Укажите Remote OpenVPN service в настройках страны.")
        }
    }

    private func friendlyVPNError(_ error: Error, profile: ServerProfile) -> Error {
        let text = error.localizedDescription.lowercased()
        if text.contains("password") || text.contains("sudo") || text.contains("not permitted") {
            return UserFacingError(
                "VPS не разрешил управление OpenVPN без пароля. Настройте ограниченный sudo -n для systemctl start/stop \(profile.remoteVPNService). Пароль приложение не запрашивает и не хранит."
            )
        }
        return error
    }

    func refreshApplicationStates(_ rawProfile: ServerProfile) {
        guard let profile = try? rawProfile.validated() else { return }
        for application in ManagedApplication.supported {
            let key = applicationKey(application, profile)
            guard FileManager.default.isExecutableFile(atPath: application.binaryPath) else {
                applicationStates[key] = .failed("Не установлено")
                continue
            }
            guard isApplicationRunning(application) else {
                launchedProcesses.removeValue(forKey: "app:\(application.id)")
                launchedApplicationProfiles.removeValue(forKey: application.id)
                applicationStates[key] = ManagedApplicationStateResolver.resolve(
                    isRunning: false,
                    launchedThroughProfile: false,
                    proxyIsActive: false,
                    profileName: profile.name
                )
                continue
            }

            applicationStates[key] = ManagedApplicationStateResolver.resolve(
                isRunning: true,
                launchedThroughProfile: launchedApplicationProfiles[application.id] == profile.id,
                proxyIsActive: state(for: profile).proxy.isActive,
                profileName: profile.name
            )
        }
    }

    private func applicationKey(_ application: ManagedApplication, _ profile: ServerProfile) -> String {
        "\(profile.id.uuidString):\(application.id)"
    }

    private func matchesTunnel(_ arguments: String, profile: ServerProfile, marker: String) -> Bool {
        let endpoint = marker == "-D"
            ? "127.0.0.1:\(profile.proxyPort)"
            : "127.0.0.1:\(profile.rdpLocalPort):\(profile.rdpTargetHost):\(profile.rdpTargetPort)"
        return arguments.contains("ssh")
            && arguments.contains(marker)
            && arguments.contains(endpoint)
            && arguments.contains(profile.sshAlias)
    }

    private func update(
        _ id: ServerProfile.ID,
        _ keyPath: WritableKeyPath<ProfileConnectionState, ConnectionState>,
        _ value: ConnectionState
    ) {
        var state = states[id] ?? ProfileConnectionState()
        state[keyPath: keyPath] = value
        states[id] = state
    }
}

struct UserFacingError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
