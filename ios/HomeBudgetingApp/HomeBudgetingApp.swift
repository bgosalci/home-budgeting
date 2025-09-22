#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI

struct HomeBudgetingAppEntry: App {
    @StateObject private var viewModel = BudgetViewModel()

    var body: some Scene {
        WindowGroup {
            HomeBudgetingRootView()
                .environmentObject(viewModel)
        }
    }
}
#endif
