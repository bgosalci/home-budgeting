package com.homebudgeting.data

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class BudgetRepository(private val storage: BudgetStorage) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mutex = Mutex()
    private val _state = MutableStateFlow(BudgetState.Empty)
    val state: StateFlow<BudgetState> = _state.asStateFlow()

    init {
        scope.launch {
            _state.value = storage.load()
        }
    }

    suspend fun refresh() {
        mutex.withLock {
            _state.value = storage.load()
        }
    }

    suspend fun createMonth(monthKey: String) {
        updateState { current ->
            if (current.months.containsKey(monthKey)) return@updateState current
            val lastKey = current.months.keys.sorted().lastOrNull()
            val template = BudgetMonth()
            val newMonth = if (lastKey != null) {
                val lastMonth = current.months[lastKey]
                template.copy(
                    categories = lastMonth?.categories?.mapValues { (_, cat) -> cat.copy() } ?: emptyMap()
                )
            } else {
                template
            }
            current.copy(months = (current.months + (monthKey to newMonth)).toSortedMap())
        }
    }

    suspend fun deleteMonth(monthKey: String) {
        updateState { current ->
            if (!current.months.containsKey(monthKey)) return@updateState current
            val newMonths = current.months.toMutableMap()
            newMonths.remove(monthKey)
            current.copy(months = newMonths.toSortedMap(), ui = clearCollapsed(current.ui, monthKey))
        }
    }

    suspend fun upsertMonth(monthKey: String, transform: (BudgetMonth) -> BudgetMonth) {
        updateState { current ->
            val month = current.months[monthKey] ?: BudgetMonth()
            val updated = transform(month).ensureIntegrity()
            val newMonths = current.months.toMutableMap()
            newMonths[monthKey] = updated
            current.copy(months = newMonths.toSortedMap())
        }
    }

    suspend fun setMapping(mapping: PredictionMapping) {
        updateState { current -> current.copy(mapping = mapping.ensureIntegrity()) }
    }

    suspend fun setDescriptionMap(descMap: DescriptionMap) {
        updateState { current -> current.copy(descMap = descMap.ensureIntegrity()) }
    }

    suspend fun setDescriptionList(list: List<String>) {
        updateState { current -> current.copy(descList = list.distinctBy { it.lowercase() }) }
    }

    suspend fun setNotes(notes: List<Note>) {
        updateState { current -> current.copy(notes = notes.sortedByDescending { it.time }) }
    }

    suspend fun setCollapsed(monthKey: String, group: String, collapsed: Boolean) {
        updateState { current ->
            val collapsedMap = current.ui.collapsed.toMutableMap()
            val groupMap = (collapsedMap[monthKey] ?: emptyMap()).toMutableMap()
            if (collapsed) {
                groupMap[group] = true
            } else {
                groupMap.remove(group)
            }
            if (groupMap.isEmpty()) {
                collapsedMap.remove(monthKey)
            } else {
                collapsedMap[monthKey] = groupMap
            }
            current.copy(ui = UiPreferences(collapsed = collapsedMap))
        }
    }

    suspend fun setAllCollapsed(monthKey: String, groups: Collection<String>, collapsed: Boolean) {
        updateState { current ->
            val collapsedMap = current.ui.collapsed.toMutableMap()
            if (collapsed) {
                collapsedMap[monthKey] = groups.associateWith { true }
            } else {
                collapsedMap.remove(monthKey)
            }
            current.copy(ui = UiPreferences(collapsed = collapsedMap))
        }
    }

    suspend fun importData(incoming: BudgetState) {
        updateState { current -> mergeStates(current, incoming.ensureIntegrity()) }
    }

    private fun clearCollapsed(ui: UiPreferences, monthKey: String): UiPreferences {
        if (!ui.collapsed.containsKey(monthKey)) return ui
        val map = ui.collapsed.toMutableMap()
        map.remove(monthKey)
        return UiPreferences(collapsed = map)
    }

    private suspend fun updateState(block: (BudgetState) -> BudgetState) {
        mutex.withLock {
            val updated = block(_state.value).ensureIntegrity()
            storage.save(updated)
            _state.value = updated
        }
    }

    private fun mergeStates(current: BudgetState, incoming: BudgetState): BudgetState {
        val mergedMapping = mergePredictionMapping(current.mapping, incoming.mapping)
        val mergedDescMap = mergeDescriptionMap(current.descMap, incoming.descMap)
        val mergedDescList = (current.descList + incoming.descList)
            .fold(mutableListOf<String>()) { acc, item ->
                if (acc.none { it.equals(item, ignoreCase = true) }) acc.add(item)
                acc
            }
        val mergedMonths = current.months.toMutableMap()
        incoming.months.forEach { (key, month) ->
            val sanitized = month.ensureIntegrity()
            mergedMonths[key] = sanitized
        }
        val mergedNotes = (current.notes + incoming.notes)
            .groupBy { it.id }
            .mapValues { (_, value) -> value.maxByOrNull { it.time }!! }
            .values
            .sortedByDescending { it.time }
        return current.copy(
            version = incoming.version.coerceAtLeast(current.version),
            months = mergedMonths.toSortedMap(),
            mapping = mergedMapping,
            descMap = mergedDescMap,
            descList = mergedDescList,
            notes = mergedNotes,
        )
    }

    private fun mergePredictionMapping(
        base: PredictionMapping,
        incoming: PredictionMapping
    ): PredictionMapping {
        val mergedExact = base.exact + incoming.exact
        val mergedTokens = mergeBags(base.tokens, incoming.tokens)
        return PredictionMapping(exact = mergedExact, tokens = mergedTokens)
    }

    private fun mergeDescriptionMap(
        base: DescriptionMap,
        incoming: DescriptionMap
    ): DescriptionMap {
        val mergedExact = mergeBags(base.exact, incoming.exact)
        val mergedTokens = mergeBags(base.tokens, incoming.tokens)
        return DescriptionMap(exact = mergedExact, tokens = mergedTokens)
    }

    private fun mergeBags(
        base: Map<String, Map<String, Int>>,
        incoming: Map<String, Map<String, Int>>
    ): Map<String, Map<String, Int>> {
        val result = base.toMutableMap()
        incoming.forEach { (key, bag) ->
            val merged = (result[key] ?: emptyMap()).toMutableMap()
            bag.forEach { (entry, count) ->
                merged[entry] = (merged[entry] ?: 0) + count
            }
            result[key] = merged
        }
        return result
    }

    suspend fun exportAll(): String = storage.exportAll()
}
