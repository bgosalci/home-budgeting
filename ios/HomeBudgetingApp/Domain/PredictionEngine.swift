import Foundation

actor PredictionEngine {
    private let repository: BudgetRepository

    init(repository: BudgetRepository) {
        self.repository = repository
    }

    func predictCategory(desc: String, categories: [String], amount: Double?) async -> String {
        let base = desc.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !base.isEmpty else { return "" }
        let state = await repository.currentState()
        let mapping = state.mapping
        if let amount, amount.isFinite {
            let key = amountKey(base: base, amount: amount)
            if let mapped = mapping.exact[key], categories.contains(mapped) {
                return mapped
            }
        }
        if let mapped = mapping.exact[base], categories.contains(mapped) {
            return mapped
        }
        var scores: [String: Int] = [:]
        tokens(of: base).forEach { token in
            guard let bag = mapping.tokens[token] else { return }
            bag.forEach { category, count in
                scores[category, default: 0] += count
            }
        }
        return scores.sorted { $0.value > $1.value }
            .first(where: { categories.contains($0.key) })?.key ?? ""
    }

    func learnCategory(desc: String, category: String?, amount: Double?) async {
        guard !desc.isEmpty, let category, !category.isEmpty else { return }
        let base = desc.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var state = await repository.currentState()
        var exact = state.mapping.exact
        var tokenMap = state.mapping.tokens
        if let amount, amount.isFinite {
            exact[amountKey(base: base, amount: amount)] = category
        } else {
            exact[base] = category
        }
        tokens(of: base).forEach { token in
            var bag = tokenMap[token] ?? [:]
            bag[category, default: 0] += 1
            tokenMap[token] = bag
        }
        let updatedMapping = PredictionMapping(exact: exact, tokens: tokenMap)
        _ = await repository.setMapping(updatedMapping)
        await updateDescriptionMap(desc: desc, category: category)
    }

    func learnDescription(_ desc: String) async {
        let normalized = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let state = await repository.currentState()
        if state.descList.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
            return
        }
        var list = state.descList
        list.append(normalized)
        _ = await repository.setDescriptionList(list)
    }

    func suggestDescriptions(_ partial: String, limit: Int = 4) async -> [String] {
        let norm = partial.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !norm.isEmpty else { return [] }
        let state = await repository.currentState()
        return state.descList.filter { $0.lowercased().hasPrefix(norm) }.prefix(limit).map { $0 }
    }

    func recordTransaction(_ tx: BudgetTransaction) async {
        if !tx.category.isEmpty {
            await learnCategory(desc: tx.desc, category: tx.category, amount: tx.amount)
        } else {
            await learnDescription(tx.desc)
        }
    }

    func pinMapping(desc: String, category: String) async {
        await learnCategory(desc: desc, category: category, amount: nil)
        await learnDescription(desc)
    }

    private func updateDescriptionMap(desc: String, category: String) async {
        let normalized = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        var state = await repository.currentState()
        var tokens = state.descMap.tokens
        var catBag = tokens[category] ?? [:]
        catBag[normalized, default: 0] += 1
        tokens[category] = catBag

        var exact = state.descMap.exact
        let key = normalized.lowercased()
        var freq = exact[key] ?? [:]
        freq[category, default: 0] += 1
        exact[key] = freq

        _ = await repository.setDescriptionMap(DescriptionMap(exact: exact, tokens: tokens))
        await learnDescription(desc)
    }

    private func tokens(of desc: String) -> [String] {
        desc.lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func amountKey(base: String, amount: Double) -> String {
        String(format: "%@|%.2f", base, amount)
    }
}
