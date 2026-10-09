import SwiftUI

/// "9:00 AM" from minutes since midnight.
func clock(_ minutes: Int) -> String {
    Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now)!
        .formatted(date: .omitted, time: .shortened)
}

func money(_ cents: Int) -> String {
    let value = Double(cents) / 100
    return value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
}

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable {
    case daily, weekly
    var id: String { rawValue }
    var label: String { self == .daily ? "Per day" : "Per week" }
}

struct BudgetSettings: Codable {
    var amountCents = 2000
    var period = BudgetPeriod.daily
    var startDate = Calendar.current.startOfDay(for: .now)
    /// Balance carried in from before `startDate` (set when the budget amount changes).
    var carryCents = 0
    var quickStepCents = 100
    var theme = AppTheme.mint
    var appearance = Appearance.system
    /// Time of day reminders are delivered, in minutes since midnight.
    var reminderMinutes = 9 * 60

    init() {}

    // Tolerant decoding so data saved by older versions still loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BudgetSettings.defaults
        amountCents = try c.decodeIfPresent(Int.self, forKey: .amountCents) ?? d.amountCents
        period = try c.decodeIfPresent(BudgetPeriod.self, forKey: .period) ?? d.period
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate) ?? d.startDate
        carryCents = try c.decodeIfPresent(Int.self, forKey: .carryCents) ?? 0
        quickStepCents = try c.decodeIfPresent(Int.self, forKey: .quickStepCents) ?? d.quickStepCents
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .mint
        appearance = try c.decodeIfPresent(Appearance.self, forKey: .appearance) ?? .system
        reminderMinutes = try c.decodeIfPresent(Int.self, forKey: .reminderMinutes) ?? 9 * 60
    }

    private static let defaults = BudgetSettings()
}

struct Spend: Identifiable, Codable {
    var id = UUID()
    var date = Date.now
    var cents: Int
    var note = ""

    init(cents: Int, note: String = "") {
        self.cents = cents
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        cents = try c.decode(Int.self, forKey: .cents)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

enum EventKind: String, Codable, CaseIterable, Identifiable {
    case bill, subscription, payday
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bill: "Bill"
        case .subscription: "Subscription"
        case .payday: "Payday"
        }
    }
    var icon: String {
        switch self {
        case .bill: "doc.text.fill"
        case .subscription: "arrow.triangle.2.circlepath"
        case .payday: "banknote.fill"
        }
    }
    var color: Color {
        switch self {
        case .bill: .orange
        case .subscription: .purple
        case .payday: .green
        }
    }
}

enum Recurrence: String, Codable, CaseIterable, Identifiable {
    case once, weekly, biweekly, monthly, yearly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .once: "One time"
        case .weekly: "Weekly"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}

struct BudgetEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var amountCents: Int
    var kind: EventKind
    var recurrence: Recurrence
    var date: Date
    /// Days before the due date to notify; nil means no reminder.
    var remindDaysBefore: Int? = nil

    func occurs(on day: Date, calendar cal: Calendar = .current) -> Bool {
        let start = cal.startOfDay(for: date)
        let day = cal.startOfDay(for: day)
        guard day >= start else { return false }
        let sc = cal.dateComponents([.day, .month], from: start)
        let dc = cal.dateComponents([.day, .month], from: day)
        let daysApart = cal.dateComponents([.day], from: start, to: day).day ?? 0
        let lastDayOfMonth = cal.range(of: .day, in: .month, for: day)?.count ?? 31
        switch recurrence {
        case .once: return daysApart == 0
        case .weekly: return daysApart % 7 == 0
        case .biweekly: return daysApart % 14 == 0
        case .monthly: return dc.day == min(sc.day ?? 1, lastDayOfMonth)
        case .yearly: return dc.month == sc.month && dc.day == min(sc.day ?? 1, lastDayOfMonth)
        }
    }
}
