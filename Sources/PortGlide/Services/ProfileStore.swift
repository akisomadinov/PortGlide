import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [ServerProfile] = []
    @Published var selectedID: ServerProfile.ID?
    @Published var persistenceError: String?

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
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
            let data = try Data(contentsOf: fileURL)
            profiles = try JSONDecoder().decode([ServerProfile].self, from: data)
            if profiles.isEmpty { throw CocoaError(.fileReadCorruptFile) }
            selectedID = profiles.first?.id
        } catch {
            profiles = [.example]
            selectedID = ServerProfile.example.id
            do { try persist() } catch { persistenceError = error.localizedDescription }
        }
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profiles).write(to: fileURL, options: .atomic)
    }

    private static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PortGlide", isDirectory: true)
            .appendingPathComponent("profiles.json")
    }
}
