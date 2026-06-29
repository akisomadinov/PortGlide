import SwiftUI

struct VPNCredentialsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var controller: TunnelController

    let profile: ServerProfile
    @State private var username = ""
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Доступ OpenVPN").font(.title2.bold())
                Text(profile.name).foregroundStyle(.secondary)
            }

            Form {
                TextField("Доменный логин", text: $username)
                    .textContentType(.username)
                SecureField("Новый пароль", text: $password)
                    .textContentType(.password)
                Text("Credentials передаются на VPS только через SSH stdin и сохраняются в macOS Keychain. В JSON, аргументы процессов и Git они не попадают.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Отмена") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Обновить и перезапустить") {
                    Task {
                        isSubmitting = true
                        let success = await controller.updateRemoteVPNCredentials(
                            profile,
                            username: username,
                            password: password
                        )
                        isSubmitting = false
                        if success { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || username.isEmpty || password.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520, height: 360)
        .onAppear {
            if let credentials = controller.storedVPNCredentials(for: profile) {
                username = credentials.username
                password = credentials.password
            }
        }
    }
}

