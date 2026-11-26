// Code shared by the app and the Screen Time monitor extension: the night window, the store in the
// App Group (the only place both can read and write), and the upload of a finished night.

import Foundation

enum Config {
    static let supabaseURL = URL(string: "https://pnuevrttqqqxxbgwnctd.supabase.co")!
    // Publishable key: meant to be public; on its own it can only call the Moonlight functions.
    static let supabaseKey = "sb_publishable_xjkz6vWPFo-Mv9RuYgPKrQ_mMo-lYhf"
    static let appGroup = "group.nl.moonlight.app"
    static let windowEnd = (hour: 7, minute: 0)
    /// Usage thresholds in minutes. They are the bucket edges from CONCEPT.md §3.
    static let thresholds = [2, 5, 15, 60]
}

// MARK: - Night window

enum NightWindow {
    /// "21:00" → (21, 0)
    static func parse(_ goal: String) -> (hour: Int, minute: Int) {
        let p = goal.split(separator: ":").compactMap { Int($0) }
        return (p.count > 0 ? p[0] : 21, p.count > 1 ? p[1] : 0)
    }

    /// A night is dated by the evening it starts. Goals before noon (e.g. 00:30) belong to the
    /// previous evening.
    static func nightDate(forWindowStart start: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: start)
        return calendar.component(.hour, from: start) < 12 ? calendar.date(byAdding: .day, value: -1, to: day)! : day
    }

    /// Start and end of the night dated `date` (local midnight of the evening) for `goal`.
    static func window(for date: Date, goal: String, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let g = parse(goal)
        let day = calendar.startOfDay(for: date)
        let startDay = g.hour < 12 ? calendar.date(byAdding: .day, value: 1, to: day)! : day
        let start = calendar.date(bySettingHour: g.hour, minute: g.minute, second: 0, of: startDay)!
        let next = calendar.date(byAdding: .day, value: 1, to: day)!
        let end = calendar.date(bySettingHour: Config.windowEnd.hour, minute: Config.windowEnd.minute, second: 0, of: next)!
        return (start, end)
    }

    static func isoDate(_ d: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}

// MARK: - Store in the App Group

/// One night as the monitor extension saw it.
struct MeasuredNight: Codable, Equatable {
    var night: String          // "2026-11-23"
    var windowStart: Date
    var windowEnd: Date
    var minutesAtLeast: Int    // 0, 2, 5, 15 or 60
    var crossedAt: Date?       // when 2 minutes were reached
    var ended = false          // the window is over
    var uploaded = false       // the server has this version
}

final class SharedStore {
    static let shared = SharedStore()
    let defaults = UserDefaults(suiteName: Config.appGroup) ?? .standard

    var participant: String? {
        get { defaults.string(forKey: "participant") }
        set { defaults.set(newValue, forKey: "participant") }
    }

    var goal: String {
        get { defaults.string(forKey: "goal") ?? "21:00" }
        set { defaults.set(newValue, forKey: "goal") }
    }

    /// The apps and categories that count, as chosen in the Screen Time picker (encoded
    /// FamilyActivitySelection; only the app and the extension can decode the tokens).
    var selectionData: Data? {
        get { defaults.data(forKey: "selection") }
        set { defaults.set(newValue, forKey: "selection") }
    }

    var nights: [MeasuredNight] {
        get {
            guard let d = defaults.data(forKey: "nights") else { return [] }
            return (try? JSONDecoder().decode([MeasuredNight].self, from: d)) ?? []
        }
        set {
            // Keep the last 30 nights.
            let kept = Array(newValue.sorted { $0.night < $1.night }.suffix(30))
            defaults.set(try? JSONEncoder().encode(kept), forKey: "nights")
        }
    }

    func update(night: String, _ change: (inout MeasuredNight) -> Void, orCreate make: () -> MeasuredNight) {
        var all = nights
        if let i = all.firstIndex(where: { $0.night == night }) {
            change(&all[i])
        } else {
            var n = make()
            change(&n)
            all.append(n)
        }
        nights = all
    }

    /// Short log of what the extension did, shown in Settings → Diagnostics.
    func log(_ line: String) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd-MM HH:mm:ss"
        var lines = defaults.stringArray(forKey: "log") ?? []
        lines.append("\(f.string(from: Date())) \(line)")
        defaults.set(Array(lines.suffix(60)), forKey: "log")
    }

    var logLines: [String] { defaults.stringArray(forKey: "log") ?? [] }
}

// MARK: - Upload

enum Reporter {
    /// Sends every night that changed since its last upload. Safe to call often: the server only
    /// ever raises the minutes of a night.
    static func uploadPending() async {
        let store = SharedStore.shared
        guard let participant = store.participant, !participant.isEmpty else { return }
        for n in store.nights where !n.uploaded {
            do {
                try await upload(n, participant: participant)
                store.update(night: n.night, { $0.uploaded = ($0 == n) || $0.uploaded }, orCreate: { n })
                store.log("uploaded \(n.night): ≥\(n.minutesAtLeast) min")
            } catch {
                store.log("upload \(n.night) failed: \(error.localizedDescription)")
            }
        }
    }

    static func upload(_ n: MeasuredNight, participant: String) async throws {
        let iso = ISO8601DateFormatter()
        var body: [String: Any] = [
            "p_participant": participant,
            "p_night": n.night,
            "p_window_start": iso.string(from: n.windowStart),
            "p_window_end": iso.string(from: n.windowEnd),
            "p_minutes": n.minutesAtLeast,
        ]
        body["p_crossed_at"] = n.crossedAt.map { iso.string(from: $0) } ?? NSNull()
        var req = URLRequest(url: Config.supabaseURL.appendingPathComponent("rest/v1/rpc/report_screen_time_night"))
        req.httpMethod = "POST"
        req.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 20
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw NSError(domain: "Moonlight", code: code,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(code) \(String(data: data, encoding: .utf8) ?? "")"])
        }
    }
}
