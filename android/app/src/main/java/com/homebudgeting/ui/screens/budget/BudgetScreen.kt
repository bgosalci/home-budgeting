package com.homebudgeting.ui.screens.budget

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.homebudgeting.data.Income
import com.homebudgeting.domain.CategorySummary
import com.homebudgeting.domain.MonthTotals
import com.homebudgeting.viewmodel.BudgetUiState
import com.homebudgeting.viewmodel.BudgetViewModel
import java.time.YearMonth
import java.util.Locale

@Composable
fun BudgetScreen(state: BudgetUiState, viewModel: BudgetViewModel) {
    var monthInput by rememberSaveable(state.selectedMonthKey) {
        mutableStateOf(state.selectedMonthKey ?: YearMonth.now().toString())
    }
    var incomeName by rememberSaveable(state.selectedMonthKey) { mutableStateOf("") }
    var incomeAmount by rememberSaveable(state.selectedMonthKey) { mutableStateOf("") }
    var editingIncomeId by rememberSaveable(state.selectedMonthKey) { mutableStateOf<String?>(null) }

    var categoryName by rememberSaveable(state.selectedMonthKey) { mutableStateOf("") }
    var categoryGroup by rememberSaveable(state.selectedMonthKey) { mutableStateOf("") }
    var categoryBudget by rememberSaveable(state.selectedMonthKey) { mutableStateOf("") }

    LaunchedEffect(state.selectedMonthKey) {
        monthInput = state.selectedMonthKey ?: YearMonth.now().toString()
        editingIncomeId = null
        incomeName = ""
        incomeAmount = ""
        categoryName = ""
        categoryGroup = ""
        categoryBudget = ""
    }

    Column(
        modifier = Modifier
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        MonthHeader(
            monthInput = monthInput,
            onMonthInputChange = { monthInput = it },
            state = state,
            onAddMonth = { viewModel.createMonth(monthInput) },
            onSelectMonth = { viewModel.selectMonth(it) },
            onDeleteNext = { viewModel.deleteNextMonth() }
        )
        BalanceSummary(state)
        IncomeSection(
            incomes = state.incomes,
            incomeName = incomeName,
            incomeAmount = incomeAmount,
            isEditing = editingIncomeId != null,
            onNameChange = { incomeName = it },
            onAmountChange = { incomeAmount = it },
            onSubmit = {
                val amount = incomeAmount.toDoubleOrNull()
                if (amount != null) {
                    if (editingIncomeId == null) {
                        viewModel.addIncome(incomeName, amount)
                    } else {
                        viewModel.updateIncome(editingIncomeId!!, incomeName, amount)
                    }
                    incomeName = ""
                    incomeAmount = ""
                    editingIncomeId = null
                }
            },
            onDelete = { id -> viewModel.deleteIncome(id) },
            onEdit = { id, name, amount ->
                editingIncomeId = id
                incomeName = name
                incomeAmount = String.format(Locale.UK, "%.2f", amount)
            },
            onCancel = {
                editingIncomeId = null
                incomeName = ""
                incomeAmount = ""
            }
        )
        CategoriesSection(
            categories = state.categories,
            collapsed = state.collapsedGroups,
            totals = state.totals,
            categoryName = categoryName,
            categoryGroup = categoryGroup,
            categoryBudget = categoryBudget,
            onNameChange = { categoryName = it },
            onGroupChange = { categoryGroup = it },
            onBudgetChange = { categoryBudget = it },
            onSubmit = {
                val budget = categoryBudget.toDoubleOrNull() ?: 0.0
                viewModel.addOrUpdateCategory(categoryName, categoryGroup, budget)
                categoryName = ""
                categoryGroup = ""
                categoryBudget = ""
            },
            onDelete = { viewModel.deleteCategory(it) },
            onToggle = { viewModel.toggleGroup(it) },
            onCollapseAll = { viewModel.setAllGroupsCollapsed(true) },
            onExpandAll = { viewModel.setAllGroupsCollapsed(false) }
        )
    }
}

@Composable
private fun MonthHeader(
    monthInput: String,
    onMonthInputChange: (String) -> Unit,
    state: BudgetUiState,
    onAddMonth: () -> Unit,
    onSelectMonth: (String) -> Unit,
    onDeleteNext: () -> Unit
) {
    ElevatedCard(shape = RoundedCornerShape(16.dp)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                text = "Selected Month",
                style = MaterialTheme.typography.titleMedium
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = monthInput,
                    onValueChange = onMonthInputChange,
                    label = { Text("Add Month (YYYY-MM)") },
                    modifier = Modifier.weight(1f)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Button(onClick = onAddMonth) {
                    Text("Add")
                }
            }
            if (state.monthKeys.isNotEmpty()) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(text = "Open Month", modifier = Modifier.weight(1f))
                    MonthDropdown(months = state.monthKeys, selected = state.selectedMonthKey, onSelect = onSelectMonth)
                }
            }
            val nextLabel = nextFutureMonth(state)
            Button(onClick = onDeleteNext, enabled = nextLabel != null) {
                Text(nextLabel?.let { "Delete $it" } ?: "Delete Next Month")
            }
        }
    }
}

@Composable
private fun MonthDropdown(months: List<String>, selected: String?, onSelect: (String) -> Unit) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    Column(horizontalAlignment = Alignment.End) {
        Button(onClick = { expanded = true }) {
            Text(selected ?: "Select")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            months.forEach { key ->
                DropdownMenuItem(
                    text = { Text(key) },
                    onClick = {
                        expanded = false
                        onSelect(key)
                    }
                )
            }
        }
    }
}

private fun nextFutureMonth(state: BudgetUiState): String? {
    val selected = state.selectedMonthKey ?: return null
    val months = state.monthKeys
    val idx = months.indexOf(selected)
    if (idx < 0 || idx + 1 >= months.size) return null
    val nextKey = months[idx + 1]
    val isFuture = runCatching { YearMonth.parse(nextKey).isAfter(YearMonth.now()) }.getOrDefault(false)
    return if (isFuture) nextKey else null
}

@Composable
private fun BalanceSummary(state: BudgetUiState) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Summary", style = MaterialTheme.typography.titleMedium)
            Text("Income: £${state.totals.totalIncome.format()}", fontWeight = FontWeight.SemiBold)
            Text("Budgeted Spend: £${state.totals.budgetTotal.format()}")
            Text("Actual Spend: £${state.totals.actualTotal.format()}")
            Text("Leftover (actual): £${state.totals.leftoverActual.format()}", fontWeight = FontWeight.SemiBold)
            state.prediction?.let { prediction ->
                Text(
                    text = "Predicted Leftover: £${prediction.predictedLeftover.format()} (sample ${prediction.sampleSize})",
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }
}

@Composable
private fun IncomeSection(
    incomes: List<Income>,
    incomeName: String,
    incomeAmount: String,
    isEditing: Boolean,
    onNameChange: (String) -> Unit,
    onAmountChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onDelete: (String) -> Unit,
    onEdit: (String, String, Double) -> Unit,
    onCancel: () -> Unit
) {
    ElevatedCard {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Money In", style = MaterialTheme.typography.titleLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = incomeName,
                    onValueChange = onNameChange,
                    label = { Text("Income Name") },
                    modifier = Modifier.weight(1f)
                )
                OutlinedTextField(
                    value = incomeAmount,
                    onValueChange = onAmountChange,
                    label = { Text("Amount") },
                    keyboardOptions = KeyboardOptions.Default.copy(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.weight(1f)
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onSubmit) {
                    Text(if (isEditing) "Update" else "Add")
                }
                if (isEditing) {
                    TextButton(onClick = onCancel) {
                        Text("Cancel")
                    }
                }
            }
            Divider()
            incomes.forEach { income ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(income.name, fontWeight = FontWeight.SemiBold)
                        Text("£${income.amount.format()}", style = MaterialTheme.typography.bodySmall)
                    }
                    Row {
                        TextButton(onClick = { onEdit(income.id, income.name, income.amount) }) {
                            Text("Edit")
                        }
                        TextButton(onClick = { onDelete(income.id) }) {
                            Text("Delete")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CategoriesSection(
    categories: List<CategorySummary>,
    collapsed: Set<String>,
    totals: MonthTotals,
    categoryName: String,
    categoryGroup: String,
    categoryBudget: String,
    onNameChange: (String) -> Unit,
    onGroupChange: (String) -> Unit,
    onBudgetChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onDelete: (String) -> Unit,
    onToggle: (String) -> Unit,
    onCollapseAll: () -> Unit,
    onExpandAll: () -> Unit
) {
    ElevatedCard {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Money Out - Categories", style = MaterialTheme.typography.titleLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = categoryName,
                    onValueChange = onNameChange,
                    label = { Text("Category") },
                    modifier = Modifier.weight(1f)
                )
                OutlinedTextField(
                    value = categoryGroup,
                    onValueChange = onGroupChange,
                    label = { Text("Group") },
                    modifier = Modifier.weight(1f)
                )
                OutlinedTextField(
                    value = categoryBudget,
                    onValueChange = onBudgetChange,
                    label = { Text("Budget") },
                    keyboardOptions = KeyboardOptions.Default.copy(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.weight(1f)
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onSubmit) { Text("Save Category") }
                TextButton(onClick = onCollapseAll) { Text("Collapse All") }
                TextButton(onClick = onExpandAll) { Text("Expand All") }
            }
            Divider()
            categories.groupBy { it.group }.forEach { (group, items) ->
                val isCollapsed = collapsed.contains(group)
                GroupHeader(group = group, isCollapsed = isCollapsed, onToggle = { onToggle(group) })
                if (!isCollapsed) {
                    items.forEach { cat ->
                        CategoryRow(cat, onDelete)
                    }
                }
            }
            Divider()
            Text("Totals", style = MaterialTheme.typography.titleMedium)
            Text("Budget: £${totals.budgetTotal.format()}")
            Text("Actual: £${totals.actualTotal.format()}")
        }
    }
}

@Composable
private fun GroupHeader(group: String, isCollapsed: Boolean, onToggle: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(group, fontWeight = FontWeight.SemiBold)
        TextButton(onClick = onToggle) {
            Text(if (isCollapsed) "Expand" else "Collapse")
        }
    }
}

@Composable
private fun CategoryRow(cat: CategorySummary, onDelete: (String) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(cat.name, fontWeight = FontWeight.Medium)
            Text("Budget £${cat.budget.format()} · Actual £${cat.actual.format()} · Diff £${cat.difference.format()}", style = MaterialTheme.typography.bodySmall)
        }
        TextButton(onClick = { onDelete(cat.name) }) {
            Text("Delete")
        }
    }
}

private fun Double.format(): String = String.format(Locale.UK, "%,.2f", this)
