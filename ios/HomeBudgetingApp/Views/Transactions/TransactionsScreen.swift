import SwiftUI

struct TransactionsScreen: View {
    @EnvironmentObject private var viewModel: BudgetViewModel
    @State private var showEditor = false
    @State private var editingTransaction: BudgetTransaction?
    @State private var activeDialog: AppDialog?
    @State private var isScrolled = false

    private var transactionsState: TransactionsUiState { viewModel.uiState.transactions }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                    }
                    .frame(height: 0)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    
                    Section {
                        HStack {
                            Text("Total")
                                .font(.headline)
                            Spacer()
                            Text(currency(transactionsState.total))
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    transactionSections
                }
                .listStyle(.insetGrouped)
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isScrolled = value < -50
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if isScrolled {
                        VStack(alignment: .center, spacing: 1) {
                            Text("Transactions")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text(currency(transactionsState.total))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Transactions, Total \(currency(transactionsState.total))")
                    } else {
                        Text("Transactions")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    categoryFilter
                    Button(action: { viewModel.updateTransactionSearch("") }) {
                        Image(systemName: "magnifyingglass")
                    }
                    .controlSize(.small)
                    addButton
                }
            }
            .searchable(
                text: searchBinding,
                placement: .toolbar,
                prompt: "Search description"
            )
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


    private var categoryFilter: some View {
        Picker(
            selection: categoryBinding,
            label: Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.iconOnly)
        ) {
            Text("All").tag("")
            ForEach(transactionsState.availableCategories, id: \.self) { category in
                Text(category).tag(category)
            }
        }
        .pickerStyle(.menu)
        .controlSize(.small)
        .frame(maxWidth: 80)
    }
    
    private var addButton: some View {
        Button(action: { editingTransaction = nil; showEditor = true }) {
            Image(systemName: "plus")
        }
        .controlSize(.small)
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

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


private struct TransactionEditor: View {
    var categories: [String]
    var transaction: BudgetTransaction?
    var onSave: (String, String, Double, String?, String?) -> Void

    @EnvironmentObject private var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var desc: String = ""
    @State private var amount: String = ""
    @State private var category: String = ""
    @State private var predictedCategory: String = ""
    @State private var predictionTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Transaction")) {
                    DatePicker(
                        "Date",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    TextField("Description", text: $desc)
                    TextField("Amount", text: $amount)
                        .signedDecimalKeyboard(text: $amount)
                    if !predictedCategory.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.secondary)
                            Text("Suggested: \(predictedCategory)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            if category != predictedCategory {
                                Button("Apply") {
                                    category = predictedCategory
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
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
                        let formattedDate = formattedDate(from: selectedDate)
                        onSave(formattedDate, desc, value, category.isEmpty ? nil : category, transaction?.id)
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let tx = transaction {
                    selectedDate = parseDate(tx.date) ?? Date()
                    desc = tx.desc
                    amount = String(tx.amount)
                    category = tx.category
                } else {
                    selectedDate = Date()
                    predictedCategory = ""
                }
                refreshPrediction()
            }
            .onChange(of: desc) { _ in refreshPrediction() }
            .onChange(of: amount) { _ in refreshPrediction() }
            .onDisappear {
                predictionTask?.cancel()
                predictionTask = nil
            }
        }
    }

    private func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.string(from: date)
    }

    private func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func refreshPrediction() {
        let normalizedDesc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        predictionTask?.cancel()
        guard !normalizedDesc.isEmpty else {
            predictedCategory = ""
            predictionTask = nil
            return
        }
        let amountValue = Double(amount)
        let requestDesc = normalizedDesc
        let requestAmount = amountValue
        predictionTask = Task {
            let suggestion = await viewModel.predictCategory(desc: requestDesc, amount: requestAmount)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                let currentDesc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
                let currentAmount = Double(amount)
                if currentDesc == requestDesc, currentAmount == requestAmount {
                    predictedCategory = suggestion
                }
                predictionTask = nil
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
