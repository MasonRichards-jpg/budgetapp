import SwiftUI

struct CalendarView: View {
    @Environment(BudgetStore.self) private var store
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now))!
    @State private var selected = Calendar.current.startOfDay(for: .now)
    @State private var editing: BudgetEvent?

    private let cal = Calendar.current

    var body: some View {
        // Custom title instead of a NavigationStack: nav bars misbehave inside the swipeable paged container.
        ZStack(alignment: .top) {
            ThemeBackdrop(theme: store.settings.theme)
            ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Calendar").font(.largeTitle.bold())
                    Spacer()
                    Button {
                        editing = BudgetEvent(title: "", amountCents: 0, kind: .bill, recurrence: .monthly, date: selected)
                    } label: { Image(systemName: "plus").font(.title3.weight(.semibold)) }
                    .accessibilityLabel("Add event")
                }
                header
                weekdayRow
                grid
                dayDetail
            }
            .padding()
            }
        }
        .sheet(item: $editing) { EventEditor(event: $0) }
    }

    private var header: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(month, format: .dateTime.month(.wide).year()).font(.title3.weight(.semibold))
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
        }
        .overlay(alignment: .bottom) {
            Text("Spent this month: \(money(store.spentCents(inMonthOf: month)))")
                .font(.caption).foregroundStyle(.secondary)
                .offset(y: 18)
        }
        .padding(.bottom, 14)
    }

    private var weekdayRow: some View {
        let symbols = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return HStack {
            ForEach(0..<7, id: \.self) { i in
                Text(symbols[(first + i) % 7])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, day in
                if let day { dayCell(day) } else { Color.clear.frame(height: 76) }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = cal.isDate(day, inSameDayAs: selected)
        let isToday = cal.isDateInToday(day)
        let items = store.events(on: day)
        let spent = store.spentCents(on: day)
        let tint = items.first?.kind.color
        return Button { selected = day } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.callout.weight(isToday || tint != nil ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.accentColor : Color.primary)
                VStack(spacing: 2) {
                    ForEach(items.prefix(2)) { e in
                        Text(e.title)
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .frame(maxWidth: .infinity)
                            .background(e.kind.color, in: Capsule())
                    }
                    if items.count > 2 {
                        Text("+\(items.count - 2) more").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if spent > 0 {
                    Text("−\(money(spent))")
                        .font(.system(size: 9, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.red)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            .padding(.vertical, 4).padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76)
            .background((tint ?? .clear).opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : (tint ?? .clear).opacity(0.6),
                                  lineWidth: isSelected ? 2.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selected, format: .dateTime.weekday(.wide).month().day()).font(.headline)
            let items = store.events(on: selected)
            if items.isEmpty {
                if store.spends(on: selected).isEmpty { Text("Nothing scheduled").foregroundStyle(.secondary) }
            }
            ForEach(items) { e in
                Button { editing = e } label: { EventRow(event: e) }.foregroundStyle(.primary)
            }
            let spends = store.spends(on: selected)
            if !spends.isEmpty {
                Text("Spent · \(money(store.spentCents(on: selected)))").font(.headline).padding(.top, 8)
                ForEach(spends) { sp in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sp.note.isEmpty ? "Spend" : sp.note)
                                .foregroundStyle(sp.note.isEmpty ? .secondary : .primary)
                            Text(sp.date, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("−\(money(sp.cents))").monospacedDigit()
                    }
                    .padding(12)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shift(_ by: Int) {
        month = cal.date(byAdding: .month, value: by, to: month)!
    }

    private func daysInMonth() -> [Date?] {
        let count = cal.range(of: .day, in: .month, for: month)!.count
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let days: [Date?] = (0..<count).map { cal.date(byAdding: .day, value: $0, to: month) }
        return Array(repeating: nil, count: lead) + days
    }
}

struct EventEditor: View {
    @Environment(BudgetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var event: BudgetEvent
    @State private var amountText = ""

    init(event: BudgetEvent) {
        _event = State(initialValue: event)
        _amountText = State(initialValue: event.amountCents > 0 ? String(format: "%.2f", Double(event.amountCents) / 100) : "")
    }

    private var isNew: Bool { !store.events.contains { $0.id == event.id } }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $event.kind) {
                    ForEach(EventKind.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                TextField("Name (e.g. Rent, Netflix, Paycheck)", text: $event.title)
                LabeledContent("Amount") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                DatePicker("Date", selection: $event.date, displayedComponents: .date)
                Picker("Repeats", selection: $event.recurrence) {
                    ForEach(Recurrence.allCases) { Text($0.label).tag($0) }
                }
                Section {
                    Toggle("Remind me", isOn: Binding(
                        get: { event.remindDaysBefore != nil },
                        set: { event.remindDaysBefore = $0 ? 1 : nil }))
                    if let days = event.remindDaysBefore {
                        Stepper(value: Binding(get: { days }, set: { event.remindDaysBefore = $0 }), in: 0...30) {
                            Text(days == 0 ? "On the day" : days == 1 ? "1 day before" : "\(days) days before")
                        }
                    }
                } footer: {
                    if event.remindDaysBefore != nil {
                        Text("You'll get a notification at \(clock(store.settings.reminderMinutes)). Change the time in Settings.")
                    }
                }
                if !isNew {
                    Button("Delete", role: .destructive) { store.delete(event); dismiss() }
                }
            }
            .navigationTitle(isNew ? "New \(event.kind.label)" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        event.amountCents = parseCents(amountText) ?? 0
                        if event.title.trimmingCharacters(in: .whitespaces).isEmpty { event.title = event.kind.label }
                        store.upsert(event)
                        dismiss()
                    }
                }
            }
        }
    }
}
