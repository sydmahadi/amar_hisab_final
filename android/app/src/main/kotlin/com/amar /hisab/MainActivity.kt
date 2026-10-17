
package com.amar.hisab

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.DocumentsContract
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "amar_hisab/backup"
        private const val REQUEST_FOLDER = 7401
        private const val REQUEST_SAVE = 7402
        private const val PREFS = "amar_hisab_backup_prefs"
        private const val KEY_FOLDER_URI = "backup_folder_uri"
    }

    private var pendingFolderResult: MethodChannel.Result? = null
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingFilename: String? = null
    private var pendingContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "chooseBackupFolder" -> chooseBackupFolder(result)

                "saveBackupToFolder" -> {
                    val filename = call.argument<String>("filename")
                    val content = call.argument<String>("content")

                    if (filename.isNullOrBlank() || content == null) {
                        result.error(
                            "INVALID_ARGUMENT",
                            "Backup filename or content is missing.",
                            null
                        )
                    } else {
                        saveBackup(filename, content, result)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun chooseBackupFolder(result: MethodChannel.Result) {
        if (pendingFolderResult != null) {
            result.error("BUSY", "A folder selection is already open.", null)
            return
        }

        pendingFolderResult = result

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }

        try {
            startActivityForResult(intent, REQUEST_FOLDER)
        } catch (e: Exception) {
            pendingFolderResult = null
            result.error("FOLDER_PICKER_ERROR", e.message, null)
        }
    }

    private fun saveBackup(
        filename: String,
        content: String,
        result: MethodChannel.Result
    ) {
        if (pendingSaveResult != null) {
            result.error("BUSY", "A backup save operation is already open.", null)
            return
        }

        val folderUri = getSharedPreferences(PREFS, MODE_PRIVATE)
            .getString(KEY_FOLDER_URI, null)

        if (folderUri.isNullOrBlank()) {
            result.error(
                "NO_FOLDER",
                "Choose a backup folder first.",
                null
            )
            return
        }

        val parentUri = Uri.parse(folderUri)

        try {
            val documentId = DocumentsContract.getTreeDocumentId(parentUri)
            val parentDocumentUri =
                DocumentsContract.buildDocumentUriUsingTree(
                    parentUri,
                    documentId
                )

            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/json"
                putExtra(Intent.EXTRA_TITLE, filename)
                addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            }

            // A save dialog is used so the user can confirm the
            // location and filename. No existing file is overwritten
            // silently.
            pendingSaveResult = result
            pendingFilename = filename
            pendingContent = content

            startActivityForResult(intent, REQUEST_SAVE)
        } catch (e: Exception) {
            pendingSaveResult = null
            pendingFilename = null
            pendingContent = null
            result.error("SAVE_ERROR", e.message, null)
        }
    }

    @Deprecated("Deprecated in Android API; retained for Flutter compatibility.")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            REQUEST_FOLDER -> {
                val result = pendingFolderResult
                pendingFolderResult = null

                if (resultCode != Activity.RESULT_OK || data?.data == null) {
                    result?.success(false)
                    return
                }

                val uri = data.data!!

                try {
                    val flags = data.flags and (
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        )

                    contentResolver.takePersistableUriPermission(uri, flags)

                    getSharedPreferences(PREFS, MODE_PRIVATE)
                        .edit()
                        .putString(KEY_FOLDER_URI, uri.toString())
                        .apply()

                    result?.success(true)
                } catch (e: Exception) {
                    result?.error("FOLDER_PERMISSION_ERROR", e.message, null)
                }
            }

            REQUEST_SAVE -> {
                val result = pendingSaveResult
                val content = pendingContent

                pendingSaveResult = null
                pendingFilename = null
                pendingContent = null

                if (resultCode != Activity.RESULT_OK || data?.data == null) {
                    result?.success(false)
                    return
                }

                val uri = data.data!!

                try {
                    if (content == null) {
                        result?.error("NO_CONTENT", "Backup content is missing.", null)
                        return
                    }

                    contentResolver.openOutputStream(uri, "wt").use { stream ->
                        if (stream == null) {
                            throw IllegalStateException("Cannot open backup file.")
                        }
                        stream.write(content.toByteArray(Charsets.UTF_8))
                        stream.flush()
                    }

                    result?.success(true)
                } catch (e: Exception) {
                    result?.error("WRITE_ERROR", e.message, null)
                }
            }
        }
    }
}
