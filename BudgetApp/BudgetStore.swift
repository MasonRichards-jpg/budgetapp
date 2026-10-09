import SwiftUI
import WidgetKit

@Observable
final class BudgetStore {
    var settings = BudgetSettings()
    var spends: [Spend] = []
    var events: [BudgetEvent] = []

    private let cal = Calendar.current
    private let fileURL: URL

    private struct Snapshot: Codable {
        var settings: BudgetSettings
        var spends: [Spend]
        var events: [BudgetEvent]
    }

    static let groupID = "group.com.masonrichards.budgetapp"

    /// Sideloading tools (AltStore/SideStore) rename the App Group per user and list the new names under
    /// `ALTAppGroups` in Info.plist, so prefer those and fall back to our own ID.
    private static var sharedContainer: URL? {
        let altGroups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? []
        for id in altGroups + [groupID] {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) { return url }
        }
        return nil
    }

    init() {
        // Shared App Group container so the widget sees the same data; falls back to Documents.
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("budget.json")
        let group = Self.sharedContainer?
            .appendingPathComponent("budget.json")
        fileURL = group ?? docs
        let source = FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : docs
        if let data = try? Data(contentsOf: source),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            settings = snap.settings
            spends = snap.spends
            events = snap.events
        }
    }

    private func save() {
        let snap = Snapshot(settings: settings, spends: spends, events: events)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: fileURL, options: .atomic)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Budget math

    /// Money available at the end of `day`: carry + accrued allowance − spending.
    /// Unspent allowance rolls over because the balance is computed cumulatively.
    func balanceCents(on day: Date = .now) -> Int {
        let d = cal.startOfDay(for: day)
        let start = settings.startDate
        guard d >= start else { return settings.carryCents }
        let allowance = settings.amountCents * payouts(through: d)
        let end = cal.date(byAdding: .day, value: 1, to: d)!
        let spent = spends.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.cents }
        return settings.carryCents + allowance - spent
    }

    /// Allowances received from `startDate` through `day`: one per day, or one at the start of each calendar week.
    private func payouts(through day: Date) -> Int {
        switch settings.period {
        case .daily:
            return (cal.dateComponents([.day], from: settings.startDate, to: day).day ?? 0) + 1
        case .weekly:
            let first = cal.dateInterval(of: .weekOfYear, for: settings.startDate)!.start
            let current = cal.dateInterval(of: .weekOfYear, for: day)!.start
            return (cal.dateComponents([.day], from: first, to: current).day ?? 0) / 7 + 1
        }
    }

    /// When the next allowance lands (tomorrow, or the start of next week).
    var nextPayout: Date {
        let today = cal.startOfDay(for: .now)
        switch settings.period {
        case .daily: return cal.date(byAdding: .day, value: 1, to: today)!
        case .weekly: return cal.dateInterval(of: .weekOfYear, for: today)!.end
        }
    }

    var todaysSpends: [Spend] {
        spends.filter { cal.isDateInToday($0.date) }.sorted { $0.date > $1.date }
    }

    var spentTodayCents: Int { todaysSpends.reduce(0) { $0 + $1.cents } }

    // MARK: Spending

    func addSpend(cents: Int, note: String = "") {
        guard cents > 0 else { return }
        spends.append(Spend(cents: cents, note: note.trimmingCharacters(in: .whitespacesAndNewlines)))
        save()
    }

    func setNote(_ note: String, for spend: Spend) {
        guard let i = spends.firstIndex(where: { $0.id == spend.id }) else { return }
        spends[i].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    func setReminderTime(_ minutes: Int) { settings.reminderMinutes = minutes; save() }
    func setTheme(_ theme: AppTheme) { settings.theme = theme; save() }
    func setAppearance(_ appearance: Appearance) { settings.appearance = appearance; save() }

    func deleteSpend(_ spend: Spend) {
        spends.removeAll { $0.id == spend.id }
        save()
    }

    /// Changes the budget from today on. The allowance already given for the current day/week is swapped
    /// for the new amount, so changing settings never pays out twice or loses rollover.
    func updateBudget(amountCents: Int, period: BudgetPeriod) {
        let before = balanceCents()
        let delta = amountCents - settings.amountCents
        settings.startDate = cal.startOfDay(for: .now)
        settings.amountCents = amountCents
        settings.period = period
        settings.carryCents = 0
        settings.carryCents = before + delta - balanceCents()
        save()
    }

    /// Sets today's balance directly without touching the budget; future allowances add on top of it.
    func setBalance(_ cents: Int) {
        settings.carryCents += cents - balanceCents()
        save()
    }

    /// Back to the original budget: clears rollover and all recorded spending (calendar included).
    func resetBudget() {
        settings.startDate = cal.startOfDay(for: .now)
        settings.carryCents = 0
        spends.removeAll()
        save()
    }

    func spends(on day: Date) -> [Spend] {
        spends.filter { cal.isDate($0.date, inSameDayAs: day) }.sorted { $0.date > $1.date }
    }

    func spentCents(on day: Date) -> Int { spends(on: day).reduce(0) { $0 + $1.cents } }

    func spentCents(inMonthOf day: Date) -> Int {
        spends.filter { cal.isDate($0.date, equalTo: day, toGranularity: .month) }.reduce(0) { $0 + $1.cents }
    }

    func setQuickStep(_ cents: Int) {
        settings.quickStepCents = max(1, cents)
        save()
    }

    // MARK: Events

    func upsert(_ event: BudgetEvent) {
        if let i = events.firstIndex(where: { $0.id == event.id }) {
            events[i] = event
        } else {
            events.append(event)
        }
        save()
    }

    func delete(_ event: BudgetEvent) {
        events.removeAll { $0.id == event.id }
        save()
    }

    func events(on day: Date) -> [BudgetEvent] {
        events.filter { $0.occurs(on: day) }.sorted { $0.title < $1.title }
    }

    func upcoming(days: Int = 30, limit: Int = 4) -> [(date: Date, event: BudgetEvent)] {
        let today = cal.startOfDay(for: .now)
        var result: [(Date, BudgetEvent)] = []
        for offset in 0..<days {
            let day = cal.date(byAdding: .day, value: offset, to: today)!
            for e in events(on: day) { result.append((day, e)) }
            if result.count >= limit { break }
        }
        return Array(result.prefix(limit)).map { (date: $0.0, event: $0.1) }
    }
}
