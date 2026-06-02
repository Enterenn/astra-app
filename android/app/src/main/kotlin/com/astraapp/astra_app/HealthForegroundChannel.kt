package com.astraapp.astra_app

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object HealthForegroundChannel {
    const val CHANNEL_NAME = "com.astraapp.astra_app/health_foreground"

    private const val METHOD_START = "startHealthCollectionService"
    private const val METHOD_STOP = "stopHealthCollectionService"
    private const val METHOD_IS_RUNNING = "isHealthCollectionServiceRunning"
    private const val METHOD_SET_UI_ACTIVE = "setUiActive"
    private const val METHOD_COLLECT = "collectSteps"

    @Volatile
    private var methodChannel: MethodChannel? = null

    @Volatile
    private var uiActive: Boolean = true

    @Volatile
    private var appContext: Context? = null

    fun attach(engine: FlutterEngine, context: Context) {
        appContext = context.applicationContext
        if (methodChannel != null) {
            return
        }
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_START -> {
                    startService(context)
                    result.success(null)
                }
                METHOD_STOP -> {
                    stopService(context)
                    result.success(null)
                }
                METHOD_IS_RUNNING -> {
                    result.success(HealthStepForegroundService.isRunning)
                }
                METHOD_SET_UI_ACTIVE -> {
                    uiActive = call.arguments as? Boolean ?: true
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        methodChannel = channel
    }

    fun detach() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        appContext = null
    }

    fun requestDartCollection() {
        if (uiActive) {
            return
        }
        methodChannel?.invokeMethod(METHOD_COLLECT, null)
    }

    private fun startService(context: Context) {
        val intent = Intent(context, HealthStepForegroundService::class.java).apply {
            action = HealthStepForegroundService.ACTION_START
        }
        ContextCompat.startForegroundService(context, intent)
    }

    private fun stopService(context: Context) {
        val intent = Intent(context, HealthStepForegroundService::class.java).apply {
            action = HealthStepForegroundService.ACTION_STOP
        }
        context.startService(intent)
    }
}
