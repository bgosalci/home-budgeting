package com.homebudgeting.ui.screens.transactions

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.homebudgeting.viewmodel.BudgetUiState
import com.homebudgeting.viewmodel.BudgetViewModel
import java.time.LocalDate
import java.util.Locale
import com.homebudgeting.data.BudgetTransaction

@Composable
fun TransactionsScreen(state: BudgetUiState, viewModel: BudgetViewModel) {
    var txDate by rememberSaveable(state.selectedMonthKey) { mutableStateOf(LocalDate.now().toString()) }
    var txDesc by rememberSaveable(state.selectedMonthKey) { mutableStateOf("") }
    var txAmount by rememberSaveable(state.selectedMonthKey) { mutableStateOf("") }
    var txCategory by rememberSaveable(state.selectedMonthKey) { mutableStateOf("") }
    var editingId by rememberSaveable(state.selectedMonthKey) { mutableStateOf<String?>(null) }
    var showCategoryMenu by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(state.selectedMonthKey) {
        editingId = null
        txDate = state.selectedMonthKey?.let { "$it-01" } ?: LocalDate.now().toString()
        txDesc = ""
        txAmount = ""
        txCategory = ""
    }

    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        SearchBar(
            search = state.transactions.search,
            onSearchChange = { viewModel.updateTransactionSearch(it) },
            categories = listOf("All") + state.transactions.availableCategories,
            selected = state.transactions.category ?: "All",
            onFilterChange = { category ->
                val filter = if (category == "All") null else category
                viewModel.updateTransactionFilter(filter)
            }
        )
        TransactionList(state = state, onEdit = { tx ->
            editingId = tx.id
            txDate = tx.date
            txDesc = tx.desc
            txAmount = String.format(Locale.UK, "%.2f", tx.amount)
            txCategory = tx.category
            viewModel.updateDescriptionInput(tx.desc)
        }, onDelete = { id -> viewModel.deleteTransaction(id) })
        Divider()
        val predicted = viewModel.predictCategory(txDesc, txAmount.toDoubleOrNull())
        if (predicted.isNotBlank()) {
            Text("Suggested Category: $predicted", style = MaterialTheme.typography.bodySmall)
        }
        OutlinedTextField(
            value = txDate,
            onValueChange = { txDate = it },
            label = { Text("Date (YYYY-MM-DD)") },
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = txDesc,
            onValueChange = {
                txDesc = it
                viewModel.updateDescriptionInput(it)
            },
            label = { Text("Description") },
            modifier = Modifier.fillMaxWidth()
        )
        if (state.descSuggestions.isNotEmpty()) {
            SuggestionList(suggestions = state.descSuggestions, onSelect = {
                txDesc = it
                viewModel.clearSuggestions()
            })
        }
        OutlinedTextField(
            value = txAmount,
            onValueChange = { txAmount = it },
            label = { Text("Amount") },
            keyboardOptions = KeyboardOptions.Default.copy(keyboardType = KeyboardType.Decimal),
            modifier = Modifier.fillMaxWidth()
        )
        Column(horizontalAlignment = Alignment.End) {
            Button(onClick = { showCategoryMenu = true }) {
                Text(if (txCategory.isBlank()) "Select Category" else txCategory)
            }
            DropdownMenu(expanded = showCategoryMenu, onDismissRequest = { showCategoryMenu = false }) {
                state.transactions.availableCategories.forEach { category ->
                    DropdownMenuItem(
                        text = { Text(category) },
                        onClick = {
                            txCategory = category
                            showCategoryMenu = false
                        }
                    )
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = {
                val amount = txAmount.toDoubleOrNull()
                if (txDate.isNotBlank() && txDesc.isNotBlank() && amount != null) {
                    viewModel.addOrUpdateTransaction(txDate, txDesc, amount, txCategory.ifBlank { null }, editingId)
                    txDesc = ""
                    txAmount = ""
                    txCategory = ""
                    editingId = null
                    viewModel.clearSuggestions()
                }
            }) {
                Text(if (editingId == null) "Add Transaction" else "Update Transaction")
            }
            if (editingId != null) {
                TextButton(onClick = {
                    editingId = null
                    txDesc = ""
                    txAmount = ""
                    txCategory = ""
                    viewModel.clearSuggestions()
                }) { Text("Cancel") }
            }
            Spacer(modifier = Modifier.weight(1f))
            TextButton(onClick = { viewModel.deleteAllTransactions() }) {
                Text("Delete All")
            }
        }
    }
}

@Composable
private fun SearchBar(
    search: String,
    onSearchChange: (String) -> Unit,
    categories: List<String>,
    selected: String,
    onFilterChange: (String) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(
            value = search,
            onValueChange = onSearchChange,
            label = { Text("Search description") },
            modifier = Modifier.fillMaxWidth()
        )
        CategoryFilter(categories = categories, selected = selected, onFilterChange = onFilterChange)
    }
}

@Composable
private fun CategoryFilter(categories: List<String>, selected: String, onFilterChange: (String) -> Unit) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    Column(horizontalAlignment = Alignment.Start) {
        Button(onClick = { expanded = true }) {
            Text(selected)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            categories.forEach { option ->
                DropdownMenuItem(text = { Text(option) }, onClick = {
                    expanded = false
                    onFilterChange(option)
                })
            }
        }
    }
}

@Composable
private fun TransactionList(
    state: BudgetUiState,
    onEdit: (BudgetTransaction) -> Unit,
    onDelete: (String) -> Unit
) {
    ElevatedCard {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Transactions", style = MaterialTheme.typography.titleLarge)
            Text("Total £${state.transactions.total.format()}")
            LazyColumn(modifier = Modifier.height(280.dp)) {
                state.transactions.groups.forEach { group ->
                    item {
                        Text(
                            text = "${group.label} · Day £${group.dayTotal.format()} · Running £${group.runningTotal.format()}",
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.padding(vertical = 4.dp)
                        )
                    }
                    items(group.transactions) { tx ->
                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp)
                        ) {
                            Column(modifier = Modifier.padding(12.dp)) {
                                Text(tx.desc, fontWeight = FontWeight.Medium)
                                Text("£${tx.amount.format()} · ${tx.category}", style = MaterialTheme.typography.bodySmall)
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    TextButton(onClick = { onEdit(tx) }) { Text("Edit") }
                                    TextButton(onClick = { onDelete(tx.id) }) { Text("Delete") }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SuggestionList(suggestions: List<String>, onSelect: (String) -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(8.dp)) {
            Text("Description Suggestions", style = MaterialTheme.typography.labelLarge)
            suggestions.forEach { suggestion ->
                TextButton(onClick = { onSelect(suggestion) }) {
                    Text(suggestion)
                }
            }
        }
    }
}

private fun Double.format(): String = String.format(Locale.UK, "%,.2f", this)
