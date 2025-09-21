package com.homebudgeting.domain

import com.homebudgeting.data.BudgetMonth
import com.homebudgeting.data.BudgetTransaction
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs

private val dateFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd", Locale.UK)
private val headerFormatter = DateTimeFormatter.ofPattern("EEE d MMM", Locale.UK)

fun parseDate(value: String?): LocalDate? = runCatching {
    if (value.isNullOrBlank()) return@runCatching null
    LocalDate.parse(value, dateFormatter)
}.getOrNull()

data class CategorySummary(
    val name: String,
    val group: String,
    val budget: Double,
    val actual: Double
) {
    val difference: Double get() = budget - actual
}

data class GroupSummary(
    val name: String,
    val budget: Double,
    val actual: Double
) {
    val difference: Double get() = budget - actual
}

data class MonthTotals(
    val totalIncome: Double,
    val budgetTotal: Double,
    val actualTotal: Double,
    val leftoverActual: Double,
    val leftoverBudget: Double,
    val categories: List<CategorySummary>,
    val groups: List<GroupSummary>
)

fun computeMonthTotals(month: BudgetMonth?): MonthTotals {
    if (month == null) {
        return MonthTotals(0.0, 0.0, 0.0, 0.0, 0.0, emptyList(), emptyList())
    }
    val totalIncome = month.incomes.sumOf { it.amount }
    val categories = month.categories
    val actualPerCategory = mutableMapOf<String, Double>()
    month.transactions.forEach { tx ->
        val key = tx.category
        actualPerCategory[key] = (actualPerCategory[key] ?: 0.0) + tx.amount
    }
    val categorySummaries = categories.entries
        .sortedBy { it.key.lowercase(Locale.UK) }
        .map { (name, meta) ->
            val group = meta.group.ifBlank { "Other" }
            val actual = actualPerCategory[name] ?: 0.0
            CategorySummary(name = name, group = group, budget = meta.budget, actual = actual)
        }
    val groups = categorySummaries
        .groupBy { it.group }
        .map { (groupName, list) ->
            val budget = list.sumOf { it.budget }
            val actual = list.sumOf { it.actual }
            GroupSummary(groupName, budget, actual)
        }
        .sortedBy { it.name.lowercase(Locale.UK) }

    val budgetTotal = categorySummaries.sumOf { it.budget }
    val actualTotal = categorySummaries.sumOf { it.actual }
    val leftoverActual = totalIncome - actualTotal
    val leftoverBudget = totalIncome - budgetTotal

    return MonthTotals(
        totalIncome = totalIncome,
        budgetTotal = budgetTotal,
        actualTotal = actualTotal,
        leftoverActual = leftoverActual,
        leftoverBudget = leftoverBudget,
        categories = categorySummaries,
        groups = groups
    )
}

data class TransactionGroup(
    val date: LocalDate,
    val label: String,
    val transactions: List<BudgetTransaction>,
    val dayTotal: Double,
    val runningTotal: Double,
    val startIndex: Int
)

data class TransactionFilter(
    val search: String = "",
    val category: String? = null
)

fun groupTransactions(
    month: BudgetMonth?,
    filter: TransactionFilter = TransactionFilter()
): Pair<List<TransactionGroup>, Double> {
    if (month == null) return emptyList<TransactionGroup>() to 0.0
    val searchLower = filter.search.trim().lowercase(Locale.UK)
    val categoryFilter = filter.category?.takeIf { it.isNotBlank() }
    val filtered = month.transactions
        .filter { tx ->
            val matchesSearch = searchLower.isBlank() || tx.desc.lowercase(Locale.UK).contains(searchLower)
            val matchesCategory = categoryFilter.isNullOrBlank() || tx.category == categoryFilter
            matchesSearch && matchesCategory
        }
        .sortedBy { it.date }
    val grouped = sortedMapOf<LocalDate, MutableList<BudgetTransaction>>()
    filtered.forEach { tx ->
        val date = parseDate(tx.date) ?: return@forEach
        val list = grouped.getOrPut(date) { mutableListOf() }
        list += tx
    }
    val groups = mutableListOf<TransactionGroup>()
    var runningTotal = 0.0
    var runningIndex = 1
    grouped.forEach { (date, list) ->
        val dayTotal = list.sumOf { it.amount }
        runningTotal += dayTotal
        val label = date.format(headerFormatter)
        groups += TransactionGroup(
            date = date,
            label = label,
            transactions = list,
            dayTotal = dayTotal,
            runningTotal = runningTotal,
            startIndex = runningIndex
        )
        runningIndex += list.size
    }
    val total = filtered.sumOf { it.amount }
    return groups to total
}

data class CalendarDay(
    val dayOfMonth: Int?,
    val total: Double?,
    val isToday: Boolean
)

data class CalendarMonth(
    val title: String,
    val weeks: List<List<CalendarDay>>
)

fun buildCalendar(monthKey: String?, month: BudgetMonth?, today: LocalDate = LocalDate.now()): CalendarMonth {
    if (monthKey.isNullOrBlank()) {
        return CalendarMonth(title = "", weeks = emptyList())
    }
    val parsed = runCatching { LocalDate.parse("$monthKey-01", dateFormatter) }.getOrElse {
        return CalendarMonth(title = monthKey, weeks = emptyList())
    }
    val year = parsed.year
    val monthValue = parsed.month
    val totalsByDay = mutableMapOf<Int, Double>()
    month?.transactions?.forEach { tx ->
        val day = tx.date.takeLast(2).toIntOrNull() ?: return@forEach
        val current = totalsByDay[day] ?: 0.0
        totalsByDay[day] = current + abs(tx.amount)
    }
    val firstDay = parsed.withDayOfMonth(1)
    val daysInMonth = parsed.lengthOfMonth()
    val startOffset = ((firstDay.dayOfWeek.value + 6) % 7) // Monday = 0
    val weeks = mutableListOf<List<CalendarDay>>()
    var day = 1
    val todayMatch = today.year == year && today.month == monthValue
    while (day <= daysInMonth) {
        val week = mutableListOf<CalendarDay>()
        for (i in 0 until 7) {
            if (weeks.isEmpty() && i < startOffset) {
                week += CalendarDay(null, null, false)
            } else if (day <= daysInMonth) {
                val isToday = todayMatch && today.dayOfMonth == day
                week += CalendarDay(day, totalsByDay[day], isToday)
                day += 1
            } else {
                week += CalendarDay(null, null, false)
            }
        }
        weeks += week
    }
    val title = "${monthValue.name.lowercase(Locale.UK).replaceFirstChar { it.titlecase(Locale.UK) }} $year"
    return CalendarMonth(title = title, weeks = weeks)
}
