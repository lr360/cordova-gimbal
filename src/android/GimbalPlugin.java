package com.gimbal;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult.Status;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.Context;
import android.graphics.Rect;
import android.util.DisplayMetrics;
import android.view.View;
import android.view.ViewTreeObserver.OnGlobalLayoutListener;
import android.view.inputmethod.InputMethodManager;

import com.gimbal.logging.GimbalLogConfig;
import com.gimbal.logging.GimbalLogLevel;
import com.gimbal.proximity.Proximity;
import com.gimbal.proximity.ProximityError;
import com.gimbal.proximity.ProximityListener;

import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.Menu;
import android.view.View;
import android.widget.CompoundButton;
import android.widget.Switch;
import android.widget.Toast;

public class GimbalPlugin extends CordovaPlugin implements ProximityListener {

    private final static int REQUEST_ENABLE_BT = 1;
    private static final String PROXIMITY_SERVICE_ENABLED_KEY = "proximity.service.enabled";
    private static final String TAG = GimbalPlugin.class.getSimpleName();

    private VisitManagerHandler manager;

    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        Log.d(TAG, "CODENAME: " + Build.VERSION.CODENAME);
        Log.d(TAG, "INCREMENTAL: " + Build.VERSION.INCREMENTAL);
        Log.d(TAG, "RELEASE: " + Build.VERSION.RELEASE);
        Log.d(TAG, "SDK_INT: " + Build.VERSION.SDK_INT);

        initializeProximity();

        String proximityServiceEnabled = getUserPreference(PROXIMITY_SERVICE_ENABLED_KEY);
        if (proximityServiceEnabled != null && Boolean.valueOf(proximityServiceEnabled)) {
            startProximityService();
        }
    }

    private void initializeProximity() {
        Log.d(TAG, "initializeProximity");

        GimbalLogConfig.setLogLevel(GimbalLogLevel.INFO);
        GimbalLogConfig.enableFileLogging(this.cordova.getActivity().getApplicationContext());
    }

    @Override
    public boolean execute (String action, final JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equalsIgnoreCase("startService")) {
            cordova.getThreadPool().execute( new Runnable() {
                public void run() {
                    JSONObject arguments = args.optJSONObject(0);
                    String appId = args.optString(0);
                    String appSecret = args.optString(1);

                    Proximity.initialize(cordova.getActivity(), appId, appSecret);
                    Proximity.optimizeWithApplicationLifecycle(cordova.getActivity().getApplication());
                }
            });

            return true;
        }

        return false;
    }

    private void startProximityService() {
        Log.d(TAG, "startSession");
        Proximity.startService(this);
    }

   @Override
    public void serviceStarted() {
        Log.d(TAG, "serviceStarted");
        showTransmitters();
    }

    @Override
    public void startServiceFailed(int errorCode, String message) {
        Log.e(TAG, "serviceFailed because of " + message);

        String logMsg = String.format("Proximity Service failed with error code %d, message: %s!", errorCode, message);
        Log.d("Proximity", logMsg);

        if (errorCode == ProximityError.PROXIMITY_BLUETOOTH_IS_OFF.getCode()) {
            turnONBluetooth();
        }
    }

    private void turnONBluetooth() {
        Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
        this.cordova.getActivity().startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT);
    }

    private void showTransmitters() {
        Log.d(TAG, "session started callback");

        manager = new VisitManagerHandler();
        manager.init(this.webView);
        manager.startScanning();
    }

    private void saveUserPreferrence(String key, String value) {
        SharedPreferences sharedPreferences = this.cordova.getActivity().getSharedPreferences(this.cordova.getActivity().getPackageName(), this.cordova.getActivity().MODE_PRIVATE);
        Editor editor = sharedPreferences.edit();
        editor.putString(key, value);
        editor.commit();
    }

    private String getUserPreference(String key) {
        SharedPreferences sharedPreferences = this.cordova.getActivity().getSharedPreferences(this.cordova.getActivity().getPackageName(), this.cordova.getActivity().MODE_PRIVATE);
        return sharedPreferences.getString(key, null);
    }
}
