package com.example.driver

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import io.flutter.plugin.common.EventChannel
import io.socket.client.IO
import io.socket.client.Socket
import org.json.JSONObject
import java.net.URISyntaxException

class LocationService : Service() {
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private var socket: Socket? = null
    private var driverId: Int = -1
    private var token: String? = null
    private var serverUrl: String? = null

    companion object {
        private var eventSink: EventChannel.EventSink? = null
        private var hasActiveListeners = false
        const val NOTIFICATION_CHANNEL_ID = "LocationServiceChannel"
        const val NOTIFICATION_ID = 12345

        fun setEventSink(sink: EventChannel.EventSink?) {
            eventSink = sink
            hasActiveListeners = sink != null
            Log.d("LocationService", "Event sink ${if (sink != null) "set" else "cleared"}")
        }

        private fun sendLocationUpdate(lat: Double, lng: Double) {
            if (!hasActiveListeners) return
            
            try {
                Handler(Looper.getMainLooper()).post {
                    eventSink?.success(mapOf(
                        "lat" to lat,
                        "lng" to lng,
                        "timestamp" to System.currentTimeMillis()
                    ))
                }
            } catch (e: Exception) {
                Log.e("LocationService", "Error sending location update", e)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        Log.d("LocationService", "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("LocationService", "Service starting")

        // Handle potential null intent (system restart)
        if (intent == null) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            token = prefs.getString("flutter.token", null)
            driverId = prefs.getInt("flutter.driverId", -1)
            serverUrl = prefs.getString("flutter.serverUrl", null)
            
            if (token == null || driverId == -1 || serverUrl == null) {
                stopSelf()
                return START_NOT_STICKY
            }
        } else {
            token = intent.getStringExtra("token")
            driverId = intent.getIntExtra("driverId", -1)
            serverUrl = intent.getStringExtra("serverUrl")
        }

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())

        if (token != null && driverId != -1 && serverUrl != null) {
            startLocationUpdates()
            connectSocket(serverUrl!!)
        } else {
            stopSelf()
        }

        return START_STICKY
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Driver Tracking Active")
            .setContentText("Your location is being shared in real-time")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Location Service Channel",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Channel for location tracking service"
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun startLocationUpdates() {
        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            10000L // 10 seconds
        ).apply {
            setMinUpdateIntervalMillis(5000L) // 5 seconds minimum
            setWaitForAccurateLocation(true)
        }.build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    Log.d("LocationService", "New location: ${location.latitude}, ${location.longitude}")
                    sendLocationToServer(location.latitude, location.longitude)
                }
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
            Log.d("LocationService", "Location updates started")
        } catch (e: SecurityException) {
            Log.e("LocationService", "Location permission not granted", e)
            stopSelf()
        }
    }

    private fun connectSocket(serverUrl: String) {
        try {
            val opts = IO.Options().apply {
                transports = arrayOf("websocket")
                auth = mapOf("token" to token)
                reconnection = true
                reconnectionAttempts = Int.MAX_VALUE
                reconnectionDelay = 1000
                reconnectionDelayMax = 5000
            }
            
            socket = IO.socket(serverUrl, opts).apply {
                on(Socket.EVENT_CONNECT) {
                    Log.i("LocationService", "Socket connected")
                }
                on(Socket.EVENT_DISCONNECT) { args ->
                    Log.w("LocationService", "Socket disconnected: ${args.joinToString()}")
                }
                on(Socket.EVENT_CONNECT_ERROR) { args ->
                    Log.e("LocationService", "Socket connect error: ${args[0]}")
                }
                connect()
            }
            Log.d("LocationService", "Socket connection initiated")
        } catch (e: URISyntaxException) {
            Log.e("LocationService", "Invalid server URL", e)
            stopSelf()
        }
    }

    private fun sendLocationToServer(lat: Double, lng: Double) {
        // Send to server
        if (socket?.connected() == true) {
            val locationData = JSONObject().apply {
                put("driverId", driverId)
                put("lat", lat)
                put("lng", lng)
                put("token", token)
                put("timestamp", System.currentTimeMillis())
            }
            socket?.emit("driverLocation", locationData)
        }
        
        // Send to Flutter
        sendLocationUpdate(lat, lng)
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("LocationService", "Service destroyed - cleaning up")
        
        try {
            fusedLocationClient.removeLocationUpdates(locationCallback)
            socket?.disconnect()
            socket = null
            eventSink = null
            hasActiveListeners = false
        } catch (e: Exception) {
            Log.e("LocationService", "Error during cleanup", e)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}