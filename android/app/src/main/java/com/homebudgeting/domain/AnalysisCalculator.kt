package com.homebudgeting.domain

import com.homebudgeting.data.BudgetMonth
import com.homebudgeting.data.BudgetState
import com.homebudgeting.data.BudgetTransaction
import java.time.YearMonth
import java.time.format.TextStyle
import java.util.Locale

private val monthLocale = Locale.UK

fun buildBudgetSpread(
    monthKey: String?,
    month: BudgetMonth?
): AnalysisResult.BudgetSpread? {
    if (monthKey == null || month == null) return null
    val totals = computeMonthTotals(month)
    val labels = totals.groups.map { it.name }
    if (labels.isEmpty()) return null
    val planned = totals.groups.map { it.budget }
    val actual = totals.groups.map { it.actual }
    val plannedTotal = planned.sum()
    val actualTotal = actual.sum()
    val plannedPercent = planned.map { value -> if (plannedTotal == 0.0) 0.0 else (value / plannedTotal) * 100.0 }
    val actualPercent = actual.map { value -> if (actualTotal == 0.0) 0.0 else (value / actualTotal) * 100.0 }
    return AnalysisResult.BudgetSpread(labels, planned, actual, plannedPercent, actualPercent, plannedTotal, actualTotal)
}

fun buildMoneyInSeries(
    state: BudgetState,
    selectedYear: String?,
    category: String?
): AnalysisResult.Series? {
    val months = state.months.keys.sorted().filter { key ->
        selectedYear.isNullOrBlank() || key.startsWith(selectedYear)
    }
    if (months.isEmpty()) return null
    val labels = months.map { formatMonthLabel(it) }
    val values = months.map { key ->
        val month = state.months[key]
        month?.incomes?.filter { category.isNullOrBlank() || it.name == category }?.sumOf { it.amount } ?: 0.0
    }
    val label = if (category.isNullOrBlank()) "Total Income" else "$category Income"
    val total = values.sum()
    return AnalysisResult.Series(labels, values, label, total)
}

fun buildMonthlySpendSeries(
    state: BudgetState,
    selectedYear: String?,
    group: String?,
    category: String?,
    categoryMeta: Map<String, String>
): AnalysisResult.Series? {
    val months = state.months.keys.sorted().filter { key ->
        selectedYear.isNullOrBlank() || key.startsWith(selectedYear)
    }
    if (months.isEmpty()) return null
    val labels = months.map { formatMonthLabel(it) }
    val values = months.map { key ->
        val month = state.months[key]
        if (month == null) 0.0 else sumTransactions(month.transactions, group, category, categoryMeta)
    }
    val label = when {
        !category.isNullOrBlank() -> "$category Spend"
        !group.isNullOrBlank() -> "$group Spend"
        else -> "Total Spend"
    }
    val total = values.sum()
    return AnalysisResult.Series(labels, values, label, total)
}

private fun sumTransactions(
    transactions: List<BudgetTransaction>,
    group: String?,
    category: String?,
    categoryMeta: Map<String, String>
): Double {
    return transactions.filter { tx ->
        when {
            !category.isNullOrBlank() -> tx.category == category
            !group.isNullOrBlank() -> categoryMeta[tx.category] == group
            else -> true
        }
    }.sumOf { it.amount }
}

fun availableIncomeCategories(state: BudgetState): List<String> {
    val set = linkedSetOf<String>()
    state.months.values.forEach { month ->
        month.incomes.forEach { set += it.name }
    }
    return set.filter { it.isNotBlank() }.sortedBy { it.lowercase(Locale.UK) }
}

fun formatMonthLabel(key: String): String {
    return runCatching {
        val ym = YearMonth.parse(key)
        val month = ym.month.getDisplayName(TextStyle.SHORT, monthLocale)
        "$month ${ym.year}"
    }.getOrElse { key }
}
