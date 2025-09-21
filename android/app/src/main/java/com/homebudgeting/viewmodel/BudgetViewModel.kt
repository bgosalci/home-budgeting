package com.homebudgeting.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.homebudgeting.data.BudgetRepository
import com.homebudgeting.data.BudgetState
import com.homebudgeting.data.BudgetTransaction
import com.homebudgeting.data.DescriptionMap
import com.homebudgeting.data.Income
import com.homebudgeting.data.Note
import com.homebudgeting.data.PredictionMapping
import com.homebudgeting.domain.AnalysisMode
import com.homebudgeting.domain.AnalysisOptions
import com.homebudgeting.domain.AnalysisResult
import com.homebudgeting.domain.BalancePrediction
import com.homebudgeting.domain.CalendarMonth
import com.homebudgeting.domain.CategorySummary
import com.homebudgeting.domain.ChartStyle
import com.homebudgeting.domain.MonthTotals
import com.homebudgeting.domain.PredictionEngine
import com.homebudgeting.domain.TransactionFilter
import com.homebudgeting.domain.TransactionGroup
import com.homebudgeting.domain.availableIncomeCategories
import com.homebudgeting.domain.buildBudgetSpread
import com.homebudgeting.domain.buildCalendar
import com.homebudgeting.domain.buildMonthlySpendSeries
import com.homebudgeting.domain.buildMoneyInSeries
import com.homebudgeting.domain.computeMonthTotals
import com.homebudgeting.domain.groupTransactions
import com.homebudgeting.domain.predictBalance
import com.homebudgeting.data.BudgetStorage
import com.homebudgeting.domain.AnalysisUiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import java.time.YearMonth
import java.util.Locale
import java.util.UUID

private val EmptyTotals = MonthTotals(
    totalIncome = 0.0,
    budgetTotal = 0.0,
    actualTotal = 0.0,
    leftoverActual = 0.0,
    leftoverBudget = 0.0,
    categories = emptyList(),
    groups = emptyList()
)

data class TransactionsUiState(
    val search: String = "",
    val category: String? = null,
    val groups: List<TransactionGroup> = emptyList(),
    val total: Double = 0.0,
    val availableCategories: List<String> = emptyList()
)

data class BudgetUiState(
    val isLoading: Boolean = true,
    val monthKeys: List<String> = emptyList(),
    val selectedMonthKey: String? = null,
    val totals: MonthTotals = EmptyTotals,
    val incomes: List<Income> = emptyList(),
    val categories: List<CategorySummary> = emptyList(),
    val collapsedGroups: Set<String> = emptySet(),
    val transactions: TransactionsUiState = TransactionsUiState(),
    val notes: List<Note> = emptyList(),
    val descSuggestions: List<String> = emptyList(),
    val prediction: BalancePrediction? = null,
    val analysis: AnalysisUiState = AnalysisUiState(),
    val calendar: CalendarMonth = CalendarMonth("", emptyList()),
    val mapping: PredictionMapping = PredictionMapping(),
    val descMap: DescriptionMap = DescriptionMap(),
    val descList: List<String> = emptyList()
)

class BudgetViewModel(
    private val repository: BudgetRepository,
    private val predictionEngine: PredictionEngine,
    private val json: Json = Json { ignoreUnknownKeys = true }
) : ViewModel() {

    private val _uiState = MutableStateFlow(BudgetUiState())
    val uiState: StateFlow<BudgetUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            repository.state.collect { state ->
                _uiState.update { current -> composeUiState(state, current) }
            }
        }
    }

    private fun composeUiState(baseState: BudgetState, current: BudgetUiState): BudgetUiState {
        val months = baseState.months.keys.sorted()
        val selected = current.selectedMonthKey
            ?.takeIf { baseState.months.containsKey(it) }
            ?: months.lastOrNull()
            ?: YearMonth.now().toString()
        val month = baseState.months[selected]
        val totals = computeMonthTotals(month)
        val collapsedGroups = baseState.ui.collapsed[selected]?.filterValues { it }?.keys ?: emptySet()
        val categories = month?.categories?.keys?.sortedBy { it.lowercase(Locale.UK) } ?: emptyList()
        val filter = TransactionFilter(current.transactions.search, current.transactions.category)
        val (groups, total) = groupTransactions(month, filter)
        val analysisState = buildAnalysisState(baseState, selected, current.analysis)
        val notes = baseState.notes.sortedByDescending { it.time }
        return current.copy(
            isLoading = false,
            monthKeys = months,
            selectedMonthKey = selected,
            totals = totals,
            incomes = month?.incomes ?: emptyList(),
            categories = totals.categories,
            collapsedGroups = collapsedGroups.toSet(),
            transactions = current.transactions.copy(
                groups = groups,
                total = total,
                availableCategories = categories
            ),
            notes = notes,
            prediction = predictBalance(selected, baseState.months),
            analysis = analysisState,
            calendar = buildCalendar(selected, month),
            mapping = baseState.mapping,
            descMap = baseState.descMap,
            descList = baseState.descList
        )
    }

    private fun buildAnalysisState(
        state: BudgetState,
        selectedMonth: String,
        current: AnalysisUiState
    ): AnalysisUiState {
        val months = state.months.keys.sorted()
        val years = months.map { it.take(4) }.distinct().sorted()
        val monthData = state.months[selectedMonth]
        val categoryMeta = monthData?.categories?.mapValues { it.value.group.ifBlank { "Other" } } ?: emptyMap()
        val groups = categoryMeta.values.toSet().sortedBy { it.lowercase(Locale.UK) }
        val incomeCats = availableIncomeCategories(state)
        val sanitizedOptions = when (current.options.mode) {
            AnalysisMode.BudgetSpread -> {
                val chartStyle = if (current.options.chartStyle == ChartStyle.Line) ChartStyle.Bar else current.options.chartStyle
                val selected = current.options.selectedMonth?.takeIf { months.contains(it) } ?: selectedMonth
                current.options.copy(
                    mode = AnalysisMode.BudgetSpread,
                    chartStyle = chartStyle,
                    selectedMonth = selected,
                    selectedYear = null,
                    selectedGroup = null,
                    selectedCategory = null
                )
            }
            AnalysisMode.MoneyIn -> {
                val chartStyle = if (current.options.chartStyle == ChartStyle.Pie) ChartStyle.Line else current.options.chartStyle
                val selectedYear = current.options.selectedYear?.takeIf { it.isNullOrBlank() || years.contains(it) } ?: ""
                val selectedCategory = current.options.selectedCategory?.takeIf { it.isNullOrBlank() || incomeCats.contains(it) } ?: ""
                current.options.copy(
                    mode = AnalysisMode.MoneyIn,
                    chartStyle = chartStyle,
                    selectedMonth = null,
                    selectedYear = selectedYear,
                    selectedGroup = null,
                    selectedCategory = selectedCategory
                )
            }
            AnalysisMode.MonthlySpend -> {
                val chartStyle = if (current.options.chartStyle == ChartStyle.Pie) ChartStyle.Line else current.options.chartStyle
                val selectedYear = current.options.selectedYear?.takeIf { it.isNullOrBlank() || years.contains(it) } ?: ""
                val selectedGroup = current.options.selectedGroup?.takeIf { it.isNullOrBlank() || groups.contains(it) } ?: ""
                val filteredCategories = categoryMeta
                    .filter { selectedGroup.isBlank() || it.value == selectedGroup }
                    .keys
                    .sortedBy { it.lowercase(Locale.UK) }
                val selectedCategory = current.options.selectedCategory?.takeIf { it.isNullOrBlank() || filteredCategories.contains(it) } ?: ""
                current.options.copy(
                    mode = AnalysisMode.MonthlySpend,
                    chartStyle = chartStyle,
                    selectedMonth = null,
                    selectedYear = selectedYear,
                    selectedGroup = selectedGroup,
                    selectedCategory = selectedCategory
                )
            }
        }
        val result = when (sanitizedOptions.mode) {
            AnalysisMode.BudgetSpread -> buildBudgetSpread(sanitizedOptions.selectedMonth, state.months[sanitizedOptions.selectedMonth])
            AnalysisMode.MoneyIn -> buildMoneyInSeries(
                state,
                sanitizedOptions.selectedYear.takeIf { it?.isNotBlank() == true },
                sanitizedOptions.selectedCategory.takeIf { it?.isNotBlank() == true }
            )
            AnalysisMode.MonthlySpend -> buildMonthlySpendSeries(
                state,
                sanitizedOptions.selectedYear.takeIf { it?.isNotBlank() == true },
                sanitizedOptions.selectedGroup.takeIf { it?.isNotBlank() == true },
                sanitizedOptions.selectedCategory.takeIf { it?.isNotBlank() == true },
                categoryMeta
            )
        }
        val availableCategories = when (sanitizedOptions.mode) {
            AnalysisMode.MoneyIn -> incomeCats
            AnalysisMode.MonthlySpend -> categoryMeta
                .filter { sanitizedOptions.selectedGroup.isNullOrBlank() || it.value == sanitizedOptions.selectedGroup }
                .keys
                .sortedBy { it.lowercase(Locale.UK) }
            AnalysisMode.BudgetSpread -> categoryMeta.keys.sortedBy { it.lowercase(Locale.UK) }
        }
        val availableGroups = when (sanitizedOptions.mode) {
            AnalysisMode.MonthlySpend -> groups
            else -> emptyList()
        }
        return AnalysisUiState(
            options = sanitizedOptions,
            availableMonths = months,
            availableYears = years,
            availableGroups = availableGroups,
            availableCategories = availableCategories,
            result = result
        )
    }

    fun selectMonth(monthKey: String) {
        _uiState.update { it.copy(selectedMonthKey = monthKey) }
        refreshDerivedState()
    }

    fun createMonth(monthKey: String) {
        val key = validateMonthKey(monthKey) ?: return
        viewModelScope.launch {
            if (!repository.state.value.months.containsKey(key)) {
                repository.createMonth(key)
            }
        }
    }

    fun deleteNextMonth() {
        val current = _uiState.value
        val months = current.monthKeys
        val selected = current.selectedMonthKey ?: return
        val idx = months.indexOf(selected)
        if (idx < 0 || idx + 1 >= months.size) return
        val nextKey = months[idx + 1]
        val future = runCatching { YearMonth.parse(nextKey) }.getOrNull()?.isAfter(YearMonth.now()) ?: false
        if (!future) return
        viewModelScope.launch { repository.deleteMonth(nextKey) }
    }

    fun addIncome(name: String, amount: Double) {
        val monthKey = _uiState.value.selectedMonthKey ?: return
        if (name.isBlank()) return
        val income = Income(generateId(), name.trim(), amount)
        viewModelScope.launch {
            repository.upsertMonth(monthKey) { month ->
                val list = month.incomes.toMutableList()
                list += income
                month.copy(incomes = list)
            }
        }
    }

    fun updateIncome(id: String, name: String, amount: Double) {
        val monthKey = _uiState.value.selectedMonthKey ?: return
        viewModelScope.launch {
            repository.upsertMonth(monthKey) { month ->
                val list = month.incomes.map { income ->
                    if (income.id == id) income.copy(name = name.trim(), amount = amount) else income
                }
                month.copy(incomes = list)
            }
        }
    }

    fun deleteIncome(id: String) {
        val monthKey = _uiState.value.selectedMonthKey ?: return
        viewModelScope.launch {
            repository.upsertMonth(monthKey) { month ->
                month.copy(incomes = month.incomes.filterNot { it.id == id })
            }
        }
    }

    fun addOrUpdateCategory(name: String, group: String, budget: Double) {
        val monthKey = _uiState.value.selectedMonthKey ?: return
        if (name.isBlank()) return
        val normalizedGroup = group.ifBlank { "Other" }
        viewModelScope.launch {
            repository.upsertMonth(monthKey) { month ->
                val map = month.categories.toMutableMap()
                map[name] = com.homebudgeting.data.BudgetCategory(group = normalizedGroup, budget = budget)
                month.copy(categories = map)
            }
        }
    }

    fun deleteCategory(name: String) {
        val monthKey = _uiState.value.selectedMonthKey ?: return
        viewModelScope.launch {
            repository.upsertMonth(monthKey) { month ->
                val map = month.categories.toMutableMap()
                map.remove(name)
                month.copy(categories = map)
            }
        }
    }

    fun toggleGroup(group: String) {
        val monthKey = _uiState.value.selectedMonthKey ?: return
        viewModelScope.launch {
            val collapsed = _uiState.value.collapsedGroups.contains(group)
            repository.setCollapsed(monthKey, group, !collapsed)
        }
    }

    fun setAllGroupsCollapsed(collapsed: Boolean) {
        val monthKey = _uiState.value.selectedMonthKey ?: return
        val groups = _uiState.value.categories.map { it.group }.toSet()
        viewModelScope.launch { repository.setAllCollapsed(monthKey, groups, collapsed) }
    }

    fun addOrUpdateTransaction(
        date: String,
        desc: String,
        amount: Double,
        category: String?,
        editingId: String? = null
    ) {
        val monthKey = _uiState.value.selectedMonthKey ?: return
        if (date.isBlank() || desc.isBlank() || !amount.isFinite()) return
        val tx = BudgetTransaction(
            id = editingId ?: generateId(),
            date = date,
            desc = desc.trim(),
            amount = amount,
            category = category.orEmpty()
        )
        viewModelScope.launch {
            repository.upsertMonth(monthKey) { month ->
                val list = month.transactions.toMutableList()
                val index = list.indexOfFirst { it.id == tx.id }
                if (index >= 0) {
                    list[index] = tx
                } else {
                    list += tx
                }
                month.copy(transactions = list)
            }
            predictionEngine.recordTransaction(tx)
        }
    }

    fun deleteTransaction(id: String) {
        val monthKey = _uiState.value.selectedMonthKey ?: return
        viewModelScope.launch {
            repository.upsertMonth(monthKey) { month ->
                month.copy(transactions = month.transactions.filterNot { it.id == id })
            }
        }
    }

    fun deleteAllTransactions() {
        val monthKey = _uiState.value.selectedMonthKey ?: return
        viewModelScope.launch {
            repository.upsertMonth(monthKey) { month -> month.copy(transactions = emptyList()) }
        }
    }

    fun updateTransactionSearch(value: String) {
        _uiState.update { it.copy(transactions = it.transactions.copy(search = value)) }
        refreshDerivedState()
    }

    fun updateTransactionFilter(category: String?) {
        _uiState.update { it.copy(transactions = it.transactions.copy(category = category)) }
        refreshDerivedState()
    }

    fun addNote(desc: String, body: String) {
        if (desc.isBlank() && body.isBlank()) return
        viewModelScope.launch {
            val notes = repository.state.value.notes.toMutableList()
            val time = System.currentTimeMillis()
            notes += Note(id = time, desc = desc.trim(), data = body.trim(), time = time)
            repository.setNotes(notes)
        }
    }

    fun updateNote(id: Long, desc: String, body: String) {
        viewModelScope.launch {
            val notes = repository.state.value.notes.toMutableList()
            val idx = notes.indexOfFirst { it.id == id }
            if (idx >= 0) {
                val time = System.currentTimeMillis()
                notes[idx] = notes[idx].copy(desc = desc.trim(), data = body.trim(), time = time)
                repository.setNotes(notes)
            }
        }
    }

    fun deleteNote(id: Long) {
        viewModelScope.launch {
            val notes = repository.state.value.notes.filterNot { it.id == id }
            repository.setNotes(notes)
        }
    }

    fun updateAnalysisMode(mode: AnalysisMode) {
        _uiState.update { it.copy(analysis = it.analysis.copy(options = it.analysis.options.copy(mode = mode))) }
        refreshDerivedState()
    }

    fun updateAnalysisChartStyle(style: ChartStyle) {
        _uiState.update { it.copy(analysis = it.analysis.copy(options = it.analysis.options.copy(chartStyle = style))) }
        refreshDerivedState()
    }

    fun updateAnalysisMonth(monthKey: String) {
        _uiState.update { it.copy(analysis = it.analysis.copy(options = it.analysis.options.copy(selectedMonth = monthKey))) }
        refreshDerivedState()
    }

    fun updateAnalysisYear(year: String?) {
        _uiState.update { it.copy(analysis = it.analysis.copy(options = it.analysis.options.copy(selectedYear = year))) }
        refreshDerivedState()
    }

    fun updateAnalysisGroup(group: String?) {
        _uiState.update { it.copy(analysis = it.analysis.copy(options = it.analysis.options.copy(selectedGroup = group))) }
        refreshDerivedState()
    }

    fun updateAnalysisCategory(category: String?) {
        _uiState.update { it.copy(analysis = it.analysis.copy(options = it.analysis.options.copy(selectedCategory = category))) }
        refreshDerivedState()
    }

    fun updateDescriptionInput(input: String) {
        val suggestions = predictionEngine.suggestDescriptions(input)
        _uiState.update { it.copy(descSuggestions = suggestions) }
    }

    fun clearSuggestions() {
        _uiState.update { it.copy(descSuggestions = emptyList()) }
    }

    fun predictCategory(desc: String, amount: Double?): String {
        val categories = _uiState.value.categories.map { it.name }
        return predictionEngine.predictCategory(desc, categories, amount)
    }

    fun pinPrediction(desc: String, category: String) {
        viewModelScope.launch { predictionEngine.pinMapping(desc, category) }
    }

    suspend fun exportAll(): String = repository.exportAll()

    suspend fun importJson(jsonContent: String) {
        val incoming = runCatching { json.decodeFromString<BudgetState>(jsonContent) }.getOrNull() ?: return
        repository.importData(incoming)
    }

    private fun refreshDerivedState() {
        val base = repository.state.value
        _uiState.update { composeUiState(base, it) }
    }

    private fun validateMonthKey(raw: String): String? {
        val trimmed = raw.trim()
        return runCatching { YearMonth.parse(trimmed) }.map { it.toString() }.getOrNull()
    }

    private fun generateId(): String = UUID.randomUUID().toString()

    companion object {
        fun provideFactory(context: Context): ViewModelProvider.Factory {
            val appContext = context.applicationContext
            return object : ViewModelProvider.Factory {
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    val storage = BudgetStorage(appContext)
                    val repository = BudgetRepository(storage)
                    val engine = PredictionEngine(repository)
                    @Suppress("UNCHECKED_CAST")
                    return BudgetViewModel(repository, engine) as T
                }
            }
        }
    }
}
