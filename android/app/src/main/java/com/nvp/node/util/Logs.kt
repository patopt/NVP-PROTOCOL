package com.nvp.node.util

import androidx.compose.runtime.mutableStateListOf

data class LogLine(val level: String, val msg: String, val at: Long = System.currentTimeMillis())

/** Tiny in-memory log buffer observed by the Logs screen (mirrors iOS nvpLog). */
object Logs {
    val lines = mutableStateListOf<LogLine>()
    fun add(level: String, msg: String) {
        lines.add(0, LogLine(level, msg))
        if (lines.size > 200) lines.removeAt(lines.size - 1)
    }
}
