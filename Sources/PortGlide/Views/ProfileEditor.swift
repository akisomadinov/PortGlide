import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ServerProfile
    @State private var errorMessage: String?
    let onSave: (ServerProfile) throws -> Void

    init(profile: ServerProfile, onSave: @escaping (ServerProfile) throws -> Void) {
        _draft = State(initialValue: profile)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Страна") {
                    TextField("Название", text: $draft.name)
                    TextField("Флаг", text: $draft.flag)
                    TextField("SSH alias", text: $draft.sshAlias)
                }
                Section("SOCKS5 proxy") {
                    TextField("Локальный порт", value: $draft.proxyPort, format: .number)
                }
                Section("RDP через VPS") {
                    TextField("Локальный порт", value: $draft.rdpLocalPort, format: .number)
                    TextField("RDP target host", text: $draft.rdpTargetHost)
                    TextField("RDP target port", value: $draft.rdpTargetPort, format: .number)
                    TextField("Remote OpenVPN service", text: $draft.remoteVPNService)
                }
                Section("Локальный VPN-клиент") {
                    HStack {
                        TextField("Путь к .ovpn", text: $draft.vpnConfigPath)
                        Button("Выбрать…", action: chooseVPNFile)
                    }
                    Text("Сохраняется только путь; содержимое и ключи приложение не читает.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Отмена") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Сохранить") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 560, height: 610)
    }

    private func chooseVPNFile() {
        let panel = NSOpenPanel()
        if let openVPNType = UTType(filenameExtension: "ovpn") {
            panel.allowedContentTypes = [openVPNType]
        }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Выберите OpenVPN profile (.ovpn)"
        if panel.runModal() == .OK, let url = panel.url {
            draft.vpnConfigPath = url.path
        }
    }

    private func save() {
        do {
            try onSave(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
