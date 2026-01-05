package com.lagrangecode.getmycar

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.HashMap

/**
 * Handler for Car Bluetooth detection using Android's Bluetooth Classic APIs
 * 
 * This class monitors Bluetooth Classic connections (not BLE) to detect car connections.
 * It listens for Bluetooth connection state changes and notifies Flutter via method channel.
 */
class CarBluetoothHandler(private val context: Context, dartExecutor: DartExecutor) {
    private val channel = MethodChannel(dartExecutor.binaryMessenger, "com.findmycar/car_bluetooth")
    private val eventChannel = EventChannel(dartExecutor.binaryMessenger, "com.findmycar/car_bluetooth_events")
    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private var isMonitoring = false
    private var connectionReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null
    
    init {
        // Set up method channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    try {
                        initialize(result)
                    } catch (e: Exception) {
                        result.error("INIT_ERROR", e.message, null)
                    }
                }
                "startMonitoring" -> {
                    try {
                        startMonitoring(result)
                    } catch (e: Exception) {
                        result.error("MONITOR_ERROR", e.message, null)
                    }
                }
                "stopMonitoring" -> {
                    try {
                        stopMonitoring(result)
                    } catch (e: Exception) {
                        result.error("STOP_ERROR", e.message, null)
                    }
                }
                "getPairedDevices" -> {
                    try {
                        getPairedDevices(result)
                    } catch (e: Exception) {
                        result.error("GET_DEVICES_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Set up event channel for streaming connection events
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun initialize(result: MethodChannel.Result) {
        if (bluetoothAdapter == null) {
            result.error("NO_BLUETOOTH", "Bluetooth not available on this device", null)
            return
        }
        
        if (!bluetoothAdapter.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is disabled", null)
            return
        }
        
        result.success(true)
    }

    private fun startMonitoring(result: MethodChannel.Result) {
        if (isMonitoring) {
            result.success(true)
            return
        }
        
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth not available", null)
            return
        }
        
        // Register broadcast receiver for connection state changes
        connectionReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    BluetoothDevice.ACTION_ACL_CONNECTED -> {
                        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        device?.let {
                            notifyConnectionChange(true, it.address, it.name ?: "Unknown")
                        }
                    }
                    BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        device?.let {
                            notifyConnectionChange(false, it.address, it.name ?: "Unknown")
                        }
                    }
                }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
        }
        
        context.registerReceiver(connectionReceiver, filter)
        isMonitoring = true
        
        // Check initially connected devices
        checkConnectedDevices()
        
        result.success(true)
    }

    private fun stopMonitoring(result: MethodChannel.Result) {
        if (!isMonitoring) {
            result.success(true)
            return
        }
        
        connectionReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (e: Exception) {
                // Receiver might not be registered
            }
        }
        connectionReceiver = null
        isMonitoring = false
        
        result.success(true)
    }

    private fun checkConnectedDevices() {
        if (bluetoothAdapter == null) return
        
        try {
            // Get connected devices via Bluetooth Profile
            val connectedDevices = bluetoothAdapter.getBondedDevices()
            for (device in connectedDevices) {
                // Check if device is actually connected (best-effort check)
                val connectionState = device.bondState
                if (connectionState == BluetoothDevice.BOND_BONDED) {
                    // Note: We can't reliably check if a Classic device is currently connected
                    // without using BluetoothProfile, which requires a service connection.
                    // For now, we'll rely on the broadcast receiver for connection events.
                }
            }
        } catch (e: Exception) {
            // Handle error silently
        }
    }

    private fun getPairedDevices(result: MethodChannel.Result) {
        if (bluetoothAdapter == null) {
            result.success(emptyList<Map<String, Any>>())
            return
        }
        
        try {
            val pairedDevices = bluetoothAdapter.bondedDevices
            val deviceList = ArrayList<Map<String, Any>>()
            
            for (device in pairedDevices) {
                val deviceMap = HashMap<String, Any>()
                deviceMap["id"] = device.address
                deviceMap["name"] = device.name ?: "Unknown"
                // Note: We can't reliably check connection state for Classic devices
                // without using BluetoothProfile service
                deviceMap["isConnected"] = false
                deviceList.add(deviceMap)
            }
            
            result.success(deviceList)
        } catch (e: Exception) {
            result.error("ERROR", "Error getting paired devices: ${e.message}", null)
        }
    }

    private fun notifyConnectionChange(isConnected: Boolean, deviceId: String, deviceName: String) {
        val arguments = HashMap<String, Any>()
        arguments["isConnected"] = isConnected
        arguments["deviceId"] = deviceId
        arguments["deviceName"] = deviceName
        
        // Send event through event channel
        eventSink?.success(arguments)
    }

    fun dispose() {
        stopMonitoring(object : MethodChannel.Result {
            override fun success(result: Any?) {}
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun notImplemented() {}
        })
    }
}

