import SwiftUI
import HomeBudgetingApp

@main
struct HomeBudgetingAppMain: App {
    @StateObject private var viewModel = BudgetViewModel()

    var body: some Scene {
        WindowGroup {
            HomeBudgetingRootView()
                .environmentObject(viewModel)
        }
    }
}
