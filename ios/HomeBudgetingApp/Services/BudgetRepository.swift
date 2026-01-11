import Foundation

actor BudgetRepository {
    private let storage: BudgetStorage
    private var state: BudgetState
    private var hasLoadedState = false

    init(storage: BudgetStorage = .shared) {
        self.storage = storage
        self.state = BudgetState.empty
    }

    func currentState() -> BudgetState {
        ensureLoadedState()
        return state
    }

    @discardableResult
    func refresh() -> BudgetState {
        let loaded = storage.load().ensured()
        state = loaded
        hasLoadedState = true
        return state
    }

    @discardableResult
    func createMonth(_ monthKey: String) -> BudgetState {
        updateState { state in
            guard state.months[monthKey] == nil else { return }
            let lastKey = state.months.keys.sorted().last
            var newMonth = BudgetMonth()
            if let lastKey, let lastMonth = state.months[lastKey] {
                newMonth.categories = lastMonth.categories
            }
            state.months[monthKey] = newMonth
        }
    }

    @discardableResult
    func deleteMonth(_ monthKey: String) -> BudgetState {
        updateState { state in
            state.months.removeValue(forKey: monthKey)
            state.ui.collapsed.removeValue(forKey: monthKey)
            state.ui.incomeCollapsed.removeValue(forKey: monthKey)
        }
    }

    @discardableResult
    func upsertMonth(_ monthKey: String, transform: (BudgetMonth) -> BudgetMonth) -> BudgetState {
        updateState { state in
            let month = state.months[monthKey] ?? BudgetMonth()
            state.months[monthKey] = transform(month).ensured()
        }
    }

    @discardableResult
    func setMapping(_ mapping: PredictionMapping) -> BudgetState {
        updateState { state in
            state.mapping = mapping.ensured()
        }
    }

    @discardableResult
    func setDescriptionMap(_ map: DescriptionMap) -> BudgetState {
        updateState { state in
            state.descMap = map.ensured()
        }
    }

    @discardableResult
    func setDescriptionList(_ list: [String]) -> BudgetState {
        updateState { state in
            var deduped: [String] = []
            list.forEach { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                if !deduped.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                    deduped.append(trimmed)
                }
            }
            state.descList = deduped
        }
    }

    @discardableResult
    func setNotes(_ notes: [BudgetNote]) -> BudgetState {
        updateState { state in
            state.notes = notes.sorted { $0.time > $1.time }
        }
    }

    @discardableResult
    func setCollapsed(monthKey: String, group: String, collapsed: Bool) -> BudgetState {
        updateState { state in
            var monthMap = state.ui.collapsed[monthKey] ?? [:]
            if collapsed {
                monthMap[group] = true
            } else {
                monthMap.removeValue(forKey: group)
            }
            if monthMap.isEmpty {
                state.ui.collapsed.removeValue(forKey: monthKey)
            } else {
                state.ui.collapsed[monthKey] = monthMap
            }
        }
    }

    @discardableResult
    func setIncomeCollapsed(monthKey: String, collapsed: Bool) -> BudgetState {
        updateState { state in
            if collapsed {
                state.ui.incomeCollapsed[monthKey] = true
            } else {
                state.ui.incomeCollapsed.removeValue(forKey: monthKey)
            }
        }
    }

    @discardableResult
    func importData(_ incoming: BudgetState) -> BudgetState {
        updateState { state in
            let sanitized = incoming.ensured()
            state.version = max(state.version, sanitized.version)
            sanitized.months.forEach { key, month in
                state.months[key] = month
            }
            state.mapping = mergePredictionMapping(base: state.mapping, incoming: sanitized.mapping)
            state.descMap = mergeDescriptionMap(base: state.descMap, incoming: sanitized.descMap)
            let mergedDesc = state.descList + sanitized.descList
            var deduped: [String] = []
            mergedDesc.forEach { value in
                if !deduped.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                    deduped.append(value)
                }
            }
            state.descList = deduped
            let mergedNotes = (state.notes + sanitized.notes)
                .reduce(into: [Int64: BudgetNote]()) { acc, note in
                    let existing = acc[note.id]
                    if let existing, existing.time >= note.time {
                        acc[note.id] = existing
                    } else {
                        acc[note.id] = note
                    }
                }
            state.notes = mergedNotes.values.sorted { $0.time > $1.time }
        }
    }

    func exportAll() -> String {
        storage.exportAll()
    }

    private func updateState(_ block: (inout BudgetState) -> Void) -> BudgetState {
        ensureLoadedState()
        var copy = state
        block(&copy)
        copy = copy.ensured()
        let sortedMonths = copy.months.sorted { $0.key < $1.key }
        copy.months = Dictionary(uniqueKeysWithValues: sortedMonths)
        state = copy
        storage.save(copy)
        return state
    }

    private func ensureLoadedState() {
        guard !hasLoadedState else { return }
        state = storage.load().ensured()
        hasLoadedState = true
    }

    private func mergePredictionMapping(base: PredictionMapping, incoming: PredictionMapping) -> PredictionMapping {
        var exact = base.exact
        incoming.exact.forEach { exact[$0.key] = $0.value }
        let tokens = mergeBags(base: base.tokens, incoming: incoming.tokens)
        return PredictionMapping(exact: exact, tokens: tokens)
    }

    private func mergeDescriptionMap(base: DescriptionMap, incoming: DescriptionMap) -> DescriptionMap {
        let exact = mergeBags(base: base.exact, incoming: incoming.exact)
        let tokens = mergeBags(base: base.tokens, incoming: incoming.tokens)
        return DescriptionMap(exact: exact, tokens: tokens)
    }

    private func mergeBags(base: [String: [String: Int]], incoming: [String: [String: Int]]) -> [String: [String: Int]] {
        var result = base
        incoming.forEach { key, bag in
            var merged = result[key] ?? [:]
            bag.forEach { entry, count in
                merged[entry] = (merged[entry] ?? 0) + count
            }
            result[key] = merged
        }
        return result
    }
}
