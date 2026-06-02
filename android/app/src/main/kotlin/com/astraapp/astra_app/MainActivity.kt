package com.astraapp.astra_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        HealthForegroundChannel.attach(flutterEngine, this)
        BackgroundHealthCapabilityChannel.attach(flutterEngine, this)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        BackgroundHealthCapabilityChannel.detach()
        HealthForegroundChannel.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
