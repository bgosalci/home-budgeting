import Foundation

func buildBudgetSpread(monthKey: String?, month: BudgetMonth?, level: BudgetSpreadLevel = .group) -> AnalysisResult? {
    guard let month else { return nil }
    let totals = computeMonthTotals(month)
    guard !totals.groups.isEmpty else { return nil }
    let items: [(name: String, budget: Double, actual: Double)] = level == .group
        ? totals.groups.map { ($0.name, $0.budget, $0.actual) }
        : totals.categories.map { ($0.name, $0.budget, $0.actual) }
    let labels = items.map { $0.name }
    let planned = items.map { $0.budget }
    let actual = items.map { $0.actual }
    let plannedTotal = planned.reduce(0, +)
    let actualTotal = actual.reduce(0, +)
    let plannedPercent = planned.map { plannedTotal == 0 ? 0 : ($0 / plannedTotal) * 100 }
    let actualPercent = actual.map { actualTotal == 0 ? 0 : ($0 / actualTotal) * 100 }
    let data = BudgetSpreadData(
        labels: labels,
        planned: planned,
        actual: actual,
        plannedPercent: plannedPercent,
        actualPercent: actualPercent,
        plannedTotal: plannedTotal,
        actualTotal: actualTotal,
        totalIncome: totals.totalIncome,
        leftoverBudget: totals.leftoverBudget,
        leftoverActual: totals.leftoverActual
    )
    return .budgetSpread(data)
}

func buildMoneyInSeries(state: BudgetState, selectedYear: String?, category: String?) -> AnalysisResult? {
    let months = state.months.keys.sorted().filter { key in
        guard let selectedYear, !selectedYear.isEmpty else { return true }
        return key.hasPrefix(selectedYear)
    }
    guard !months.isEmpty else { return nil }
    let labels = months.map(formatMonthLabel)
    let values = months.map { key -> Double in
        guard let month = state.months[key] else { return 0 }
        return month.incomes
            .filter { category?.isEmpty ?? true || $0.name == category }
            .reduce(0) { $0 + $1.amount }
    }
    let label = (category?.isEmpty ?? true) ? "Total Income" : "\(category!) Income"
    let total = values.reduce(0, +)
    return .series(SeriesData(labels: labels, values: values, label: label, total: total))
}

func buildMonthlySpendSeries(
    state: BudgetState,
    selectedYear: String?,
    group: String?,
    category: String?,
    categoryMeta: [String: String]
) -> AnalysisResult? {
    let months = state.months.keys.sorted().filter { key in
        guard let selectedYear, !selectedYear.isEmpty else { return true }
        return key.hasPrefix(selectedYear)
    }
    guard !months.isEmpty else { return nil }
    let labels = months.map(formatMonthLabel)
    let values = months.map { key -> Double in
        guard let month = state.months[key] else { return 0 }
        return sumTransactions(transactions: month.transactions, group: group, category: category, categoryMeta: categoryMeta)
    }
    let label: String
    if let category, !category.isEmpty {
        label = "\(category) Spend"
    } else if let group, !group.isEmpty {
        label = "\(group) Spend"
    } else {
        label = "Total Spend"
    }
    let total = values.reduce(0, +)
    return .series(SeriesData(labels: labels, values: values, label: label, total: total))
}

private func sumTransactions(
    transactions: [BudgetTransaction],
    group: String?,
    category: String?,
    categoryMeta: [String: String]
) -> Double {
    transactions.filter { tx in
        if let category, !category.isEmpty {
            return tx.category == category
        }
        if let group, !group.isEmpty {
            return categoryMeta[tx.category] == group
        }
        return true
    }.reduce(0) { $0 + $1.amount }
}

func buildNetCashFlowSeries(state: BudgetState, selectedYear: String?) -> AnalysisResult? {
    let months = state.months.keys.sorted().filter { key in
        guard let selectedYear, !selectedYear.isEmpty else { return true }
        return key.hasPrefix(selectedYear)
    }
    guard !months.isEmpty else { return nil }
    let labels = months.map(formatMonthLabel)
    var incomeArr = [Double]()
    var spendArr = [Double]()
    var netArr = [Double]()
    for key in months {
        guard let month = state.months[key] else {
            incomeArr.append(0); spendArr.append(0); netArr.append(0)
            continue
        }
        let income = month.incomes.reduce(0) { $0 + $1.amount }
        let spend = month.transactions.reduce(0) { $0 + $1.amount }
        incomeArr.append(income)
        spendArr.append(spend)
        netArr.append(income - spend)
    }
    let totalIncome = incomeArr.reduce(0, +)
    let totalNet = netArr.reduce(0, +)
    let averageNet = months.isEmpty ? 0 : totalNet / Double(months.count)
    let savingsRate = totalIncome == 0 ? 0 : (totalNet / totalIncome) * 100
    return .netCashFlow(NetCashFlowData(
        labels: labels,
        income: incomeArr,
        spend: spendArr,
        net: netArr,
        totalNet: totalNet,
        averageNet: averageNet,
        savingsRate: savingsRate
    ))
}

func buildSavingsRateSeries(state: BudgetState, selectedYear: String?) -> AnalysisResult? {
    let months = state.months.keys.sorted().filter { key in
        guard let selectedYear, !selectedYear.isEmpty else { return true }
        return key.hasPrefix(selectedYear)
    }
    guard !months.isEmpty else { return nil }
    let labels = months.map(formatMonthLabel)
    let values = months.map { key -> Double in
        guard let month = state.months[key] else { return 0 }
        let income = month.incomes.reduce(0) { $0 + $1.amount }
        let spend = month.transactions.reduce(0) { $0 + $1.amount }
        guard income > 0 else { return 0 }
        return ((income - spend) / income) * 100
    }
    let total = values.reduce(0, +)
    return .series(SeriesData(labels: labels, values: values, label: "Savings Rate", total: total, isPercentage: true))
}

func availableIncomeCategories(_ state: BudgetState) -> [String] {
    var ordered = [String]()
    state.months.values.forEach { month in
        month.incomes.forEach { income in
            let value = income.name
            guard !value.isEmpty else { return }
            if !ordered.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                ordered.append(value)
            }
        }
    }
    return ordered.sorted { $0.lowercased() < $1.lowercased() }
}

func formatMonthLabel(_ key: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.dateFormat = "yyyy-MM"
    if let date = formatter.date(from: key) {
        let output = DateFormatter()
        output.locale = formatter.locale
        output.dateFormat = "MMM yyyy"
        return output.string(from: date)
    }
    return key
}
