package com.homebudgeting.ui.screens.notes

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.homebudgeting.viewmodel.BudgetUiState
import com.homebudgeting.viewmodel.BudgetViewModel
import java.text.DateFormat
import java.util.Date

@Composable
fun NotesScreen(state: BudgetUiState, viewModel: BudgetViewModel) {
    var desc by rememberSaveable { mutableStateOf("") }
    var body by rememberSaveable { mutableStateOf("") }
    var editingId by rememberSaveable { mutableStateOf<Long?>(null) }

    Column(
        modifier = Modifier
            .padding(16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        OutlinedTextField(value = desc, onValueChange = { desc = it }, label = { Text("Title") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(value = body, onValueChange = { body = it }, label = { Text("Note") }, modifier = Modifier.fillMaxWidth())
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = {
                if (desc.isNotBlank() || body.isNotBlank()) {
                    if (editingId == null) {
                        viewModel.addNote(desc, body)
                    } else {
                        viewModel.updateNote(editingId!!, desc, body)
                    }
                    desc = ""
                    body = ""
                    editingId = null
                }
            }) { Text(if (editingId == null) "Add Note" else "Update Note") }
            if (editingId != null) {
                TextButton(onClick = {
                    editingId = null
                    desc = ""
                    body = ""
                }) { Text("Cancel") }
            }
        }
        Divider()
        state.notes.forEach { note ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(note.desc, fontWeight = FontWeight.SemiBold)
                    Text(note.data)
                    Text(DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(Date(note.time)), style = MaterialTheme.typography.bodySmall)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        TextButton(onClick = {
                            editingId = note.id
                            desc = note.desc
                            body = note.data
                        }) { Text("Edit") }
                        TextButton(onClick = { viewModel.deleteNote(note.id) }) { Text("Delete") }
                    }
                }
            }
        }
    }
}
