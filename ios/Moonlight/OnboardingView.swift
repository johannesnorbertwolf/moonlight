// Welcome → name and goal (joins the group) → Screen Time permission → what counts → notifications.

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch step {
                case 0: welcome
                case 1: profile
                case 2: permission
                case 3: apps
                default: notifications
                }
            }
            .padding(24)
        }
        .screen()
        .animation(.default, value: step)
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
        }
        .frame(maxWidth: .infinity)
    }

    private var profile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Moonlight").font(.largeTitle.bold())
            Text(t("onb.name")).font(.headline).padding(.top, 12)
            TextField("", text: $name)
                .textContentType(.givenName)
                .padding(12)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
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
            try await model.join(name: trimmed, goal: Fmt.time(goal))
            error = nil
            step = screenTime.authorized ? 3 : 2
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
                    if screenTime.authorized { step = 3 }
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
                Button(t("onb.continue")) { step = 4 }
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
