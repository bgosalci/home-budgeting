package com.homebudgeting.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.homebudgeting.data.BudgetRepository
import com.homebudgeting.data.BudgetState
import com.homebudgeting.data.BudgetTransaction
import com.homebudgeting.data.BudgetMonth
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
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
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

    private val exportJson = Json {
        prettyPrint = true
        encodeDefaults = true
    }

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

    suspend fun exportData(
        kind: DataTransferKind,
        monthKey: String?,
        format: DataFormat
    ): ExportPayload {
        val state = repository.state.value.ensureIntegrity()
        return when (kind) {
            DataTransferKind.TRANSACTIONS -> {
                val key = requireMonth(monthKey)
                val transactions = state.months[key]?.transactions ?: emptyList()
                if (format == DataFormat.CSV) {
                    val csv = makeCsv(transactions)
                    ExportPayload(
                        fileName = kind.filename(key, format),
                        mimeType = "text/csv",
                        content = csv.toByteArray(Charsets.UTF_8)
                    )
                } else {
                    val jsonContent = exportJson.encodeToString(transactions)
                    ExportPayload(
                        fileName = kind.filename(key, format),
                        mimeType = "application/json",
                        content = jsonContent.toByteArray(Charsets.UTF_8)
                    )
                }
            }
            DataTransferKind.CATEGORIES -> {
                val key = requireMonth(monthKey)
                val categories = state.months[key]?.categories ?: emptyMap()
                val payload = CategoriesExport(categories = categories)
                val jsonContent = exportJson.encodeToString(payload)
                ExportPayload(
                    fileName = kind.filename(key, format),
                    mimeType = "application/json",
                    content = jsonContent.toByteArray(Charsets.UTF_8)
                )
            }
            DataTransferKind.PREDICTION -> {
                val payload = PredictionExport(
                    mapping = state.mapping.ensureIntegrity(),
                    descMap = state.descMap.ensureIntegrity(),
                    descList = state.descList
                )
                val jsonContent = exportJson.encodeToString(payload)
                ExportPayload(
                    fileName = kind.filename(null, format),
                    mimeType = "application/json",
                    content = jsonContent.toByteArray(Charsets.UTF_8)
                )
            }
            DataTransferKind.ALL -> {
                val payload = FullExport(
                    version = state.version,
                    months = state.months,
                    mapping = state.mapping.ensureIntegrity(),
                    descMap = state.descMap.ensureIntegrity(),
                    descList = state.descList
                )
                val jsonContent = exportJson.encodeToString(payload)
                ExportPayload(
                    fileName = kind.filename(null, format),
                    mimeType = "application/json",
                    content = jsonContent.toByteArray(Charsets.UTF_8)
                )
            }
        }
    }

    suspend fun importData(
        kind: DataTransferKind,
        monthKey: String?,
        format: DataFormat,
        content: ByteArray
    ): ImportSummary {
        return when (kind) {
            DataTransferKind.TRANSACTIONS -> {
                val key = requireMonth(monthKey)
                val drafts = decodeTransactions(content, format)
                val added = appendTransactions(key, drafts)
                ImportSummary("Imported $added transactions into $key.")
            }
            DataTransferKind.CATEGORIES -> {
                val key = requireMonth(monthKey)
                val categories = decodeCategories(content)
                val sanitized = categories.mapValues { it.value.ensureIntegrity() }
                repository.upsertMonth(key) { month ->
                    month.copy(categories = month.categories + sanitized)
                }
                ImportSummary("Merged ${sanitized.size} categories into $key.")
            }
            DataTransferKind.PREDICTION -> {
                val text = content.toString(Charsets.UTF_8)
                val payload = runCatching { json.decodeFromString<PredictionExport>(text) }
                    .getOrElse { throw DataTransferException("The selected file is not valid JSON.") }
                val incoming = BudgetState(
                    version = repository.state.value.version,
                    months = emptyMap(),
                    mapping = payload.mapping,
                    descMap = payload.descMap,
                    descList = payload.descList,
                    notes = emptyList()
                )
                repository.importData(incoming)
                ImportSummary("Imported prediction data.")
            }
            DataTransferKind.ALL -> {
                val text = content.toString(Charsets.UTF_8)
                val state = runCatching { json.decodeFromString<BudgetState>(text) }
                    .getOrElse { throw DataTransferException("The selected file is not valid JSON.") }
                repository.importData(state)
                ImportSummary("Imported full backup.")
            }
        }
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

    private fun requireMonth(monthKey: String?): String {
        val normalized = monthKey?.let { validateMonthKey(it) }
        return normalized ?: throw DataTransferException("Enter a month in YYYY-MM format.")
    }

    private fun decodeTransactions(content: ByteArray, format: DataFormat): List<TransactionDraft> = when (format) {
        DataFormat.JSON -> {
            val text = content.toString(Charsets.UTF_8)
            val direct = runCatching { json.decodeFromString<List<BudgetTransaction>>(text) }.getOrNull()
            val transactions = direct ?: runCatching { json.decodeFromString<TransactionsWrapper>(text) }
                .getOrNull()?.transactions
                ?: throw DataTransferException("The selected file is not valid JSON.")
            transactions.map { TransactionDraft(it.date, it.desc, it.amount, it.category) }
        }
        DataFormat.CSV -> parseCsv(content.toString(Charsets.UTF_8))
    }

    private fun decodeCategories(content: ByteArray): Map<String, com.homebudgeting.data.BudgetCategory> {
        val text = content.toString(Charsets.UTF_8)
        val wrapped = runCatching { json.decodeFromString<CategoriesExport>(text) }.getOrNull()
        if (wrapped != null) return wrapped.categories
        return runCatching { json.decodeFromString<Map<String, com.homebudgeting.data.BudgetCategory>>(text) }
            .getOrElse { throw DataTransferException("The selected file is not valid JSON.") }
    }

    private suspend fun appendTransactions(monthKey: String, drafts: List<TransactionDraft>): Int {
        if (drafts.isEmpty()) return 0
        val base = repository.state.value
        val categories = base.months[monthKey]?.categories?.keys?.toMutableSet() ?: mutableSetOf()
        val prepared = drafts.map { draft ->
            var tx = BudgetTransaction(
                id = generateId(),
                date = draft.date,
                desc = draft.desc,
                amount = draft.amount,
                category = draft.category
            ).ensureIntegrity()
            if (tx.category.isBlank()) {
                val predicted = predictionEngine.predictCategory(tx.desc, categories.toList(), tx.amount)
                if (predicted.isNotBlank()) {
                    tx = tx.copy(category = predicted)
                }
            }
            if (tx.category.isNotBlank()) {
                categories += tx.category
            }
            tx
        }
        repository.upsertMonth(monthKey) { month ->
            month.copy(transactions = month.transactions + prepared)
        }
        prepared.forEach { predictionEngine.recordTransaction(it) }
        return prepared.size
    }

    private fun makeCsv(transactions: List<BudgetTransaction>): String {
        val builder = StringBuilder()
        builder.appendLine("Date,Description,Category,Amount")
        transactions.forEach { tx ->
            val parts = tx.date.split('-')
            val date = if (parts.size == 3) "${parts[2]}/${parts[1]}/${parts[0]}" else ""
            val amount = String.format(Locale.UK, "£%.2f", tx.amount)
            builder.append(date)
                .append(',')
                .append(tx.desc)
                .append(',')
                .append(tx.category)
                .append(',')
                .append(amount)
                .append('\n')
        }
        return builder.toString().trimEnd('\n')
    }

    private fun parseCsv(text: String): List<TransactionDraft> {
        val lines = text.lineSequence()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .toList()
        if (lines.isEmpty()) return emptyList()
        val header = splitCsvLine(lines.first()).map { it.lowercase(Locale.UK) }
        if (header.size < 4 ||
            header[0] != "date" ||
            header[1] != "description" ||
            header[2] != "category" ||
            header[3] != "amount"
        ) {
            throw DataTransferException("The CSV file must include Date, Description, Category and Amount columns.")
        }
        return lines.drop(1).map { line ->
            val columns = splitCsvLine(line)
            if (columns.size < 4) {
                throw DataTransferException("The CSV file must include Date, Description, Category and Amount columns.")
            }
            val date = normalizeCsvDate(columns[0])
            val desc = columns[1]
            val category = columns[2]
            val amountRaw = columns.drop(3).joinToString(",")
            val amount = cleanAmount(amountRaw)
            TransactionDraft(date = date, desc = desc, amount = amount, category = category)
        }
    }

    private fun splitCsvLine(line: String): List<String> {
        val result = mutableListOf<String>()
        val current = StringBuilder()
        var inQuotes = false
        var index = 0
        while (index < line.length) {
            val ch = line[index]
            when {
                ch == '"' -> {
                    if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
                        current.append('"')
                        index++
                    } else {
                        inQuotes = !inQuotes
                    }
                }
                ch == ',' && !inQuotes -> {
                    result += current.toString().trim()
                    current.clear()
                }
                else -> current.append(ch)
            }
            index++
        }
        result += current.toString().trim()
        return result
    }

    private fun normalizeCsvDate(raw: String): String {
        val parts = raw.trim().split('/', '-', ignoreCase = false).filter { it.isNotBlank() }
        return if (parts.size == 3 && parts[2].length == 4) {
            "${parts[2]}-${parts[1]}-${parts[0]}"
        } else {
            ""
        }
    }

    private fun cleanAmount(raw: String): Double {
        val cleaned = raw.replace(Regex("[^0-9.-]"), "")
        return cleaned.toDoubleOrNull() ?: 0.0
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

enum class DataTransferKind(
    val displayName: String,
    val requiresMonth: Boolean,
    val supportsCsv: Boolean
) {
    TRANSACTIONS("Transactions", true, true),
    CATEGORIES("Categories", true, false),
    PREDICTION("Prediction", false, false),
    ALL("All Data", false, false);

    fun filename(monthKey: String?, format: DataFormat): String = when (this) {
        TRANSACTIONS -> {
            val suffix = if (format == DataFormat.CSV) "csv" else "json"
            "transactions-${monthKey ?: "month"}.$suffix"
        }
        CATEGORIES -> "categories.json"
        PREDICTION -> "prediction-map.json"
        ALL -> "budget-all.json"
    }
}

enum class DataFormat(val displayName: String) {
    JSON("JSON"),
    CSV("CSV")
}

data class ExportPayload(
    val fileName: String,
    val mimeType: String,
    val content: ByteArray
)

data class ImportSummary(val message: String)

@Serializable
private data class TransactionsWrapper(val transactions: List<BudgetTransaction> = emptyList())

@Serializable
private data class CategoriesExport(val categories: Map<String, com.homebudgeting.data.BudgetCategory> = emptyMap())

@Serializable
private data class PredictionExport(
    val mapping: PredictionMapping = PredictionMapping(),
    val descMap: DescriptionMap = DescriptionMap(),
    val descList: List<String> = emptyList()
)

@Serializable
private data class FullExport(
    val version: Int = 1,
    val months: Map<String, BudgetMonth> = emptyMap(),
    val mapping: PredictionMapping = PredictionMapping(),
    val descMap: DescriptionMap = DescriptionMap(),
    val descList: List<String> = emptyList()
)

private data class TransactionDraft(
    val date: String,
    val desc: String,
    val amount: Double,
    val category: String
)

class DataTransferException(message: String) : Exception(message)
