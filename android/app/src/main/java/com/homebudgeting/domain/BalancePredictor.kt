package com.homebudgeting.domain

import com.homebudgeting.data.BudgetMonth
import com.homebudgeting.data.BudgetTransaction
import java.time.LocalDate
import java.time.YearMonth
import kotlin.math.max

private data class RemainderStats(
    val remainder: Double,
    val sourceDay: Int?,
    val sampleSize: Int
)

data class BalancePrediction(
    val predictedSpend: Double,
    val predictedLeftover: Double,
    val spentSoFar: Double,
    val incomesTotal: Double,
    val observationDay: Int,
    val remainderUsedDay: Int?,
    val sampleSize: Int
)

fun predictBalance(
    monthKey: String?,
    months: Map<String, BudgetMonth>,
    today: LocalDate = LocalDate.now()
): BalancePrediction? {
    if (monthKey.isNullOrBlank()) return null
    val month = months[monthKey] ?: return null
    val observation = determineObservationDay(monthKey, month.transactions, today)
    val monthLength = observation.monthLength
    val cumulative = accumulateByDay(month.transactions, monthLength)
    val spentSoFar = cumulative[minOf(observation.day, monthLength)]
    val incomesTotal = month.incomes.sumOf { it.amount }
    val remainders = computeHistoryRemainders(months, monthKey)
    val remainderStats = pickRemainder(remainders, observation.day)
    val predictedSpend = max(0.0, spentSoFar + remainderStats.remainder)
    val predictedLeftover = incomesTotal - predictedSpend
    return BalancePrediction(
        predictedSpend = predictedSpend,
        predictedLeftover = predictedLeftover,
        spentSoFar = spentSoFar,
        incomesTotal = incomesTotal,
        observationDay = observation.day,
        remainderUsedDay = remainderStats.sourceDay,
        sampleSize = remainderStats.sampleSize
    )
}

private data class Observation(val day: Int, val monthLength: Int)

private fun determineObservationDay(
    monthKey: String,
    transactions: List<BudgetTransaction>,
    today: LocalDate
): Observation {
    val parsed = parseMonthKey(monthKey) ?: return Observation(day = 0, monthLength = 31)
    val monthLength = parsed.lengthOfMonth()
    val todayKey = YearMonth.from(today).toString()
    if (monthKey < todayKey) {
        return Observation(day = monthLength, monthLength = monthLength)
    }
    val validDays = transactions.mapNotNull { it.date.takeLast(2).toIntOrNull() }
        .filter { it in 1..monthLength }
    if (monthKey == todayKey) {
        val todayDay = minOf(today.dayOfMonth, monthLength)
        val observed = (validDays + todayDay).maxOrNull() ?: todayDay
        return Observation(observed, monthLength)
    }
    if (validDays.isNotEmpty()) {
        return Observation(validDays.maxOrNull() ?: 0, monthLength)
    }
    return Observation(day = 0, monthLength = monthLength)
}

private fun accumulateByDay(
    transactions: List<BudgetTransaction>,
    monthLength: Int
): DoubleArray {
    val totals = DoubleArray(monthLength + 1)
    transactions.forEach { tx ->
        val day = tx.date.takeLast(2).toIntOrNull()
        if (day != null && day in 1..monthLength) {
            totals[day] += tx.amount
        }
    }
    val cumulative = DoubleArray(monthLength + 1)
    for (day in 1..monthLength) {
        cumulative[day] = cumulative[day - 1] + totals[day]
    }
    return cumulative
}

private fun computeHistoryRemainders(
    months: Map<String, BudgetMonth>,
    excludeKey: String
): Map<Int, MutableList<Double>> {
    val map = mutableMapOf<Int, MutableList<Double>>()
    months.forEach { (key, month) ->
        if (key == excludeKey) return@forEach
        val parsed = parseMonthKey(key) ?: return@forEach
        val length = parsed.lengthOfMonth()
        val cumulative = accumulateByDay(month.transactions, length)
        val finalSpend = cumulative[length]
        for (day in 0..length) {
            val spent = cumulative[day]
            val remainder = finalSpend - spent
            map.getOrPut(day) { mutableListOf() }.add(remainder)
        }
    }
    return map
}

private fun pickRemainder(
    map: Map<Int, MutableList<Double>>,
    targetDay: Int
): RemainderStats {
    if (map.isEmpty()) return RemainderStats(0.0, null, 0)
    map[targetDay]?.takeIf { it.isNotEmpty() }?.let {
        return RemainderStats(it.median(), targetDay, it.size)
    }
    for (offset in 1..31) {
        val lower = targetDay - offset
        if (lower >= 0) {
            map[lower]?.takeIf { it.isNotEmpty() }?.let {
                return RemainderStats(it.median(), lower, it.size)
            }
        }
        val higher = targetDay + offset
        map[higher]?.takeIf { it.isNotEmpty() }?.let {
            return RemainderStats(it.median(), higher, it.size)
        }
    }
    val lastEntry = map.entries.maxByOrNull { it.key }
    return if (lastEntry != null) {
        RemainderStats(lastEntry.value.median(), lastEntry.key, lastEntry.value.size)
    } else {
        RemainderStats(0.0, null, 0)
    }
}

private fun List<Double>.median(): Double {
    if (isEmpty()) return 0.0
    val sorted = this.sorted()
    val mid = size / 2
    return if (size % 2 == 0) {
        (sorted[mid - 1] + sorted[mid]) / 2.0
    } else {
        sorted[mid]
    }
}

private fun parseMonthKey(key: String): YearMonth? = runCatching {
    YearMonth.parse(key)
}.getOrNull()
