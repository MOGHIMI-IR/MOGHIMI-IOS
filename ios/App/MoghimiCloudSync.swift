import Foundation

enum MoghimiCloudSyncError: LocalizedError {
    case noActiveEntries, noSupportedProfiles, invalidResponse, requestFailed(Int)
    var errorDescription: String? {
        switch self {
        case .noActiveEntries: return "در سایت هنوز کانفیگ فعالی منتشر نشده است."
        case .noSupportedProfiles: return "کانفیگ فعالی با قالب قابل پشتیبانی پیدا نشد."
        case .invalidResponse: return "پاسخ سرویس کانفیگ معتبر نیست."
        case .requestFailed(let status): return "ارتباط با سرویس کانفیگ ناموفق بود (HTTP \(status))."
        }
    }
}

enum MoghimiCloudSync {
    static let subscriptionId = "moghimi-cloud"
    private static let projectURL = "https://atrwhvyhopifugphfcpe.supabase.co"
    private static let publishableKey = "sb_publishable_9jauFOO0mFzTSs5rtI2Orw_ZekPGGdt"
    private static let storageBucket = "v2ray-files"

    private struct Entry: Decodable {
        let title: String?
        let entryType: String
        let configText: String?
        let filePath: String?
        enum CodingKeys: String, CodingKey {
            case title
            case entryType = "entry_type"
            case configText = "config_text"
            case filePath = "file_path"
        }
    }

    static func fetchProfiles() async throws -> [VpnProfile] {
        let address = "\(projectURL)/rest/v1/v2ray_entries?select=id,title,entry_type,config_text,file_path,file_name&is_active=eq.true&order=created_at.desc"
        guard let url = URL(string: address) else { throw MoghimiCloudSyncError.invalidResponse }
        let data = try await request(url: url, method: "GET", body: nil, includeApiKey: true)
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        guard !entries.isEmpty else { throw MoghimiCloudSyncError.noActiveEntries }

        var imported: [VpnProfile] = []
        var seen = Set<String>()
        for entry in entries {
            let payload: String
            switch entry.entryType {
            case "text":
                payload = entry.configText ?? ""
            case "file":
                guard let path = entry.filePath, !path.isEmpty else { continue }
                payload = try await downloadPrivateFile(path)
            default:
                continue
            }

            for var profile in ProfileCodec.decodeSubscriptionBody(payload) {
                if profile.name == "Unnamed", let title = entry.title, !title.isEmpty {
                    profile.name = title
                }
                profile.subscriptionId = subscriptionId
                let key = [
                    profile.proto.rawValue, profile.address, String(profile.port),
                    profile.uuid, profile.ssPassword, profile.hystPassword
                ].joined(separator: "|")
                if seen.insert(key).inserted { imported.append(profile) }
            }
        }
        guard !imported.isEmpty else { throw MoghimiCloudSyncError.noSupportedProfiles }
        return imported
    }

    private static func downloadPrivateFile(_ filePath: String) async throws -> String {
        let encodedPath = filePath.split(separator: "/", omittingEmptySubsequences: false)
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        guard let signURL = URL(string: "\(projectURL)/storage/v1/object/sign/\(storageBucket)/\(encodedPath)") else {
            throw MoghimiCloudSyncError.invalidResponse
        }
        let body = try JSONSerialization.data(withJSONObject: ["expiresIn": 600])
        let responseData = try await request(url: signURL, method: "POST", body: body, includeApiKey: true)
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let signedPath = json["signedURL"] as? String, !signedPath.isEmpty else {
            throw MoghimiCloudSyncError.invalidResponse
        }

        let finalURL: URL?
        if let absolute = URL(string: signedPath), absolute.scheme != nil {
            finalURL = absolute
        } else {
            let relative = signedPath.hasPrefix("/") ? String(signedPath.dropFirst()) : signedPath
            let normalized = relative.hasPrefix("storage/v1/") ? relative : "storage/v1/\(relative)"
            finalURL = URL(string: "\(projectURL)/\(normalized)")
        }
        guard let url = finalURL else { throw MoghimiCloudSyncError.invalidResponse }
        let fileData = try await request(url: url, method: "GET", body: nil, includeApiKey: false)
        guard let text = String(data: fileData, encoding: .utf8) else {
            throw MoghimiCloudSyncError.invalidResponse
        }
        return text
    }

    private static func request(url: URL, method: String, body: Data?, includeApiKey: Bool) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 12
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("MoghimiV2Ray-iOS/1.0.0", forHTTPHeaderField: "User-Agent")
        if includeApiKey {
            // The Supabase publishable key is sent only in the apikey header, not as a user JWT.
            request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MoghimiCloudSyncError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            // Do not return response bodies, signed URLs, or profile text in error messages.
            throw MoghimiCloudSyncError.requestFailed(http.statusCode)
        }
        return data
    }
}
