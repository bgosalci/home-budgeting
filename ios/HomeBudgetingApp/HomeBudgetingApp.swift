import SwiftUI

struct HomeBudgetingAppEntry: App {
    @StateObject private var viewModel = BudgetViewModel()
    @StateObject private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            HomeBudgetingRootView()
                .environmentObject(viewModel)
                .environmentObject(appSettings)
        }
    }
}
