import SwiftUI

struct HomeView: View {
    @Environment(BudgetStore.self) private var store
    @State private var showCustom = false
    @State private var showSettings = false
    @State private var noteTarget: Spend?
    @State private var showReset = false
    @State private var editingEvent: BudgetEvent?
    @State private var showAllSpends = false

    var body: some View {
        let balance = store.balanceCents()
        let theme = store.settings.theme
        ZStack(alignment: .top) {
            ThemeBackdrop(theme: theme)
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Text("Today").font(.largeTitle.bold())
                        Spacer()
                        Button { showReset = true } label: {
                            Image(systemName: "arrow.counterclockwise").font(.body.weight(.semibold))
                        }
                        .accessibilityLabel("Reset budget")
                        .padding(.trailing, 8)
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill").font(.title3)
                        }
                        .accessibilityLabel("Settings")
                    }
                    Text(store.settings.period == .daily
                         ? "\(money(store.settings.amountCents)) per day · rolls over"
                         : "\(money(store.settings.amountCents)) per week · next \(store.nextPayout.formatted(.dateTime.weekday(.wide)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        store.addSpend(cents: store.settings.quickStepCents)
                    } label: {
                        VStack(spacing: 6) {
                            Text(money(balance))
                                .font(.system(size: 54, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .contentTransition(.numericText())
                            Text("tap to spend \(money(store.settings.quickStepCents))")
                                .font(.footnote.weight(.medium))
                                .opacity(0.85)
                        }
                        .foregroundStyle(.white)
                        .padding(24)
                        .frame(width: 280, height: 280)
                        .background(Circle().fill(theme.gradient(overBudget: balance < 0)))
                        .shadow(color: theme.glow(overBudget: balance < 0), radius: 20, y: 10)
                    }
                    .buttonStyle(PressableStyle())
                    .animation(.snappy, value: balance)

                    Button { showCustom = true } label: {
                        Label("Enter exact amount", systemImage: "plus.forwardslash.minus")
                    }
                    .font(.headline)
                    .buttonStyle(CapsuleStyle())

                    upcomingSection
                    todaySection
                }
                .padding()
            }
            .scrollClipDisabled()
            .sheet(isPresented: $showCustom) { AmountEntrySheet().presentationDetents([.large]) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $editingEvent) { EventEditor(event: $0) }
            .sheet(item: $noteTarget) { NoteSheet(spend: $0).presentationDetents([.height(220)]) }
            .confirmationDialog("Reset your budget?", isPresented: $showReset, titleVisibility: .visible) {
                Button("Reset to \(money(store.settings.amountCents))", role: .destructive) { store.resetBudget() }
            } message: {
                Text("Your balance goes back to the original budget. Rollover and all recorded spending, including on the calendar, will be cleared.")
            }
        }
    }

    @ViewBuilder private var todaySection: some View {
        if !store.todaysSpends.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Spent today · \(money(store.spentTodayCents))")
                    .font(.headline)
                ForEach(showAllSpends ? store.todaysSpends : Array(store.todaysSpends.prefix(3))) { spend in
                    HStack {
                        Button { noteTarget = spend } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                if spend.note.isEmpty {
                                    Text("Add a note").foregroundStyle(.secondary).italic()
                                } else {
                                    Text(spend.note)
                                }
                                Text(spend.date, format: .dateTime.hour().minute())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Text("−\(money(spend.cents))").monospacedDigit()
                        Button { store.deleteSpend(spend) } label: {
                            Image(systemName: "arrow.uturn.backward.circle")
                        }
                        .accessibilityLabel("Undo")
                    }
                    .padding(12)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
                }
                if store.todaysSpends.count > 3 {
                    Button(showAllSpends ? "Show less" : "Show all \(store.todaysSpends.count)") {
                        withAnimation { showAllSpends.toggle() }
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Horizontal strip so it stays visible no matter how long today's spend list gets.
    @ViewBuilder private var upcomingSection: some View {
        let items = store.upcoming(days: 21, limit: 8)  // 3 weeks, so monthly items never show twice
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Coming up").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            Button { editingEvent = item.event } label: {
                                UpcomingChip(event: item.event, date: item.date)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.tint)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.thinMaterial, in: Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

struct EventRow: View {
    let event: BudgetEvent
    var date: Date? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.kind.icon)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(event.kind.color, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.body.weight(.medium))
                HStack(spacing: 4) {
                    Text(subtitle)
                    if event.remindDaysBefore != nil { Image(systemName: "bell.fill") }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if event.amountCents > 0 {
                Text("\(event.kind == .payday ? "+" : "−")\(money(event.amountCents))")
                    .monospacedDigit()
                    .foregroundStyle(event.kind == .payday ? .green : .primary)
            }
        }
        .padding(12)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var subtitle: String {
        if let date {
            let day = Calendar.current.isDateInToday(date) ? "Today"
                : Calendar.current.isDateInTomorrow(date) ? "Tomorrow"
                : date.formatted(.dateTime.weekday(.abbreviated).month().day())
            return "\(day) · \(event.recurrence.label)"
        }
        return "\(event.kind.label) · \(event.recurrence.label)"
    }
}

struct NoteSheet: View {
    @Environment(BudgetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let spend: Spend
    @State private var note = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("−\(money(spend.cents))").font(.title2.bold())
            TextField("What was it for?", text: $note)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit(save)
            Button("Save", action: save).buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear { note = spend.note }
    }

    private func save() {
        store.setNote(note, for: spend)
        dismiss()
    }
}

struct UpcomingChip: View {
    let event: BudgetEvent
    let date: Date

    private var when: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.abbreviated).month().day())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: event.kind.icon).font(.caption)
                Text(when).font(.caption.weight(.semibold))
            }
            .foregroundStyle(event.kind.color)
            Text(event.title).font(.subheadline.weight(.semibold)).lineLimit(1)
            Text(event.amountCents > 0
                 ? "\(event.kind == .payday ? "+" : "−")\(money(event.amountCents))"
                 : event.kind.label)
                .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(12)
        .frame(width: 130, alignment: .leading)
        .background(event.kind.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(event.kind.color.opacity(0.4)))
    }
}
