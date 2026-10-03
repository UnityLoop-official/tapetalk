package com.saimon.saimon_musix

import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import java.io.ByteArrayOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Dice a Flutter se un'app (es. Spotify, Shazam) è installata, ne dà
    // l'icona e la apre.
    // Le app che si possono controllare sono elencate in <queries> nel manifest.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tapetalk/apps")
            .setMethodCallHandler { call, result ->
                val pkg = call.argument<String>("package")
                when (call.method) {
                    "isInstalled" -> result.success(pkg != null && isInstalled(pkg))
                    "icon" -> result.success(pkg?.let { iconPng(it) })
                    "open" -> {
                        val intent = pkg?.let { packageManager.getLaunchIntentForPackage(it) }
                        if (intent != null) startActivity(intent)
                        result.success(intent != null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // L'icona dell'app come PNG, o null se non è installata.
    private fun iconPng(pkg: String): ByteArray? {
        if (!isInstalled(pkg)) return null
        val drawable = packageManager.getApplicationIcon(pkg)
        val size = 192
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(Canvas(bitmap))
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }

    private fun isInstalled(pkg: String): Boolean =
        try {
            packageManager.getPackageInfo(pkg, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
}
