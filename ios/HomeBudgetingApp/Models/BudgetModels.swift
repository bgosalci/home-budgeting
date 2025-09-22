import Foundation

struct BudgetState: Codable {
    var version: Int = 1
    var months: [String: BudgetMonth] = [:]
    var mapping: PredictionMapping = PredictionMapping()
    var descMap: DescriptionMap = DescriptionMap()
    var ui: UiPreferences = UiPreferences()
    var descList: [String] = []
    var notes: [BudgetNote] = []

    private enum CodingKeys: String, CodingKey {
        case version
        case months
        case mapping
        case descMap
        case ui
        case descList
        case notes
    }

    init(
        version: Int = 1,
        months: [String: BudgetMonth] = [:],
        mapping: PredictionMapping = PredictionMapping(),
        descMap: DescriptionMap = DescriptionMap(),
        ui: UiPreferences = UiPreferences(),
        descList: [String] = [],
        notes: [BudgetNote] = []
    ) {
        self.version = version
        self.months = months
        self.mapping = mapping
        self.descMap = descMap
        self.ui = ui
        self.descList = descList
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        months = try container.decodeIfPresent([String: BudgetMonth].self, forKey: .months) ?? [:]
        mapping = try container.decodeIfPresent(PredictionMapping.self, forKey: .mapping) ?? PredictionMapping()
        descMap = try container.decodeIfPresent(DescriptionMap.self, forKey: .descMap) ?? DescriptionMap()
        ui = try container.decodeIfPresent(UiPreferences.self, forKey: .ui) ?? UiPreferences()
        descList = try container.decodeIfPresent([String].self, forKey: .descList) ?? []
        notes = try container.decodeIfPresent([BudgetNote].self, forKey: .notes) ?? []
    }

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

    private enum CodingKeys: String, CodingKey {
        case incomes
        case transactions
        case categories
    }

    init(
        incomes: [Income] = [],
        transactions: [BudgetTransaction] = [],
        categories: [String: BudgetCategory] = [:]
    ) {
        self.incomes = incomes
        self.transactions = transactions
        self.categories = categories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        incomes = try container.decodeIfPresent([Income].self, forKey: .incomes) ?? []
        transactions = try container.decodeIfPresent([BudgetTransaction].self, forKey: .transactions) ?? []
        categories = try container.decodeIfPresent([String: BudgetCategory].self, forKey: .categories) ?? [:]
    }

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

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case amount
    }

    init(id: String, name: String, amount: Double) {
        self.id = id
        self.name = name
        self.amount = amount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        amount = container.decodeLossyDouble(forKey: .amount) ?? 0
    }

    func ensured() -> Income {
        Income(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), amount: amount.isFinite ? amount : 0)
    }
}

struct BudgetCategory: Codable {
    var group: String = "Other"
    var budget: Double = 0

    private enum CodingKeys: String, CodingKey {
        case group
        case budget
    }

    init(group: String = "Other", budget: Double = 0) {
        self.group = group
        self.budget = budget
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        group = try container.decodeIfPresent(String.self, forKey: .group) ?? "Other"
        budget = container.decodeLossyDouble(forKey: .budget) ?? 0
    }

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

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case desc
        case amount
        case category
    }

    init(id: String, date: String, desc: String, amount: Double, category: String) {
        self.id = id
        self.date = date
        self.desc = desc
        self.amount = amount
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        desc = try container.decodeIfPresent(String.self, forKey: .desc) ?? ""
        amount = container.decodeLossyDouble(forKey: .amount) ?? 0
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
    }

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

    private enum CodingKeys: String, CodingKey {
        case id
        case desc
        case data
        case time
    }

    init(id: Int64, desc: String, data: String, time: TimeInterval) {
        self.id = id
        self.desc = desc
        self.data = data
        self.time = time
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(Int64.self, forKey: .id) {
            id = value
        } else if let stringValue = try? container.decode(String.self, forKey: .id), let parsed = Int64(stringValue) {
            id = parsed
        } else {
            id = Int64(Date().timeIntervalSince1970 * 1000)
        }
        desc = try container.decodeIfPresent(String.self, forKey: .desc) ?? ""
        data = try container.decodeIfPresent(String.self, forKey: .data) ?? ""
        time = container.decodeLossyDouble(forKey: .time) ?? Date().timeIntervalSince1970
    }
}

struct PredictionMapping: Codable {
    var exact: [String: String] = [:]
    var tokens: [String: [String: Int]] = [:]

    private enum CodingKeys: String, CodingKey {
        case exact
        case tokens
    }

    init(exact: [String: String] = [:], tokens: [String: [String: Int]] = [:]) {
        self.exact = exact
        self.tokens = tokens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exact = try container.decodeIfPresent([String: String].self, forKey: .exact) ?? [:]
        var decodedTokens = decodeCountBag(in: container, forKey: .tokens)
        if let fallback = try? container.decode([String: String].self, forKey: .tokens) {
            mergeCountBags(into: &decodedTokens, incoming: convertFlatStringMap(fallback))
        }
        tokens = decodedTokens
    }

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

    private enum CodingKeys: String, CodingKey {
        case exact
        case tokens
    }

    init(exact: [String: [String: Int]] = [:], tokens: [String: [String: Int]] = [:]) {
        self.exact = exact
        self.tokens = tokens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var decodedExact = decodeCountBag(in: container, forKey: .exact)
        if let fallback = try? container.decode([String: String].self, forKey: .exact) {
            mergeCountBags(into: &decodedExact, incoming: convertFlatStringMap(fallback))
        }
        var decodedTokens = decodeCountBag(in: container, forKey: .tokens)
        if let fallbackTokens = try? container.decode([String: String].self, forKey: .tokens) {
            mergeCountBags(into: &decodedTokens, incoming: convertFlatStringMap(fallbackTokens))
        }
        exact = decodedExact
        tokens = decodedTokens
    }

    func ensured() -> DescriptionMap {
        DescriptionMap(
            exact: exact.mapValues { $0.filter { $0.value > 0 } },
            tokens: tokens.mapValues { $0.filter { $0.value > 0 } }
        )
    }
}

private let fallbackTrimCharacters = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'"))

private func decodeCountBag<Key: CodingKey>(in container: KeyedDecodingContainer<Key>, forKey key: Key) -> [String: [String: Int]] {
    if let direct = try? container.decode([String: [String: Int]].self, forKey: key) {
        return direct
    }
    if let doubles = try? container.decode([String: [String: Double]].self, forKey: key) {
        return convertDoubleCountBag(doubles)
    }
    if let strings = try? container.decode([String: [String: String]].self, forKey: key) {
        return convertStringCountBag(strings)
    }
    return [:]
}

private func convertDoubleCountBag(_ raw: [String: [String: Double]]) -> [String: [String: Int]] {
    raw.reduce(into: [:]) { result, entry in
        let bag = entry.value.reduce(into: [String: Int]()) { inner, pair in
            if let count = sanitizedCount(from: pair.value) {
                inner[pair.key] = count
            }
        }
        if !bag.isEmpty {
            result[entry.key] = bag
        }
    }
}

private func convertStringCountBag(_ raw: [String: [String: String]]) -> [String: [String: Int]] {
    raw.reduce(into: [:]) { result, entry in
        let bag = entry.value.reduce(into: [String: Int]()) { inner, pair in
            if let count = parseCount(from: pair.value) {
                inner[pair.key] = count
            }
        }
        if !bag.isEmpty {
            result[entry.key] = bag
        }
    }
}

private func convertFlatStringMap(_ raw: [String: String]) -> [String: [String: Int]] {
    raw.reduce(into: [:]) { result, entry in
        let value = entry.value.trimmingCharacters(in: fallbackTrimCharacters)
        guard !value.isEmpty else { return }
        var bag = result[entry.key] ?? [:]
        bag[value, default: 0] += 1
        result[entry.key] = bag
    }
}

private func mergeCountBags(into base: inout [String: [String: Int]], incoming: [String: [String: Int]]) {
    guard !incoming.isEmpty else { return }
    incoming.forEach { key, bag in
        var existing = base[key] ?? [:]
        bag.forEach { entry, count in
            guard count > 0 else { return }
            existing[entry, default: 0] += count
        }
        if existing.isEmpty {
            base.removeValue(forKey: key)
        } else {
            base[key] = existing
        }
    }
}

private func sanitizedCount(from raw: Double) -> Int? {
    guard raw.isFinite else { return nil }
    let rounded = Int(raw.rounded())
    return rounded > 0 ? rounded : nil
}

private func parseCount(from raw: String) -> Int? {
    let trimmed = raw.trimmingCharacters(in: fallbackTrimCharacters)
    if let intValue = Int(trimmed), intValue > 0 {
        return intValue
    }
    if let doubleValue = Double(trimmed), doubleValue.isFinite {
        let rounded = Int(doubleValue.rounded())
        return rounded > 0 ? rounded : nil
    }
    return nil
}

struct UiPreferences: Codable {
    var collapsed: [String: [String: Bool]] = [:]

    private enum CodingKeys: String, CodingKey {
        case collapsed
    }

    init(collapsed: [String: [String: Bool]] = [:]) {
        self.collapsed = collapsed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        collapsed = try container.decodeIfPresent([String: [String: Bool]].self, forKey: .collapsed) ?? [:]
    }

    func ensured() -> UiPreferences {
        UiPreferences(
            collapsed: collapsed.mapValues { groups in
                groups.filter { $0.value }
            }
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyDouble(forKey key: Key) -> Double? {
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        if let stringValue = try? decode(String.self, forKey: key) {
            return Double(stringValue)
        }
        return nil
    }
}
