
package com.example.driver

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.example.driver/location_service"
    private val eventChannelName = "com.example.driver/location_events"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d("MainActivity", "Configuring Flutter engine")

        // Method Channel for service control
        MethodChannel(flutterEngine.dartExecutor, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> handleStartService(call, result)
                "stopService" -> handleStopService(result)
                else -> result.notImplemented()
            }
        }

        // Event Channel for location updates
        EventChannel(flutterEngine.dartExecutor, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    Log.d("MainActivity", "EventChannel listener attached")
                    eventSink = events
                    LocationService.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    Log.d("MainActivity", "EventChannel listener detached")
                    eventSink = null
                    LocationService.setEventSink(null)
                }
            }
        )
    }

    private fun handleStartService(call: MethodCall, result: Result) {
        val token = call.argument<String>("token")
        // CORRECTED: Expect a String, not an Int
        val driverId = call.argument<String>("driverId")
        val serverUrl = call.argument<String>("serverUrl")

        if (token == null || driverId == null || serverUrl == null) {
            result.error("INVALID_ARGUMENTS", "Missing required parameters", null)
            return
        }

        checkBatteryOptimization()
        // CORRECTED: Pass the String driverId
        startLocationService(token, driverId, serverUrl)
        result.success("Service Started")
    }

    private fun handleStopService(result: Result) {
        stopLocationService()
        result.success("Service Stopped")
    }

    // CORRECTED: The signature now accepts a String for driverId
    private fun startLocationService(token: String, driverId: String, serverUrl: String) {
        val serviceIntent = Intent(this, LocationService::class.java).apply {
            putExtra("token", token)
            putExtra("driverId", driverId)
            putExtra("serverUrl", serverUrl)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun stopLocationService() {
        val serviceIntent = Intent(this, LocationService::class.java)
        stopService(serviceIntent)
    }

    private fun checkBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        }
    }

    override fun onDestroy() {
        Log.d("MainActivity", "Activity destroyed - cleaning up")
        eventSink = null
        LocationService.setEventSink(null)
        super.onDestroy()
    }
}
// package com.example.driver

// import android.content.Intent
// import android.net.Uri
// import android.os.Build
// import android.os.PowerManager
// import android.provider.Settings
// import android.util.Log
// import androidx.annotation.NonNull
// import io.flutter.embedding.android.FlutterActivity
// import io.flutter.embedding.engine.FlutterEngine
// import io.flutter.plugin.common.EventChannel
// import io.flutter.plugin.common.MethodChannel
// import io.flutter.plugin.common.MethodCall
// import io.flutter.plugin.common.MethodChannel.Result


// class MainActivity : FlutterActivity() {
//     private val methodChannelName = "com.example.driver/location_service"
//     private val eventChannelName = "com.example.driver/location_events"
//     private var eventSink: EventChannel.EventSink? = null

//     override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
//         super.configureFlutterEngine(flutterEngine)
//         Log.d("MainActivity", "Configuring Flutter engine")

//         // Method Channel for service control
//         MethodChannel(flutterEngine.dartExecutor, methodChannelName).setMethodCallHandler { call, result ->
//             when (call.method) {
//                 "startService" -> handleStartService(call, result)
//                 "stopService" -> handleStopService(result)
//                 else -> result.notImplemented()
//             }
//         }

//         // Event Channel for location updates
//         EventChannel(flutterEngine.dartExecutor, eventChannelName).setStreamHandler(
//             object : EventChannel.StreamHandler {
//                 override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
//                     Log.d("MainActivity", "EventChannel listener attached")
//                     eventSink = events
//                     LocationService.setEventSink(events)
//                 }

//                 override fun onCancel(arguments: Any?) {
//                     Log.d("MainActivity", "EventChannel listener detached")
//                     eventSink = null
//                     LocationService.setEventSink(null)
//                 }
//             }
//         )
//     }

//     private fun handleStartService(call: MethodCall, result: Result) {
//         val token = call.argument<String>("token")
//         val driverId = call.argument<Int>("driverId")
//         val serverUrl = call.argument<String>("serverUrl")

//         if (token == null || driverId == null || serverUrl == null) {
//             result.error("INVALID_ARGUMENTS", "Missing required parameters", null)
//             return
//         }

//         checkBatteryOptimization()
//         startLocationService(token, driverId, serverUrl)
//         result.success("Service Started")
//     }

//     private fun handleStopService(result: Result) {
//         stopLocationService()
//         result.success("Service Stopped")
//     }

//     private fun startLocationService(token: String, driverId: Int, serverUrl: String) {
//         val serviceIntent = Intent(this, LocationService::class.java).apply {
//             putExtra("token", token)
//             putExtra("driverId", driverId)
//             putExtra("serverUrl", serverUrl)
//         }

//         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//             startForegroundService(serviceIntent)
//         } else {
//             startService(serviceIntent)
//         }
//     }

//     private fun stopLocationService() {
//         val serviceIntent = Intent(this, LocationService::class.java)
//         stopService(serviceIntent)
//     }

//     private fun checkBatteryOptimization() {
//         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
//             val powerManager = getSystemService(POWER_SERVICE) as PowerManager
//             if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
//                 val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
//                     data = Uri.parse("package:$packageName")
//                 }
//                 startActivity(intent)
//             }
//         }
//     }

//     override fun onDestroy() {
//         Log.d("MainActivity", "Activity destroyed - cleaning up")
//         eventSink = null
//         LocationService.setEventSink(null)
//         super.onDestroy()
//     }
// }