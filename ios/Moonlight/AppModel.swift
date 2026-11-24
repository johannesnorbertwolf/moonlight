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
    /// Code from an invite link that hasn't been acted on yet (onboarding or the switch-group alert).
    @Published var pendingCode: String?
    /// The code of the group I'm in, for rejoining silently when the sign-in is lost.
    private var groupCode = UserDefaults.standard.string(forKey: "groupCode")

    private let remote = Remote.shared
    private let store = SharedStore.shared

    // MARK: onboarding

    /// Joins the group with `code`. Throws RemoteError with `nameTaken` / `unknownCode`.
    func join(code: String, name: String, goal: String, takeover: Bool = false) async throws {
        let pid = try await remote.join(code: code, name: name, goal: goal, takeover: takeover)
        joined(participant: pid, code: Invite.normalize(code), name: name, goal: goal)
    }

    /// Starts a new group with me as owner.
    func createGroup(_ groupName: String, name: String, goal: String) async throws {
        let pid = try await remote.createGroup(groupName: groupName, name: name, goal: goal)
        joined(participant: pid, code: nil, name: name, goal: goal) // the code arrives with load()
    }

    private func joined(participant: String, code: String?, name: String, goal: String) {
        self.name = name
        self.goal = goal
        UserDefaults.standard.set(name, forKey: "name")
        setGroupCode(code)
        // The Screen Time extension reports under this id (migration 0005).
        if store.participant != participant {
            store.participant = participant
        }
        store.goal = goal
        group = nil
        pendingCode = nil
    }

    private func setGroupCode(_ code: String?) {
        groupCode = code
        UserDefaults.standard.set(code, forKey: "groupCode")
    }

    /// Offered when an invite link to another group is opened after onboarding.
    @Published var switchOffer: GroupInfo?

    /// An invite link (or QR code) opened the app.
    func openInvite(_ code: String) {
        if !onboarded { pendingCode = code; return }
        if code == groupCode { return }
        Task {
            if let info = try? await remote.groupInfo(code: code) { switchOffer = info } else { toast = t("join.notFound") }
        }
    }

    /// Leaves the group on an invite link to another group, keeping my name and goal.
    func switchGroup(to code: String) async {
        do {
            try await join(code: code, name: name, goal: goal)
            if ScreenTime.shared.authorized { ScreenTime.shared.startMonitoring() }
            await load()
        } catch let e as RemoteError where e.nameTaken {
            toast = t("join.nameTakenShort")
        } catch {
            toast = t("join.err")
        }
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
            if data == nil, !name.isEmpty, let code = groupCode, await remote.isNewUser {
                // Joined before but the anonymous sign-in is gone: join again with the same name,
                // which takes over the same participant.
                let pid = try await remote.join(code: code, name: name, goal: goal, takeover: true)
                store.participant = pid
                data = try await remote.groupData()
            }
            if let data {
                // Keep what's needed to report and rejoin (also moves older installs to ids).
                if let code = data.group.code, code != groupCode { setGroupCode(code) }
                if store.participant != data.me {
                    store.participant = data.me
                    await Reporter.uploadPending()
                }
                group = GroupModel.from(data)
                loadError = nil
            } else if await !remote.isNewUser || groupCode == nil {
                // Signed in but in no group (removed by the owner, or left): back to the start.
                reset(signOut: false)
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

    func removeMember(_ m: Member) async {
        do {
            try await remote.removeMember(m.id)
            await load()
        } catch {
            toast = t("onb.err.network")
        }
    }

    /// "Leave group and delete my data".
    func leaveGroup() async {
        do {
            try await remote.leaveGroup()
        } catch {
            toast = t("onb.err.network")
            return
        }
        reset()
    }

    func reset(signOut: Bool = true) {
        if signOut { Task { await remote.signOut() } }
        for k in ["onboarded", "name", "groupCode"] { UserDefaults.standard.removeObject(forKey: k) }
        groupCode = nil
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
