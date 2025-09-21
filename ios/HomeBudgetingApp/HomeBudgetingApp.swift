import SwiftUI

@main
struct HomeBudgetingApp: App {
    @StateObject private var viewModel = BudgetViewModel()

    var body: some Scene {
        WindowGroup {
            HomeBudgetingRootView()
                .environmentObject(viewModel)
        }
    }
}
