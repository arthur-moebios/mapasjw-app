package br.com.mapasjw.cartas

import android.content.ClipData
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingMapFileResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.mapasjw.cartas/share",
        ).setMethodCallHandler { call, result ->
            if (call.method != "shareFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val bytes = call.argument<ByteArray>("bytes")
                    ?: throw IllegalArgumentException("O arquivo está vazio.")
                val requestedName = call.argument<String>("fileName") ?: "programacao"
                val fileName = requestedName.replace(Regex("[^A-Za-z0-9._-]"), "_")
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                val title = call.argument<String>("title") ?: "Compartilhar arquivo"
                val sharedDirectory = File(cacheDir, "shared").apply { mkdirs() }
                sharedDirectory.listFiles()
                    ?.filter { it.isFile && System.currentTimeMillis() - it.lastModified() > 86_400_000 }
                    ?.forEach { it.delete() }

                val sharedFile = File(sharedDirectory, fileName)
                sharedFile.writeBytes(bytes)
                val contentUri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    sharedFile,
                )
                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                    type = mimeType
                    putExtra(Intent.EXTRA_STREAM, contentUri)
                    clipData = ClipData.newUri(contentResolver, title, contentUri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }

                startActivity(Intent.createChooser(shareIntent, title))
                result.success(true)
            } catch (_: Exception) {
                result.error(
                    "share_failed",
                    "Não foi possível abrir o compartilhamento.",
                    null,
                )
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.mapasjw.cartas/map_import",
        ).setMethodCallHandler { call, result ->
            if (call.method != "pickMapFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingMapFileResult != null) {
                result.error("picker_busy", "Já existe uma seleção de arquivo aberta.", null)
                return@setMethodCallHandler
            }

            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(
                    Intent.EXTRA_MIME_TYPES,
                    arrayOf(
                        "application/vnd.google-earth.kml+xml",
                        "application/vnd.google-earth.kmz",
                        "application/xml",
                        "text/xml",
                        "application/zip",
                    ),
                )
            }
            try {
                pendingMapFileResult = result
                startActivityForResult(intent, MAP_FILE_REQUEST_CODE)
            } catch (_: Exception) {
                pendingMapFileResult = null
                result.error("picker_unavailable", "Não foi possível abrir os arquivos.", null)
            }
        }
    }

    @Deprecated("Deprecated in Android, retained for the document picker result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != MAP_FILE_REQUEST_CODE) return

        val result = pendingMapFileResult ?: return
        pendingMapFileResult = null
        val uri = if (resultCode == RESULT_OK) data?.data else null
        if (uri == null) {
            result.success(null)
            return
        }

        Thread {
            try {
                val (fileName, fileBytes) = readMapFile(uri)
                runOnUiThread {
                    result.success(mapOf("fileName" to fileName, "bytes" to fileBytes))
                }
            } catch (exception: Exception) {
                runOnUiThread {
                    result.error(
                        "map_file_read_failed",
                        exception.message ?: "Não foi possível ler o arquivo selecionado.",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun readMapFile(uri: Uri): Pair<String, ByteArray> {
        var fileName = uri.lastPathSegment ?: "territorios.kml"
        val metadata: Cursor? = contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null,
        )
        metadata?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) fileName = cursor.getString(nameIndex) ?: fileName
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex) &&
                    cursor.getLong(sizeIndex) > MAX_MAP_FILE_BYTES
                ) {
                    throw IllegalArgumentException("O arquivo deve ter até 20 MB.")
                }
            }
        }

        val output = ByteArrayOutputStream()
        contentResolver.openInputStream(uri)?.use { input ->
            val buffer = ByteArray(8 * 1024)
            var totalBytes = 0
            while (true) {
                val bytesRead = input.read(buffer)
                if (bytesRead < 0) break
                totalBytes += bytesRead
                if (totalBytes > MAX_MAP_FILE_BYTES) {
                    throw IllegalArgumentException("O arquivo deve ter até 20 MB.")
                }
                output.write(buffer, 0, bytesRead)
            }
        } ?: throw IllegalArgumentException("Não foi possível abrir o arquivo selecionado.")

        if (output.size() == 0) throw IllegalArgumentException("O arquivo está vazio.")
        return fileName to output.toByteArray()
    }

    companion object {
        private const val MAP_FILE_REQUEST_CODE = 8306
        private const val MAX_MAP_FILE_BYTES = 20L * 1024L * 1024L
    }
}
