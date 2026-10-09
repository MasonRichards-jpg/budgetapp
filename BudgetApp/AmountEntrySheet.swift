import SwiftUI

/// Keypad that fills in from the right, like a card terminal: typing 4 4 6 gives $4.46.
struct AmountEntrySheet: View {
    enum Mode { case spend, setBalance }

    @Environment(BudgetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var mode = Mode.spend
    @State private var digits = ""
    @State private var note = ""

    private var cents: Int { Int(digits) ?? 0 }
    private let keys = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["00", "0", "⌫"]]

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
            }
            if mode == .setBalance {
                Text("Set today's balance. Your \(money(store.settings.amountCents)) budget stays the same.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Spacer()
            Text(money(cents))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(cents == 0 ? .secondary : .primary)

            if mode == .spend {
                TextField("What was it for? (optional)", text: $note)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(spacing: 12) {
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(row, id: \.self) { key in
                            Button { press(key) } label: {
                                Text(key)
                                    .font(.title.weight(.medium))
                                    .frame(maxWidth: .infinity, minHeight: 64)
                                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }

            Button {
                switch mode {
                case .spend: store.addSpend(cents: cents, note: note)
                case .setBalance: store.setBalance(cents)
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } label: {
                Text(confirmTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(cents == 0 ? Color.gray.opacity(0.4) : store.settings.theme.accent, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .disabled(mode == .spend && cents == 0)
        }
        .padding()
    }

    private var confirmTitle: String {
        switch mode {
        case .spend: cents == 0 ? "Enter an amount" : "Spend \(money(cents))"
        case .setBalance: "Set balance to \(money(cents))"
        }
    }

    private func press(_ key: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if key == "⌫" {
            digits = String(digits.dropLast())
        } else if digits.count + key.count <= 8 {
            digits = String(Int(digits + key) ?? 0)
            if digits == "0" { digits = "" }
        }
    }
}
