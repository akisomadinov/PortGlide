import SwiftUI

struct ProfileDetailView: View {
    let profile: ServerProfile
    let onEdit: () -> Void
    @EnvironmentObject private var controller: TunnelController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Text(profile.flag.isEmpty ? "🌐" : profile.flag).font(.system(size: 46))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name).font(.largeTitle.bold())
                        Text(profile.sshAlias).font(.callout.monospaced()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Настроить", systemImage: "slider.horizontal.3", action: onEdit)
                }

                GroupBox("Подключения") {
                    VStack(spacing: 0) {
                        ServiceListRow(
                            title: "SSH",
                            subtitle: "Проверка доступа через \(profile.sshAlias)",
                            systemImage: "key.horizontal",
                            state: connectionState.ssh,
                            primaryTitle: "Проверить",
                            primaryAction: { Task { await controller.checkSSH(profile) } }
                        )

                        Divider()

                        ServiceListRow(
                            title: "SOCKS5 Proxy",
                            subtitle: "127.0.0.1:\(profile.proxyPort)",
                            systemImage: "network",
                            state: connectionState.proxy,
                            primaryTitle: connectionState.proxy.isActive ? "Выключить" : "Включить",
                            primaryAction: {
                                Task {
                                    if connectionState.proxy.isActive {
                                        await controller.stopProxy(profile)
                                    } else {
                                        await controller.startProxy(profile)
                                    }
                                }
                            }
                        )

                        Divider()

                        ServiceListRow(
                            title: "OpenVPN на VPS",
                            subtitle: profile.remoteVPNService.isEmpty ? "Сервис не настроен" : profile.remoteVPNService,
                            systemImage: "shield.lefthalf.filled",
                            state: connectionState.remoteVPN,
                            primaryTitle: connectionState.remoteVPN.isActive ? "Выключить" : "Включить",
                            primaryAction: {
                                Task {
                                    if connectionState.remoteVPN.isActive {
                                        await controller.stopRemoteVPN(profile)
                                    } else {
                                        await controller.startRemoteVPN(profile)
                                    }
                                }
                            }
                        )

                        Divider()

                        ServiceListRow(
                            title: "RDP-туннель",
                            subtitle: "127.0.0.1:\(profile.rdpLocalPort) → \(profile.rdpTargetHost):\(profile.rdpTargetPort)",
                            systemImage: "desktopcomputer",
                            state: connectionState.rdp,
                            primaryTitle: connectionState.rdp.isActive ? "Выключить" : "Включить",
                            primaryAction: {
                                Task {
                                    if connectionState.rdp.isActive {
                                        await controller.stopRDP(profile)
                                    } else {
                                        await controller.startRDP(profile)
                                    }
                                }
                            },
                            secondaryTitle: "Открыть RDP",
                            secondaryAction: { controller.openRDPClient(profile) }
                        )
                    }
                    .padding(.horizontal, 8)
                }

                GroupBox("Приложения через SOCKS5") {
                    VStack(spacing: 0) {
                        ForEach(Array(ManagedApplication.supported.enumerated()), id: \.element.id) { index, application in
                            if index > 0 { Divider() }
                            let appState = controller.state(for: application, profile: profile)
                            ServiceListRow(
                                title: application.name,
                                subtitle: "Запуск через \(profile.name) · 127.0.0.1:\(profile.proxyPort)",
                                systemImage: application.systemImage,
                                state: appState,
                                primaryTitle: appState.isActive ? "Уже запущено" : "Запустить",
                                primaryAction: {
                                    Task { await controller.launch(application, through: profile) }
                                },
                                primaryDisabled: appState.isActive
                                    || !FileManager.default.isExecutableFile(atPath: application.binaryPath)
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }

                GroupBox("Локальный VPN-профиль") {
                    ServiceListRow(
                        title: profile.vpnConfigPath.isEmpty
                            ? "Файл .ovpn не выбран"
                            : URL(fileURLWithPath: profile.vpnConfigPath).lastPathComponent,
                        subtitle: "Не связан с RDP и открывается только вручную",
                        systemImage: "doc.badge.gearshape",
                        state: connectionState.localVPN,
                        primaryTitle: "Открыть",
                        primaryAction: { Task { await controller.openLocalVPN(profile) } }
                    )
                    .padding(.horizontal, 8)
                }

                Text("Каждая функция управляется отдельно. OpenVPN никогда не открывает RDP-приложение; кнопка «Открыть RDP» работает только при включённом RDP-туннеле.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .task(id: profile.id) {
            await controller.refresh(profile)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    controller.refreshApplicationStates(profile)
                }
            }
        }
    }

    private var connectionState: ProfileConnectionState {
        controller.state(for: profile)
    }
}
