import SwiftUI

@main
struct MoonlightApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var screenTime = ScreenTime.shared
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(screenTime)
                .preferredColorScheme(.dark)
                .tint(Color.moon)
                .onChange(of: phase) { _, p in
                    if p == .active, model.onboarded {
                        Task { await model.load() }
                        screenTime.authorized = screenTime.authorized // refresh published value
                    }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @State private var tab = 0

    var body: some View {
        Group {
            if !model.onboarded {
                OnboardingView()
            } else {
                TabView(selection: $tab) {
                    NavigationStack { TodayView(tab: $tab) }
                        .tabItem { Label(t("tab.today"), systemImage: "moon.stars") }.tag(0)
                    NavigationStack { GroupScreen() }
                        .tabItem { Label(t("tab.group"), systemImage: "person.3") }.tag(1)
                    NavigationStack { HistoryView() }
                        .tabItem { Label(t("tab.history"), systemImage: "calendar") }.tag(2)
                    NavigationStack { SettingsView() }
                        .tabItem { Label(t("tab.settings"), systemImage: "gearshape") }.tag(3)
                }
                .task { await model.load() }
            }
        }
        .id(model.lang) // redraw everything when the language changes
        .overlay(alignment: .bottom) {
            if let msg = model.toast {
                Text(msg)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.surface2, in: Capsule())
                    .padding(.bottom, 90)
                    .task {
                        try? await Task.sleep(for: .seconds(2.2))
                        model.toast = nil
                    }
            }
        }
    }
}

/// Wraps a screen that needs the group: loading, error, or the content.
struct GroupGate<Content: View>: View {
    @EnvironmentObject var model: AppModel
    @ViewBuilder var content: (GroupModel) -> Content

    var body: some View {
        if let g = model.group {
            content(g)
        } else if let err = model.loadError {
            VStack(spacing: 16) {
                Text(err).multilineTextAlignment(.center)
                Button(t("retry")) { Task { await model.load() } }.buttonStyle(PrimaryButton())
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .screen()
        } else {
            ProgressView(t("loading"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .screen()
        }
    }
}

struct EmptyNightsCard: View {
    var body: some View {
        Card {
            VStack(spacing: 12) {
                MoonView(bucket: .future, size: 64)
                Text(t("empty.title")).font(.title3.weight(.semibold))
                Text(t("empty.body")).foregroundStyle(Color.text2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
}
