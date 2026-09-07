package com.lyme.beikenext

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL_WIDGET = "com.lyme.beikenext/widget"
    private val CHANNEL_BATTERY = "com.lyme.beikenext/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_WIDGET
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateCurriculumData" -> {
                    val data = call.arguments as? String
                    if (data != null) {
                        UpcomingClassWidget.saveFullData(this, data)
                        UpcomingClassWidget.updateAllWidgets(this)
                        UpcomingClassWidget.updateBackgroundRefresh(this)
                    }
                    result.success(null)
                }
                "updateUpcomingClass" -> {
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_BATTERY
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openBatteryOptimizationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
