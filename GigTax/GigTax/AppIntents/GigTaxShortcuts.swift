import AppIntents

struct GigTaxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogShiftIntent(),
            phrases: [
                "Log a shift in \(.applicationName)",
                "Log a shift with \(.applicationName)",
            ],
            shortTitle: "Log a Shift",
            systemImageName: "dollarsign.circle"
        )
        AppShortcut(
            intent: TaxOwedIntent(),
            phrases: [
                "How much do I owe in taxes in \(.applicationName)",
                "What do I owe in taxes with \(.applicationName)",
            ],
            shortTitle: "Tax Owed",
            systemImageName: "chart.bar"
        )
    }
}
