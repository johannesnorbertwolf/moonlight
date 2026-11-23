// Supabase over plain HTTPS: anonymous sign-in, then the functions from supabase/migrations
// (join_group, group_data, set_reaction, update_goal). Same calls as web/remote.js.

import Foundation

struct RemoteError: LocalizedError {
    let status: Int
    let body: String
    var errorDescription: String? { "HTTP \(status): \(body)" }
}

actor Remote {
    static let shared = Remote()

    private struct Session: Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
    }

    private var session: Session? = {
        guard let d = UserDefaults.standard.data(forKey: "moonlight.session") else { return nil }
        return try? JSONDecoder().decode(Session.self, from: d)
    }()

    private func store(_ s: Session?) {
        session = s
        UserDefaults.standard.set(s.flatMap { try? JSONEncoder().encode($0) }, forKey: "moonlight.session")
    }

    // MARK: auth

    private func authRequest(_ path: String, body: [String: Any]) async throws -> Session {
        var c = URLComponents(url: Config.supabaseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if path == "auth/v1/token" { c.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")] }
        var req = URLRequest(url: c.url!)
        req.httpMethod = "POST"
        req.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status),
              let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = j["access_token"] as? String,
              let refresh = j["refresh_token"] as? String else {
            throw RemoteError(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
        let expiresIn = (j["expires_in"] as? Double) ?? 3600
        return Session(accessToken: access, refreshToken: refresh, expiresAt: Date().addingTimeInterval(expiresIn - 60))
    }

    /// A valid access token: the stored one, a refreshed one, or a new anonymous user.
    private func token() async throws -> String {
        if let s = session, s.expiresAt > Date() { return s.accessToken }
        if let s = session {
            if let fresh = try? await authRequest("auth/v1/token", body: ["refresh_token": s.refreshToken]) {
                store(fresh)
                return fresh.accessToken
            }
        }
        let fresh = try await authRequest("auth/v1/signup", body: ["data": [String: Any]()]) // anonymous sign-in
        store(fresh)
        return fresh.accessToken
    }

    var hasSession: Bool { session != nil }

    func signOut() { store(nil) }

    // MARK: rpc

    private func rpc(_ name: String, _ params: [String: Any] = [:]) async throws -> Data {
        var req = URLRequest(url: Config.supabaseURL.appendingPathComponent("rest/v1/rpc/\(name)"))
        req.httpMethod = "POST"
        req.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: params)
        req.timeoutInterval = 20
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw RemoteError(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    /// While there is only one group, no code is needed (migration 0003).
    func join(name: String, goal: String, platform: String = "ios") async throws {
        _ = try await rpc("join_group", ["p_code": NSNull(), "p_name": name, "p_goal": goal, "p_platform": platform])
    }

    /// Raw group data, or nil if this phone hasn't joined (or its anonymous user is gone).
    func groupData() async throws -> GroupData? {
        guard session != nil else { return nil }
        let data = try await rpc("group_data")
        if data.isEmpty || String(data: data, encoding: .utf8) == "null" { return nil }
        return try JSONDecoder().decode(GroupData.self, from: data)
    }

    func setReaction(target: String, night: String, emoji: String?) async throws {
        _ = try await rpc("set_reaction", ["p_target": target, "p_night": night, "p_emoji": emoji ?? NSNull()])
    }

    func updateGoal(_ goal: String) async throws {
        _ = try await rpc("update_goal", ["p_goal": goal])
    }
}

// MARK: - group_data() payload

struct GroupData: Decodable {
    struct Group: Decodable {
        let name: String
        let challenge_start: String
        let challenge_nights: Int
    }
    struct Member: Decodable {
        let id: String
        let name: String
        let goal: String
        let platform: String
    }
    struct AndroidNight: Decodable {
        let participant: String
        let night: String
    }
    struct ScreenTimeNight: Decodable {
        let participant: String
        let night: String
        let minutes: Int
        let crossed_at: String?
    }
    struct Reaction: Decodable {
        let target: String
        let night: String
        let from: String
        let emoji: String
    }

    let me: String
    let group: Group
    let members: [Member]
    let events: [[String]]           // [participant, kind, occurred_at]
    let android_nights: [AndroidNight]
    let screen_time_nights: [ScreenTimeNight]?   // nil until migration 0004 has run
    let reactions: [Reaction]
}
