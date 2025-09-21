import SwiftUI

public struct HomeBudgetingRootView: View {
    @EnvironmentObject private var viewModel: BudgetViewModel

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
        }
        .tint(Color.accentColor)
        .background(Color(.systemGroupedBackground))
    }
}

struct HomeBudgetingRootView_Previews: PreviewProvider {
    static var previews: some View {
        HomeBudgetingRootView()
            .environmentObject(BudgetViewModel())
    }
}
