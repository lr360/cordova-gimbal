package com.gimbal;

import java.util.Date;
import java.util.LinkedHashMap;

import android.util.Log;

import org.apache.cordova.CordovaWebView;

import com.gimbal.proximity.ProximityFactory;
import com.gimbal.proximity.ProximityOptions;
import com.gimbal.proximity.Visit;
import com.gimbal.proximity.VisitListener;
import com.gimbal.proximity.VisitManager;

public class VisitManagerHandler implements VisitListener {

    private static final String TAG = "VisitManagerHandler";
    private CordovaWebView webView = null;

    private final LinkedHashMap<String, TransmitterAttributes> transmitters = new LinkedHashMap<String, TransmitterAttributes>();
    private final VisitManager visitManager = ProximityFactory.getInstance().createVisitManager();
    //private ProximityTransmittersActivity activity;

    public void init(CordovaWebView webView) {
        //this.activity = activity;
        this.webView = webView;
    }

    public void stopScanning() {
        visitManager.stop();
    }

    public void startScanning() {
        startScanningWithOptions();
    }

    private void startScanningWithOptions() {
        visitManager.setVisitListener(this);
        ProximityOptions options = new ProximityOptions();
        options.setOption(ProximityOptions.VisitOptionSignalStrengthWindowKey,
                ProximityOptions.VisitOptionSignalStrengthWindowNone);
        visitManager.startWithOptions(options);
    }

    @Override
    public void receivedSighting(Visit visit, Date updateTime, Integer rssi) {
        Log.d(TAG, "I received a sighting! " + visit.getTransmitter().getName() + "and RSSI is:" + rssi);

        String name = visit.getTransmitter().getName();

        TransmitterAttributes attributes = new TransmitterAttributes();
        attributes.setBattery(visit.getTransmitter().getBattery());
        attributes.setIdentifier(visit.getTransmitter().getIdentifier());
        attributes.setName(visit.getTransmitter().getName());
        attributes.setTemperature(visit.getTransmitter().getTemperature());
        attributes.setRssi(rssi);
        attributes.setDepart(false);
        transmitters.put(name, attributes);

        //this.activity.addDevice(transmitters);
        fireEvent("proximity", attributes.getIdentifier(), attributes.getName(), attributes.getRssi());
    }

    @Override
    public void didArrive(Visit visit) {
        Log.d(TAG, "I got ARRIVE for " + visit.getTransmitter().getName());
    }

    @Override
    public void didDepart(Visit visit) {
        Log.d(TAG, "I got DEPART for " + visit.getTransmitter().getName());

        String name = visit.getTransmitter().getName();
        TransmitterAttributes attributes = new TransmitterAttributes();
        attributes.setDepart(true);
        transmitters.put(name, attributes);

        //this.activity.addDevice(transmitters);
    }

    /**
     * Fires the given event.
     *
     * @param {String} event The Name of the event
     * @param {String} id    The ID of the notification
     * @param {String} json  A custom (JSON) string
     */
    public void fireEvent (String event, String identifier, String name, int rssi) {
        Log.d(TAG, "Fire Event: " + identifier + ", " + rssi);
        String params = "\"" + identifier + "\",\"" + name + "\",\\'" + rssi + "\\'.replace(/(^\"|\"$)/g, \\'\\')";
        String js     = "setTimeout('window.gimbal.on" + event + "(" + params + ")',0)";
        this.webView.sendJavascript(js);
    }
}
