import Foundation

/// Identifiers shared by the UI app and the Network Extension.
enum AppGroup {
    static let id = "group.com.moghimi.vpn.ios"
    static let tunnelBundleId = "com.moghimi.vpn.ios.PacketTunnel"
    static let profilesKey = "profiles"
    static let subscriptionsKey = "subscriptions"
    static let settingsKey = "settings"
    static let activeIdKey = "activeProfileId"
    static let activeConfigKey = "activeConfigJson"
    static var defaults: UserDefaults? { UserDefaults(suiteName: id) }
}
