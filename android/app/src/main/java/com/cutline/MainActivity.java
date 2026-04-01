package com.cutline;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.content.IntentSender;
import android.content.pm.PackageManager;
import android.location.Location;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import com.google.android.gms.common.api.ResolvableApiException;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationAvailability;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.LocationSettingsRequest;
import com.google.android.gms.location.LocationSettingsStatusCodes;
import com.google.android.gms.location.Priority;
import com.google.android.gms.location.SettingsClient;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "cutline/device_location";
    private static final int REQUEST_CODE_ENABLE_LOCATION = 4812;
    private static final long DEFAULT_TIMEOUT_MS = 18000L;
    private static final long DEFAULT_MAX_AGE_MS = 45000L;
    private static final float DEFAULT_MAX_ACCURACY_METERS = 120f;

    private MethodChannel.Result pendingLocationResult;
    private FusedLocationProviderClient fusedLocationClient;
    private Handler handler;
    private LocationCallback locationCallback;
    private Runnable timeoutRunnable;
    private Location bestLocation;
    private long pendingTimeoutMs = DEFAULT_TIMEOUT_MS;
    private long pendingMaxAgeMs = DEFAULT_MAX_AGE_MS;
    private float pendingMaxAccuracyMeters = DEFAULT_MAX_ACCURACY_METERS;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this);
        handler = new Handler(Looper.getMainLooper());

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("getPreciseCurrentLocation".equals(call.method)) {
                        handlePreciseCurrentLocation(call, result);
                    } else {
                        result.notImplemented();
                    }
                });
    }

    private void handlePreciseCurrentLocation(MethodCall call, MethodChannel.Result result) {
        if (pendingLocationResult != null) {
            result.error("IN_PROGRESS", "Another location request is already running.", null);
            return;
        }

        final boolean hasFine = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED;
        final boolean hasCoarse = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED;

        if (!hasFine && !hasCoarse) {
            result.error("PERMISSION_DENIED", "Location permission is required.", null);
            return;
        }
        if (!hasFine) {
            result.error(
                    "PRECISE_PERMISSION_REQUIRED",
                    "Enable precise location permission to use live GPS.",
                    null
            );
            return;
        }

        Number timeoutArg = call.argument("timeoutMs");
        Number maxAgeArg = call.argument("maxAgeMs");
        Number accuracyArg = call.argument("maxAccuracyMeters");

        pendingTimeoutMs = timeoutArg == null
                ? DEFAULT_TIMEOUT_MS
                : Math.max(5000L, timeoutArg.longValue());
        pendingMaxAgeMs = maxAgeArg == null
                ? DEFAULT_MAX_AGE_MS
                : Math.max(5000L, maxAgeArg.longValue());
        pendingMaxAccuracyMeters = accuracyArg == null
                ? DEFAULT_MAX_ACCURACY_METERS
                : Math.max(20f, accuracyArg.floatValue());

        pendingLocationResult = result;
        bestLocation = null;
        checkLocationSettingsAndResolve();
    }

    private void checkLocationSettingsAndResolve() {
        LocationRequest request = buildLocationRequest();
        LocationSettingsRequest settingsRequest = new LocationSettingsRequest.Builder()
                .addLocationRequest(request)
                .setAlwaysShow(true)
                .build();

        SettingsClient settingsClient = LocationServices.getSettingsClient(this);
        settingsClient
                .checkLocationSettings(settingsRequest)
                .addOnSuccessListener(unused -> requestPreciseCurrentLocation())
                .addOnFailureListener(error -> {
                    if (!(error instanceof ResolvableApiException)) {
                        finishWithError("SERVICE_DISABLED", "Turn on GPS to continue.");
                        return;
                    }

                    ResolvableApiException resolvable = (ResolvableApiException) error;
                    if (resolvable.getStatusCode()
                            != LocationSettingsStatusCodes.RESOLUTION_REQUIRED) {
                        finishWithError("SERVICE_DISABLED", "Turn on GPS to continue.");
                        return;
                    }

                    try {
                        resolvable.startResolutionForResult(
                                this,
                                REQUEST_CODE_ENABLE_LOCATION
                        );
                    } catch (IntentSender.SendIntentException e) {
                        finishWithError("SERVICE_DISABLED", "Turn on GPS to continue.");
                    }
                });
    }

    @SuppressLint("MissingPermission")
    private void requestPreciseCurrentLocation() {
        cleanupLocationCallbacks();
        scheduleTimeout();

        locationCallback = new LocationCallback() {
            @Override
            public void onLocationResult(@NonNull LocationResult locationResult) {
                Location latest = locationResult.getLastLocation();
                if (latest != null && maybeFinishWithLocation(latest)) {
                    return;
                }
                for (Location location : locationResult.getLocations()) {
                    if (maybeFinishWithLocation(location)) {
                        return;
                    }
                }
            }

            @Override
            public void onLocationAvailability(@NonNull LocationAvailability availability) {
                if (!availability.isLocationAvailable() && bestLocation == null) {
                    // Keep waiting until timeout. Temporary unavailability is common indoors.
                }
            }
        };

        fusedLocationClient.requestLocationUpdates(
                buildLocationRequest(),
                locationCallback,
                Looper.getMainLooper()
        ).addOnFailureListener(
                error -> finishWithError(
                        "LOCATION_UNAVAILABLE",
                        "Could not get a live GPS location."
                )
        );
    }

    @SuppressWarnings("deprecation")
    private LocationRequest buildLocationRequest() {
        LocationRequest request = LocationRequest.create();
        request.setPriority(Priority.PRIORITY_HIGH_ACCURACY);
        request.setInterval(1000L);
        request.setFastestInterval(500L);
        request.setSmallestDisplacement(0f);
        request.setMaxWaitTime(2000L);
        request.setWaitForAccurateLocation(true);
        return request;
    }

    private boolean maybeFinishWithLocation(Location location) {
        if (!isRequestActive() || location == null) {
            return false;
        }
        if (isMockLocation(location)) {
            finishWithError(
                    "MOCK_LOCATION",
                    "Mock location detected. Turn off mock location in developer options."
            );
            return true;
        }
        if (!isFreshEnough(location)) {
            return false;
        }

        if (bestLocation == null || isBetterLocation(location, bestLocation)) {
            bestLocation = location;
        }
        if (!isAccurateEnough(location)) {
            return false;
        }

        finishWithSuccess(location);
        return true;
    }

    private boolean isFreshEnough(Location location) {
        long timestampMs = location.getTime();
        if (timestampMs <= 0) {
            return false;
        }
        long ageMs = Math.max(0L, System.currentTimeMillis() - timestampMs);
        return ageMs <= pendingMaxAgeMs;
    }

    private boolean isAccurateEnough(Location location) {
        return location.hasAccuracy()
                && location.getAccuracy() > 0f
                && location.getAccuracy() <= pendingMaxAccuracyMeters;
    }

    private boolean isBetterLocation(Location candidate, Location currentBest) {
        if (currentBest == null) {
            return true;
        }
        if (!candidate.hasAccuracy()) {
            return false;
        }
        if (!currentBest.hasAccuracy()) {
            return true;
        }
        if (candidate.getAccuracy() < currentBest.getAccuracy()) {
            return true;
        }
        return candidate.getTime() > currentBest.getTime();
    }

    private boolean isMockLocation(Location location) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return location.isMock();
        }
        //noinspection deprecation
        return location.isFromMockProvider();
    }

    private void scheduleTimeout() {
        cancelTimeout();
        timeoutRunnable = () -> {
            if (!isRequestActive()) {
                return;
            }
            if (bestLocation != null
                    && isFreshEnough(bestLocation)
                    && isAccurateEnough(bestLocation)) {
                finishWithSuccess(bestLocation);
                return;
            }
            finishWithError(
                    "LOCATION_UNAVAILABLE",
                    "Could not get an accurate live GPS location."
            );
        };
        handler.postDelayed(timeoutRunnable, pendingTimeoutMs);
    }

    private void cancelTimeout() {
        if (timeoutRunnable == null) {
            return;
        }
        handler.removeCallbacks(timeoutRunnable);
        timeoutRunnable = null;
    }

    private boolean isRequestActive() {
        return pendingLocationResult != null;
    }

    private void finishWithSuccess(Location location) {
        MethodChannel.Result result = pendingLocationResult;
        if (result == null) {
            cleanupLocationCallbacks();
            return;
        }

        Map<String, Object> payload = new HashMap<>();
        payload.put("latitude", location.getLatitude());
        payload.put("longitude", location.getLongitude());
        payload.put("accuracy", location.hasAccuracy() ? location.getAccuracy() : 0d);
        payload.put("isMocked", isMockLocation(location));
        payload.put("provider", location.getProvider());
        payload.put("timestampMs", location.getTime());

        pendingLocationResult = null;
        cleanupLocationCallbacks();
        result.success(payload);
    }

    private void finishWithError(String code, String message) {
        MethodChannel.Result result = pendingLocationResult;
        if (result == null) {
            cleanupLocationCallbacks();
            return;
        }

        pendingLocationResult = null;
        cleanupLocationCallbacks();
        result.error(code, message, null);
    }

    private void cleanupLocationCallbacks() {
        cancelTimeout();

        if (locationCallback != null && fusedLocationClient != null) {
            fusedLocationClient.removeLocationUpdates(locationCallback);
            locationCallback = null;
        }
        bestLocation = null;
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        if (requestCode != REQUEST_CODE_ENABLE_LOCATION || pendingLocationResult == null) {
            return;
        }

        if (resultCode == Activity.RESULT_OK) {
            requestPreciseCurrentLocation();
        } else {
            finishWithError("RESOLUTION_CANCELLED", "GPS was not enabled.");
        }
    }

    @Override
    protected void onDestroy() {
        cleanupLocationCallbacks();
        super.onDestroy();
    }
}
