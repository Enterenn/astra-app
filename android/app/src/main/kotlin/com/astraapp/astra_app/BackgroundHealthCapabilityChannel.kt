package com.astraapp.astra_app

import android.content.Context
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object BackgroundHealthCapabilityChannel {
    const val CHANNEL_NAME = "com.astraapp.astra_app/background_health_capability"

    private const val METHOD_BATTERY_EXEMPT = "isIgnoringBatteryOptimizations"
    private const val METHOD_MANUFACTURER = "getDeviceManufacturer"

    @Volatile
    private var methodChannel: MethodChannel? = null

    fun attach(engine: FlutterEngine, context: Context) {
        if (methodChannel != null) {
            return
        }
        val appContext = context.applicationContext
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_BATTERY_EXEMPT -> {
                    val powerManager =
                        appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(
                        powerManager.isIgnoringBatteryOptimizations(appContext.packageName),
                    )
                }
                METHOD_MANUFACTURER -> {
                    result.success(Build.MANUFACTURER)
                }
                else -> result.notImplemented()
            }
        }
        methodChannel = channel
    }

    fun detach() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }
}
