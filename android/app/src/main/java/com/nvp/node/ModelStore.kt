package com.nvp.node

import android.content.Context
import android.net.Uri
import java.io.File

/**
 * Locates and imports the on-device model file. Models live in the app's external
 * files dir (visible in the Files app / file manager under Android/data or the
 * app folder) so users can copy a `.task` model in, and they survive reinstalls
 * when placed in shared storage.
 */
object ModelStore {
    fun modelsDir(context: Context): File {
        val base = context.getExternalFilesDir(null) ?: context.filesDir
        return File(base, "models").apply { mkdirs() }
    }

    /** First `.task` or `.bin` model file present, or null. */
    fun modelFilePath(context: Context): String? {
        val dir = modelsDir(context)
        val f = dir.listFiles()?.firstOrNull { it.isFile && (it.name.endsWith(".task") || it.name.endsWith(".bin")) }
        return f?.absolutePath
    }

    fun isInstalled(context: Context): Boolean = modelFilePath(context) != null

    fun sizeOnDiskMb(context: Context): Long {
        val p = modelFilePath(context) ?: return 0
        return File(p).length() / (1024 * 1024)
    }

    /** Copy a user-picked model file (SAF Uri) into the models dir. Returns success. */
    fun importFrom(context: Context, uri: Uri): Boolean {
        val name = queryName(context, uri) ?: "model.task"
        val dest = File(modelsDir(context), name)
        return runCatching {
            context.contentResolver.openInputStream(uri)!!.use { input ->
                dest.outputStream().use { out -> input.copyTo(out, 1 shl 20) }
            }
            true
        }.getOrDefault(false)
    }

    private fun queryName(context: Context, uri: Uri): String? {
        context.contentResolver.query(uri, null, null, null, null)?.use { c ->
            val i = c.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
            if (i >= 0 && c.moveToFirst()) return c.getString(i)
        }
        return null
    }
}
