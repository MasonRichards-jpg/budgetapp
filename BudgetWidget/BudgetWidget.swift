import WidgetKit
import SwiftUI

struct BudgetEntry: TimelineEntry {
    let date: Date
    let balanceCents: Int
    let amountCents: Int
    let period: BudgetPeriod
    let theme: AppTheme
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: .now, balanceCents: 2000, amountCents: 2000, period: .daily, theme: .mint)
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        completion(entry(BudgetStore(), on: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let store = BudgetStore()
        let cal = Calendar.current
        let midnight = cal.startOfDay(for: .now)
        // Balance changes each midnight (new allowance rolls in), so queue a week of entries.
        var entries = [entry(store, on: .now)]
        for i in 1...7 {
            let day = cal.date(byAdding: .day, value: i, to: midnight)!
            entries.append(entry(store, on: day, shownAt: day))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(_ store: BudgetStore, on day: Date, shownAt: Date? = nil) -> BudgetEntry {
        BudgetEntry(date: shownAt ?? day, balanceCents: store.balanceCents(on: day),
                    amountCents: store.settings.amountCents, period: store.settings.period,
                    theme: store.settings.theme)
    }
}

struct BudgetWidgetView: View {
    let entry: BudgetEntry
    @Environment(\.widgetFamily) private var family

    private var over: Bool { entry.balanceCents < 0 }
    private var rate: String { "of \(money(entry.amountCents))/\(entry.period == .daily ? "day" : "week")" }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Text("left").font(.system(size: 9))
                        Text(money(entry.balanceCents)).font(.headline).minimumScaleFactor(0.5).lineLimit(1)
                    }
                    .padding(4)
                }
            case .accessoryRectangular:
                VStack(alignment: .leading) {
                    Text("Budget left").font(.caption2)
                    Text(money(entry.balanceCents)).font(.title2.bold()).minimumScaleFactor(0.6)
                    Text(rate).font(.caption2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .systemMedium:
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Left to spend").font(.subheadline.weight(.medium)).opacity(0.85)
                        Text(money(entry.balanceCents))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5).lineLimit(1)
                        Text(over ? "over budget" : "\(rate) · rolls over").font(.footnote).opacity(0.85)
                    }
                    Spacer()
                }
                .foregroundStyle(.white)
            default:
                VStack(alignment: .leading, spacing: 2) {
                    Text("Left to spend").font(.caption.weight(.medium)).opacity(0.85)
                    Spacer()
                    Text(money(entry.balanceCents))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5).lineLimit(1)
                    Text(over ? "over budget" : rate).font(.caption2).opacity(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.white)
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryCircular || family == .accessoryRectangular {
                Color.clear
            } else {
                entry.theme.gradient(overBudget: over)
            }
        }
        .widgetURL(URL(string: "dailybudget://today"))
    }
}

@main
struct BudgetWidgets: WidgetBundle {
    var body: some Widget {
        BudgetWidget()
        UpcomingWidget()
    }
}

struct BudgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BudgetWidget", provider: Provider()) { entry in
            BudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Budget")
        .description("How much you have left to spend.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
