#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI

public struct HomeBudgetingRootView: View {
    @EnvironmentObject private var viewModel: BudgetViewModel
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        TabView {
            BudgetScreen()
                .tabItem { Label("Budget", systemImage: "chart.pie") }
            TransactionsScreen()
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }
            AnalysisScreen()
                .tabItem { Label("Analysis", systemImage: "chart.bar.xaxis") }
            CalendarScreen()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            NotesScreen()
                .tabItem { Label("Notes", systemImage: "note.text") }
            PredictionScreen()
                .tabItem { Label("Predict", systemImage: "wand.and.rays") }
            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Color.accentColor)
        .background(Color(.systemGroupedBackground))
        .preferredColorScheme(appSettings.selectedTheme.colorScheme)
        .fullScreenCover(isPresented: lockBinding) {
            AppLockView()
                .environmentObject(appSettings)
                .interactiveDismissDisabled(true)
        }
        .onAppear {
            appSettings.refreshBiometricState()
            appSettings.lock()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                appSettings.lock()
            case .active:
                appSettings.refreshBiometricState()
            default:
                break
            }
        }
    }
}

private extension HomeBudgetingRootView {
    var lockBinding: Binding<Bool> {
        Binding(
            get: { appSettings.isAppLockEnabled && !appSettings.isUnlocked },
            set: { _ in }
        )
    }
}

struct HomeBudgetingRootView_Previews: PreviewProvider {
    static var previews: some View {
        HomeBudgetingRootView()
            .environmentObject(BudgetViewModel())
            .environmentObject(AppSettings())
    }
}
#endif
