import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var controller: TunnelController
    @State private var editedProfile: ServerProfile?
    @State private var profileToDelete: ServerProfile?

    var body: some View {
        NavigationSplitView {
            List(store.profiles, selection: $store.selectedID) { profile in
                HStack(spacing: 10) {
                    Text(profile.flag.isEmpty ? "🌐" : profile.flag).font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                        Text(profile.sshAlias).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tag(profile.id)
                .contextMenu {
                    Button("Редактировать") { editedProfile = profile }
                    Button("Удалить", role: .destructive) { profileToDelete = profile }
                }
            }
            .navigationTitle("Страны")
            .toolbar {
                ToolbarItemGroup {
                    Button("Добавить страну", systemImage: "plus") {
                        editedProfile = ServerProfile(
                            name: "Новая страна",
                            flag: "🌐",
                            sshAlias: "new-vps",
                            proxyPort: nextFreePort(start: 1091),
                            rdpLocalPort: nextFreePort(start: 13391),
                            rdpTargetHost: "127.0.0.1"
                        )
                    }
                    Menu {
                        Button("Восстановить пример профиля") {
                            try? store.resetDefaults()
                        }
                    } label: {
                        Label("Дополнительно", systemImage: "ellipsis.circle")
                    }
                }
            }
        } detail: {
            if let profile = store.selectedProfile {
                ProfileDetailView(profile: profile) { editedProfile = profile }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "globe.europe.africa")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("Выберите страну")
                        .font(.title2)
                    Text("Или добавьте новый VPS через кнопку +")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(item: $editedProfile) { profile in
            ProfileEditor(profile: profile, onSave: store.upsert)
        }
        .alert(
            "Удалить профиль \(profileToDelete?.name ?? "")?",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            ),
            presenting: profileToDelete
        ) { profile in
            Button("Удалить", role: .destructive) { try? store.remove(profile) }
            Button("Отмена", role: .cancel) {}
        } message: { _ in
            Text("Активные соединения сначала нужно выключить вручную.")
        }
        .alert("Ошибка хранения профилей", isPresented: Binding(
            get: { store.persistenceError != nil },
            set: { if !$0 { store.persistenceError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.persistenceError ?? "Неизвестная ошибка")
        }
        .frame(minWidth: 880, minHeight: 620)
    }

    private func nextFreePort(start: Int) -> Int {
        let used = Set(store.profiles.flatMap { [$0.proxyPort, $0.rdpLocalPort] })
        return (start...65535).first(where: { !used.contains($0) }) ?? start
    }
}
