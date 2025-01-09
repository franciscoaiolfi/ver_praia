package com.balneabilidade_widget
import com.example.locationprovider.LocationProvider

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.location.Location
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.locationprovider/channel"
    private lateinit var locationProvider: LocationProvider

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        locationProvider = LocationProvider(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLastKnownLocation" -> {
                    locationProvider.getLastKnownLocation { location ->
                        if (location != null) {
                            result.success(mapOf(
                                "latitude" to location.latitude,
                                "longitude" to location.longitude
                            ))
                        } else {
                            result.success(null)
                        }
                    }
                }
                "startLocationUpdates" -> {
                    locationProvider.startLocationUpdates { location ->
                    }
                    result.success(null)
                }
                "stopLocationUpdates" -> {
                    locationProvider.stopLocationUpdates()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
