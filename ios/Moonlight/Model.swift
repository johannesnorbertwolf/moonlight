// Rules from CONCEPT.md §3 and the group as the screens see it. Port of web/data.js and
// web/estimate.js (keep them in sync).

import Foundation

enum Bucket: String, CaseIterable {
    case free, light, medium, heavy, very_heavy, missing, future

    static func from(minutes: Double) -> Bucket {
        switch minutes {
        case ..<2: .free
        case ..<5: .light
        case ..<15: .medium
        case ..<60: .heavy
        default: .very_heavy
        }
    }
}

struct Session { let offset: Double; let min: Double }   // minutes after the window start

struct Night {
    let date: String
    let bucket: Bucket
    let min: Double?             // estimated minutes (nil when missing)
    let atLeast: Bool            // Screen Time nights only know "at least N minutes"
    let sessions: [Session]
    let crossedAt: Date?
}

struct Member: Identifiable {
    let id: String
    let name: String
    let goal: String
    let platform: String
    let isMe: Bool
    var nights: [String: Night]
}

struct Reaction { let target: String; let night: String; let from: String; let emoji: String }

struct GroupModel {
    let live: Bool
    let name: String
    let start: Date
    let last: Date?              // most recent finished night, nil before the first one
    let nightsTotal: Int
    var members: [Member]
    var reactions: [Reaction]
    let meId: String

    var me: Member { members.first { $0.isMe }! }
}

let reactionEmoji = ["🌙", "👏", "🔥", "😴", "❤️", "🛌", "🦉", "🦥", "🥱"]

// MARK: - dates

enum Dates {
    static var cal: Calendar { .current }

    static func addDays(_ d: Date, _ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: d)! }

    static func parseISODay(_ s: String) -> Date {
        let p = s.split(separator: "-").compactMap { Int($0) }
        return cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))!
    }

    static func minutes(_ hhmm: String) -> Int { let g = NightWindow.parse(hhmm); return g.hour * 60 + g.minute }

    /// Date of the most recent completed night (dated by the evening it starts).
    static func lastNightDate(now: Date = Date()) -> Date {
        let c = cal.dateComponents([.hour, .minute], from: now)
        let afterEnd = c.hour! * 60 + c.minute! >= Config.windowEnd.hour * 60 + Config.windowEnd.minute
        return addDays(cal.startOfDay(for: now), afterEnd ? -1 : -2)
    }

    static func inNightWindow(goal: String, now: Date = Date()) -> Bool {
        let c = cal.dateComponents([.hour, .minute], from: now)
        let m = c.hour! * 60 + c.minute!
        let s = minutes(goal), e = Config.windowEnd.hour * 60 + Config.windowEnd.minute
        return s > e ? (m >= s || m < e) : (m >= s && m < e)
    }

    static func minutesUntilWindow(goal: String, now: Date = Date()) -> Int {
        if inNightWindow(goal: goal, now: now) { return 0 }
        let c = cal.dateComponents([.hour, .minute], from: now)
        var d = minutes(goal) - (c.hour! * 60 + c.minute!)
        if d < 0 { d += 24 * 60 }
        return d
    }

    static func windowLength(goal: String) -> Int {
        var d = Config.windowEnd.hour * 60 + Config.windowEnd.minute - minutes(goal)
        if d <= 0 { d += 24 * 60 }
        return d
    }

    static func clock(goal: String, offset: Double) -> String {
        let m = (minutes(goal) + Int(offset.rounded())) % (24 * 60)
        return String(format: "%02d:%02d", m / 60, m % 60)
    }
}

// MARK: - estimate (iPhone Shortcuts and Android events)

enum Estimate {
    static let cap: TimeInterval = 10 * 60
    static let orphan: TimeInterval = 60
    static let margin: TimeInterval = 2 * 60

    struct Event { let kind: String; let at: Date }

    static func useIntervals(_ events: [Event]) -> [(Date, Date)] {
        var out: [(Date, Date)] = []
        var depth = 0
        var since: Date?
        var prev: Date?
        func stop(_ t: Date) {
            if let s = since, t > s { out.append((s, t)) }
            since = nil
        }
        for e in events {
            if depth > 0, since != nil, let p = prev, e.at.timeIntervalSince(p) > cap {
                stop(p.addingTimeInterval(cap))
                depth = 0
            }
            if e.kind == "open" {
                if depth == 0 { since = e.at }
                depth += 1
            } else if e.kind == "close" {
                if depth == 0 { out.append((e.at.addingTimeInterval(-orphan), e.at)) }
                else {
                    depth -= 1
                    if depth == 0 { stop(e.at) }
                }
            }
            prev = e.at
        }
        if depth > 0, since != nil, let p = prev { stop(p.addingTimeInterval(cap)) }
        return out
    }

    static func summarize(_ intervals: [(Date, Date)], date: Date, goal: String) -> Night {
        let (ws, we) = NightWindow.window(for: date, goal: goal)
        var total: TimeInterval = 0
        var crossed: Date?
        var sessions: [Session] = []
        for (a, b) in intervals.sorted(by: { $0.0 < $1.0 }) {
            let a2 = max(a, ws), b2 = min(b, we)
            guard b2 > a2 else { continue }
            let len = b2.timeIntervalSince(a2)
            if crossed == nil, total + len >= margin { crossed = a2.addingTimeInterval(margin - total) }
            total += len
            sessions.append(Session(offset: a2.timeIntervalSince(ws) / 60, min: (len / 6).rounded() / 10))
        }
        let min = (total / 6).rounded() / 10
        return Night(date: NightWindow.isoDate(date), bucket: .from(minutes: min), min: min,
                     atLeast: false, sessions: sessions, crossedAt: crossed)
    }
}

// MARK: - building the group

extension GroupModel {
    static func from(_ d: GroupData, now: Date = Date()) -> GroupModel {
        let start = Dates.parseISODay(d.group.challenge_start)
        let end = Dates.addDays(start, d.group.challenge_nights - 1)
        var last: Date? = min(Dates.lastNightDate(now: now), end)
        if let l = last, l < start { last = nil }

        let iso = ISO8601DateFormatter()
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        func parse(_ s: String) -> Date? { isoFrac.date(from: s) ?? iso.date(from: s) ?? postgres(s) }

        var eventsBy: [String: [Estimate.Event]] = [:]
        for e in d.events where e.count >= 3 {
            if let at = parse(e[2]) { eventsBy[e[0], default: []].append(.init(kind: e[1], at: at)) }
        }
        let android = Set(d.android_nights.map { "\($0.participant)|\($0.night)" })
        var screenTime: [String: GroupData.ScreenTimeNight] = [:]
        for s in d.screen_time_nights ?? [] { screenTime["\(s.participant)|\(s.night)"] = s }
        let usesApp = Set((d.screen_time_nights ?? []).map(\.participant))

        let members = d.members.map { p -> Member in
            let intervals = Estimate.useIntervals(eventsBy[p.name] ?? [])
            var nights: [String: Night] = [:]
            if let last {
                var day = start
                while day <= last {
                    let key = NightWindow.isoDate(day)
                    if usesApp.contains(p.name) {
                        // The Moonlight iPhone app reports every night; no report means "missing".
                        if let s = screenTime["\(p.name)|\(key)"] {
                            nights[key] = Night(date: key, bucket: .from(minutes: Double(s.minutes)), min: Double(s.minutes),
                                                atLeast: true, sessions: [], crossedAt: s.crossed_at.flatMap(parse))
                        } else {
                            nights[key] = Night(date: key, bucket: .missing, min: nil, atLeast: false, sessions: [], crossedAt: nil)
                        }
                    } else if p.platform == "android" && !android.contains("\(p.name)|\(key)") {
                        nights[key] = Night(date: key, bucket: .missing, min: nil, atLeast: false, sessions: [], crossedAt: nil)
                    } else {
                        nights[key] = Estimate.summarize(intervals, date: day, goal: p.goal)
                    }
                    day = Dates.addDays(day, 1)
                }
            }
            return Member(id: p.id, name: p.name, goal: p.goal, platform: p.platform, isMe: p.id == d.me, nights: nights)
        }
        return GroupModel(live: true, name: d.group.name, start: start, last: last, nightsTotal: d.group.challenge_nights,
                          members: members, reactions: d.reactions.map { .init(target: $0.target, night: $0.night, from: $0.from, emoji: $0.emoji) },
                          meId: d.me)
    }

    /// Postgres jsonb timestamps look like "2026-11-23T21:04:00.123456+00:00".
    private static func postgres(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX", "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"] {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    // MARK: streaks

    func personalStreak(_ m: Member) -> Int {
        guard let last else { return 0 }
        var n = 0
        var d = last
        while let night = m.nights[NightWindow.isoDate(d)] {
            if night.bucket != .missing {
                if night.bucket != .free { break }
                n += 1
            }
            d = Dates.addDays(d, -1)
        }
        return n
    }

    func groupStreak() -> Int {
        guard let last else { return 0 }
        var n = 0
        var d = last
        while d >= start {
            let reported = members.compactMap { $0.nights[NightWindow.isoDate(d)] }.filter { $0.bucket != .missing }
            if !reported.isEmpty {
                if !reported.allSatisfy({ $0.bucket == .free }) { break }
                n += 1
            }
            d = Dates.addDays(d, -1)
        }
        return n
    }

    func bestStreak(_ m: Member) -> Int {
        var best = 0, run = 0
        for key in m.nights.keys.sorted() {
            let b = m.nights[key]!.bucket
            if b == .missing { continue }
            run = b == .free ? run + 1 : 0
            best = max(best, run)
        }
        return best
    }

    func reactions(for member: Member, night: String) -> (counts: [(String, Int)], mine: String?) {
        var counts: [String: Int] = [:]
        var mine: String?
        for r in reactions where r.target == member.id && r.night == night {
            counts[r.emoji, default: 0] += 1
            if r.from == meId { mine = r.emoji }
        }
        let ordered = reactionEmoji.compactMap { e in counts[e].map { (e, $0) } }
        return (ordered, mine)
    }
}
