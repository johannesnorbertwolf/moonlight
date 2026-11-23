// Screen Time setup in the app: permission, the choice of apps that count, and the nightly schedule
// that wakes the monitor extension.

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

extension DeviceActivityName {
    static let night = DeviceActivityName("night")
}

@MainActor
final class ScreenTime: ObservableObject {
    static let shared = ScreenTime()

    @Published var authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    @Published var selection: FamilyActivitySelection
    @Published var lastError: String?

    private let store = SharedStore.shared

    init() {
        if let d = SharedStore.shared.selectionData,
           let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: d) {
            selection = s
        } else {
            // includeEntireCategory: picking a category also covers apps installed later.
            selection = FamilyActivitySelection(includeEntireCategory: true)
        }
    }

    var hasSelection: Bool {
        !selection.categoryTokens.isEmpty || !selection.applicationTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            lastError = error.localizedDescription
        }
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func saveSelection(_ s: FamilyActivitySelection) {
        selection = s
        store.selectionData = try? JSONEncoder().encode(s)
        startMonitoring()
    }

    /// (Re)starts the nightly schedule: goal time → 07:00, every night, with an event per threshold.
    func startMonitoring() {
        guard authorized, hasSelection else { return }
        let g = NightWindow.parse(store.goal)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: g.hour, minute: g.minute),
            intervalEnd: DateComponents(hour: Config.windowEnd.hour, minute: Config.windowEnd.minute),
            repeats: true)
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for m in Config.thresholds {
            events[DeviceActivityEvent.Name("t\(m)")] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: m))
        }
        let center = DeviceActivityCenter()
        center.stopMonitoring([.night])
        do {
            try center.startMonitoring(.night, during: schedule, events: events)
            lastError = nil
            store.log("monitoring \(store.goal)–07:00")
        } catch {
            lastError = error.localizedDescription
            store.log("startMonitoring failed: \(error.localizedDescription)")
        }
    }

    var isMonitoring: Bool {
        DeviceActivityCenter().activities.contains(.night)
    }
}
