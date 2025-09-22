import Foundation

private struct Observation {
    let day: Int
    let monthLength: Int
}

private struct RemainderStats {
    let remainder: Double
    let sourceDay: Int?
    let sampleSize: Int
}

struct BalancePrediction {
    let predictedSpend: Double
    let predictedLeftover: Double
    let spentSoFar: Double
    let incomesTotal: Double
    let observationDay: Int
    let remainderUsedDay: Int?
    let sampleSize: Int
}

func predictBalance(monthKey: String?, months: [String: BudgetMonth], today: Date = Date()) -> BalancePrediction? {
    guard let monthKey, let month = months[monthKey] else { return nil }
    guard parseMonthKey(monthKey) != nil else { return nil }
    let observation = determineObservationDay(monthKey: monthKey, transactions: month.transactions, today: today)
    let cumulative = accumulateByDay(transactions: month.transactions, monthLength: observation.monthLength)
    let observedDay = min(observation.day, observation.monthLength)
    let spentSoFar = cumulative[observedDay]
    let incomesTotal = month.incomes.reduce(0) { $0 + $1.amount }
    let remainders = computeHistoryRemainders(months: months, excludeKey: monthKey)
    let remainderStats = pickRemainder(map: remainders, targetDay: observation.day)
    let predictedSpend = max(0, spentSoFar + remainderStats.remainder)
    let predictedLeftover = incomesTotal - predictedSpend
    return BalancePrediction(
        predictedSpend: predictedSpend,
        predictedLeftover: predictedLeftover,
        spentSoFar: spentSoFar,
        incomesTotal: incomesTotal,
        observationDay: observation.day,
        remainderUsedDay: remainderStats.sourceDay,
        sampleSize: remainderStats.sampleSize
    )
}

private func parseMonthKey(_ key: String) -> DateComponents? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.dateFormat = "yyyy-MM"
    guard let date = formatter.date(from: key) else { return nil }
    return Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
}

private func determineObservationDay(monthKey: String, transactions: [BudgetTransaction], today: Date) -> Observation {
    guard let components = parseMonthKey(monthKey), let year = components.year, let month = components.month else {
        return Observation(day: 0, monthLength: 31)
    }
    let calendar = Calendar(identifier: .gregorian)
    let date = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    let monthLength = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
    let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
    let currentKey = String(format: "%04d-%02d", todayComponents.year ?? year, todayComponents.month ?? month)
    let validDays = transactions.compactMap { tx -> Int? in
        guard let date = parseDate(tx.date) else { return nil }
        let day = calendar.component(.day, from: date)
        return (1...monthLength).contains(day) ? day : nil
    }
    if monthKey < currentKey {
        return Observation(day: monthLength, monthLength: monthLength)
    }
    if monthKey == currentKey {
        let todayDay = min(todayComponents.day ?? 1, monthLength)
        let observed = max(validDays.max() ?? 0, todayDay)
        return Observation(day: observed, monthLength: monthLength)
    }
    if let maxDay = validDays.max() {
        return Observation(day: maxDay, monthLength: monthLength)
    }
    return Observation(day: 0, monthLength: monthLength)
}

private func accumulateByDay(transactions: [BudgetTransaction], monthLength: Int) -> [Double] {
    let calendar = Calendar(identifier: .gregorian)
    var totals = Array(repeating: 0.0, count: monthLength + 1)
    transactions.forEach { tx in
        guard let date = parseDate(tx.date) else { return }
        let day = calendar.component(.day, from: date)
        guard day >= 1, day <= monthLength else { return }
        totals[day] += tx.amount
    }
    var cumulative = Array(repeating: 0.0, count: monthLength + 1)
    for day in 1...monthLength {
        cumulative[day] = cumulative[day - 1] + totals[day]
    }
    return cumulative
}

private func computeHistoryRemainders(months: [String: BudgetMonth], excludeKey: String) -> [Int: [Double]] {
    var map: [Int: [Double]] = [:]
    months.forEach { key, month in
        guard key != excludeKey, let components = parseMonthKey(key), let year = components.year, let monthValue = components.month else {
            return
        }
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: year, month: monthValue, day: 1))!
        let length = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        let cumulative = accumulateByDay(transactions: month.transactions, monthLength: length)
        let finalSpend = cumulative[length]
        for day in 0...length {
            let spent = cumulative[min(day, length)]
            let remainder = finalSpend - spent
            map[day, default: []].append(remainder)
        }
    }
    return map
}

private func pickRemainder(map: [Int: [Double]], targetDay: Int) -> RemainderStats {
    guard !map.isEmpty else { return RemainderStats(remainder: 0, sourceDay: nil, sampleSize: 0) }
    if let values = map[targetDay], !values.isEmpty {
        return RemainderStats(remainder: values.median(), sourceDay: targetDay, sampleSize: values.count)
    }
    for offset in 1...31 {
        let lower = targetDay - offset
        if lower >= 0, let list = map[lower], !list.isEmpty {
            return RemainderStats(remainder: list.median(), sourceDay: lower, sampleSize: list.count)
        }
        let higher = targetDay + offset
        if let list = map[higher], !list.isEmpty {
            return RemainderStats(remainder: list.median(), sourceDay: higher, sampleSize: list.count)
        }
    }
    if let (day, list) = map.max(by: { $0.key < $1.key }), !list.isEmpty {
        return RemainderStats(remainder: list.median(), sourceDay: day, sampleSize: list.count)
    }
    return RemainderStats(remainder: 0, sourceDay: nil, sampleSize: 0)
}

private extension Array where Element == Double {
    func median() -> Double {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let mid = count / 2
        if count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        } else {
            return sorted[mid]
        }
    }
}
