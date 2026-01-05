package com.lagrangecode.getmycar

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var carBluetoothHandler: CarBluetoothHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Car Bluetooth handler
        carBluetoothHandler = CarBluetoothHandler(
            this,
            flutterEngine.dartExecutor
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        carBluetoothHandler?.dispose()
        carBluetoothHandler = null
    }
}
