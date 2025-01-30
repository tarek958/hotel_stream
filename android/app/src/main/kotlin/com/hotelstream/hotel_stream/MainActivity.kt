package com.hotelstream.hotel_stream

import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.hotelstream.hotel_stream/tv_controls"
    private lateinit var channel: MethodChannel
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Set up kiosk mode
        window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                       WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                       WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAndroidTV" -> {
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            hideSystemUI()
        }
    }

    private fun hideSystemUI() {
        window.setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                       WindowManager.LayoutParams.FLAG_FULLSCREEN)
        window.decorView.systemUiVisibility = (android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
                or android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
    }

    // Handle D-pad navigation and send events to Flutter
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_DPAD_UP -> {
                    channel.invokeMethod("dpadEvent", "up")
                    return super.dispatchKeyEvent(event)
                }
                KeyEvent.KEYCODE_DPAD_DOWN -> {
                    channel.invokeMethod("dpadEvent", "down")
                    return super.dispatchKeyEvent(event)
                }
                KeyEvent.KEYCODE_DPAD_LEFT -> {
                    channel.invokeMethod("dpadEvent", "left")
                    return super.dispatchKeyEvent(event)
                }
                KeyEvent.KEYCODE_DPAD_RIGHT -> {
                    channel.invokeMethod("dpadEvent", "right")
                    return super.dispatchKeyEvent(event)
                }
                KeyEvent.KEYCODE_DPAD_CENTER,
                KeyEvent.KEYCODE_ENTER -> {
                    channel.invokeMethod("dpadEvent", "select")
                    return super.dispatchKeyEvent(event)
                }
                // Block system keys
                KeyEvent.KEYCODE_HOME,
                KeyEvent.KEYCODE_MENU -> return true
                
                // Allow other keys
                else -> return super.dispatchKeyEvent(event)
            }
        }
        return super.dispatchKeyEvent(event)
    }
} 