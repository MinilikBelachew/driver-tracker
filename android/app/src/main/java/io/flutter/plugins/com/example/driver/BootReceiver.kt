package com.example.driver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.widget.Toast

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("BootReceiver", "Received broadcast: ${intent.action}")
        Toast.makeText(context, "BootReceiver triggered!", Toast.LENGTH_LONG).show()
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON" -> {
                startLocationService(context)
            }
        }
    }

    private fun startLocationService(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = prefs.getString("flutter.token", null)
        val driverId = prefs.getString("flutter.driverId", "")
        val serverUrl = prefs.getString("flutter.serverUrl", "https://driver-cotrolling.onrender.com")

        if (token != null && driverId != null && driverId.isNotEmpty()) {
            val serviceIntent = Intent(context, LocationService::class.java).apply {
                putExtra("token", token)
                putExtra("driverId", driverId)
                putExtra("serverUrl", serverUrl)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_RECEIVER_FOREGROUND
            }

            Log.d("BootReceiver", "Starting service with token: $token, driverId: $driverId")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } else {
            Log.d("BootReceiver", "Not starting service - missing credentials")
        }
    }
}