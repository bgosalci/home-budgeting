import SwiftUI

struct TransactionsScreen: View {
    @EnvironmentObject private var viewModel: BudgetViewModel
    @State private var showEditor = false
    @State private var editingTransaction: BudgetTransaction?
    @State private var activeDialog: AppDialog?
    @State private var isSearchPresented = false

    private var transactionsState: TransactionsUiState { viewModel.uiState.transactions }

    var body: some View {
        NavigationStack {
            List {
                transactionSections
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: searchBinding,
                isPresented: $isSearchPresented,
                placement: .toolbar,
                prompt: "Search description"
            )
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    titleContent
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    categoryFilter
                    Button(action: { isSearchPresented = true }) {
                        Image(systemName: "magnifyingglass")
                    }
                    Button(action: { editingTransaction = nil; showEditor = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                TransactionEditor(
                    categories: transactionsState.availableCategories,
                    transaction: editingTransaction,
                    onSave: { date, desc, amount, category, id in
                        viewModel.addOrUpdateTransaction(date: date, desc: desc, amount: amount, category: category, editingId: id)
                    }
                )
            }
            .appDialog($activeDialog)
        }
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { transactionsState.search },
            set: { viewModel.updateTransactionSearch($0) }
        )
    }

    private var categoryBinding: Binding<String> {
        Binding(
            get: { transactionsState.category ?? "" },
            set: { viewModel.updateTransactionFilter($0.isEmpty ? nil : $0) }
        )
    }

    private var titleContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Transactions")
                .font(.headline)
            Text("Total \(currency(transactionsState.total))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var categoryFilter: some View {
        Picker(
            selection: categoryBinding,
            label: Label("Filter category", systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.iconOnly)
        ) {
            Text("All").tag("")
            ForEach(transactionsState.availableCategories, id: \.self) { category in
                Text(category).tag(category)
            }
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var transactionSections: some View {
        ForEach(transactionsState.groups) { group in
            Section(header: sectionHeader(for: group)) {
                ForEach(group.transactions) { tx in
                    Button(action: {
                        editingTransaction = tx
                        showEditor = true
                    }) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tx.desc).font(.headline)
                                Text(tx.category.isEmpty ? "Uncategorised" : tx.category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(currency(tx.amount)).bold()
                                Text("#\(group.startIndex + (group.transactions.firstIndex(where: { $0.id == tx.id }) ?? 0))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(.primary)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            activeDialog = AppDialog.confirm(
                                title: "Delete Transaction",
                                message: "Delete \(tx.desc) for \(currency(tx.amount))?",
                                confirmTitle: "Delete",
                                destructive: true,
                                onConfirm: { viewModel.deleteTransaction(id: tx.id) }
                            )
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                HStack {
                    Text("Day total")
                    Spacer()
                    Text(currency(group.dayTotal))
                }.font(.caption)
                HStack {
                    Text("Running total")
                    Spacer()
                    Text(currency(group.runningTotal))
                }.font(.caption)
            }
        }
        if !transactionsState.groups.isEmpty {
            clearTransactionsSection
        }
    }

    private var clearTransactionsSection: some View {
        Section {
            Button(role: .destructive) {
                let monthName = viewModel.uiState.selectedMonthKey ?? "this month"
                activeDialog = AppDialog.confirm(
                    title: "Clear Transactions",
                    message: "Are you sure you want to delete all transactions for \(monthName)?",
                    confirmTitle: "Clear",
                    destructive: true,
                    onConfirm: { viewModel.deleteAllTransactions() }
                )
            } label: {
                Text("Clear Transactions")
            }
        }
    }

    private func sectionHeader(for group: TransactionGroup) -> some View {
        HStack {
            Text(group.label)
            Spacer()
            Text(transactionCountDescription(for: group.transactionCount))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func transactionCountDescription(for count: Int) -> String {
        count == 1 ? "1 transaction" : "\(count) transactions"
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

private struct TransactionEditor: View {
    var categories: [String]
    var transaction: BudgetTransaction?
    var onSave: (String, String, Double, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var date: String = ""
    @State private var desc: String = ""
    @State private var amount: String = ""
    @State private var category: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Transaction")) {
                    TextField("Date (yyyy-MM-dd)", text: $date)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    TextField("Description", text: $desc)
                    TextField("Amount", text: $amount)
                        .signedDecimalKeyboard(text: $amount)
                    Picker("Category", selection: $category) {
                        Text("Uncategorised").tag("")
                        ForEach(categories, id: \.self) { value in
                            Text(value).tag(value)
                        }
                    }
                }
            }
            .navigationTitle(transaction == nil ? "New Transaction" : "Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = Double(amount) else { return }
                        onSave(date, desc, value, category.isEmpty ? nil : category, transaction?.id)
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let tx = transaction {
                    date = tx.date
                    desc = tx.desc
                    amount = String(tx.amount)
                    category = tx.category
                } else if date.isEmpty {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    date = formatter.string(from: Date())
                }
            }
        }
    }
}

struct TransactionsScreen_Previews: PreviewProvider {
    static var previews: some View {
        TransactionsScreen()
            .environmentObject(BudgetViewModel())
    }
}
