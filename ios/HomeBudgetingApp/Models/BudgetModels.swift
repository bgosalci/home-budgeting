import Foundation

struct BudgetState: Codable {
    var version: Int = 1
    var months: [String: BudgetMonth] = [:]
    var mapping: PredictionMapping = PredictionMapping()
    var descMap: DescriptionMap = DescriptionMap()
    var ui: UiPreferences = UiPreferences()
    var descList: [String] = []
    var notes: [BudgetNote] = []

    static let empty = BudgetState()

    func ensured() -> BudgetState {
        var sanitizedMonths: [String: BudgetMonth] = [:]
        for (key, month) in months {
            sanitizedMonths[key] = month.ensured()
        }
        let dedupedDesc = descList.reduce(into: [String]()) { result, item in
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if !result.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                result.append(trimmed)
            }
        }
        let sanitizedNotes = notes.sorted { $0.time > $1.time }
        return BudgetState(
            version: version,
            months: sanitizedMonths,
            mapping: mapping.ensured(),
            descMap: descMap.ensured(),
            ui: ui.ensured(),
            descList: dedupedDesc,
            notes: sanitizedNotes
        )
    }
}

struct BudgetMonth: Codable {
    var incomes: [Income] = []
    var transactions: [BudgetTransaction] = []
    var categories: [String: BudgetCategory] = [:]

    func ensured() -> BudgetMonth {
        BudgetMonth(
            incomes: incomes.map { $0.ensured() },
            transactions: transactions.map { $0.ensured() },
            categories: categories.mapValues { $0.ensured() }
        )
    }
}

struct Income: Identifiable, Codable {
    var id: String
    var name: String
    var amount: Double

    func ensured() -> Income {
        Income(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), amount: amount.isFinite ? amount : 0)
    }
}

struct BudgetCategory: Codable {
    var group: String = "Other"
    var budget: Double = 0

    func ensured() -> BudgetCategory {
        BudgetCategory(group: group.isEmpty ? "Other" : group, budget: budget.isFinite ? budget : 0)
    }
}

struct BudgetTransaction: Identifiable, Codable {
    var id: String
    var date: String
    var desc: String
    var amount: Double
    var category: String

    func ensured() -> BudgetTransaction {
        BudgetTransaction(
            id: id,
            date: date,
            desc: desc.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount.isFinite ? amount : 0,
            category: category.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

struct BudgetNote: Identifiable, Codable {
    var id: Int64
    var desc: String
    var data: String
    var time: TimeInterval
}

struct PredictionMapping: Codable {
    var exact: [String: String] = [:]
    var tokens: [String: [String: Int]] = [:]

    func ensured() -> PredictionMapping {
        let sanitizedExact = exact.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let sanitizedTokens = tokens.mapValues { bag in
            bag.filter { $0.value > 0 }
        }
        return PredictionMapping(exact: sanitizedExact, tokens: sanitizedTokens)
    }
}

struct DescriptionMap: Codable {
    var exact: [String: [String: Int]] = [:]
    var tokens: [String: [String: Int]] = [:]

    func ensured() -> DescriptionMap {
        DescriptionMap(
            exact: exact.mapValues { $0.filter { $0.value > 0 } },
            tokens: tokens.mapValues { $0.filter { $0.value > 0 } }
        )
    }
}

struct UiPreferences: Codable {
    var collapsed: [String: [String: Bool]] = [:]

    func ensured() -> UiPreferences {
        UiPreferences(
            collapsed: collapsed.mapValues { groups in
                groups.filter { $0.value }
            }
        )
    }
}
