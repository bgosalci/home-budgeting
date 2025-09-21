package com.homebudgeting.ui.screens.budget

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.homebudgeting.data.Income
import com.homebudgeting.domain.CategorySummary
import com.homebudgeting.domain.MonthTotals
import com.homebudgeting.viewmodel.BudgetUiState
import com.homebudgeting.viewmodel.BudgetViewModel
import com.homebudgeting.viewmodel.DataFormat
import com.homebudgeting.viewmodel.DataTransferException
import com.homebudgeting.viewmodel.DataTransferKind
import com.homebudgeting.viewmodel.ExportPayload
import kotlinx.coroutines.launch
import java.time.YearMonth
import java.util.Locale

@Composable
fun BudgetScreen(state: BudgetUiState, viewModel: BudgetViewModel) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var monthInput by rememberSaveable(state.selectedMonthKey) {
        mutableStateOf(state.selectedMonthKey ?: YearMonth.now().toString())
    }
    var incomeName by rememberSaveable(state.selectedMonthKey) { mutableStateOf("") }
    var incomeAmount by rememberSaveable(state.selectedMonthKey) { mutableStateOf("") }
    var editingIncomeId by rememberSaveable(state.selectedMonthKey) { mutableStateOf<String?>(null) }

    var categoryName by rememberSaveable(state.selectedMonthKey) { mutableStateOf("") }
    var categoryGroup by rememberSaveable(state.selectedMonthKey) { mutableStateOf("") }
    var categoryBudget by rememberSaveable(state.selectedMonthKey) { mutableStateOf("") }

    var exportDialogOpen by rememberSaveable { mutableStateOf(false) }
    var importDialogOpen by rememberSaveable { mutableStateOf(false) }
    var exportKind by rememberSaveable { mutableStateOf(DataTransferKind.TRANSACTIONS) }
    var exportFormat by rememberSaveable { mutableStateOf(DataFormat.JSON) }
    var exportMonth by rememberSaveable(state.selectedMonthKey) { mutableStateOf(state.selectedMonthKey ?: YearMonth.now().toString()) }
    var importKind by rememberSaveable { mutableStateOf(DataTransferKind.TRANSACTIONS) }
    var importFormat by rememberSaveable { mutableStateOf(DataFormat.JSON) }
    var importMonth by rememberSaveable(state.selectedMonthKey) { mutableStateOf(state.selectedMonthKey ?: YearMonth.now().toString()) }
    var pendingExport by remember { mutableStateOf<ExportPayload?>(null) }
    var pendingImport by remember { mutableStateOf<ImportRequest?>(null) }
    var feedbackMessage by rememberSaveable { mutableStateOf<String?>(null) }

    val exportLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("*/*")
    ) { uri ->
        val payload = pendingExport
        if (uri != null && payload != null) {
            runCatching {
                context.contentResolver.openOutputStream(uri)?.use { stream ->
                    stream.write(payload.content)
                } ?: throw IllegalStateException()
            }.onSuccess {
                feedbackMessage = "Export complete: ${payload.fileName}"
            }.onFailure {
                feedbackMessage = "Export failed."
            }
        }
        pendingExport = null
    }

    val importLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        val request = pendingImport
        if (uri != null && request != null) {
            val bytes = runCatching {
                context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            }.getOrNull()
            if (bytes != null) {
                scope.launch {
                    try {
                        val result = viewModel.importData(
                            kind = request.kind,
                            monthKey = request.month,
                            format = request.format,
                            content = bytes
                        )
                        feedbackMessage = result.message
                    } catch (e: DataTransferException) {
                        feedbackMessage = e.message
                    } catch (_: Exception) {
                        feedbackMessage = "Import failed."
                    }
                }
            } else {
                feedbackMessage = "Unable to read the selected file."
            }
        }
        pendingImport = null
    }

    LaunchedEffect(state.selectedMonthKey) {
        monthInput = state.selectedMonthKey ?: YearMonth.now().toString()
        editingIncomeId = null
        incomeName = ""
        incomeAmount = ""
        categoryName = ""
        categoryGroup = ""
        categoryBudget = ""
        val defaultMonth = state.selectedMonthKey ?: YearMonth.now().toString()
        exportMonth = defaultMonth
        importMonth = defaultMonth
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
        DataSection(
            onExport = {
                exportKind = DataTransferKind.TRANSACTIONS
                exportFormat = DataFormat.JSON
                exportDialogOpen = true
            },
            onImport = {
                importKind = DataTransferKind.TRANSACTIONS
                importFormat = DataFormat.JSON
                importDialogOpen = true
            }
        )
    }

    if (exportDialogOpen) {
        DataTransferDialog(
            title = "Export Data",
            confirmLabel = "Export",
            kind = exportKind,
            onKindChange = {
                exportKind = it
                if (!it.supportsCsv) exportFormat = DataFormat.JSON
            },
            format = exportFormat,
            onFormatChange = { exportFormat = it },
            month = exportMonth,
            onMonthChange = { exportMonth = it },
            availableMonths = state.monthKeys,
            onDismiss = { exportDialogOpen = false },
            onConfirm = {
                val normalized = if (exportKind.requiresMonth) normalizeMonth(exportMonth) else null
                if (exportKind.requiresMonth && normalized == null) {
                    feedbackMessage = "Enter a month in YYYY-MM format."
                    return@DataTransferDialog
                }
                exportDialogOpen = false
                scope.launch {
                    try {
                        val payload = viewModel.exportData(exportKind, normalized, exportFormat)
                        pendingExport = payload
                        exportLauncher.launch(payload.fileName)
                    } catch (e: DataTransferException) {
                        feedbackMessage = e.message
                    } catch (_: Exception) {
                        feedbackMessage = "Export failed."
                    }
                }
            }
        )
    }

    if (importDialogOpen) {
        DataTransferDialog(
            title = "Import Data",
            confirmLabel = "Select",
            kind = importKind,
            onKindChange = {
                importKind = it
                if (!it.supportsCsv) importFormat = DataFormat.JSON
            },
            format = importFormat,
            onFormatChange = { importFormat = it },
            month = importMonth,
            onMonthChange = { importMonth = it },
            availableMonths = state.monthKeys,
            onDismiss = { importDialogOpen = false },
            onConfirm = {
                val normalized = if (importKind.requiresMonth) normalizeMonth(importMonth) else null
                if (importKind.requiresMonth && normalized == null) {
                    feedbackMessage = "Enter a month in YYYY-MM format."
                    return@DataTransferDialog
                }
                val request = ImportRequest(importKind, importFormat, normalized)
                pendingImport = request
                importDialogOpen = false
                importLauncher.launch(request.mimeTypes)
            }
        )
    }

    LaunchedEffect(feedbackMessage) {
        feedbackMessage?.let {
            Toast.makeText(context, it, Toast.LENGTH_LONG).show()
            feedbackMessage = null
        }
    }
}

@Composable
private fun DataSection(onExport: () -> Unit, onImport: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("Data", style = MaterialTheme.typography.titleMedium)
            Text(
                "Export or import data in the same formats as the web app.",
                style = MaterialTheme.typography.bodySmall
            )
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(onClick = onExport, modifier = Modifier.weight(1f)) {
                    Text("Export Data")
                }
                Button(onClick = onImport, modifier = Modifier.weight(1f)) {
                    Text("Import Data")
                }
            }
        }
    }
}

@Composable
private fun DataTransferDialog(
    title: String,
    confirmLabel: String,
    kind: DataTransferKind,
    onKindChange: (DataTransferKind) -> Unit,
    format: DataFormat,
    onFormatChange: (DataFormat) -> Unit,
    month: String,
    onMonthChange: (String) -> Unit,
    availableMonths: List<String>,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onConfirm) { Text(confirmLabel) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
        title = { Text(title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Data set", style = MaterialTheme.typography.labelLarge)
                    DataKindOptions(selected = kind, onSelected = onKindChange)
                }
                if (kind.requiresMonth) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Month", style = MaterialTheme.typography.labelLarge)
                        OutlinedTextField(
                            value = month,
                            onValueChange = onMonthChange,
                            label = { Text("YYYY-MM") },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                        )
                        if (availableMonths.isNotEmpty()) {
                            TextButton(onClick = { onMonthChange(availableMonths.last()) }) {
                                Text("Use latest month")
                            }
                        }
                    }
                }
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Format", style = MaterialTheme.typography.labelLarge)
                    if (kind.supportsCsv) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            RadioButton(
                                selected = format == DataFormat.JSON,
                                onClick = { onFormatChange(DataFormat.JSON) }
                            )
                            Text("JSON", modifier = Modifier.padding(end = 16.dp))
                            RadioButton(
                                selected = format == DataFormat.CSV,
                                onClick = { onFormatChange(DataFormat.CSV) }
                            )
                            Text("CSV")
                        }
                    } else {
                        Text("JSON", style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }
    )
}

@Composable
private fun DataKindOptions(selected: DataTransferKind, onSelected: (DataTransferKind) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        DataTransferKind.values().forEach { option ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                RadioButton(selected = option == selected, onClick = { onSelected(option) })
                Text(option.displayName)
            }
        }
    }
}

private fun normalizeMonth(input: String): String? =
    runCatching { YearMonth.parse(input.trim()) }.map { it.toString() }.getOrNull()

private data class ImportRequest(
    val kind: DataTransferKind,
    val format: DataFormat,
    val month: String?
) {
    val mimeTypes: Array<String> = when (format) {
        DataFormat.JSON -> arrayOf("application/json")
        DataFormat.CSV -> arrayOf("text/csv", "text/comma-separated-values", "text/plain")
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
