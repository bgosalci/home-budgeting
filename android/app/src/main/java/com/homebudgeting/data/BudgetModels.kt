package com.homebudgeting.data

import kotlinx.serialization.Serializable

@Serializable
data class BudgetState(
    val version: Int = 1,
    val months: Map<String, BudgetMonth> = emptyMap(),
    val mapping: PredictionMapping = PredictionMapping(),
    val descMap: DescriptionMap = DescriptionMap(),
    val ui: UiPreferences = UiPreferences(),
    val descList: List<String> = emptyList(),
    val notes: List<Note> = emptyList()
) {
    fun ensureIntegrity(): BudgetState {
        val fixedMonths = months.mapValues { (_, month) -> month.ensureIntegrity() }
        return copy(
            months = fixedMonths,
            mapping = mapping.ensureIntegrity(),
            descMap = descMap.ensureIntegrity(),
            ui = ui.ensureIntegrity(),
            descList = descList.distinctBy { it.lowercase() }
        )
    }

    companion object {
        val Empty = BudgetState()
    }
}

@Serializable
data class BudgetMonth(
    val incomes: List<Income> = emptyList(),
    val transactions: List<BudgetTransaction> = emptyList(),
    val categories: Map<String, BudgetCategory> = emptyMap()
) {
    fun ensureIntegrity(): BudgetMonth {
        return copy(
            incomes = incomes.map { it.ensureIntegrity() },
            transactions = transactions.map { it.ensureIntegrity() },
            categories = categories.mapValues { (_, value) -> value.ensureIntegrity() }
        )
    }
}

@Serializable
data class Income(
    val id: String,
    val name: String,
    val amount: Double
) {
    fun ensureIntegrity(): Income = copy(
        name = name.trim(),
        amount = amount.takeIf { it.isFinite() } ?: 0.0
    )
}

@Serializable
data class BudgetCategory(
    val group: String = "Other",
    val budget: Double = 0.0
) {
    fun ensureIntegrity(): BudgetCategory = copy(
        group = group.ifBlank { "Other" },
        budget = budget.takeIf { it.isFinite() } ?: 0.0
    )
}

@Serializable
data class BudgetTransaction(
    val id: String,
    val date: String,
    val desc: String,
    val amount: Double,
    val category: String
) {
    fun ensureIntegrity(): BudgetTransaction = copy(
        desc = desc.trim(),
        amount = amount.takeIf { it.isFinite() } ?: 0.0,
        category = category.trim()
    )
}

@Serializable
data class Note(
    val id: Long,
    val desc: String,
    val data: String,
    val time: Long
)

@Serializable
data class PredictionMapping(
    val exact: Map<String, String> = emptyMap(),
    val tokens: Map<String, Map<String, Int>> = emptyMap()
) {
    fun ensureIntegrity(): PredictionMapping = copy(
        exact = exact.filterValues { it.isNotBlank() },
        tokens = tokens.mapValues { (_, bag) -> bag.filterValues { it > 0 } }
    )
}

@Serializable
data class DescriptionMap(
    val exact: Map<String, Map<String, Int>> = emptyMap(),
    val tokens: Map<String, Map<String, Int>> = emptyMap()
) {
    fun ensureIntegrity(): DescriptionMap = copy(
        exact = exact.mapValues { (_, bag) -> bag.filterValues { it > 0 } },
        tokens = tokens.mapValues { (_, bag) -> bag.filterValues { it > 0 } }
    )
}

@Serializable
data class UiPreferences(
    val collapsed: Map<String, Map<String, Boolean>> = emptyMap()
) {
    fun ensureIntegrity(): UiPreferences = copy(
        collapsed = collapsed.mapValues { (_, groups) ->
            groups.filterValues { it }
        }
    )
}
