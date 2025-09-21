import SwiftUI

struct BudgetScreen: View {
    @EnvironmentObject private var viewModel: BudgetViewModel
    @State private var newMonthKey: String = ""
    @State private var incomeName: String = ""
    @State private var incomeAmount: String = ""
    @State private var categoryName: String = ""
    @State private var categoryGroup: String = ""
    @State private var categoryBudget: String = ""

    private var totals: MonthTotals { viewModel.uiState.totals }

    var body: some View {
        NavigationStack {
            List {
                monthSection
                summarySection
                incomesSection
                categoriesSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Collapse") { viewModel.setAllGroupsCollapsed(true) }
                    Button("Expand") { viewModel.setAllGroupsCollapsed(false) }
                }
            }
        }
    }

    private var monthSection: some View {
        Section(header: Text("Month")) {
            Picker("Selected Month", selection: Binding(
                get: { viewModel.uiState.selectedMonthKey ?? "" },
                set: { viewModel.selectMonth($0) }
            )) {
                ForEach(viewModel.uiState.monthKeys, id: \.self) { key in
                    Text(key).tag(key)
                }
            }
            .pickerStyle(.menu)

            HStack {
                TextField("YYYY-MM", text: $newMonthKey)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                Button("Create") {
                    viewModel.createMonth(newMonthKey)
                    newMonthKey = ""
                }
                .buttonStyle(.borderedProminent)
            }
            if let selected = viewModel.uiState.selectedMonthKey {
                Button(role: .destructive) {
                    viewModel.deleteNextMonth()
                } label: {
                    Label("Delete next future month", systemImage: "trash")
                }
                .disabled(viewModel.uiState.monthKeys.last == selected)
            }
        }
    }

    private var summarySection: some View {
        Section(header: Text("Summary")) {
            HStack {
                summaryTile(title: "Income", value: totals.totalIncome)
                summaryTile(title: "Budget", value: totals.budgetTotal)
                summaryTile(title: "Actual", value: totals.actualTotal)
            }
            HStack {
                summaryTile(title: "Left (actual)", value: totals.leftoverActual)
                summaryTile(title: "Left (budget)", value: totals.leftoverBudget)
            }
        }
    }

    private var incomesSection: some View {
        Section(header: Text("Income")) {
            if viewModel.uiState.incomes.isEmpty {
                Text("No income recorded").foregroundColor(.secondary)
            }
            ForEach(viewModel.uiState.incomes) { income in
                HStack {
                    VStack(alignment: .leading) {
                        Text(income.name).font(.headline)
                        Text("ID: \(income.id)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(currency(income.amount))
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { viewModel.deleteIncome(id: income.id) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            VStack {
                TextField("Name", text: $incomeName)
                TextField("Amount", text: $incomeAmount)
                    .keyboardType(.decimalPad)
                Button("Add Income") {
                    if let amount = Double(incomeAmount) {
                        viewModel.addIncome(name: incomeName, amount: amount)
                        incomeName = ""
                        incomeAmount = ""
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var categoriesSection: some View {
        Section(header: Text("Categories")) {
            if viewModel.uiState.categories.isEmpty {
                Text("No categories configured").foregroundColor(.secondary)
            }
            let groups = Dictionary(grouping: viewModel.uiState.categories, by: { $0.group })
            ForEach(groups.keys.sorted(), id: \.self) { key in
                let items = groups[key] ?? []
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { !viewModel.uiState.collapsedGroups.contains(key) },
                        set: { _ in viewModel.toggleGroup(key) }
                    ),
                    content: {
                        ForEach(items, id: \.name) { category in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(category.name).font(.headline)
                                    Text("Budget: \(currency(category.budget))").font(.caption)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Actual: \(currency(category.actual))")
                                    Text("Diff: \(currency(category.difference))")
                                        .foregroundColor(category.difference >= 0 ? .green : .red)
                                }.font(.caption)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { viewModel.deleteCategory(name: category.name) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    },
                    label: {
                        HStack {
                            Text(key)
                            Spacer()
                            if let summary = viewModel.uiState.totals.groups.first(where: { $0.name == key }) {
                                Text(currency(summary.actual)).font(.footnote)
                            }
                        }
                    }
                )
            }
            VStack {
                TextField("Category name", text: $categoryName)
                TextField("Group", text: $categoryGroup)
                TextField("Budget", text: $categoryBudget)
                    .keyboardType(.decimalPad)
                Button("Save Category") {
                    if let budget = Double(categoryBudget) {
                        viewModel.addOrUpdateCategory(name: categoryName, group: categoryGroup, budget: budget)
                        categoryName = ""
                        categoryGroup = ""
                        categoryBudget = ""
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func summaryTile(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(currency(value)).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

struct BudgetScreen_Previews: PreviewProvider {
    static var previews: some View {
        BudgetScreen()
            .environmentObject(BudgetViewModel())
    }
}
