package com.homebudgeting.domain

enum class AnalysisMode { BudgetSpread, MoneyIn, MonthlySpend }

enum class ChartStyle { Pie, Bar, Line }

data class AnalysisOptions(
    val mode: AnalysisMode = AnalysisMode.BudgetSpread,
    val chartStyle: ChartStyle = ChartStyle.Bar,
    val selectedMonth: String? = null,
    val selectedYear: String? = null,
    val selectedGroup: String? = null,
    val selectedCategory: String? = null
)

sealed class AnalysisResult {
    data class BudgetSpread(
        val labels: List<String>,
        val planned: List<Double>,
        val actual: List<Double>,
        val plannedPercent: List<Double>,
        val actualPercent: List<Double>,
        val plannedTotal: Double,
        val actualTotal: Double
    ) : AnalysisResult()

    data class Series(
        val labels: List<String>,
        val values: List<Double>,
        val label: String,
        val total: Double
    ) : AnalysisResult()
}

data class AnalysisUiState(
    val options: AnalysisOptions = AnalysisOptions(),
    val availableMonths: List<String> = emptyList(),
    val availableYears: List<String> = emptyList(),
    val availableGroups: List<String> = emptyList(),
    val availableCategories: List<String> = emptyList(),
    val result: AnalysisResult? = null
)
