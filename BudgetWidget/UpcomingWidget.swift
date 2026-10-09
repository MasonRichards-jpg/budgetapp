import WidgetKit
import SwiftUI

// MARK: Entry

struct MonthDay {
    let date: Date
    let number: Int
    let kinds: [EventKind]
    let isToday: Bool
    let isPast: Bool
}

struct UpcomingItem: Identifiable {
    let id: Int
    let date: Date
    let event: BudgetEvent
}

struct UpcomingEntry: TimelineEntry {
    let date: Date
    let month: Date
    /// Leading nils pad the first week so day 1 lands on the right weekday.
    let days: [MonthDay?]
    let upcoming: [UpcomingItem]
    let theme: AppTheme

    /// Built from plain events (no store) so it's easy to preview and test.
    init(events: [BudgetEvent], day: Date, theme: AppTheme, calendar cal: Calendar = .current) {
        let today = cal.startOfDay(for: day)
        let monthStart = cal.dateInterval(of: .month, for: today)!.start
        let count = cal.range(of: .day, in: .month, for: monthStart)!.count
        let lead = (cal.component(.weekday, from: monthStart) - cal.firstWeekday + 7) % 7

        var days: [MonthDay?] = Array(repeating: nil, count: lead)
        for i in 0..<count {
            let d = cal.date(byAdding: .day, value: i, to: monthStart)!
            let kinds = Set(events.filter { $0.occurs(on: d, calendar: cal) }.map(\.kind))
            days.append(MonthDay(date: d, number: i + 1,
                                 kinds: EventKind.allCases.filter(kinds.contains),
                                 isToday: d == today, isPast: d < today))
        }

        var upcoming: [UpcomingItem] = []
        // 3 weeks, matching the app, so monthly items never show twice.
        for offset in 0..<21 where upcoming.count < 6 {
            let d = cal.date(byAdding: .day, value: offset, to: today)!
            for e in events.filter({ $0.occurs(on: d, calendar: cal) }).sorted(by: { $0.title < $1.title }) {
                upcoming.append(UpcomingItem(id: upcoming.count, date: d, event: e))
            }
        }

        self.date = day
        self.month = monthStart
        self.days = days
        self.upcoming = Array(upcoming.prefix(6))
        self.theme = theme
    }
}

// MARK: Views

/// Whole dollars drop the cents so amounts fit the narrow widget rows.
private func shortMoney(_ cents: Int) -> String {
    let code = Locale.current.currency?.identifier ?? "USD"
    let value = Double(cents) / 100
    return cents % 100 == 0
        ? value.formatted(.currency(code: code).precision(.fractionLength(0)))
        : value.formatted(.currency(code: code))
}

struct MiniMonth: View {
    let entry: UpcomingEntry
    let cell: CGFloat
    let font: CGFloat

    private var weekdaySymbols: [String] {
        let cal = Calendar.current
        let s = cal.veryShortWeekdaySymbols
        return (0..<7).map { s[(cal.firstWeekday - 1 + $0) % 7] }
    }

    private var weeks: [[MonthDay?]] {
        var all = entry.days
        while all.count % 7 != 0 { all.append(nil) }
        return stride(from: 0, to: all.count, by: 7).map { Array(all[$0..<$0 + 7]) }
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdaySymbols[i])
                        .font(.system(size: font - 1, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<weeks.count, id: \.self) { w in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        dayCell(weeks[w][i]).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder private func dayCell(_ day: MonthDay?) -> some View {
        if let day {
            let color = day.kinds.first?.color
            Text("\(day.number)")
                .font(.system(size: font, weight: day.isToday || color != nil ? .bold : .regular, design: .rounded))
                .foregroundStyle(day.isToday ? Color.white : day.isPast ? Color.secondary : Color.primary)
                .frame(width: cell, height: cell)
                .background {
                    if day.isToday {
                        Circle().fill(entry.theme.accent)
                    } else if let color {
                        Circle().fill(color.opacity(day.isPast ? 0.15 : 0.3))
                    }
                }
                .overlay(alignment: .bottom) {
                    // Second event type on the same day shows as a small dot.
                    if day.kinds.count > 1 {
                        Circle().fill(day.kinds[1].color).frame(width: 3, height: 3).offset(y: 2)
                    }
                }
        } else {
            Color.clear.frame(width: cell, height: cell)
        }
    }
}

struct UpcomingRow: View {
    let item: UpcomingItem
    let today: Date

    private var when: String {
        let cal = Calendar.current
        if cal.isDate(item.date, inSameDayAs: today) { return "Today" }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: today)),
           cal.isDate(item.date, inSameDayAs: tomorrow) { return "Tomorrow" }
        return item.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(item.event.kind.color)
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.event.title).font(.caption.weight(.semibold)).lineLimit(1)
                Text(when).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            if item.event.amountCents > 0 {
                Text("\(item.event.kind == .payday ? "+" : "−")\(shortMoney(item.event.amountCents))")
                    .font(.caption2.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(item.event.kind == .payday ? Color.green : Color.primary)
                    .lineLimit(1)
            }
        }
    }
}

struct UpcomingContent: View {
    let entry: UpcomingEntry
    let large: Bool

    private var header: some View {
        Text(entry.month, format: .dateTime.month(.wide))
            .font(.system(size: large ? 15 : 11, weight: .bold))
            .foregroundStyle(entry.theme.accent)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: large ? 8 : 6) {
            if entry.upcoming.isEmpty {
                Text("Nothing coming up").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(entry.upcoming.prefix(large ? 4 : 3)) { UpcomingRow(item: $0, today: entry.date) }
        }
    }

    var body: some View {
        if large {
            VStack(alignment: .leading, spacing: 8) {
                header
                MiniMonth(entry: entry, cell: 22, font: 12)
                Divider()
                Text("Coming up").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                list
                Spacer(minLength: 0)
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    header
                    MiniMonth(entry: entry, cell: 14, font: 9)
                }
                .frame(width: 136)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Coming up").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                    list
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

struct UpcomingWidgetView: View {
    let entry: UpcomingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        UpcomingContent(entry: entry, large: family == .systemLarge)
            .containerBackground(for: .widget) {
                ZStack(alignment: .top) {
                    Rectangle().fill(.background)
                    LinearGradient(colors: [entry.theme.accent.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom)
                }
            }
            .widgetURL(URL(string: "dailybudget://calendar"))
    }
}

// MARK: Widget

struct UpcomingProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingEntry {
        UpcomingEntry(events: [], day: .now, theme: .mint)
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingEntry) -> Void) {
        let store = BudgetStore()
        completion(UpcomingEntry(events: store.events, day: .now, theme: store.settings.theme))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingEntry>) -> Void) {
        let store = BudgetStore()
        let cal = Calendar.current
        let midnight = cal.startOfDay(for: .now)
        // Today moves and "Tomorrow" labels change at midnight, so queue a week of daily entries.
        let entries = [UpcomingEntry(events: store.events, day: .now, theme: store.settings.theme)] + (1...7).map {
            UpcomingEntry(events: store.events, day: cal.date(byAdding: .day, value: $0, to: midnight)!,
                          theme: store.settings.theme)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct UpcomingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpcomingWidget", provider: UpcomingProvider()) { entry in
            UpcomingWidgetView(entry: entry)
        }
        .configurationDisplayName("Upcoming")
        .description("This month's calendar with your next bills, subscriptions and paydays.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
