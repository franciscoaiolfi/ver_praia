package com.example.locationprovider

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.os.Looper
import android.util.Log
import com.google.android.gms.location.*

class LocationProvider(context: Context) {

    private val fusedLocationClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)

    private val locationRequest: LocationRequest = LocationRequest.create().apply {
        interval = 10000
        fastestInterval = 5000
        priority = Priority.PRIORITY_HIGH_ACCURACY
    }

    private var locationCallback: LocationCallback? = null
    private var currentLocation: Location? = null

    @SuppressLint("MissingPermission")
    fun startLocationUpdates(onLocationUpdate: (Location?) -> Unit) {
        Log.d("LocationProvider", "Iniciando atualizações de localização")

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                super.onLocationResult(locationResult)
                currentLocation = locationResult.lastLocation

                if (currentLocation != null) {
                    Log.d("LocationProvider", "Localização atual: Lat=${currentLocation?.latitude}, Lon=${currentLocation?.longitude}")
                } else {
                    Log.d("LocationProvider", "Localização não encontrada na callback")
                }

                onLocationUpdate(currentLocation)
            }

            override fun onLocationAvailability(locationAvailability: LocationAvailability) {
                super.onLocationAvailability(locationAvailability)
                Log.d("LocationProvider", "Disponibilidade de localização: ${locationAvailability.isLocationAvailable}")
            }
        }

        fusedLocationClient.requestLocationUpdates(
            locationRequest,
            locationCallback!!,
            Looper.getMainLooper()
        )
    }

    fun stopLocationUpdates() {
        Log.d("LocationProvider", "Parando atualizações de localização")
        locationCallback?.let {
            fusedLocationClient.removeLocationUpdates(it)
        }
        locationCallback = null
    }

    @SuppressLint("MissingPermission")
    fun getLastKnownLocation(onSuccess: (Location?) -> Unit) {
        Log.d("LocationProvider", "Tentando obter última localização conhecida")
        fusedLocationClient.lastLocation.addOnSuccessListener { location ->
            if (location != null) {
                Log.d("LocationProvider", "Última localização conhecida: Lat=${location.latitude}, Lon=${location.longitude}")
            } else {
                Log.d("LocationProvider", "Última localização conhecida não disponível")
            }
            onSuccess(location)
        }.addOnFailureListener { e ->
            Log.e("LocationProvider", "Erro ao obter última localização conhecida: ${e.message}", e)
            onSuccess(null)
        }
    }
}
