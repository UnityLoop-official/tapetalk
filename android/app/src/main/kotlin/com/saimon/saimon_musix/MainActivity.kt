package com.saimon.saimon_musix

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Dice a Flutter se un'app (es. Spotify, Shazam) è installata e la apre.
    // Le app che si possono controllare sono elencate in <queries> nel manifest.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tapetalk/apps")
            .setMethodCallHandler { call, result ->
                val pkg = call.argument<String>("package")
                when (call.method) {
                    "isInstalled" -> result.success(pkg != null && isInstalled(pkg))
                    "open" -> {
                        val intent = pkg?.let { packageManager.getLaunchIntentForPackage(it) }
                        if (intent != null) startActivity(intent)
                        result.success(intent != null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isInstalled(pkg: String): Boolean =
        try {
            packageManager.getPackageInfo(pkg, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
}
