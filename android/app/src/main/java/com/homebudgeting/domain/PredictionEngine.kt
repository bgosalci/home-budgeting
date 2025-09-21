package com.homebudgeting.domain

import com.homebudgeting.data.BudgetRepository
import com.homebudgeting.data.BudgetTransaction
import com.homebudgeting.data.DescriptionMap
import com.homebudgeting.data.PredictionMapping
import java.util.Locale

class PredictionEngine(private val repository: BudgetRepository) {

    fun predictCategory(desc: String, categories: List<String>, amount: Double?): String {
        val base = desc.trim().lowercase(Locale.UK)
        if (base.isBlank()) return ""
        val mapping = repository.state.value.mapping
        if (amount != null && amount.isFinite()) {
            val key = amountKey(base, amount)
            mapping.exact[key]?.takeIf { categories.contains(it) }?.let { return it }
        }
        mapping.exact[base]?.takeIf { categories.contains(it) }?.let { return it }
        val scores = mutableMapOf<String, Int>()
        tokensOf(base).forEach { token ->
            val bag = mapping.tokens[token] ?: return@forEach
            bag.forEach { (cat, count) ->
                scores[cat] = (scores[cat] ?: 0) + count
            }
        }
        return scores.entries
            .sortedByDescending { it.value }
            .firstOrNull { categories.contains(it.key) }
            ?.key ?: ""
    }

    suspend fun learnCategory(desc: String, category: String?, amount: Double?) {
        if (desc.isBlank() || category.isNullOrBlank()) return
        val base = desc.trim().lowercase(Locale.UK)
        val mapping = repository.state.value.mapping
        val exact = mapping.exact.toMutableMap()
        val tokens = mapping.tokens.toMutableMap()
        if (amount != null && amount.isFinite()) {
            exact[amountKey(base, amount)] = category
        } else {
            exact[base] = category
        }
        tokensOf(base).forEach { token ->
            val bag = (tokens[token] ?: emptyMap()).toMutableMap()
            bag[category] = (bag[category] ?: 0) + 1
            tokens[token] = bag
        }
        repository.setMapping(PredictionMapping(exact = exact, tokens = tokens))
        updateDescMap(desc, category)
    }

    suspend fun learnDescription(desc: String) {
        val normalized = desc.trim()
        if (normalized.isEmpty()) return
        val list = repository.state.value.descList.toMutableList()
        if (list.none { it.equals(normalized, ignoreCase = true) }) {
            list += normalized
            repository.setDescriptionList(list)
        }
    }

    fun suggestDescriptions(partial: String, limit: Int = 4): List<String> {
        val norm = partial.trim().lowercase(Locale.UK)
        if (norm.isBlank()) return emptyList()
        return repository.state.value.descList
            .filter { it.lowercase(Locale.UK).startsWith(norm) }
            .take(limit)
    }

    suspend fun recordTransaction(tx: BudgetTransaction) {
        if (tx.category.isNotBlank()) {
            learnCategory(tx.desc, tx.category, tx.amount)
        } else {
            learnDescription(tx.desc)
        }
    }

    suspend fun pinMapping(desc: String, category: String) {
        learnCategory(desc, category, null)
        learnDescription(desc)
    }

    private suspend fun updateDescMap(desc: String, category: String) {
        val normalized = desc.trim()
        if (normalized.isEmpty() || category.isBlank()) return
        val state = repository.state.value.descMap
        val tokens = state.tokens.toMutableMap()
        val catBag = (tokens[category] ?: emptyMap()).toMutableMap()
        catBag[normalized] = (catBag[normalized] ?: 0) + 1
        tokens[category] = catBag

        val exact = state.exact.toMutableMap()
        val key = normalized.lowercase(Locale.UK)
        val freq = (exact[key] ?: emptyMap()).toMutableMap()
        freq[category] = (freq[category] ?: 0) + 1
        exact[key] = freq

        repository.setDescriptionMap(DescriptionMap(exact = exact, tokens = tokens))
        learnDescription(desc)
    }

    private fun tokensOf(desc: String): List<String> = desc
        .lowercase(Locale.UK)
        .replace(Regex("[^a-z0-9\\s]"), " ")
        .split(Regex("\\s+"))
        .filter { it.isNotBlank() }

    private fun amountKey(base: String, amount: Double): String =
        "$base|${String.format(Locale.UK, "%.2f", amount)}"
}
