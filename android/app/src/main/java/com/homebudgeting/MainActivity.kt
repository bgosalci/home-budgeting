package com.homebudgeting

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.homebudgeting.ui.HomeBudgetingApp
import com.homebudgeting.ui.theme.HomeBudgetingTheme
import com.homebudgeting.viewmodel.BudgetViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val viewModel: BudgetViewModel = viewModel(factory = BudgetViewModel.provideFactory(applicationContext))
            HomeBudgetingTheme {
                HomeBudgetingApp(viewModel)
            }
        }
    }
}
