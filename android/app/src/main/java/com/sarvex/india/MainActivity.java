package com.sarvex.india;

import android.graphics.Color;
import android.os.Bundle;
import android.view.Window;

import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Keep Android system bars outside the WebView content area.
        // This prevents the marketplace header from drawing underneath
        // the clock, network, and battery indicators on edge-to-edge devices.
        WindowCompat.setDecorFitsSystemWindows(getWindow(), true);

        Window window = getWindow();
        window.setStatusBarColor(Color.rgb(23, 37, 84));
        WindowInsetsControllerCompat insetsController =
                new WindowInsetsControllerCompat(window, window.getDecorView());
        insetsController.setAppearanceLightStatusBars(false);
        window.setNavigationBarColor(Color.rgb(255, 255, 255));
    }
}
