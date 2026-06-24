package com.nvp.node.worker

import android.content.Context
import com.nvp.node.ModelStore
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.util.concurrent.TimeUnit

/** Downloads a model file from a direct URL into the models dir, with live progress. */
class ModelDownloader {
    private val client = OkHttpClient.Builder().connectTimeout(30, TimeUnit.SECONDS).readTimeout(60, TimeUnit.SECONDS).build()

    /** onProgress(downloadedBytes, totalBytes, mbPerSec). Returns true on success. */
    fun download(
        context: Context,
        url: String,
        onProgress: (Long, Long, Double) -> Unit,
    ): Boolean {
        val name = url.substringAfterLast('/').substringBefore('?').ifBlank { "model.task" }
        val dest = File(ModelStore.modelsDir(context), name)
        val req = Request.Builder().url(url).build()
        return runCatching {
            client.newCall(req).execute().use { r ->
                if (!r.isSuccessful) return false
                val body = r.body ?: return false
                val total = body.contentLength()
                body.byteStream().use { input ->
                    dest.outputStream().use { out ->
                        val buf = ByteArray(1 shl 16)
                        var read: Int; var done = 0L; val t0 = System.currentTimeMillis()
                        while (input.read(buf).also { read = it } >= 0) {
                            out.write(buf, 0, read); done += read
                            val sec = (System.currentTimeMillis() - t0) / 1000.0
                            val mbps = if (sec > 0.3) (done / 1_000_000.0) / sec else 0.0
                            onProgress(done, total, mbps)
                        }
                    }
                }
            }
            true
        }.getOrDefault(false)
    }
}
