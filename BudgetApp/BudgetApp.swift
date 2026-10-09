import SwiftUI
import UserNotifications

@main
struct BudgetApp: App {
    @State private var store = BudgetStore()
    @AppStorage("tab") private var tab = 0
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = Reminders.delegate
    }

    var body: some Scene {
        WindowGroup {
            // Paged so you can swipe between screens; the page style hides the system tab bar, so draw our own.
            TabView(selection: $tab) {
                HomeView().tag(0)
                CalendarView().tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(.container, edges: .bottom)
            .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
            // Paged TabView leaves the status-bar strip uncovered; tint it to match the screens' gradient.
            .background(alignment: .top) {
                store.settings.theme.accent.opacity(0.34)
                    .frame(height: 100)
                    .background(Color(.systemBackground))
                    .ignoresSafeArea()
            }
            .environment(store)
            .tint(store.settings.theme.accent)
            .preferredColorScheme(store.settings.appearance.scheme)
            .onChange(of: store.events) { resync() }
            .onChange(of: store.settings.reminderMinutes) { resync() }
            .onChange(of: scenePhase) { if scenePhase == .active { resync() } }
            // Widget taps: dailybudget://calendar opens the Calendar tab, anything else Today.
            .onOpenURL { url in tab = url.host == "calendar" ? 1 : 0 }
        }
    }

    private func resync() {
        Task { await Reminders.reschedule(store) }
    }

    private var tabBar: some View {
        HStack {
            tabButton("Today", "circle.circle.fill", 0)
            tabButton("Calendar", "calendar", 1)
        }
        .padding(.top, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func tabButton(_ title: String, _ icon: String, _ index: Int) -> some View {
        Button {
            withAnimation { tab = index }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(tab == index ? store.settings.theme.accent : Color.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
