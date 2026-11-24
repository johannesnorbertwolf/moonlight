import FamilyControls
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var screenTime: ScreenTime
    @State private var goal = Date()
    @State private var showPicker = false
    @State private var confirmLeave = false
    @State private var showInvite = false

    var body: some View {
        Form {
            Section(t("settings.name")) {
                Text(model.name)
                Text(t("settings.name.locked")).font(.footnote).foregroundStyle(Color.text2)
            }
            .listRowBackground(Color.surface)

            if let g = model.group, g.live {
                Section(t("settings.group")) {
                    LabeledContent(g.name, value: g.code.map(Invite.spaced) ?? "")
                        .font(.body.monospaced())
                    if g.code != nil { Button(t("invite.title")) { showInvite = true } }
                    if g.iAmOwner { NavigationLink(t("members.title")) { MembersView() } }
                    Button(t("leave.button"), role: .destructive) { confirmLeave = true }
                }
                .listRowBackground(Color.surface)
            }

            Section {
                DatePicker(t("settings.goal"), selection: $goal, displayedComponents: .hourAndMinute)
                    .environment(\.locale, Locale(identifier: "en_GB"))
                if Fmt.time(goal) != model.goal {
                    Button(t("settings.save")) { Task { _ = await model.updateGoal(Fmt.time(goal)) } }
                }
            } footer: {
                Text(t("settings.goal.note"))
            }
            .listRowBackground(Color.surface)

            Section(t("settings.screenTime")) {
                if screenTime.authorized && screenTime.hasSelection {
                    Label(t("settings.st.ok", ["start": model.goal]), systemImage: "checkmark.circle")
                        .foregroundStyle(Color.accent)
                } else {
                    Label(t("settings.st.off"), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Color(hex: 0xef9f27))
                    if !screenTime.authorized {
                        Button(t("onb.st.allow")) { Task { await screenTime.requestAuthorization(); screenTime.startMonitoring() } }
                    }
                }
                Button(t("settings.st.apps")) { showPicker = true }
                if let e = screenTime.lastError { Text(e).font(.caption).foregroundStyle(Color.text2) }
            }
            .listRowBackground(Color.surface)

            Section(t("settings.language")) {
                Picker(t("settings.language"), selection: Binding(get: { model.lang }, set: { model.setLang($0) })) {
                    ForEach(Lang.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.surface)

            Section(t("settings.diag")) {
                NavigationLink(t("settings.diag")) { DiagnosticsView() }
                if let g = model.group { Text(t("settings.live", ["group": g.name])).font(.footnote).foregroundStyle(Color.text2) }
            }
            .listRowBackground(Color.surface)

        }
        .navigationTitle(t("settings.title"))
        .screen()
        .onAppear {
            let g = NightWindow.parse(model.goal)
            goal = Calendar.current.date(bySettingHour: g.hour, minute: g.minute, second: 0, of: Date())!
        }
        .familyActivityPicker(isPresented: $showPicker, selection: Binding(
            get: { screenTime.selection },
            set: { screenTime.saveSelection($0) }))
        .confirmationDialog(t("leave.button"), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(t("leave.confirm"), role: .destructive) { Task { await model.leaveGroup() } }
        } message: {
            Text(t("leave.body", ["group": model.group?.name ?? ""]))
        }
        .sheet(isPresented: $showInvite) {
            if let g = model.group { InviteSheet(group: g) }
        }
    }
}

/// For the group's owner: remove members (swipe left).
struct MembersView: View {
    @EnvironmentObject var model: AppModel
    @State private var removing: Member?

    var body: some View {
        List {
            if let g = model.group {
                Section {
                    ForEach(g.members) { m in
                        HStack {
                            Text(m.name)
                            if m.isMe { Text("(\(t("group.you")))").foregroundStyle(Color.text2) }
                            Spacer()
                            Text(t("group.goal", ["time": m.goal])).font(.footnote).foregroundStyle(Color.text2)
                        }
                        .swipeActions {
                            if !m.isMe {
                                Button(t("remove.confirm"), role: .destructive) { removing = m }
                            }
                        }
                    }
                } footer: {
                    Text(t("members.hint"))
                }
                .listRowBackground(Color.surface)
            }
        }
        .navigationTitle(t("members.title"))
        .screen()
        .confirmationDialog(t("remove.title", ["name": removing?.name ?? ""]),
                            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible, presenting: removing) { m in
            Button(t("remove.confirm"), role: .destructive) { Task { await model.removeMember(m) } }
        } message: { _ in
            Text(t("remove.body"))
        }
    }
}

/// What the Screen Time extension recorded and logged, for checking the measurement.
struct DiagnosticsView: View {
    @State private var nights: [MeasuredNight] = []
    @State private var log: [String] = []

    var body: some View {
        List {
            Section("Nights") {
                ForEach(nights.reversed(), id: \.night) { n in
                    VStack(alignment: .leading) {
                        Text("\(n.night): ≥\(n.minutesAtLeast) min").font(.headline)
                        Text("\(Fmt.time(n.windowStart))–\(Fmt.time(n.windowEnd))"
                             + (n.crossedAt.map { " · 2 min at \(Fmt.time($0))" } ?? "")
                             + (n.ended ? " · ended" : "") + (n.uploaded ? " · uploaded" : " · not uploaded"))
                            .font(.caption).foregroundStyle(Color.text2)
                    }
                }
            }
            .listRowBackground(Color.surface)
            Section("Log") {
                ForEach(Array(log.reversed().enumerated()), id: \.offset) { _, l in
                    Text(l).font(.caption.monospaced())
                }
            }
            .listRowBackground(Color.surface)
        }
        .toolbar {
            Button(t("settings.upload")) {
                Task { await Reporter.uploadPending(); refresh() }
            }
        }
        .screen()
        .onAppear(perform: refresh)
    }

    private func refresh() {
        nights = SharedStore.shared.nights
        log = SharedStore.shared.logLines
    }
}
