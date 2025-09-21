package com.homebudgeting.data

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

class BudgetStorage(private val context: Context) {
    private val json = Json {
        ignoreUnknownKeys = true
        prettyPrint = true
        encodeDefaults = true
    }

    private val fileName = "budget_local_v1.json"

    private fun storageFile(): File = File(context.filesDir, fileName)

    suspend fun load(): BudgetState = withContext(Dispatchers.IO) {
        runCatching {
            val file = storageFile()
            if (!file.exists()) {
                BudgetState.Empty
            } else {
                val text = file.readText()
                if (text.isBlank()) {
                    BudgetState.Empty
                } else {
                    json.decodeFromString<BudgetState>(text).ensureIntegrity()
                }
            }
        }.getOrElse { BudgetState.Empty }
    }

    suspend fun save(state: BudgetState) = withContext(Dispatchers.IO) {
        val file = storageFile()
        if (!file.parentFile.exists()) {
            file.parentFile.mkdirs()
        }
        file.writeText(json.encodeToString(state.ensureIntegrity()))
    }

    suspend fun exportAll(): String = withContext(Dispatchers.IO) {
        json.encodeToString(load())
    }
}
