package com.eventixar.eventixar

import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "shareImages") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val phone = call.argument<String>("phone")
                val paths = call.argument<List<String>>("paths")
                if (phone.isNullOrBlank() || paths.isNullOrEmpty()) {
                    result.error("bad_args", "Faltan el teléfono o las imágenes.", null)
                    return@setMethodCallHandler
                }
                try {
                    shareToWhatsApp(phone, paths)
                    result.success(null)
                } catch (error: Exception) {
                    result.error("whatsapp", error.message, null)
                }
            }
    }

    private fun shareToWhatsApp(phone: String, paths: List<String>) {
        val pkg = whatsAppPackage()
            ?: throw IllegalStateException("No está instalado WhatsApp.")
        val authority = "$packageName.ticketshare"
        val uris = paths.map { path ->
            FileProvider.getUriForFile(this, authority, File(path))
        }
        val intent = if (uris.size == 1) {
            Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uris.first())
                clipData = ClipData.newRawUri("ticket", uris.first())
            }
        } else {
            Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                type = "image/png"
                putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
                val clip = ClipData.newRawUri("ticket", uris.first())
                for (uri in uris.drop(1)) {
                    clip.addItem(ClipData.Item(uri))
                }
                clipData = clip
            }
        }
        intent.setPackage(pkg)
        intent.putExtra("jid", "$phone@s.whatsapp.net")
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        for (uri in uris) {
            grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }

    private fun whatsAppPackage(): String? {
        val manager = packageManager
        for (name in listOf("com.whatsapp", "com.whatsapp.w4b")) {
            try {
                @Suppress("DEPRECATION")
                manager.getPackageInfo(name, PackageManager.GET_ACTIVITIES)
                return name
            } catch (_: PackageManager.NameNotFoundException) {
                continue
            }
        }
        return null
    }

    companion object {
        private const val CHANNEL = "eventixar/whatsapp"
    }
}
