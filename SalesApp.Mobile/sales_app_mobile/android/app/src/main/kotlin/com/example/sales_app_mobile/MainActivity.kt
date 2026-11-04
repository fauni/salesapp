package com.example.sales_app_mobile

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Client requirement: no screenshots / screen recording of the app.
        // FLAG_SECURE also blanks the app's preview in the recent-apps switcher
        // and blocks casting the screen to non-secure displays.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }
}
