// App state: who I am, the loaded group, and the actions the screens trigger.

import SwiftUI
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published var onboarded = UserDefaults.standard.bool(forKey: "onboarded") || AppModel.isDemo

    #if DEBUG
    static let isDemo = GroupModel.demoRequested
    #else
    static let isDemo = false
    #endif
    @Published var name = UserDefaults.standard.string(forKey: "name") ?? ""
    @Published var goal = SharedStore.shared.goal
    @Published var group: GroupModel?
    @Published var loading = false
    @Published var loadError: String?
    @Published var toast: String?
    @Published var lang = L10n.lang

    private let remote = Remote.shared
    private let store = SharedStore.shared

    // MARK: onboarding

    func join(name: String, goal: String) async throws {
        try await remote.join(name: name, goal: goal)
        self.name = name
        self.goal = goal
        UserDefaults.standard.set(name, forKey: "name")
        store.participant = name
        store.goal = goal
    }

    func finishOnboarding() {
        onboarded = true
        UserDefaults.standard.set(true, forKey: "onboarded")
        scheduleMorningNotification()
        Task { await load() }
    }

    func setLang(_ l: Lang) {
        L10n.lang = l
        lang = l
        scheduleMorningNotification()
    }

    // MARK: loading

    func load() async {
        #if DEBUG
        if GroupModel.demoRequested {
            onboarded = true
            name = "Johannes"
            if group == nil { group = .demo() }
            return
        }
        #endif
        loading = true
        defer { loading = false }
        await Reporter.uploadPending()
        do {
            var data = try await remote.groupData()
            if data == nil, !name.isEmpty {
                // Joined before but the anonymous sign-in is gone: join again with the same name,
                // which takes over the same participant.
                try await remote.join(name: name, goal: goal)
                data = try await remote.groupData()
            }
            if let data {
                group = GroupModel.from(data)
                loadError = nil
            } else {
                loadError = t("error.load")
            }
        } catch {
            print("load failed", error)
            if group == nil { loadError = t("error.load") }
        }
    }

    // MARK: actions

    func react(to member: Member, night: String, emoji: String) async {
        guard let g = group else { return }
        let mine = g.reactions(for: member, night: night).mine
        let next: String? = mine == emoji ? nil : emoji
        // Show it right away, then save.
        group?.reactions.removeAll { $0.target == member.id && $0.night == night && $0.from == g.meId }
        if let next { group?.reactions.append(Reaction(target: member.id, night: night, from: g.meId, emoji: next)) }
        if !g.live { return }
        do {
            try await remote.setReaction(target: member.id, night: night, emoji: next)
        } catch {
            toast = t("react.failed")
            await load()
        }
    }

    func updateGoal(_ new: String) async -> Bool {
        do {
            try await remote.updateGoal(new)
        } catch {
            toast = t("onb.err.network")
            return false
        }
        goal = new
        store.goal = new
        ScreenTime.shared.startMonitoring()
        toast = t("settings.saved")
        await load()
        return true
    }

    func reset() {
        Task { await remote.signOut() }
        for k in ["onboarded", "name"] { UserDefaults.standard.removeObject(forKey: k) }
        store.participant = nil
        onboarded = false
        name = ""
        group = nil
    }

    // MARK: notifications

    func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        scheduleMorningNotification()
    }

    /// A daily local reminder at 09:00. (A push when everyone has reported needs a server; later.)
    func scheduleMorningNotification() {
        let c = UNMutableNotificationContent()
        c.title = t("notify.title")
        c.body = t("notify.body")
        c.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 9, minute: 0), repeats: true)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["morning"])
        center.add(UNNotificationRequest(identifier: "morning", content: c, trigger: trigger))
    }
}
