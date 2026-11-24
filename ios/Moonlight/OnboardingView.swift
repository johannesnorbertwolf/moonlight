// Welcome → group (join with a code, or start one) → name and goal (joins/creates) → Screen Time
// permission → what counts → notifications.

import FamilyControls
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var screenTime: ScreenTime
    @State private var step = 0
    @State private var name = ""
    @State private var goal = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date())!
    @State private var busy = false
    @State private var error: String?
    @State private var showPicker = false
    // group step
    @State private var code = ""
    @State private var found: GroupInfo?
    @State private var lookingUp = false
    @State private var notFound = false
    @State private var creating = false
    @State private var newGroupName = ""
    @State private var takeover = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch step {
                case 0: welcome
                case 1: groupStep
                case 2: profile
                case 3: permission
                case 4: apps
                default: notifications
                }
            }
            .padding(24)
        }
        .screen()
        .animation(.default, value: step)
        .onAppear(perform: takePendingCode)
        .onChange(of: model.pendingCode) { _, _ in takePendingCode() }
    }

    /// An invite link opened the app: fill in its code and go to the group step.
    private func takePendingCode() {
        guard let c = model.pendingCode, step <= 2 else { return }
        code = c
        creating = false
        if step == 2 { step = 1 }
        Task { await lookUp() }
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            MoonView(bucket: .free, size: 96).padding(.top, 60)
            Text(t("onb.welcome.title")).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text(t("onb.welcome.body")).foregroundStyle(Color.text2).multilineTextAlignment(.center)
            Picker(t("settings.language"), selection: Binding(get: { model.lang }, set: { model.setLang($0) })) {
                ForEach(Lang.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            Button(t("onb.start")) { step = 1 }.buttonStyle(PrimaryButton())
            if model.pendingCode != nil {
                Text(t("join.linkReady")).font(.footnote).foregroundStyle(Color.text2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private let field = RoundedRectangle(cornerRadius: 12)

    private var groupStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("join.title")).font(.largeTitle.bold())
            Text(t("join.body")).foregroundStyle(Color.text2)

            Text(t("join.code")).font(.headline).padding(.top, 12)
            TextField("K7QM4P", text: $code)
                .font(.system(.title2, design: .monospaced))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.surface, in: field)
                .onChange(of: code) { _, v in
                    found = nil
                    notFound = false
                    if Invite.normalize(v).count == 6 { Task { await lookUp() } }
                }
            if lookingUp {
                ProgressView()
            } else if let found {
                Label(t(found.members == 1 ? "join.found1" : "join.found", ["group": found.name, "n": found.members]), systemImage: "checkmark.circle")
                    .foregroundStyle(Color.accent).font(.footnote)
            } else if notFound {
                Text(t("join.notFound")).foregroundStyle(Color(hex: 0xef9f27)).font(.footnote)
            }
            Button(t("join.join")) { creating = false; takeover = false; error = nil; step = 2 }
                .buttonStyle(PrimaryButton())
                .disabled(found == nil)
                .opacity(found == nil ? 0.5 : 1)
                .padding(.top, 8)

            Text(t("join.or")).foregroundStyle(Color.text2).frame(maxWidth: .infinity).padding(.vertical, 16)

            Text(t("create.name")).font(.headline)
            TextField(t("create.placeholder"), text: $newGroupName)
                .padding(12)
                .background(Color.surface, in: field)
            Text(t("create.hint")).font(.footnote).foregroundStyle(Color.text2)
            Button(t("create.button")) { creating = true; error = nil; step = 2 }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func lookUp() async {
        let c = Invite.normalize(code)
        guard c.count == 6 else { return }
        lookingUp = true
        defer { lookingUp = false }
        let info = try? await Remote.shared.groupInfo(code: c)
        guard Invite.normalize(code) == c else { return } // typed on meanwhile
        found = info
        notFound = info == nil
    }

    private var profile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { step = 1 } label: { Label(t("back"), systemImage: "chevron.left") }
            Text(creating ? newGroupName.trimmingCharacters(in: .whitespaces) : (found?.name ?? "Moonlight"))
                .font(.largeTitle.bold())
            Text(creating ? t("create.you") : t("join.you")).foregroundStyle(Color.text2)
            Text(t("onb.name")).font(.headline).padding(.top, 12)
            TextField("", text: $name)
                .textContentType(.givenName)
                .onChange(of: name) { _, _ in takeover = false }
                .padding(12)
                .background(Color.surface, in: field)
            Text(t("onb.name.hint")).font(.footnote).foregroundStyle(Color.text2)

            Text(t("onb.goal")).font(.headline).padding(.top, 12)
            DatePicker("", selection: $goal, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "en_GB")) // 24-hour clock
            Text(t("onb.goal.hint")).font(.footnote).foregroundStyle(Color.text2)

            if let error { Text(error).foregroundStyle(Color(hex: 0xef9f27)).font(.footnote) }

            Button {
                Task { await submitProfile() }
            } label: {
                if busy { ProgressView().tint(Color.bg) } else { Text(t("onb.continue")) }
            }
            .buttonStyle(PrimaryButton())
            .disabled(busy)
            .padding(.top, 16)
        }
    }

    private func submitProfile() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { error = t("onb.err.name"); return }
        busy = true
        defer { busy = false }
        do {
            if creating {
                try await model.createGroup(newGroupName.trimmingCharacters(in: .whitespaces), name: trimmed, goal: Fmt.time(goal))
            } else {
                try await model.join(code: code, name: trimmed, goal: Fmt.time(goal), takeover: takeover)
            }
            error = nil
            step = screenTime.authorized ? 4 : 3
        } catch let e as RemoteError where e.nameTaken {
            // Second tap on Continue means "that's me": take over the existing participant.
            takeover = true
            self.error = t("join.nameTaken", ["group": found?.name ?? ""])
        } catch {
            self.error = t("join.err")
        }
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "hourglass").font(.system(size: 44)).foregroundStyle(Color.moon).padding(.top, 40)
            Text(t("onb.st.title")).font(.largeTitle.bold())
            Text(t("onb.st.body")).foregroundStyle(Color.text2)
            if let e = screenTime.lastError, !screenTime.authorized {
                Text(t("onb.st.denied")).font(.footnote).foregroundStyle(Color(hex: 0xef9f27))
                Text(e).font(.caption2).foregroundStyle(Color.text2)
            }
            Button(t("onb.st.allow")) {
                Task {
                    await screenTime.requestAuthorization()
                    if screenTime.authorized { step = 4 }
                }
            }
            .buttonStyle(PrimaryButton())
            .padding(.top, 8)
        }
    }

    private var apps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "square.grid.2x2").font(.system(size: 44)).foregroundStyle(Color.moon).padding(.top, 40)
            Text(t("onb.apps.title")).font(.largeTitle.bold())
            Text(t("onb.apps.body")).foregroundStyle(Color.text2)
            if screenTime.hasSelection {
                Text(t("onb.apps.chosen", ["n": screenTime.selection.categoryTokens.count,
                                           "a": screenTime.selection.applicationTokens.count]))
                    .font(.footnote).foregroundStyle(Color.accent)
            }
            Button(t("onb.apps.choose")) { showPicker = true }
                .buttonStyle(PrimaryButton())
                .padding(.top, 8)
            if screenTime.hasSelection {
                Button(t("onb.continue")) { step = 5 }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: Binding(
            get: { screenTime.selection },
            set: { screenTime.saveSelection($0) }))
    }

    private var notifications: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "bell.badge").font(.system(size: 44)).foregroundStyle(Color.moon).padding(.top, 40)
            Text(t("onb.notify.title")).font(.largeTitle.bold())
            Text(t("onb.notify.body")).foregroundStyle(Color.text2)
            Button(t("onb.notify.allow")) {
                Task {
                    await model.requestNotifications()
                    model.finishOnboarding()
                }
            }
            .buttonStyle(PrimaryButton())
            .padding(.top, 8)
            Button(t("onb.skip")) { model.finishOnboarding() }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }
}
