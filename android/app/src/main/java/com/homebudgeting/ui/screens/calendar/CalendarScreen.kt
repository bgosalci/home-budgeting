package com.homebudgeting.ui.screens.calendar

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.homebudgeting.domain.CalendarDay
import com.homebudgeting.viewmodel.BudgetUiState
import com.homebudgeting.viewmodel.BudgetViewModel
import java.util.Locale

@Composable
fun CalendarScreen(state: BudgetUiState, viewModel: BudgetViewModel) {
    val calendar = state.calendar
    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(calendar.title, style = MaterialTheme.typography.titleLarge)
        calendar.weeks.forEach { week ->
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                week.forEach { day -> CalendarCell(day, Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun CalendarCell(day: CalendarDay, modifier: Modifier = Modifier) {
    val background = if (day.isToday) MaterialTheme.colorScheme.primary.copy(alpha = 0.2f) else MaterialTheme.colorScheme.surface
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = background),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier.padding(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(day.dayOfMonth?.toString() ?: "", fontWeight = if (day.isToday) FontWeight.Bold else FontWeight.Normal)
            if (day.total != null) {
                Text("£${day.total.format()}", style = MaterialTheme.typography.bodySmall, textAlign = TextAlign.Center)
            }
        }
    }
}

private fun Double.format(): String = String.format(Locale.UK, "%,.2f", this)
