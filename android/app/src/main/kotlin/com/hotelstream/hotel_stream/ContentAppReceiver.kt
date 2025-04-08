package com.hotelstream.hotel_stream

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * A broadcast receiver that intercepts and blocks attempts to launch content apps
 * like Netflix, YouTube, etc. This is part of the kiosk mode implementation.
 */
class ContentAppReceiver : BroadcastReceiver() {
    private val TAG = "HotelStreamKiosk"

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val data = intent.dataString
        
        Log.i(TAG, "ContentAppReceiver: Intercepted intent - action: $action, data: $data")
        
        // Block the intent by setting result
        if (isOrderedBroadcast) {
            abortBroadcast()
        }
        
        // Launch our app instead
        try {
            val launchIntent = Intent(context, MainActivity::class.java)
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            context.startActivity(launchIntent)
            
            Log.i(TAG, "ContentAppReceiver: Redirected to our app")
        } catch (e: Exception) {
            Log.e(TAG, "ContentAppReceiver: Error launching our app: ${e.message}")
        }
    }
} 