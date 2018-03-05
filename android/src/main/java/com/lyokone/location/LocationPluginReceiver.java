package com.lyokone.location;

import android.content.Intent;
import android.content.BroadcastReceiver;
import android.location.Location;
import com.google.android.gms.location.LocationResult;
import android.content.Context;
import android.util.Log;

import com.lyokone.location.LocationService;




public class LocationPluginReceiver extends BroadcastReceiver {
    private static final String METHOD_CHANNEL_NAME = "lyokone/location";

    @Override
    public void onReceive(Context context, Intent intent) {
        LocationResult location = LocationResult.extractResult(intent);

        if(location != null) {
            Intent service = new Intent(context, LocationService.class);
            service.putExtra("location", location.getLastLocation());
            context.startService(service);
        }
    }
}
