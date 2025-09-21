import Foundation
import Combine

@MainActor
struct TransactionsUiState {
    var search: String = ""
    var category: String?
    var groups: [TransactionGroup] = []
    var total: Double = 0
    var availableCategories: [String] = []
}

@MainActor
struct BudgetUiState {
    var isLoading: Bool = true
    var monthKeys: [String] = []
    var selectedMonthKey: String?
    var totals: MonthTotals = .empty
    var incomes: [Income] = []
    var categories: [CategorySummary] = []
    var collapsedGroups: Set<String> = []
    var transactions: TransactionsUiState = TransactionsUiState()
    var notes: [BudgetNote] = []
    var descSuggestions: [String] = []
    var prediction: BalancePrediction?
    var analysis: AnalysisUiState = AnalysisUiState()
    var calendar: CalendarMonth = .empty
    var mapping: PredictionMapping = PredictionMapping()
    var descMap: DescriptionMap = DescriptionMap()
    var descList: [String] = []
}

@MainActor
final class BudgetViewModel: ObservableObject {
    @Published private(set) var uiState = BudgetUiState()

    private let repository: BudgetRepository
    private let predictionEngine: PredictionEngine
    private var baseState: BudgetState = .empty

    init(repository: BudgetRepository = BudgetRepository()) {
        self.repository = repository
        self.predictionEngine = PredictionEngine(repository: repository)
        Task {
            let state = await repository.currentState()
            await MainActor.run {
                self.applyState(state)
            }
        }
    }

    private func applyState(_ state: BudgetState) {
        baseState = state
        uiState = composeUiState(baseState: state, current: uiState)
    }

    private func composeUiState(baseState: BudgetState, current: BudgetUiState) -> BudgetUiState {
        let months = baseState.months.keys.sorted()
        let fallback = months.last ?? current.selectedMonthKey ?? currentMonthKey()
        let selected = current.selectedMonthKey
            .flatMap { baseState.months[$0] != nil ? $0 : nil }
            ?? fallback
        let month = baseState.months[selected]
        let totals = computeMonthTotals(month)
        let collapsed = baseState.ui.collapsed[selected]?.filter { $0.value }.map { $0.key } ?? []
        let categoryNames = month?.categories.keys.sorted { $0.lowercased() < $1.lowercased() } ?? []
        let filter = TransactionFilter(search: current.transactions.search, category: current.transactions.category)
        let (groups, total) = groupTransactions(month: month, filter: filter)
        let analysis = buildAnalysisState(baseState: baseState, selectedMonth: selected, current: current.analysis)
        let notes = baseState.notes.sorted { $0.time > $1.time }
        let calendar = buildCalendar(monthKey: selected, month: month)
        return BudgetUiState(
            isLoading: false,
            monthKeys: months,
            selectedMonthKey: selected,
            totals: totals,
            incomes: month?.incomes ?? [],
            categories: totals.categories,
            collapsedGroups: Set(collapsed),
            transactions: TransactionsUiState(
                search: current.transactions.search,
                category: current.transactions.category,
                groups: groups,
                total: total,
                availableCategories: categoryNames
            ),
            notes: notes,
            descSuggestions: current.descSuggestions,
            prediction: predictBalance(monthKey: selected, months: baseState.months),
            analysis: analysis,
            calendar: calendar,
            mapping: baseState.mapping,
            descMap: baseState.descMap,
            descList: baseState.descList
        )
    }

    private func buildAnalysisState(baseState: BudgetState, selectedMonth: String, current: AnalysisUiState) -> AnalysisUiState {
        let months = baseState.months.keys.sorted()
        let years = Array(Set(months.map { String($0.prefix(4)) })).sorted()
        let monthData = baseState.months[selectedMonth]
        let categoryMeta = monthData?.categories.mapValues { $0.group.isEmpty ? "Other" : $0.group } ?? [:]
        let groups = Array(Set(categoryMeta.values)).sorted { $0.lowercased() < $1.lowercased() }
        let incomeCategories = availableIncomeCategories(baseState)
        var options = current.options
        switch options.mode {
        case .budgetSpread:
            if options.chartStyle == .line { options.chartStyle = .bar }
            if let selected = options.selectedMonth, !months.contains(selected) {
                options.selectedMonth = selectedMonth
            } else if options.selectedMonth == nil {
                options.selectedMonth = selectedMonth
            }
            options.selectedYear = nil
            options.selectedGroup = nil
            options.selectedCategory = nil
        case .moneyIn:
            if options.chartStyle == .pie { options.chartStyle = .line }
            if let year = options.selectedYear, !year.isEmpty, !years.contains(year) {
                options.selectedYear = ""
            }
            if let category = options.selectedCategory, !category.isEmpty, !incomeCategories.contains(category) {
                options.selectedCategory = ""
            }
            options.selectedMonth = nil
            options.selectedGroup = nil
        case .monthlySpend:
            if options.chartStyle == .pie { options.chartStyle = .line }
            if let year = options.selectedYear, !year.isEmpty, !years.contains(year) {
                options.selectedYear = ""
            }
            if let group = options.selectedGroup, !group.isEmpty, !groups.contains(group) {
                options.selectedGroup = ""
            }
            let filteredCategories = categoryMeta
                .filter { options.selectedGroup?.isEmpty ?? true || $0.value == options.selectedGroup }
                .keys
                .sorted { $0.lowercased() < $1.lowercased() }
            if let category = options.selectedCategory, !category.isEmpty, !filteredCategories.contains(category) {
                options.selectedCategory = ""
            }
            options.selectedMonth = nil
        }
        let result: AnalysisResult?
        switch options.mode {
        case .budgetSpread:
            result = buildBudgetSpread(monthKey: options.selectedMonth, month: baseState.months[options.selectedMonth ?? ""])
        case .moneyIn:
            let year = options.selectedYear?.isEmpty == true ? nil : options.selectedYear
            let category = options.selectedCategory?.isEmpty == true ? nil : options.selectedCategory
            result = buildMoneyInSeries(state: baseState, selectedYear: year, category: category)
        case .monthlySpend:
            let year = options.selectedYear?.isEmpty == true ? nil : options.selectedYear
            let group = options.selectedGroup?.isEmpty == true ? nil : options.selectedGroup
            let category = options.selectedCategory?.isEmpty == true ? nil : options.selectedCategory
            result = buildMonthlySpendSeries(state: baseState, selectedYear: year, group: group, category: category, categoryMeta: categoryMeta)
        }
        let availableCategories: [String]
        switch options.mode {
        case .budgetSpread:
            availableCategories = categoryMeta.keys.sorted { $0.lowercased() < $1.lowercased() }
        case .moneyIn:
            availableCategories = incomeCategories
        case .monthlySpend:
            availableCategories = categoryMeta
                .filter { options.selectedGroup?.isEmpty ?? true || $0.value == options.selectedGroup }
                .keys
                .sorted { $0.lowercased() < $1.lowercased() }
        }
        let availableGroups = options.mode == .monthlySpend ? groups : []
        return AnalysisUiState(
            options: options,
            availableMonths: months,
            availableYears: years,
            availableGroups: availableGroups,
            availableCategories: availableCategories,
            result: result
        )
    }

    private func refreshDerivedState() {
        uiState = composeUiState(baseState: baseState, current: uiState)
    }

    func selectMonth(_ monthKey: String) {
        uiState.selectedMonthKey = monthKey
        refreshDerivedState()
    }

    func createMonth(_ monthKey: String) {
        guard let key = validateMonthKey(monthKey) else { return }
        Task {
            let state = await repository.createMonth(key)
            await MainActor.run { self.applyState(state) }
        }
    }

    func deleteNextMonth() {
        let months = uiState.monthKeys
        guard let selected = uiState.selectedMonthKey, let idx = months.firstIndex(of: selected), idx + 1 < months.count else {
            return
        }
        let nextKey = months[idx + 1]
        if let date = validateMonthKey(nextKey), date > currentMonthKey() {
            Task {
                let state = await repository.deleteMonth(nextKey)
                await MainActor.run { self.applyState(state) }
            }
        }
    }

    func addIncome(name: String, amount: Double) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let monthKey = uiState.selectedMonthKey else { return }
        let income = Income(id: UUID().uuidString, name: name, amount: amount)
        Task {
            let state = await repository.upsertMonth(monthKey) { month in
                var month = month
                month.incomes.append(income)
                return month
            }
            await MainActor.run { self.applyState(state) }
        }
    }

    func updateIncome(id: String, name: String, amount: Double) {
        guard let monthKey = uiState.selectedMonthKey else { return }
        Task {
            let state = await repository.upsertMonth(monthKey) { month in
                var month = month
                month.incomes = month.incomes.map { income in
                    if income.id == id {
                        return Income(id: income.id, name: name, amount: amount)
                    }
                    return income
                }
                return month
            }
            await MainActor.run { self.applyState(state) }
        }
    }

    func deleteIncome(id: String) {
        guard let monthKey = uiState.selectedMonthKey else { return }
        Task {
            let state = await repository.upsertMonth(monthKey) { month in
                var month = month
                month.incomes.removeAll { $0.id == id }
                return month
            }
            await MainActor.run { self.applyState(state) }
        }
    }

    func addOrUpdateCategory(name: String, group: String, budget: Double) {
        guard let monthKey = uiState.selectedMonthKey else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalizedGroup = group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Other" : group
        Task {
            let state = await repository.upsertMonth(monthKey) { month in
                var month = month
                month.categories[trimmed] = BudgetCategory(group: normalizedGroup, budget: budget)
                return month
            }
            await MainActor.run { self.applyState(state) }
        }
    }

    func deleteCategory(name: String) {
        guard let monthKey = uiState.selectedMonthKey else { return }
        Task {
            let state = await repository.upsertMonth(monthKey) { month in
                var month = month
                month.categories.removeValue(forKey: name)
                return month
            }
            await MainActor.run { self.applyState(state) }
        }
    }

    func toggleGroup(_ group: String) {
        guard let monthKey = uiState.selectedMonthKey else { return }
        let collapsed = uiState.collapsedGroups.contains(group)
        Task {
            let state = await repository.setCollapsed(monthKey: monthKey, group: group, collapsed: !collapsed)
            await MainActor.run { self.applyState(state) }
        }
    }

    func setAllGroupsCollapsed(_ collapsed: Bool) {
        guard let monthKey = uiState.selectedMonthKey else { return }
        let groups = Array(Set(uiState.categories.map { $0.group }))
        Task {
            let state = await repository.setAllCollapsed(monthKey: monthKey, groups: groups, collapsed: collapsed)
            await MainActor.run { self.applyState(state) }
        }
    }

    func addOrUpdateTransaction(date: String, desc: String, amount: Double, category: String?, editingId: String? = nil) {
        guard let monthKey = uiState.selectedMonthKey,
              !date.isEmpty,
              !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              amount.isFinite else { return }
        let tx = BudgetTransaction(
            id: editingId ?? UUID().uuidString,
            date: date,
            desc: desc,
            amount: amount,
            category: category ?? ""
        )
        Task {
            let state = await repository.upsertMonth(monthKey) { month in
                var month = month
                if let index = month.transactions.firstIndex(where: { $0.id == tx.id }) {
                    month.transactions[index] = tx
                } else {
                    month.transactions.append(tx)
                }
                return month
            }
            await predictionEngine.recordTransaction(tx)
            await MainActor.run { self.applyState(state) }
        }
    }

    func deleteTransaction(id: String) {
        guard let monthKey = uiState.selectedMonthKey else { return }
        Task {
            let state = await repository.upsertMonth(monthKey) { month in
                var month = month
                month.transactions.removeAll { $0.id == id }
                return month
            }
            await MainActor.run { self.applyState(state) }
        }
    }

    func deleteAllTransactions() {
        guard let monthKey = uiState.selectedMonthKey else { return }
        Task {
            let state = await repository.upsertMonth(monthKey) { month in
                var month = month
                month.transactions = []
                return month
            }
            await MainActor.run { self.applyState(state) }
        }
    }

    func updateTransactionSearch(_ value: String) {
        uiState.transactions.search = value
        refreshDerivedState()
    }

    func updateTransactionFilter(_ category: String?) {
        uiState.transactions.category = category
        refreshDerivedState()
    }

    func addNote(desc: String, body: String) {
        let trimmedDesc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDesc.isEmpty || !trimmedBody.isEmpty else { return }
        Task {
            var notes = baseState.notes
            let time = Date().timeIntervalSince1970 * 1000
            let note = BudgetNote(id: Int64(time), desc: trimmedDesc, data: trimmedBody, time: time)
            notes.append(note)
            let state = await repository.setNotes(notes)
            await MainActor.run { self.applyState(state) }
        }
    }

    func updateNote(id: Int64, desc: String, body: String) {
        Task {
            var notes = baseState.notes
            if let index = notes.firstIndex(where: { $0.id == id }) {
                let time = Date().timeIntervalSince1970 * 1000
                notes[index] = BudgetNote(id: id, desc: desc.trimmingCharacters(in: .whitespacesAndNewlines), data: body.trimmingCharacters(in: .whitespacesAndNewlines), time: time)
                let state = await repository.setNotes(notes)
                await MainActor.run { self.applyState(state) }
            }
        }
    }

    func deleteNote(id: Int64) {
        Task {
            let notes = baseState.notes.filter { $0.id != id }
            let state = await repository.setNotes(notes)
            await MainActor.run { self.applyState(state) }
        }
    }

    func updateAnalysisMode(_ mode: AnalysisMode) {
        uiState.analysis.options.mode = mode
        refreshDerivedState()
    }

    func updateAnalysisChartStyle(_ style: ChartStyle) {
        uiState.analysis.options.chartStyle = style
        refreshDerivedState()
    }

    func updateAnalysisMonth(_ monthKey: String) {
        uiState.analysis.options.selectedMonth = monthKey
        refreshDerivedState()
    }

    func updateAnalysisYear(_ year: String?) {
        uiState.analysis.options.selectedYear = year
        refreshDerivedState()
    }

    func updateAnalysisGroup(_ group: String?) {
        uiState.analysis.options.selectedGroup = group
        refreshDerivedState()
    }

    func updateAnalysisCategory(_ category: String?) {
        uiState.analysis.options.selectedCategory = category
        refreshDerivedState()
    }

    func updateDescriptionInput(_ input: String) {
        Task {
            let suggestions = await predictionEngine.suggestDescriptions(input)
            await MainActor.run { self.uiState.descSuggestions = suggestions }
        }
    }

    func clearSuggestions() {
        uiState.descSuggestions = []
    }

    func predictCategory(desc: String, amount: Double?) async -> String {
        let categories = uiState.categories.map { $0.name }
        return await predictionEngine.predictCategory(desc: desc, categories: categories, amount: amount)
    }

    func pinPrediction(desc: String, category: String) {
        Task { await predictionEngine.pinMapping(desc: desc, category: category) }
    }

    func exportAll() async -> String {
        await repository.exportAll()
    }

    func importJson(_ content: String) {
        guard let data = content.data(using: .utf8) else { return }
        Task {
            let decoder = JSONDecoder()
            if let state = try? decoder.decode(BudgetState.self, from: data) {
                let updated = await repository.importData(state)
                await MainActor.run { self.applyState(updated) }
            }
        }
    }

    private func validateMonthKey(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 7 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard formatter.date(from: trimmed) != nil else { return nil }
        return trimmed
    }

    private func currentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
}
