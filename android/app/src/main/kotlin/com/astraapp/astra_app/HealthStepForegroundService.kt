package com.astraapp.astra_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

class HealthStepForegroundService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var collectionRunnable: Runnable? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopCollectionLoop()
                stopForeground(STOP_FOREGROUND_REMOVE)
                isRunning = false
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START, null -> {
                val notification = buildForegroundNotification()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    ServiceCompat.startForeground(
                        this,
                        NOTIFICATION_ID,
                        notification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH,
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
                isRunning = true
                startCollectionLoop()
                return START_STICKY
            }
            else -> return START_STICKY
        }
    }

    override fun onDestroy() {
        stopCollectionLoop()
        isRunning = false
        super.onDestroy()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = CHANNEL_DESCRIPTION
            setShowBadge(false)
            enableVibration(false)
            enableLights(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildForegroundNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(NOTIFICATION_TITLE)
            .setContentText(NOTIFICATION_BODY)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun startCollectionLoop() {
        stopCollectionLoop()
        val runnable = object : Runnable {
            override fun run() {
                HealthForegroundChannel.requestDartCollection()
                handler.postDelayed(this, COLLECTION_INTERVAL_MS)
            }
        }
        collectionRunnable = runnable
        handler.post(runnable)
    }

    private fun stopCollectionLoop() {
        collectionRunnable?.let { handler.removeCallbacks(it) }
        collectionRunnable = null
    }

    companion object {
        const val ACTION_START = "com.astraapp.astra_app.action.START_HEALTH_FGS"
        const val ACTION_STOP = "com.astraapp.astra_app.action.STOP_HEALTH_FGS"

        const val CHANNEL_ID = "astra_health_tracking"
        const val CHANNEL_NAME = "Step tracking"
        const val CHANNEL_DESCRIPTION = "Ongoing step tracking while the app is in the background"
        const val NOTIFICATION_ID = 100
        const val NOTIFICATION_TITLE = "Tracking steps"
        const val NOTIFICATION_BODY =
            "Background step count on this device."

        // 60s — timely goal notification when walking in background (FR-25).
        private const val COLLECTION_INTERVAL_MS = 60L * 1000L

        @Volatile
        var isRunning: Boolean = false
    }
}
