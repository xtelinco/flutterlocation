package com.lyokone.location;

import android.app.Service;
import android.os.IBinder;
import android.util.Log;
import android.content.Context;
import android.content.Intent;

import android.app.Activity;
import android.app.Application;
import android.location.Location;

import io.flutter.app.FlutterActivity;
import io.flutter.app.FlutterApplication;
import io.flutter.plugin.common.PluginRegistry.PluginRegistrantCallback;
import io.flutter.view.FlutterMain;
import io.flutter.view.FlutterNativeView;
import io.flutter.plugin.common.PluginRegistry;

import com.lyokone.location.LocationPlugin;

public class LocationService extends Service {
    public static final String TAG = "LocationBackgroundService";
    private static final String METHOD_CHANNEL_NAME = "lyokone/location";
    private FlutterNativeView mFlutterView;
    private static FlutterNativeView sSharedFlutterView;
    private String appBundlePath;
    private static LocationPlugin sLocationPlugin;
    private static PluginRegistrantCallback sPluginRegistrantCallback;
    private Location lastReportedLocation;

    public static void setPluginRegistrant(PluginRegistrantCallback callback) {
        sPluginRegistrantCallback = callback;
    }

    // This returns the FlutterView for the main FlutterActivity if there is one.
    private static FlutterNativeView viewFromAppContext(Context context) {
        Application app = (Application) context;
        if (!(app instanceof FlutterApplication)) {
            Log.i(TAG, "viewFromAppContext app not a FlutterApplication");
            return null;
        }
        FlutterApplication flutterApp = (FlutterApplication) app;
        Activity activity = flutterApp.getCurrentActivity();
        if (activity == null) {
            Log.i(TAG, "viewFromAppContext activity is null");
            return null;
        }
        if (!(activity instanceof FlutterActivity)) {
            Log.i(TAG, "viewFromAppContext activity is not a FlutterActivity");
            return null;
        }
        FlutterActivity flutterActivity = (FlutterActivity) activity;
        return flutterActivity.getFlutterView().getFlutterNativeView();
    }


    public static FlutterNativeView getSharedFlutterView() {
        return sSharedFlutterView;
    }

    public static boolean setSharedFlutterView(FlutterNativeView view) {
        if (sSharedFlutterView != null && sSharedFlutterView != view) {
            return false;
        }
        sSharedFlutterView = view;
        return true;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        Context context = getApplicationContext();
        mFlutterView = viewFromAppContext(context);
        if(mFlutterView != null) {
            Application app = (Application) context;
            FlutterApplication flutterApp = (FlutterApplication) app;
         /*   Activity activity = flutterApp.getCurrentActivity();
            if( sLocationPlugin == null) {
                sLocationPlugin = new LocationPlugin( activity );
            }
*/
        }

        FlutterMain.ensureInitializationComplete(context, null);
        if (appBundlePath == null) {
            appBundlePath = FlutterMain.findAppBundlePath(context);
        }
    }

    @Override
    public void onDestroy() {
        // Try to find the native view of the main activity if there is one.
        Context context = getApplicationContext();
        FlutterNativeView nativeView = viewFromAppContext(context);

        // Don't destroy mFlutterView if it is the same as the native view for the
        // main activity, or the same as the shared native view.
        if (mFlutterView != nativeView && mFlutterView != sSharedFlutterView) {
           mFlutterView.destroy();
        }
        mFlutterView = null;

        // Don't destroy the shared native view if it is the same native view as
        // for the main activity.
        if (sSharedFlutterView != nativeView) {
               sSharedFlutterView.destroy();
        }
        sSharedFlutterView = null;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void ensureFlutterView() {
        if (mFlutterView != null) {
            return;
        }

        if (sSharedFlutterView != null) {
            mFlutterView = sSharedFlutterView;
            return;
        }

        // mFlutterView and sSharedFlutterView are both null. That likely means that
        // no FlutterView has ever been created in this process before. So, we'll
        // make one, and assign it to both mFlutterView and sSharedFlutterView.
        mFlutterView = new FlutterNativeView(getApplicationContext());
        sSharedFlutterView = mFlutterView;

        // If there was no FlutterNativeView before now, then we also must
        // initialize the PluginRegistry.
        final PluginRegistry registry = mFlutterView.getPluginRegistry();
        LocationPlugin.registerWith(registry.registrarFor("com.lyokone.location.LocationPlugin"));

       // sPluginRegistrantCallback.registerWith(mFlutterView.getPluginRegistry());
      //  Log.i(METHOD_CHANNEL_NAME, "initialisePlugins done");
        return;
    }


    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        ensureFlutterView();

        final Location location = intent.getParcelableExtra("location");
        if( location != null && LocationPlugin.instance != null) {
            LocationPlugin.instance.updateLocation(location);

            if( lastReportedLocation == null || lastReportedLocation.distanceTo( location ) > 3000 ) {
                lastReportedLocation = location;
                LocationPlugin.instance.setSignificationNewLocation(location);

                if (appBundlePath != null) {
                    mFlutterView.runFromBundle(appBundlePath, null, "background", true);
                }
            }

        }
        return START_NOT_STICKY;
    }
}