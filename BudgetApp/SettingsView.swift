import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(BudgetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var stepText = ""
    @State private var period = BudgetPeriod.daily
    @State private var notificationsDenied = false
    @State private var showSetBalance = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Period", selection: $period) {
                        ForEach(BudgetPeriod.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Budget") {
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text(period == .weekly
                         ? "The full amount is added at the start of each week. Unspent money rolls over."
                         : "The amount is added each day. Unspent money rolls over.")
                }
                Section("Theme") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(AppTheme.allCases) { t in
                            Button { store.setTheme(t) } label: {
                                VStack(spacing: 6) {
                                    Circle().fill(t.gradient())
                                        .frame(width: 48, height: 48)
                                        .overlay {
                                            if store.settings.theme == t {
                                                Image(systemName: "checkmark").font(.headline).foregroundStyle(.white)
                                            }
                                        }
                                    Text(t.label).font(.caption).foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                    Picker("Appearance", selection: Binding(
                        get: { store.settings.appearance },
                        set: { store.setAppearance($0) })) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Button { showSetBalance = true } label: {
                        LabeledContent("Adjust today's balance", value: money(store.balanceCents()))
                    }
                    .foregroundStyle(.primary)
                } footer: {
                    Text("For corrections, like extra cash you didn't track. Your budget amount stays the same.")
                }
                Section {
                    DatePicker("Reminder time", selection: Binding(
                        get: {
                            Calendar.current.date(bySettingHour: store.settings.reminderMinutes / 60,
                                                  minute: store.settings.reminderMinutes % 60, second: 0, of: .now)!
                        },
                        set: {
                            let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                            store.setReminderTime((c.hour ?? 9) * 60 + (c.minute ?? 0))
                        }), displayedComponents: .hourAndMinute)
                    if notificationsDenied {
                        Button("Notifications are off. Open iOS Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                        .font(.footnote)
                    }
                } header: { Text("Reminders") } footer: {
                    Text("When bill, subscription and payday reminders arrive. Turn reminders on per event in the calendar.")
                }
                Section {
                    LabeledContent("Quick spend") {
                        TextField("0.00", text: $stepText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("How much the big circle subtracts per tap.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let c = parseCents(amountText) {
                            store.updateBudget(amountCents: c, period: period)
                        }
                        if let c = parseCents(stepText), c > 0 { store.setQuickStep(c) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $showSetBalance) { AmountEntrySheet(mode: .setBalance) }
            .task {
                let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                notificationsDenied = status == .denied
            }
            .onAppear {
                period = store.settings.period
                amountText = String(format: "%.2f", Double(store.settings.amountCents) / 100)
                stepText = String(format: "%.2f", Double(store.settings.quickStepCents) / 100)
            }
        }
    }
}

func parseCents(_ text: String) -> Int? {
    let cleaned = text.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." }
    guard let v = Double(cleaned), v >= 0 else { return nil }
    return Int((v * 100).rounded())
}
