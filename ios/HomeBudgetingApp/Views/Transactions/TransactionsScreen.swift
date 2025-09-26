#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI

struct TransactionsScreen: View {
    @EnvironmentObject private var viewModel: BudgetViewModel
    @State private var showEditor = false
    @State private var editingTransaction: BudgetTransaction?
    @State private var activeDialog: AppDialog?
    @State private var isScrolled = false
    @State private var isAtBottom = false
    @State private var isSearchPresented = false
    @State private var scrollViewHeight: CGFloat = 0
    @State private var scrollBottomPosition: CGFloat = 0

    private var transactionsState: TransactionsUiState { viewModel.uiState.transactions }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                transactionsContent(proxy: proxy)
            }
        }
    }

    @ViewBuilder
    private func transactionsContent(proxy: ScrollViewProxy) -> some View {
        GeometryReader { geometry in
            List {
                topScrollAnchor
                headerTotalSection

                transactionSections

                if !transactionsState.groups.isEmpty {
                    footerTotalSection
                    clearTransactionsSection
                }

                bottomScrollAnchor
            }
            .listStyle(.insetGrouped)
            .coordinateSpace(name: "scroll")
            .background(
                Color.clear.preference(
                    key: ScrollContainerHeightPreferenceKey.self,
                    value: geometry.size.height
                )
            )
        }
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            withAnimation(.easeInOut(duration: 0.2)) {
                isScrolled = value < -50
            }
        }
        .onPreferenceChange(ScrollBottomPreferenceKey.self) { value in
            scrollBottomPosition = value
            refreshBottomState(bottom: value, containerHeight: scrollViewHeight)
        }
        .onPreferenceChange(ScrollContainerHeightPreferenceKey.self) { value in
            scrollViewHeight = value
            refreshBottomState(bottom: scrollBottomPosition, containerHeight: value)
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(isScrolled ? .inline : .large)
        .toolbar {
            if isScrolled {
                ToolbarItem(placement: .principal) {
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
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                scrollToggleButton(proxy: proxy)
                categoryFilter
                Button(action: { isSearchPresented = true }) {
                    Image(systemName: "magnifyingglass")
                }
                .controlSize(.small)
                addButton
            }
        }
        .searchable(
            text: searchBinding,
            isPresented: $isSearchPresented,
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

    private func scrollToggleButton(proxy: ScrollViewProxy) -> some View {
        Button(action: {
            withAnimation(.easeInOut) {
                if isAtBottom {
                    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                } else {
                    proxy.scrollTo(ScrollAnchor.bottom, anchor: .bottom)
                }
            }
        }) {
            Image(systemName: isAtBottom ? "arrow.up.to.line" : "arrow.down.to.line")
        }
        .accessibilityLabel(isAtBottom ? "Scroll to top" : "Scroll to bottom")
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
    }

    private var headerTotalSection: some View {
        Section {
            totalSummaryContent
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                    }
                )
        }
    }

    private var footerTotalSection: some View {
        Section {
            totalSummaryContent
        }
    }

    private var totalSummaryContent: some View {
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

    private var topScrollAnchor: some View {
        Color.clear
            .frame(height: 0)
            .listRowInsets(EdgeInsets())
            .id(ScrollAnchor.top)
    }

    private var bottomScrollAnchor: some View {
        Color.clear
            .frame(height: 0)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollBottomPreferenceKey.self,
                        value: geometry.frame(in: .named("scroll")).maxY
                    )
                }
            )
            .listRowInsets(EdgeInsets())
            .id(ScrollAnchor.bottom)
    }

    private func refreshBottomState(bottom: CGFloat, containerHeight: CGFloat) {
        guard containerHeight > 0 else {
            isAtBottom = false
            return
        }
        let tolerance: CGFloat = 16
        isAtBottom = bottom <= containerHeight + tolerance
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

private enum ScrollAnchor: String, Hashable {
    case top
    case bottom
}

struct ScrollBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollContainerHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
#endif


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

    private var trimmedDescription: String {
        desc.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedCategory: String {
        category.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedAmount: Double? {
        let trimmedAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmedAmount), value.isFinite else { return nil }
        return value
    }

    private var canSave: Bool {
        parsedAmount != nil && !trimmedDescription.isEmpty && !normalizedCategory.isEmpty
    }

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
                        guard let value = parsedAmount else { return }
                        let trimmedDesc = trimmedDescription
                        let categoryToSave = normalizedCategory
                        guard !trimmedDesc.isEmpty, !categoryToSave.isEmpty else { return }
                        let formattedDate = formattedDate(from: selectedDate)
                        onSave(formattedDate, trimmedDesc, value, categoryToSave, transaction?.id)
                        dismiss()
                    }
                    .disabled(!canSave)
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
            .onChange(of: desc) { refreshPrediction() }
            .onChange(of: amount) { refreshPrediction() }
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
