// The Screen Time monitor. iOS runs this extension when the night window starts and ends, and when
// phone use inside the window reaches 2, 5, 15 or 60 minutes. Apple never tells us more than that:
// no app names, no exact minutes. We store "at least N minutes" and upload it.

import DeviceActivity
import Foundation

final class NightMonitor: DeviceActivityMonitor {
    private let store = SharedStore.shared

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let (night, start, end) = currentWindow()
        store.update(night: night, { _ in }, orCreate: {
            MeasuredNight(night: night, windowStart: start, windowEnd: end, minutesAtLeast: 0)
        })
        store.log("window start \(night)")
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard let minutes = Int(event.rawValue.dropFirst()) else { return } // "t5" → 5
        let now = Date()
        let (night, start, end) = currentWindow()
        // iOS sometimes fires thresholds right after the window starts. N minutes of use can't
        // have happened less than N minutes in, so those are ignored.
        if now.timeIntervalSince(start) < Double(minutes * 60) - 5 {
            store.log("ignored early \(event.rawValue) for \(night)")
            return
        }
        store.update(night: night, { n in
            if minutes > n.minutesAtLeast {
                n.minutesAtLeast = minutes
                n.uploaded = false
            }
            if minutes == 2, n.crossedAt == nil { n.crossedAt = now }
        }, orCreate: {
            MeasuredNight(night: night, windowStart: start, windowEnd: end, minutesAtLeast: 0)
        })
        store.log("reached \(minutes) min in \(night)")
        upload()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // The window just ended, so it's the night that started last evening.
        let (night, start, end) = currentWindow(at: Date().addingTimeInterval(-60))
        store.update(night: night, { n in
            n.ended = true
            n.uploaded = false
        }, orCreate: {
            // Start was missed (the extension wasn't running yet): we only know the end.
            MeasuredNight(night: night, windowStart: start, windowEnd: end, minutesAtLeast: 0)
        })
        store.log("window end \(night)")
        upload()
    }

    /// The window that contains `date` (or the one about to end), from the saved goal time.
    private func currentWindow(at date: Date = Date()) -> (String, Date, Date) {
        let cal = Calendar.current
        let goal = store.goal
        // Before 07:00 we're in the night that started yesterday evening; after the goal time,
        // in tonight's; in between (shouldn't happen inside the window) use tonight's.
        let today = cal.startOfDay(for: date)
        var nightDay = today
        let endToday = cal.date(bySettingHour: Config.windowEnd.hour, minute: Config.windowEnd.minute, second: 0, of: today)!
        if date < endToday {
            nightDay = cal.date(byAdding: .day, value: -1, to: today)!
        }
        let w = NightWindow.window(for: nightDay, goal: goal)
        return (NightWindow.isoDate(nightDay), w.start, w.end)
    }

    /// Extensions get very little time; ask for a bit more for the network call.
    private func upload() {
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            await Reporter.uploadPending()
            done.signal()
        }
        _ = done.wait(timeout: .now() + 25)
    }
}
