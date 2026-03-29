package com.homebudgeting.ui.screens.analysis

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.homebudgeting.domain.AnalysisMode
import com.homebudgeting.domain.AnalysisResult
import com.homebudgeting.domain.BudgetSpreadLevel
import com.homebudgeting.domain.ChartStyle
import com.homebudgeting.viewmodel.BudgetUiState
import com.homebudgeting.viewmodel.BudgetViewModel
import java.util.Locale

@Composable
fun AnalysisScreen(state: BudgetUiState, viewModel: BudgetViewModel) {
    val analysis = state.analysis
    Column(
        modifier = Modifier
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        ModeSelector(current = analysis.options.mode, onSelect = { viewModel.updateAnalysisMode(it) })
        ChartStyleSelector(analysis.options.mode, analysis.options.chartStyle, onSelect = { viewModel.updateAnalysisChartStyle(it) })
        when (analysis.options.mode) {
            AnalysisMode.BudgetSpread -> {
                LevelSelector(
                    current = analysis.options.budgetSpreadLevel,
                    onSelect = { viewModel.updateBudgetSpreadLevel(it) }
                )
                MonthSelector(
                    months = analysis.availableMonths,
                    selected = analysis.options.selectedMonth ?: state.selectedMonthKey,
                    onSelect = { viewModel.updateAnalysisMonth(it) }
                )
            }
            AnalysisMode.MoneyIn -> YearCategorySelectors(
                years = analysis.availableYears,
                selectedYear = analysis.options.selectedYear ?: "",
                categories = listOf("All") + analysis.availableCategories,
                selectedCategory = analysis.options.selectedCategory ?: "",
                onYearChange = { year -> viewModel.updateAnalysisYear(year.takeIf { it != "" }) },
                onCategoryChange = { cat ->
                    val value = if (cat == "All") null else cat
                    viewModel.updateAnalysisCategory(value)
                }
            )
            AnalysisMode.MonthlySpend -> SpendSelectors(
                years = analysis.availableYears,
                groups = listOf("All") + analysis.availableGroups,
                categories = listOf("All") + analysis.availableCategories,
                selectedYear = analysis.options.selectedYear ?: "",
                selectedGroup = analysis.options.selectedGroup ?: "",
                selectedCategory = analysis.options.selectedCategory ?: "",
                onYearChange = { year -> viewModel.updateAnalysisYear(year.takeIf { it != "" }) },
                onGroupChange = { group -> viewModel.updateAnalysisGroup(group.takeIf { it != "All" }) },
                onCategoryChange = { category -> viewModel.updateAnalysisCategory(category.takeIf { it != "All" }) }
            )
            AnalysisMode.NetCashFlow, AnalysisMode.SavingsRate -> {
                Dropdown(
                    label = "Year",
                    options = listOf("All") + analysis.availableYears,
                    selected = (analysis.options.selectedYear ?: "").ifBlank { "All" },
                    onSelect = { viewModel.updateAnalysisYear(if (it == "All") null else it) }
                )
            }
        }
        AnalysisContent(analysis.result, analysis.options.chartStyle)
    }
}

@Composable
private fun ModeSelector(current: AnalysisMode, onSelect: (AnalysisMode) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        AnalysisMode.values().forEach { mode ->
            FilterChip(
                selected = current == mode,
                onClick = { onSelect(mode) },
                label = { Text(modeLabel(mode)) }
            )
        }
    }
}

@Composable
private fun LevelSelector(current: BudgetSpreadLevel, onSelect: (BudgetSpreadLevel) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        BudgetSpreadLevel.values().forEach { level ->
            FilterChip(
                selected = current == level,
                onClick = { onSelect(level) },
                label = { Text(level.name.lowercase().replaceFirstChar { it.titlecase(Locale.UK) }) }
            )
        }
    }
}

@Composable
private fun ChartStyleSelector(mode: AnalysisMode, style: ChartStyle, onSelect: (ChartStyle) -> Unit) {
    val available = when (mode) {
        AnalysisMode.BudgetSpread -> listOf(ChartStyle.Bar, ChartStyle.Pie)
        AnalysisMode.MoneyIn, AnalysisMode.MonthlySpend -> listOf(ChartStyle.Line, ChartStyle.Bar)
        AnalysisMode.NetCashFlow -> listOf(ChartStyle.Bar)
        AnalysisMode.SavingsRate -> listOf(ChartStyle.Line)
    }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        available.forEach { opt ->
            FilterChip(selected = style == opt, onClick = { onSelect(opt) }, label = { Text(opt.name.lowercase().replaceFirstChar { it.titlecase(Locale.UK) }) })
        }
    }
}

@Composable
private fun MonthSelector(months: List<String>, selected: String?, onSelect: (String) -> Unit) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    Column(horizontalAlignment = Alignment.Start) {
        Button(onClick = { expanded = true }) { Text(selected ?: "Select Month") }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            months.forEach { month ->
                DropdownMenuItem(text = { Text(month) }, onClick = {
                    expanded = false
                    onSelect(month)
                })
            }
        }
    }
}

@Composable
private fun YearCategorySelectors(
    years: List<String>,
    selectedYear: String,
    categories: List<String>,
    selectedCategory: String,
    onYearChange: (String) -> Unit,
    onCategoryChange: (String) -> Unit
) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        Dropdown(label = "Year", options = listOf("All") + years, selected = selectedYear.ifBlank { "All" }, onSelect = {
            onYearChange(if (it == "All") "" else it)
        })
        Dropdown(label = "Income", options = categories, selected = selectedCategory.ifBlank { "All" }, onSelect = onCategoryChange)
    }
}

@Composable
private fun SpendSelectors(
    years: List<String>,
    groups: List<String>,
    categories: List<String>,
    selectedYear: String,
    selectedGroup: String,
    selectedCategory: String,
    onYearChange: (String) -> Unit,
    onGroupChange: (String) -> Unit,
    onCategoryChange: (String) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Dropdown(label = "Year", options = listOf("All") + years, selected = selectedYear.ifBlank { "All" }, onSelect = {
                onYearChange(if (it == "All") "" else it)
            })
            Dropdown(label = "Group", options = groups, selected = selectedGroup.ifBlank { "All" }, onSelect = onGroupChange)
        }
        Dropdown(label = "Category", options = categories, selected = selectedCategory.ifBlank { "All" }, onSelect = onCategoryChange)
    }
}

@Composable
private fun Dropdown(label: String, options: List<String>, selected: String, onSelect: (String) -> Unit) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    Column(horizontalAlignment = Alignment.Start) {
        Text(label, style = MaterialTheme.typography.labelSmall)
        Button(onClick = { expanded = true }) { Text(selected) }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { option ->
                DropdownMenuItem(text = { Text(option) }, onClick = {
                    expanded = false
                    onSelect(option)
                })
            }
        }
    }
}

@Composable
private fun AnalysisContent(result: AnalysisResult?, style: ChartStyle) {
    when (result) {
        is AnalysisResult.BudgetSpread -> BudgetSpreadContent(result, style)
        is AnalysisResult.Series -> SeriesContent(result, style)
        is AnalysisResult.NetCashFlow -> NetCashFlowContent(result)
        else -> Text("No data available", style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun BudgetSpreadContent(result: AnalysisResult.BudgetSpread, style: ChartStyle) {
    Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Planned £${result.plannedTotal.format()} / Actual £${result.actualTotal.format()}", fontWeight = FontWeight.SemiBold)
            when (style) {
                ChartStyle.Pie -> {
                    Text("Planned Spread")
                    PieChart(labels = result.labels, values = result.plannedPercent)
                    Text("Actual Spread")
                    PieChart(labels = result.labels, values = result.actualPercent)
                }
                else -> GroupedBarChart(result.labels, result.planned, result.actual)
            }
            if (result.totalIncome > 0) {
                Text("Income & Leftover", fontWeight = FontWeight.SemiBold)
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Column {
                        Text("Income", style = MaterialTheme.typography.labelSmall)
                        Text("£${result.totalIncome.format()}", fontWeight = FontWeight.Bold)
                    }
                    Column {
                        Text("Leftover (Actual)", style = MaterialTheme.typography.labelSmall)
                        Text(
                            "£${result.leftoverActual.format()}",
                            fontWeight = FontWeight.Bold,
                            color = if (result.leftoverActual >= 0) Color(0xFF10B981) else Color(0xFFE11D48)
                        )
                    }
                    Column {
                        Text("Leftover (Budget)", style = MaterialTheme.typography.labelSmall)
                        Text(
                            "£${result.leftoverBudget.format()}",
                            fontWeight = FontWeight.Bold,
                            color = if (result.leftoverBudget >= 0) Color(0xFF0EA5E9) else Color(0xFFF97316)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SeriesContent(result: AnalysisResult.Series, style: ChartStyle) {
    Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            val totalLabel = if (result.isPercentage) {
                "${result.label}: avg ${(result.total / result.values.size.coerceAtLeast(1)).format()}%"
            } else {
                "${result.label}: £${result.total.format()}"
            }
            Text(totalLabel, fontWeight = FontWeight.SemiBold)
            when (style) {
                ChartStyle.Bar -> SimpleBarChart(result.labels, result.values)
                else -> SimpleLineChart(result.labels, result.values)
            }
        }
    }
}

@Composable
private fun NetCashFlowContent(result: AnalysisResult.NetCashFlow) {
    Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Net Cash Flow", fontWeight = FontWeight.SemiBold)
            NetCashFlowBarChart(result.labels, result.net)
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Column {
                    Text("Total Net", style = MaterialTheme.typography.labelSmall)
                    Text(
                        "£${result.totalNet.format()}",
                        fontWeight = FontWeight.Bold,
                        color = if (result.totalNet >= 0) Color(0xFF10B981) else Color(0xFFE11D48)
                    )
                }
                Column {
                    Text("Monthly Avg", style = MaterialTheme.typography.labelSmall)
                    Text(
                        "£${result.averageNet.format()}",
                        fontWeight = FontWeight.Bold,
                        color = if (result.averageNet >= 0) Color(0xFF10B981) else Color(0xFFE11D48)
                    )
                }
                Column {
                    Text("Savings Rate", style = MaterialTheme.typography.labelSmall)
                    Text(
                        "${result.savingsRate.coerceAtLeast(0.0).formatPct()}%",
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF0EA5E9)
                    )
                }
            }
        }
    }
}

@Composable
private fun PieChart(labels: List<String>, values: List<Double>) {
    val colors = listOf(
        Color(0xFF0EA5E9), Color(0xFFF97316), Color(0xFF10B981),
        Color(0xFFE11D48), Color(0xFF8B5CF6), Color(0xFF14B8A6)
    )
    Canvas(modifier = Modifier
        .size(220.dp)
        .padding(8.dp)) {
        val total = values.sum().takeIf { it != 0.0 } ?: 1.0
        var start = -90f
        values.forEachIndexed { index, value ->
            val sweep = (value / total * 360).toFloat()
            drawArc(color = colors[index % colors.size], startAngle = start, sweepAngle = sweep, useCenter = true)
            start += sweep
        }
    }
    labels.forEachIndexed { index, label ->
        Text("${label}: ${values.getOrNull(index)?.format() ?: 0.0.format()}%", style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
private fun GroupedBarChart(labels: List<String>, planned: List<Double>, actual: List<Double>) {
    if (labels.isEmpty()) {
        Box(modifier = Modifier.fillMaxWidth().height(220.dp), contentAlignment = Alignment.Center) {
            Text("No data available", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        return
    }
    val maxValue = (planned + actual).maxOrNull()?.takeIf { it > 0 } ?: 1.0
    Canvas(modifier = Modifier
        .fillMaxWidth()
        .height(220.dp)
        .padding(8.dp)) {
        val barWidth = size.width / (labels.size * 2.5f)
        labels.forEachIndexed { index, _ ->
            val xBase = index * barWidth * 2.5f + barWidth
            val plannedHeight = (planned[index] / maxValue * size.height).toFloat()
            val actualHeight = (actual[index] / maxValue * size.height).toFloat()
            val actualColor = if (actual[index] > planned[index]) Color(0xFFF97316) else Color(0xFF10B981)
            drawRect(Color(0xFF0EA5E9), topLeft = Offset(xBase, size.height - plannedHeight), size = Size(barWidth, plannedHeight))
            drawRect(actualColor, topLeft = Offset(xBase + barWidth + 12f, size.height - actualHeight), size = Size(barWidth, actualHeight))
        }
    }
}

@Composable
private fun SimpleBarChart(labels: List<String>, values: List<Double>) {
    if (labels.isEmpty()) {
        Box(modifier = Modifier.fillMaxWidth().height(220.dp), contentAlignment = Alignment.Center) {
            Text("No data available", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        return
    }
    val maxValue = values.maxOrNull()?.takeIf { it > 0 } ?: 1.0
    Canvas(modifier = Modifier
        .fillMaxWidth()
        .height(220.dp)
        .padding(8.dp)) {
        val barWidth = size.width / (labels.size * 1.8f)
        labels.forEachIndexed { index, _ ->
            val height = (values[index] / maxValue * size.height).toFloat()
            drawRect(Color(0xFF0EA5E9), topLeft = Offset(index * barWidth * 1.8f, size.height - height), size = Size(barWidth, height))
        }
    }
}

@Composable
private fun NetCashFlowBarChart(labels: List<String>, net: List<Double>) {
    val absMax = net.maxOfOrNull { kotlin.math.abs(it) }?.takeIf { it > 0 } ?: 1.0
    Canvas(modifier = Modifier
        .fillMaxWidth()
        .height(220.dp)
        .padding(8.dp)) {
        val barWidth = size.width / (labels.size * 1.8f)
        val midY = size.height / 2f
        net.forEachIndexed { index, value ->
            val barHeight = (kotlin.math.abs(value) / absMax * midY).toFloat()
            val color = if (value >= 0) Color(0xFF10B981) else Color(0xFFE11D48)
            val top = if (value >= 0) midY - barHeight else midY
            drawRect(color, topLeft = Offset(index * barWidth * 1.8f, top), size = Size(barWidth, barHeight))
        }
        drawLine(Color.Gray, start = Offset(0f, midY), end = Offset(size.width, midY), strokeWidth = 1f)
    }
}

@Composable
private fun SimpleLineChart(labels: List<String>, values: List<Double>) {
    if (labels.isEmpty()) {
        Box(modifier = Modifier.fillMaxWidth().height(220.dp), contentAlignment = Alignment.Center) {
            Text("No data available", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        return
    }
    val maxValue = values.maxOrNull()?.takeIf { it > 0 } ?: 1.0
    Canvas(modifier = Modifier
        .fillMaxWidth()
        .height(220.dp)
        .padding(8.dp)) {
        val stepX = if (values.size > 1) size.width / (values.size - 1) else size.width
        val points = values.mapIndexed { index, value ->
            val x = if (values.size == 1) size.width / 2f else index * stepX
            val y = size.height - (value / maxValue * size.height).toFloat()
            Offset(x, y)
        }
        val path = Path().apply {
            moveTo(points.first().x, points.first().y)
            points.drop(1).forEach { lineTo(it.x, it.y) }
        }
        drawPath(path = path, color = Color(0xFF10B981), style = Stroke(width = 6f, cap = StrokeCap.Round))
        points.forEach { point ->
            drawCircle(Color(0xFF10B981), radius = 8f, center = point)
        }
    }
}

private fun Double.format(): String = String.format(Locale.UK, "%,.2f", this)
private fun Double.formatPct(): String = String.format(Locale.UK, "%.1f", this)

private fun modeLabel(mode: AnalysisMode): String = when (mode) {
    AnalysisMode.BudgetSpread -> "Budget"
    AnalysisMode.MoneyIn -> "Income"
    AnalysisMode.MonthlySpend -> "Spend"
    AnalysisMode.NetCashFlow -> "Cash Flow"
    AnalysisMode.SavingsRate -> "Savings Rate"
}
