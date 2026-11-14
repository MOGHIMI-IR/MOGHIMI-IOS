import Foundation

/// Persists profiles, subscriptions and settings in the shared App Group container, and
/// builds the active Xray config for the extension to run.
@MainActor
final class ProfileStore: ObservableObject {
    @Published var profiles: [VpnProfile] = []
    @Published var subscriptions: [Subscription] = []
    @Published var settings = AppSettings()
    @Published var activeId: String? = nil
    @Published var isCloudSyncing = false
    @Published var cloudSyncMessage: String? = nil

    private let d = AppGroup.defaults

    init() { load() }

    func load() {
        if let data = d?.data(forKey: AppGroup.profilesKey),
           let v = try? JSONDecoder().decode([VpnProfile].self, from: data) { profiles = v }
        if let data = d?.data(forKey: AppGroup.subscriptionsKey),
           let v = try? JSONDecoder().decode([Subscription].self, from: data) { subscriptions = v }
        if let data = d?.data(forKey: AppGroup.settingsKey),
           let v = try? JSONDecoder().decode(AppSettings.self, from: data) { settings = v }
        activeId = d?.string(forKey: AppGroup.activeIdKey)
    }

    func save() {
        d?.set(try? JSONEncoder().encode(profiles), forKey: AppGroup.profilesKey)
        d?.set(try? JSONEncoder().encode(subscriptions), forKey: AppGroup.subscriptionsKey)
        d?.set(try? JSONEncoder().encode(settings), forKey: AppGroup.settingsKey)
        d?.set(activeId, forKey: AppGroup.activeIdKey)
    }

    var activeProfile: VpnProfile? { profiles.first { $0.id == activeId } }

    func add(_ p: VpnProfile) {
        profiles.append(p)
        if activeId == nil { activeId = p.id }
        save()
    }

    func remove(_ p: VpnProfile) {
        profiles.removeAll { $0.id == p.id }
        if activeId == p.id { activeId = profiles.first?.id }
        save()
    }

    func setActive(_ p: VpnProfile) { activeId = p.id; save() }

    func update(_ p: VpnProfile) {
        if let i = profiles.firstIndex(where: { $0.id == p.id }) { profiles[i] = p; save() }
    }

    func duplicate(_ p: VpnProfile) {
        var copy = p
        copy.id = UUID().uuidString
        copy.name = p.name + " Copy"
        copy.subscriptionId = nil
        copy.latencyMs = -1
        profiles.append(copy)
        save()
    }

    func setLatency(_ id: String, _ ms: Int) {
        if let i = profiles.firstIndex(where: { $0.id == id }) { profiles[i].latencyMs = ms; save() }
    }

    // ── Subscriptions ──────────────────────────────────────────────────────────

    func addSubscription(_ sub: Subscription) {
        subscriptions.append(sub)
        save()
    }

    func removeSubscription(_ sub: Subscription) {
        guard sub.id != MoghimiCloudSync.subscriptionId else { return }
        subscriptions.removeAll { $0.id == sub.id }
        profiles.removeAll { $0.subscriptionId == sub.id }
        if activeProfile == nil { activeId = profiles.first?.id }
        save()
    }

    /// Re-fetches a user's own subscription, or the dedicated Moghimi site group.
    func refresh(_ sub: Subscription) async {
        if sub.id == MoghimiCloudSync.subscriptionId {
            await syncMoghimiCloud()
            return
        }
        let result = await SubscriptionService.fetch(sub, settings: settings)
        guard !result.profiles.isEmpty else { return }

        let previousFingerprint = activeProfile.map(profileFingerprint)
        let fresh = result.profiles.map { p -> VpnProfile in
            var copy = p
            copy.subscriptionId = sub.id
            return copy
        }
        profiles.removeAll { $0.subscriptionId == sub.id }
        profiles.append(contentsOf: fresh)
        if let index = subscriptions.firstIndex(where: { $0.id == sub.id }) {
            subscriptions[index].profileCount = fresh.count
            subscriptions[index].lastUpdated = Date().timeIntervalSince1970
            if let usage = result.usage {
                subscriptions[index].uploadBytes = usage.upload
                subscriptions[index].downloadBytes = usage.download
                subscriptions[index].totalBytes = usage.total
                subscriptions[index].expireEpochSec = usage.expire
            }
        }
        if let previousFingerprint,
           let replacement = fresh.first(where: { profileFingerprint($0) == previousFingerprint }) {
            activeId = replacement.id
        } else if activeProfile == nil {
            activeId = profiles.first?.id
        }
        save()
    }

    func syncMoghimiCloud() async {
        guard !isCloudSyncing else { return }
        isCloudSyncing = true
        cloudSyncMessage = nil
        defer { isCloudSyncing = false }

        do {
            let downloaded = try await MoghimiCloudSync.fetchProfiles()
            let oldCloudProfiles = profiles.filter { $0.subscriptionId == MoghimiCloudSync.subscriptionId }
            let activeWasCloud = activeProfile?.subscriptionId == MoghimiCloudSync.subscriptionId
            let activeFingerprint = activeWasCloud ? activeProfile.map(profileFingerprint) : nil
            let fresh = downloaded.map { profile -> VpnProfile in
                var copy = profile
                copy.subscriptionId = MoghimiCloudSync.subscriptionId
                if let old = oldCloudProfiles.first(where: { profileFingerprint($0) == profileFingerprint(copy) }) {
                    copy.id = old.id
                    copy.latencyMs = old.latencyMs
                }
                return copy
            }

            profiles.removeAll { $0.subscriptionId == MoghimiCloudSync.subscriptionId }
            profiles.append(contentsOf: fresh)

            if let activeFingerprint,
               let replacement = fresh.first(where: { profileFingerprint($0) == activeFingerprint }) {
                activeId = replacement.id
            } else if activeWasCloud {
                activeId = fresh.first?.id
            } else if activeId == nil {
                activeId = fresh.first?.id
            }

            if let index = subscriptions.firstIndex(where: { $0.id == MoghimiCloudSync.subscriptionId }) {
                subscriptions[index].profileCount = fresh.count
                subscriptions[index].lastUpdated = Date().timeIntervalSince1970
            } else {
                subscriptions.append(Subscription(
                    id: MoghimiCloudSync.subscriptionId,
                    name: "کانفیگ‌های سایت مقیمی",
                    url: "moghimi-cloud://"
                ))
                if let index = subscriptions.firstIndex(where: { $0.id == MoghimiCloudSync.subscriptionId }) {
                    subscriptions[index].profileCount = fresh.count
                    subscriptions[index].lastUpdated = Date().timeIntervalSince1970
                }
            }
            save()
            cloudSyncMessage = "همگام‌سازی انجام شد؛ \(fresh.count) کانفیگ فعال دریافت شد."
        } catch {
            cloudSyncMessage = error.localizedDescription
        }
    }

    private func profileFingerprint(_ profile: VpnProfile) -> String {
        [
            profile.proto.rawValue, profile.address, String(profile.port),
            profile.uuid, profile.ssPassword, profile.hystPassword
        ].joined(separator: "|")
    }

    func updateAll() async {
        await syncMoghimiCloud()
        for sub in subscriptions where sub.id != MoghimiCloudSync.subscriptionId {
            await refresh(sub)
        }
    }

    /// Build the active profile's Xray config and write it where the extension reads it.
    /// Returns false if there is no active profile.
    @discardableResult
    func writeActiveConfig() -> Bool {
        guard let p = activeProfile else { return false }
        d?.set(XrayConfigBuilder.build(p, settings), forKey: AppGroup.activeConfigKey)
        return true
    }
}
