package com.homebudgeting.ui.screens.prediction

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.Alignment
import com.homebudgeting.viewmodel.BudgetUiState
import com.homebudgeting.viewmodel.BudgetViewModel

@Composable
fun PredictionScreen(state: BudgetUiState, viewModel: BudgetViewModel) {
    var desc by rememberSaveable { mutableStateOf("") }
    var category by rememberSaveable { mutableStateOf("") }
    var expanded by rememberSaveable { mutableStateOf(false) }
    val categories = state.categories.map { it.name }

    Column(
        modifier = Modifier
            .padding(16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("Pin Description → Category", style = MaterialTheme.typography.titleLarge)
        OutlinedTextField(value = desc, onValueChange = { desc = it }, label = { Text("Description") }, modifier = Modifier.fillMaxWidth())
        Column(horizontalAlignment = Alignment.Start) {
            Button(onClick = { expanded = true }) { Text(if (category.isBlank()) "Select Category" else category) }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                categories.forEach { option ->
                    DropdownMenuItem(text = { Text(option) }, onClick = {
                        category = option
                        expanded = false
                    })
                }
            }
        }
        Button(onClick = {
            if (desc.isNotBlank() && category.isNotBlank()) {
                viewModel.pinPrediction(desc, category)
                desc = ""
                category = ""
            }
        }) { Text("Save Mapping") }
        Divider()
        Text("Exact Matches", style = MaterialTheme.typography.titleMedium)
        state.mapping.exact.entries.sortedBy { it.key }.forEach { (key, value) ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(key, fontWeight = FontWeight.SemiBold)
                    Text("→ $value")
                }
            }
        }
        Divider()
        Text("Token Frequencies", style = MaterialTheme.typography.titleMedium)
        state.mapping.tokens.entries.sortedByDescending { it.value.values.sum() }.take(20).forEach { (token, counts) ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant), modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(token, fontWeight = FontWeight.SemiBold)
                    counts.entries.sortedByDescending { it.value }.forEach { (cat, freq) ->
                        Text("$cat → $freq")
                    }
                }
            }
        }
        Divider()
        Text("Known Descriptions", style = MaterialTheme.typography.titleMedium)
        state.descList.sortedBy { it.lowercase() }.forEach { item ->
            Text(item, style = MaterialTheme.typography.bodySmall)
        }
    }
}
