import SwiftUI

struct InterfaceSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(InterfacePreferences.showSSH) private var showSSH = true
    @AppStorage(InterfacePreferences.showSOCKS5) private var showSOCKS5 = true
    @AppStorage(InterfacePreferences.showApplications) private var showApplications = true
    @AppStorage(InterfacePreferences.showLocalVPN) private var showLocalVPN = true
    @AppStorage(InterfacePreferences.showRemoteOpenVPN) private var showRemoteOpenVPN = true
    @AppStorage(InterfacePreferences.showRDP) private var showRDP = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Вид главного экрана")
                    .font(.title2.bold())
                Text("Скрытые функции продолжают работать, если соединение уже запущено.")
                    .foregroundStyle(.secondary)
            }

            Form {
                Section("Подключения") {
                    Toggle("SSH", isOn: $showSSH)
                    Toggle("SOCKS5 Proxy", isOn: $showSOCKS5)
                }

                Section("Разделы") {
                    Toggle("Приложения через SOCKS5", isOn: $showApplications)
                    Toggle("Локальный VPN-профиль", isOn: $showLocalVPN)
                }

                Section("Удалённый доступ") {
                    Toggle("OpenVPN на VPS", isOn: $showRemoteOpenVPN)
                    Toggle("RDP-туннель", isOn: $showRDP)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Показать всё") {
                    showSSH = true
                    showSOCKS5 = true
                    showApplications = true
                    showLocalVPN = true
                    showRemoteOpenVPN = true
                    showRDP = true
                }
                Spacer()
                Button("Готово") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480, height: 520)
    }
}
