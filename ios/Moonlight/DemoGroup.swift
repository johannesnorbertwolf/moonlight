// Made-up group for checking the screens in the simulator without touching the real group.
// Debug builds only: launch with the argument -demo.

#if DEBUG
import Foundation

extension GroupModel {
    static var demoRequested: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    static func demo(now: Date = Date()) -> GroupModel {
        let last = Dates.lastNightDate(now: now)
        let start = Dates.addDays(last, -8)
        let plan: [(String, String, String, [Double?])] = [
            ("me", "Johannes", "21:00", [0, 0, 3, 0, 0, 12, 0, 0, 0]),
            ("sam", "Sam", "22:00", [0, 1, 0, 0, 40, 0, 0, 0, 0]),
            ("jo", "Jo", "21:30", [0, 0, 0, nil, 0, 0, 7, 0, 75]),
            ("alex", "Alex", "21:00", [5, 0, 0, 0, 0, 0, 20, 0, 0]),
        ]
        let members = plan.map { id, name, goal, mins -> Member in
            var nights: [String: Night] = [:]
            for (i, m) in mins.enumerated() {
                let key = NightWindow.isoDate(Dates.addDays(start, i))
                if let m {
                    let w = NightWindow.window(for: Dates.addDays(start, i), goal: goal)
                    nights[key] = Night(date: key, bucket: .from(minutes: m), min: m, atLeast: id == "me",
                                        sessions: [], crossedAt: m >= 2 ? w.start.addingTimeInterval(95 * 60) : nil)
                } else {
                    nights[key] = Night(date: key, bucket: .missing, min: nil, atLeast: false, sessions: [], crossedAt: nil)
                }
            }
            return Member(id: id, name: name, goal: goal, platform: "ios", isMe: id == "me", nights: nights)
        }
        let lastKey = NightWindow.isoDate(last)
        return GroupModel(live: false, name: "Moonlight demo", start: start, last: last, nightsTotal: 14, members: members,
                          reactions: [Reaction(target: "me", night: lastKey, from: "sam", emoji: "🔥"),
                                      Reaction(target: "me", night: lastKey, from: "jo", emoji: "🔥"),
                                      Reaction(target: "jo", night: lastKey, from: "alex", emoji: "🦉")],
                          meId: "me")
    }
}
#endif
