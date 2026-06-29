import SwiftUI

@main
struct PortGlideApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var tunnelController = TunnelController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(profileStore)
                .environmentObject(tunnelController)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
