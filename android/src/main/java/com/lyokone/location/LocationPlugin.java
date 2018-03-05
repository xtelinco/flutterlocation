package com.lyokone.location;

import android.Manifest;
import android.app.Activity;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.Context;
import android.content.BroadcastReceiver;
import android.content.IntentSender;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.location.Location;
import android.os.Build;
import android.os.Bundle;
import android.os.Looper;

import android.support.annotation.MainThread;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.util.Log;

import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.common.api.ResolvableApiException;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationSettingsRequest;
import com.google.android.gms.location.LocationSettingsResponse;
import com.google.android.gms.location.LocationSettingsStatusCodes;
import com.google.android.gms.location.SettingsClient;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.Task;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener;

import com.lyokone.location.LocationPluginReceiver;


/**
 * LocationPlugin
 */
public class LocationPlugin implements MethodCallHandler, StreamHandler, RequestPermissionsResultListener {
    private static final String STREAM_CHANNEL_NAME = "lyokone/locationstream";
    private static final String METHOD_CHANNEL_NAME = "lyokone/location";

    private static final int REQUEST_PERMISSIONS_REQUEST_CODE = 34;
    private static final int REQUEST_CHECK_SETTINGS = 0x1;
    private static final long UPDATE_INTERVAL_IN_MILLISECONDS = 10000;

    static public LocationPlugin instance;

    private FusedLocationProviderClient mFusedLocationClient;
    private SettingsClient mSettingsClient;
    private LocationCallback mLocationCallback;

    private EventSink events;
    private Activity activity;
    private boolean autoGetPermissions;
    private Result permissionsResult;

    private PendingIntent pendingIntent;
    private Location significantLocation;
    private boolean significantWakeup;


    public void setActivity(Activity activity) {
        if( activity != null && this.activity == null) {
            this.activity = activity;
            mFusedLocationClient = LocationServices.getFusedLocationProviderClient(activity);
            mSettingsClient = LocationServices.getSettingsClient(activity);
        }
    }

    LocationPlugin(Activity activity) {
        setActivity(activity);
        createLocationCallback();
        this.autoGetPermissions = true;
        significantWakeup = false;
    }

    /**
     * Creates a callback for receiving location events.
     */
    private void createLocationCallback() {
        mLocationCallback = new LocationCallback() {
            @Override
            public void onLocationResult(LocationResult locationResult) {
                super.onLocationResult(locationResult);
                Location location = locationResult.getLastLocation();
                HashMap<String, Double> loc = new HashMap<String, Double>();
                loc.put("latitude", location.getLatitude());
                loc.put("longitude", location.getLongitude());
                loc.put("accuracy", (double) location.getAccuracy());
                loc.put("altitude", location.getAltitude());
                events.success(loc);
            }
        };
    }

    /**
    * Return the current state of the permissions needed.
    */
    private boolean checkPermissions() {
        int permissionState = ActivityCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION);
        return permissionState == PackageManager.PERMISSION_GRANTED;
    }

    private void requestPermissions() {
        ActivityCompat.requestPermissions(activity, new String[] { Manifest.permission.ACCESS_FINE_LOCATION },
                REQUEST_PERMISSIONS_REQUEST_CODE);
    }

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        if(instance == null) {
            instance = new LocationPlugin(registrar.activity());
        }
        final MethodChannel channel = new MethodChannel(registrar.messenger(), METHOD_CHANNEL_NAME);
        channel.setMethodCallHandler( instance );

        final EventChannel eventChannel = new EventChannel(registrar.messenger(), STREAM_CHANNEL_NAME);
        eventChannel.setStreamHandler( instance );

        registrar.addRequestPermissionsResultListener( instance );
    }


    private void getLastLocation(final Result result) {
        mFusedLocationClient.getLastLocation().addOnSuccessListener(new OnSuccessListener<Location>() {
            @Override
            public void onSuccess(Location location) {
                if (location != null) {
                    HashMap<String, Double> loc = new HashMap<String, Double>();
                    loc.put("latitude", location.getLatitude());
                    loc.put("longitude", location.getLongitude());
                    loc.put("accuracy", (double) location.getAccuracy());
                    loc.put("altitude", location.getAltitude());
                    if (result != null) {
                        result.success(loc);
                        return;
                    }
                    events.success(loc);
                } else {
                    if (result != null) {
                        result.error("ERROR", "Failed to get location.", null);
                        return;
                    }
                    // Do not send error on events otherwise it will produce an error
                }
            }
        });
    }

    private String getAutorizationState() {
        if(checkPermissions()) {
            return "Always";
        }else if( ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.ACCESS_FINE_LOCATION) ) {
            return "Denied";
        }else{
            return "NotDetermined";
        }
    }

    @Override
    public void onMethodCall(MethodCall call, final Result result) {
        if (call.method.equals("getLocation")) {
            if (!checkPermissions()) {
                if( autoGetPermissions ) {
                    requestPermissions();
                }
                return;
            }
            getLastLocation(result);
        } else if (call.method.equals("getAuthorizationStatus")) {
            autoGetPermissions = false;
            Log.i(METHOD_CHANNEL_NAME, "Location state " + getAutorizationState());
            result.success( getAutorizationState() );
        } else if (call.method.equals("authorize")) {
            if (checkPermissions()) {
                result.success("Always");
            } else {
                permissionsResult = result;
                requestPermissions();
            }
        } else if (call.method.equals("wasStartedByLocationManager")) {
            result.success( significantWakeup ? (this.activity == null ? 2 : 1) : 0);
            significantWakeup = false;
        } else if (call.method.equals("getLastSignificantLocation")) {
            if( significantLocation != null ) {
                HashMap<String, Double> loc = new HashMap<String, Double>();
                loc.put("latitude", significantLocation.getLatitude());
                loc.put("longitude", significantLocation.getLongitude());
                loc.put("accuracy", (double) significantLocation.getAccuracy());
                loc.put("altitude", significantLocation.getAltitude());
                result.success( loc );
            }else{
                result.error("ERROR", "Failed to get location.", null);
            }
        } else if (call.method.equals("start")) {
            startListening(call.arguments, result);
        } else if (call.method.equals("stop")) {
            stopListening();
            result.success(1);
        } else if (call.method.equals("startMonitoringSignificant")) {
            startMonitoringSignificant(call.arguments, result);
        } else if (call.method.equals("stopMonitoringSignificant")) {
            stopMonitoringSignificant();
            result.success(1);
        } else {
            result.notImplemented();
        }
    }

    public void startListening(Object arguments, final Result result) {
        int accuracy = LocationRequest.PRIORITY_HIGH_ACCURACY;
        long interval = UPDATE_INTERVAL_IN_MILLISECONDS;
        boolean start = true;

        if( arguments != null && arguments instanceof Map ) {
            final Map<?, ?> args = (Map<?, ?>) arguments;
            final Number ac = (Number) args.get("accuracy");
            if (ac != null) {
                accuracy = ac.intValue();
                if (accuracy < LocationRequest.PRIORITY_HIGH_ACCURACY) {
                    accuracy = LocationRequest.PRIORITY_HIGH_ACCURACY;
                }
                if (accuracy > LocationRequest.PRIORITY_NO_POWER) {
                    accuracy = LocationRequest.PRIORITY_NO_POWER;
                }
            }
            final Number iv = (Number) args.get("interval");
            if (iv != null) {
                interval = iv.intValue();
                if (interval < 100) {
                    accuracy = 100;
                }
            }
            final Number st = (Number) args.get("start");
            if (st != null && st.intValue() == 0) {
                start = false;
            }
        }

        if( !start ) {
            if( result != null ) {
                result.success( 1 );
            }
            return;
        }

        if (!checkPermissions()) {
            if( autoGetPermissions ) {
                requestPermissions();
            }
            return;
        }


        final LocationRequest locationRequest = new LocationRequest();


        // Sets the desired interval for active location updates. This interval is
        // inexact. You may not receive updates at all if no location sources are available, or
        // you may receive them slower than requested. You may also receive updates faster than
        // requested if other applications are requesting location at a faster interval.
        locationRequest.setInterval( interval );

        // Sets the fastest rate for active location updates. This interval is exact, and your
        // application will never receive updates faster than this value.
        locationRequest.setFastestInterval( interval / 2 );

        locationRequest.setPriority( accuracy );

        LocationSettingsRequest.Builder builder = new LocationSettingsRequest.Builder();
        builder.addLocationRequest(locationRequest);

        /**
         * Requests location updates from the FusedLocationApi. Note: we don't call this unless location
         * runtime permission has been granted.
         */
        mSettingsClient.checkLocationSettings( builder.build() )
                .addOnSuccessListener(activity, new OnSuccessListener<LocationSettingsResponse>() {
                    @Override
                    public void onSuccess(LocationSettingsResponse locationSettingsResponse) {
                        mFusedLocationClient.requestLocationUpdates(locationRequest, mLocationCallback,
                                Looper.myLooper());
                        if( result != null ) {
                            result.success( 1 );
                        }
                    }
                }).addOnFailureListener(activity, new OnFailureListener() {
            @Override
            public void onFailure(@NonNull Exception e) {
                if( result != null ) {
                    result.success( 0 );
                }
                int statusCode = ((ApiException) e).getStatusCode();
                switch (statusCode) {
                    case LocationSettingsStatusCodes.RESOLUTION_REQUIRED:
                        try {
                            // Show the dialog by calling startResolutionForResult(), and check the
                            // result in onActivityResult().
                            ResolvableApiException rae = (ResolvableApiException) e;
                            rae.startResolutionForResult(activity, REQUEST_CHECK_SETTINGS);
                        } catch (IntentSender.SendIntentException sie) {
                            Log.i(METHOD_CHANNEL_NAME, "PendingIntent unable to execute request.");
                        }
                        break;
                    case LocationSettingsStatusCodes.SETTINGS_CHANGE_UNAVAILABLE:
                        String errorMessage = "Location settings are inadequate, and cannot be "
                                + "fixed here. Fix in Settings.";
                        Log.e(METHOD_CHANNEL_NAME, errorMessage);
                }
            }
        });
    }

    public void stopListening() {
        mFusedLocationClient.removeLocationUpdates(mLocationCallback);
    }

    public void startMonitoringSignificant(Object arguments, final Result result) {
        int accuracy = LocationRequest.PRIORITY_HIGH_ACCURACY;
        long interval = UPDATE_INTERVAL_IN_MILLISECONDS;
        boolean start = true;

        if( arguments != null && arguments instanceof Map ) {
            final Map<?, ?> args = (Map<?, ?>) arguments;
            final Number ac = (Number) args.get("accuracy");
            if (ac != null) {
                accuracy = ac.intValue();
                if (accuracy < LocationRequest.PRIORITY_HIGH_ACCURACY) {
                    accuracy = LocationRequest.PRIORITY_HIGH_ACCURACY;
                }
                if (accuracy > LocationRequest.PRIORITY_NO_POWER) {
                    accuracy = LocationRequest.PRIORITY_NO_POWER;
                }
            }
            final Number iv = (Number) args.get("interval");
            if (iv != null) {
                interval = iv.intValue();
                if (interval < 100) {
                    accuracy = 100;
                }
            }
            final Number st = (Number) args.get("start");
            if (st != null && st.intValue() == 0) {
                start = false;
            }
        }

        if( !start ) {
            if( result != null ) {
                result.success( 1 );
            }
            return;
        }

        if (!checkPermissions()) {
            if( autoGetPermissions ) {
                requestPermissions();
            }
            return;
        }


        final LocationRequest locationRequest = new LocationRequest();


        // Sets the desired interval for active location updates. This interval is
        // inexact. You may not receive updates at all if no location sources are available, or
        // you may receive them slower than requested. You may also receive updates faster than
        // requested if other applications are requesting location at a faster interval.
        locationRequest.setInterval( interval );

        // Sets the fastest rate for active location updates. This interval is exact, and your
        // application will never receive updates faster than this value.
        locationRequest.setFastestInterval( interval / 2 );

        locationRequest.setPriority( accuracy );

        LocationSettingsRequest.Builder builder = new LocationSettingsRequest.Builder();
        builder.addLocationRequest(locationRequest);

        /**
         * Requests location updates from the FusedLocationApi. Note: we don't call this unless location
         * runtime permission has been granted.
         */
        mSettingsClient.checkLocationSettings( builder.build() )
                .addOnSuccessListener(activity, new OnSuccessListener<LocationSettingsResponse>() {
                    @Override
                    public void onSuccess(LocationSettingsResponse locationSettingsResponse) {
                        Intent intent = new Intent( activity, LocationPluginReceiver.class );
                        pendingIntent = PendingIntent.getBroadcast( activity, 14872, intent, PendingIntent.FLAG_CANCEL_CURRENT);

                        Log.i(METHOD_CHANNEL_NAME, "Requesting background updates");
                        mFusedLocationClient.requestLocationUpdates(locationRequest, pendingIntent);
                        if( result != null ) {
                            result.success( 1 );
                        }
                    }
                }).addOnFailureListener(activity, new OnFailureListener() {
            @Override
            public void onFailure(@NonNull Exception e) {
                if( result != null ) {
                    result.success( 0 );
                }
                int statusCode = ((ApiException) e).getStatusCode();
                switch (statusCode) {
                    case LocationSettingsStatusCodes.RESOLUTION_REQUIRED:
                        try {
                            // Show the dialog by calling startResolutionForResult(), and check the
                            // result in onActivityResult().
                            ResolvableApiException rae = (ResolvableApiException) e;
                            rae.startResolutionForResult(activity, REQUEST_CHECK_SETTINGS);
                        } catch (IntentSender.SendIntentException sie) {
                            Log.i(METHOD_CHANNEL_NAME, "PendingIntent unable to execute request.");
                        }
                        break;
                    case LocationSettingsStatusCodes.SETTINGS_CHANGE_UNAVAILABLE:
                        String errorMessage = "Location settings are inadequate, and cannot be "
                                + "fixed here. Fix in Settings.";
                        Log.e(METHOD_CHANNEL_NAME, errorMessage);
                }
            }
        });
    }

    public void stopMonitoringSignificant() {
        if( pendingIntent != null ) {
            mFusedLocationClient.removeLocationUpdates(pendingIntent);
        }
    }


    @Override
    public void onListen(Object arguments, final EventSink eventsSink) {
        events = eventsSink;
        startListening(arguments, null);
    }

    @Override
    public void onCancel(Object arguments) {
        stopListening();
        events = null;
    }

    public boolean onRequestPermissionsResult(int requestCode,
                                       String[] permissions,
                                       int[] grantResults) {

        if( permissions.length>0 && permissions[0].equals(  Manifest.permission.ACCESS_FINE_LOCATION ) && permissionsResult != null) {
            permissionsResult.success( grantResults[0] == PackageManager.PERMISSION_GRANTED ? "Always" : "Denied" );
            permissionsResult = null;
        }

        return true;
    }

    public void setSignificationNewLocation( Location l ) {
        significantLocation = l;
        significantWakeup = true;
    }

    public void updateLocation( Location location ) {
        if( events != null ) {
            HashMap<String, Double> loc = new HashMap<String, Double>();
            loc.put("latitude", location.getLatitude());
            loc.put("longitude", location.getLongitude());
            loc.put("accuracy", (double) location.getAccuracy());
            loc.put("altitude", location.getAltitude());
            events.success(loc);
        }
    }
}
