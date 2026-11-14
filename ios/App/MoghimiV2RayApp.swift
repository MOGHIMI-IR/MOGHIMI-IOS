import SwiftUI

@main
struct MoghimiV2RayApp: App {
    @StateObject private var store = ProfileStore()
    @StateObject private var vpn = VPNManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(vpn)
                .environment(\.layoutDirection, .rightToLeft)
                .tint(theme.accent)
                .preferredColorScheme(resolvedScheme)
                .task {
                    // Sync website profiles only; never start a VPN tunnel on app launch.
                    await store.syncMoghimiCloud()
                }
        }
    }

    private var theme: AppTheme { AppTheme(rawValue: store.settings.appTheme) ?? .cyber }

    private var resolvedScheme: ColorScheme? {
        if theme == .amoled { return .dark }
        return (DarkMode(rawValue: store.settings.darkMode) ?? .system).colorScheme
    }
}
