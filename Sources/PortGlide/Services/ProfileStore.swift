import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [ServerProfile] = []
    @Published var selectedID: ServerProfile.ID?
    @Published var persistenceError: String?

    private let fileURL: URL
    private let backupFileURL: URL

    init(fileURL: URL? = nil, backupFileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.backupFileURL = backupFileURL ?? Self.defaultBackupFileURL
        load()
    }

    var selectedProfile: ServerProfile? {
        profiles.first(where: { $0.id == selectedID })
    }

    func upsert(_ profile: ServerProfile) throws {
        let valid = try profile.validated()
        if let index = profiles.firstIndex(where: { $0.id == valid.id }) {
            profiles[index] = valid
        } else {
            profiles.append(valid)
        }
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        selectedID = valid.id
        try persist()
    }

    func remove(_ profile: ServerProfile) throws {
        profiles.removeAll { $0.id == profile.id }
        if selectedID == profile.id { selectedID = profiles.first?.id }
        try persist()
    }

    func resetDefaults() throws {
        profiles = [.example]
        selectedID = ServerProfile.example.id
        try persist()
    }

    private func load() {
        do {
            profiles = try loadProfiles(from: fileURL)
            selectedID = profiles.first?.id
            try write(profiles, to: backupFileURL)
        } catch {
            do {
                profiles = try loadProfiles(from: backupFileURL)
                selectedID = profiles.first?.id
                try write(profiles, to: fileURL)
                persistenceError = "Основной файл профилей был восстановлен из резервной копии."
            } catch {
                profiles = [.example]
                selectedID = ServerProfile.example.id
                do { try persist() } catch { persistenceError = error.localizedDescription }
            }
        }
    }

    private func persist() throws {
        try write(profiles, to: fileURL)
        try write(profiles, to: backupFileURL)
    }

    private func loadProfiles(from url: URL) throws -> [ServerProfile] {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([ServerProfile].self, from: data)
        guard !decoded.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        return try decoded.map { try $0.validated() }
    }

    private func write(_ profiles: [ServerProfile], to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profiles).write(to: url, options: .atomic)
    }

    private static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PortGlide", isDirectory: true)
            .appendingPathComponent("profiles.json")
    }

    private static var defaultBackupFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PortGlide", isDirectory: true)
            .appendingPathComponent("profiles.backup.json")
    }
}
