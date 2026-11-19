package com.urbandevicecare.pos.scanner;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import com.urbandevicecare.pos.MainActivity;

/**
 * BroadcastReceiver for the CS30 Android 11 smart POS and generic handheld ETR
 * hardware barcode scanners.
 */
public class CS30BarcodeReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) return;

        String barcode = null;

        // Supported CS30, Sunmi, Newland, Zebra SE4500, and generic POS intent extras
        if (intent.hasExtra("data")) {
            barcode = intent.getStringExtra("data");
        } else if (intent.hasExtra("barcode_string")) {
            barcode = intent.getStringExtra("barcode_string");
        } else if (intent.hasExtra("scannerdata")) {
            barcode = intent.getStringExtra("scannerdata");
        } else if (intent.hasExtra("scan_result")) {
            barcode = intent.getStringExtra("scan_result");
        } else if (intent.hasExtra("nlscan.action.SCANNER_RESULT")) {
            barcode = intent.getStringExtra("nlscan.action.SCANNER_RESULT");
        } else if (intent.hasExtra("EXTRA_SCAN_DATA")) {
            barcode = intent.getStringExtra("EXTRA_SCAN_DATA");
        } else if (intent.hasExtra("se4500")) {
            barcode = intent.getStringExtra("se4500");
        }

        if (barcode != null && !barcode.trim().isEmpty()) {
            MainActivity activity = MainActivity.getInstance();
            if (activity != null) {
                activity.onBarcodeScanned(barcode.trim());
            }
        }
    }
}
