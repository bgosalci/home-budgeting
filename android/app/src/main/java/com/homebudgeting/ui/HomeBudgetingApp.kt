package com.homebudgeting.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Analytics
import androidx.compose.material.icons.outlined.Article
import androidx.compose.material.icons.outlined.CalendarToday
import androidx.compose.material.icons.outlined.Category
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.outlined.ListAlt
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.homebudgeting.ui.screens.analysis.AnalysisScreen
import com.homebudgeting.ui.screens.budget.BudgetScreen
import com.homebudgeting.ui.screens.calendar.CalendarScreen
import com.homebudgeting.ui.screens.notes.NotesScreen
import com.homebudgeting.ui.screens.prediction.PredictionScreen
import com.homebudgeting.ui.screens.transactions.TransactionsScreen
import com.homebudgeting.viewmodel.BudgetViewModel

private data class NavItem(val route: String, val label: String, val icon: androidx.compose.ui.graphics.vector.ImageVector)

@Composable
fun HomeBudgetingApp(viewModel: BudgetViewModel) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val navController = rememberNavController()
    var currentRoute by remember { mutableStateOf(Routes.Budget) }
    Scaffold(
        bottomBar = {
            NavigationBar {
                navItems.forEach { item ->
                    val selected = currentRoute == item.route
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            currentRoute = item.route
                            if (navController.currentDestination?.route != item.route) {
                                navController.navigate(item.route) {
                                    popUpTo(navController.graph.startDestinationId) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        },
                        icon = { Icon(item.icon, contentDescription = item.label) },
                        label = { Text(item.label) }
                    )
                }
            }
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding)) {
            NavigationHost(navController, uiState, viewModel)
        }
    }
}

@Composable
private fun NavigationHost(
    navController: NavHostController,
    uiState: com.homebudgeting.viewmodel.BudgetUiState,
    viewModel: BudgetViewModel
) {
    NavHost(navController = navController, startDestination = Routes.Budget) {
        composable(Routes.Budget) {
            BudgetScreen(state = uiState, viewModel = viewModel)
        }
        composable(Routes.Transactions) {
            TransactionsScreen(state = uiState, viewModel = viewModel)
        }
        composable(Routes.Analysis) {
            AnalysisScreen(state = uiState, viewModel = viewModel)
        }
        composable(Routes.Calendar) {
            CalendarScreen(state = uiState, viewModel = viewModel)
        }
        composable(Routes.Notes) {
            NotesScreen(state = uiState, viewModel = viewModel)
        }
        composable(Routes.Prediction) {
            PredictionScreen(state = uiState, viewModel = viewModel)
        }
    }
}

private object Routes {
    const val Budget = "budget"
    const val Transactions = "transactions"
    const val Analysis = "analysis"
    const val Calendar = "calendar"
    const val Notes = "notes"
    const val Prediction = "prediction"
}

private val navItems = listOf(
    NavItem(Routes.Budget, "Budget", Icons.Outlined.Category),
    NavItem(Routes.Transactions, "Transactions", Icons.Outlined.ListAlt),
    NavItem(Routes.Analysis, "Analysis", Icons.Outlined.Analytics),
    NavItem(Routes.Calendar, "Calendar", Icons.Outlined.CalendarToday),
    NavItem(Routes.Notes, "Notes", Icons.Outlined.EditNote),
    NavItem(Routes.Prediction, "Prediction", Icons.Outlined.Article)
)
