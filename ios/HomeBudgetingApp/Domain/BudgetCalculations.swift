import Foundation

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_GB")
    calendar.firstWeekday = 2 // Monday
    return calendar
}()

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_GB")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private let headerFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_GB")
    formatter.dateFormat = "EEE d MMM"
    return formatter
}()

func parseDate(_ value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    return dateFormatter.date(from: value)
}

struct CategorySummary: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let group: String
    let budget: Double
    let actual: Double
    var difference: Double { budget - actual }
}

struct GroupSummary: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let budget: Double
    let actual: Double
    var difference: Double { budget - actual }
}

struct MonthTotals {
    let totalIncome: Double
    let budgetTotal: Double
    let actualTotal: Double
    let leftoverActual: Double
    let leftoverBudget: Double
    let categories: [CategorySummary]
    let groups: [GroupSummary]

    static let empty = MonthTotals(
        totalIncome: 0,
        budgetTotal: 0,
        actualTotal: 0,
        leftoverActual: 0,
        leftoverBudget: 0,
        categories: [],
        groups: []
    )
}

func computeMonthTotals(_ month: BudgetMonth?) -> MonthTotals {
    guard let month else { return .empty }
    let totalIncome = month.incomes.reduce(into: 0.0) { $0 += $1.amount }
    var actuals: [String: Double] = [:]
    month.transactions.forEach { tx in
        actuals[tx.category, default: 0] += tx.amount
    }
    let categories = month.categories
        .map { name, meta -> CategorySummary in
            let group = meta.group.isEmpty ? "Other" : meta.group
            let actual = actuals[name] ?? 0
            return CategorySummary(name: name, group: group, budget: meta.budget, actual: actual)
        }
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
    let groups = Dictionary(grouping: categories, by: { $0.group })
        .map { group, list -> GroupSummary in
            let budget = list.reduce(into: 0.0) { $0 += $1.budget }
            let actual = list.reduce(into: 0.0) { $0 += $1.actual }
            return GroupSummary(name: group, budget: budget, actual: actual)
        }
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
    let budgetTotal = categories.reduce(into: 0.0) { $0 += $1.budget }
    let actualTotal = categories.reduce(into: 0.0) { $0 += $1.actual }
    let leftoverActual = totalIncome - actualTotal
    let leftoverBudget = totalIncome - budgetTotal
    return MonthTotals(
        totalIncome: totalIncome,
        budgetTotal: budgetTotal,
        actualTotal: actualTotal,
        leftoverActual: leftoverActual,
        leftoverBudget: leftoverBudget,
        categories: categories,
        groups: groups
    )
}

struct TransactionGroup: Identifiable {
    var id: Date { date }
    let date: Date
    let label: String
    let transactions: [BudgetTransaction]
    let transactionCount: Int
    let dayTotal: Double
    let runningTotal: Double
    let startIndex: Int
}

struct TransactionFilter {
    var search: String = ""
    var category: String?
}

func groupTransactions(month: BudgetMonth?, filter: TransactionFilter) -> ([TransactionGroup], Double) {
    guard let month else { return ([], 0) }
    let searchLower = filter.search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let categoryFilter = filter.category?.trimmingCharacters(in: .whitespacesAndNewlines)
    let filtered = month.transactions
        .filter { tx in
            let matchesSearch = searchLower.isEmpty || tx.desc.lowercased().contains(searchLower)
            let matchesCategory = (categoryFilter?.isEmpty ?? true) || tx.category == categoryFilter
            return matchesSearch && matchesCategory
        }
        .sorted { $0.date < $1.date }

    var grouped: [Date: [BudgetTransaction]] = [:]
    filtered.forEach { tx in
        guard let date = parseDate(tx.date) else { return }
        grouped[date, default: []].append(tx)
    }
    let sortedDates = grouped.keys.sorted()
    var runningTotal = 0.0
    var runningIndex = 1
    var result: [TransactionGroup] = []
    sortedDates.forEach { date in
        let list = grouped[date] ?? []
        let dayTotal = list.reduce(into: 0.0) { $0 += $1.amount }
        runningTotal += dayTotal
        let label = headerFormatter.string(from: date)
        result.append(
            TransactionGroup(
                date: date,
                label: label,
                transactions: list,
                transactionCount: list.count,
                dayTotal: dayTotal,
                runningTotal: runningTotal,
                startIndex: runningIndex
            )
        )
        runningIndex += list.count
    }
    let total = filtered.reduce(into: 0.0) { $0 += $1.amount }
    return (result, total)
}

struct CalendarDay: Identifiable {
    var id: UUID = UUID()
    let dayOfMonth: Int?
    let total: Double?
    let isToday: Bool
}

struct CalendarMonth {
    let title: String
    let weeks: [[CalendarDay]]

    static let empty = CalendarMonth(title: "", weeks: [])
}

func buildCalendar(monthKey: String?, month: BudgetMonth?, today: Date = Date()) -> CalendarMonth {
    guard let monthKey, !monthKey.isEmpty else { return .empty }
    guard let startDate = dateFormatter.date(from: monthKey + "-01") else {
        return CalendarMonth(title: monthKey, weeks: [])
    }
    let components = calendar.dateComponents([.year, .month], from: startDate)
    guard let year = components.year, let monthValue = components.month else {
        return CalendarMonth(title: monthKey, weeks: [])
    }
    var totalsByDay: [Int: Double] = [:]
    month?.transactions.forEach { tx in
        guard let day = Int(tx.date.suffix(2)), day > 0 else { return }
        let amount = abs(tx.amount)
        totalsByDay[day, default: 0] += amount
    }
    let firstDay = calendar.date(from: DateComponents(year: year, month: monthValue, day: 1))!
    let daysInMonth = calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 30
    let startOffset = (calendar.component(.weekday, from: firstDay) + 5) % 7
    var weeks: [[CalendarDay]] = []
    var day = 1
    let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
    let isCurrentMonth = todayComponents.year == year && todayComponents.month == monthValue

    while day <= daysInMonth {
        var week: [CalendarDay] = []
        for slot in 0..<7 {
            if weeks.isEmpty && slot < startOffset {
                week.append(CalendarDay(dayOfMonth: nil, total: nil, isToday: false))
            } else if day <= daysInMonth {
                let todayMatch = isCurrentMonth && todayComponents.day == day
                week.append(CalendarDay(dayOfMonth: day, total: totalsByDay[day], isToday: todayMatch))
                day += 1
            } else {
                week.append(CalendarDay(dayOfMonth: nil, total: nil, isToday: false))
            }
        }
        weeks.append(week)
    }
    let monthName = calendar.monthSymbols[monthValue - 1]
    let title = "\(monthName) \(year)"
    return CalendarMonth(title: title, weeks: weeks)
}
