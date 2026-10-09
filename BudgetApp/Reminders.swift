import UserNotifications

/// Shows reminders as banners even while the app is open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

enum Reminders {
    static let delegate = NotificationDelegate()
    /// iOS keeps at most 64 pending local notifications, so schedule a rolling window of the soonest ones.
    private static let maxPending = 60
    private static let windowDays = 120

    /// Rebuilds all pending reminders from the current events. Cheap enough to run on every change.
    static func reschedule(_ store: BudgetStore) async {
        let wanted = requests(for: store)
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard !wanted.isEmpty else { return }
        // The system only shows the permission prompt once; later calls just return the stored answer.
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        for request in wanted { try? await center.add(request) }
    }

    static func requests(for store: BudgetStore, now: Date = .now) -> [UNNotificationRequest] {
        let cal = Calendar.current
        let minutes = store.settings.reminderMinutes
        let today = cal.startOfDay(for: now)
        var found: [(fire: Date, request: UNNotificationRequest)] = []

        for offset in 0..<windowDays {
            let due = cal.date(byAdding: .day, value: offset, to: today)!
            for event in store.events(on: due) {
                guard let before = event.remindDaysBefore,
                      let fireDay = cal.date(byAdding: .day, value: -before, to: due),
                      let fire = cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: fireDay),
                      fire > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = event.title
                content.body = body(for: event, due: due, daysBefore: before)
                content.sound = .default
                let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                let id = "\(event.id.uuidString)-\(Int(due.timeIntervalSince1970))"
                found.append((fire, UNNotificationRequest(identifier: id, content: content, trigger: trigger)))
            }
        }
        return found.sorted { $0.fire < $1.fire }.prefix(maxPending).map(\.request)
    }

    private static func body(for event: BudgetEvent, due: Date, daysBefore: Int) -> String {
        let amount = event.amountCents > 0 ? " · \(money(event.amountCents))" : ""
        let what = event.kind == .payday ? "Payday" : event.kind.label
        let verb = event.kind == .payday ? "" : " due"
        switch daysBefore {
        case 0: return "\(what)\(verb) today\(amount)"
        case 1: return "\(what)\(verb) tomorrow\(amount)"
        default:
            let day = due.formatted(.dateTime.weekday(.wide).month().day())
            return "\(what)\(verb) in \(daysBefore) days (\(day))\(amount)"
        }
    }
}
