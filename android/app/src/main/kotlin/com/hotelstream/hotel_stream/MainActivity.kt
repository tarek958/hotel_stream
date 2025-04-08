package com.hotelstream.hotel_stream

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import android.view.View
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.provider.Settings
import android.content.ComponentName
import android.content.pm.PackageManager
import android.content.BroadcastReceiver.PendingResult
import android.os.Handler
import android.os.Looper
import java.util.concurrent.ConcurrentHashMap
import java.net.NetworkInterface
import java.net.InetAddress
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.hotelstream.hotel_stream/tv_controls"
    private val KIOSK_CHANNEL = "com.hotelstream/kiosk"
    private val NETWORK_CHANNEL = "com.hotel_stream/network"
    private val TAG = "HotelStreamKiosk"
    private lateinit var channel: MethodChannel
    private lateinit var kioskChannel: MethodChannel
    private lateinit var networkChannel: MethodChannel
    private var homeKeyReceiver: BroadcastReceiver? = null
    private var contentReceiver: BroadcastReceiver? = null
    private var isFallbackKioskMode = false
    
    // Key flood protection - track recent key presses to prevent rapid pressing
    private val recentKeys = ConcurrentHashMap<Int, Long>()
    private val keyFloodHandler = Handler(Looper.getMainLooper())
    private val KEY_COOLDOWN_MS = 1000L // 1 second cooldown between same key presses
    
    // List of allowed key codes - all navigation keys
    private val allowedKeyCodes = listOf(
        KeyEvent.KEYCODE_DPAD_UP,
        KeyEvent.KEYCODE_DPAD_DOWN,
        KeyEvent.KEYCODE_DPAD_LEFT,
        KeyEvent.KEYCODE_DPAD_RIGHT,
        KeyEvent.KEYCODE_DPAD_CENTER,
        KeyEvent.KEYCODE_ENTER,
        KeyEvent.KEYCODE_BACK
    )

    // Known content app keys that we specifically want to block
    private val contentAppKeys = listOf(
        4062, // Netflix key code
        227,  // YouTube key code
        228,  // Amazon Prime key code
        229,  // Various streaming services
    )

    // Known content app scan codes to block
    private val contentAppScanCodes = listOf(
        566, // Netflix scan code
        227, // YouTube scan code
        228, // Amazon Prime scan code
        229, // Various streaming services
    )
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "MainActivity created - applying kiosk mode")
        
        // Block all video content apps at startup
        blockContentApps()
        
        // Enable kiosk mode flags
        window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                       WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                       WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        
        // Disable pull-down notifications
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
        
        // Prevent screen dimming/sleep
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Android TV specific - ensure we're the top activity and block system UIs
        try {
            // Set our app as a permanent Home activity on the device
            val packageManager = packageManager
            val componentName = ComponentName(packageName, "${packageName}.MainActivity")
            packageManager.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            
            // Block system overlays - helps with Netflix button
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!Settings.canDrawOverlays(this)) {
                    Log.i(TAG, "Cannot draw overlays - some system UIs may still appear")
                }
            }
            
            // Force immersive mode for Android TV
            hideSystemUI()
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up TV kiosk mode: ${e.message}")
        }
        
        // Register HOME key broadcast receiver
        registerHomeKeyReceiver()
        
        // Start lock task mode if supported
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                startLockTask()
                Log.i(TAG, "Lock task mode started")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start lock task: ${e.message}")
                // If lock task fails, use fallback approach
                enableFallbackKioskMode()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up D-pad navigation channel
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAndroidTV" -> {
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Set up kiosk mode channel
        kioskChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KIOSK_CHANNEL)
        kioskChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enableKioskMode" -> {
                    enableKioskMode()
                    result.success(true)
                }
                "disableKioskMode" -> {
                    disableKioskMode()
                    result.success(true)
                }
                "enableFallbackKioskMode" -> {
                    isFallbackKioskMode = true
                    enableFallbackKioskMode()
                    result.success(true)
                }
                "isInFallbackMode" -> {
                    result.success(isFallbackKioskMode)
                }
                else -> result.notImplemented()
            }
        }
        
        // Set up network channel
        networkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NETWORK_CHANNEL)
        networkChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getEthernetIp" -> {
                    try {
                        val ethernetIp = getEthernetIP()
                        Log.i(TAG, "Returning Ethernet IP: $ethernetIp")
                        result.success(ethernetIp)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting Ethernet IP: ${e.message}")
                        result.error("ETHERNET_IP_ERROR", "Failed to get Ethernet IP: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        Log.i(TAG, "Method channels registered successfully")
    }
    
    private fun registerHomeKeyReceiver() {
        try {
            homeKeyReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    Log.i(TAG, "ACTION_CLOSE_SYSTEM_DIALOGS received: ${intent.action}")
                    
                    if (intent.action == Intent.ACTION_CLOSE_SYSTEM_DIALOGS) {
                        val reason = intent.getStringExtra("reason")
                        Log.i(TAG, "System dialog close reason: $reason")
                        
                        if (reason == "homekey" || reason == "recentapps") {
                            Log.i(TAG, "HOME KEY OR RECENT APPS BLOCKED VIA BROADCAST")
                            
                            // Re-apply immersive mode and lock task
                            enableKioskMode()
                            
                            // Block by bringing the app back to front
                            val bringToFrontIntent = Intent(context, MainActivity::class.java)
                            bringToFrontIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                            context.startActivity(bringToFrontIntent)
                        }
                    }
                }
            }
            
            // Register for HOME key related broadcasts
            val intentFilter = IntentFilter(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
            registerReceiver(homeKeyReceiver, intentFilter)
            Log.i(TAG, "HOME key broadcast receiver registered")
        } catch (e: Exception) {
            Log.e(TAG, "Error registering HOME key receiver: ${e.message}")
        }
    }
    
    private fun enableKioskMode() {
        Log.i(TAG, "Enabling kiosk mode")
        
        try {
            hideSystemUI()
            
            // Start lock task if supported
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    if (!am.isInLockTaskMode) {
                        startLockTask()
                        Log.i(TAG, "Lock task mode started")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start lock task: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling kiosk mode: ${e.message}")
        }
    }
    
    private fun disableKioskMode() {
        Log.i(TAG, "Disabling kiosk mode")
        
        try {
            // Exit immersive mode
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
            
            // Stop lock task mode if active
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    if (am.isInLockTaskMode) {
                        stopLockTask()
                        Log.i(TAG, "Lock task mode stopped")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error stopping lock task mode: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error disabling kiosk mode: ${e.message}")
        }
    }

    private fun enableFallbackKioskMode() {
        Log.i(TAG, "Enabling fallback kiosk mode")
        
        try {
            // Apply immersive mode
            hideSystemUI()
            
            // Set window flags to prevent interruptions
            window.addFlags(
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
            
            // Register broadcast receivers
            registerHomeKeyReceiver()
            
            // Block Netflix and other content app intents
            setupContentAppBlocking()
            
            // Mark as using fallback mode
            isFallbackKioskMode = true
            
            // Notify Flutter
            if (::kioskChannel.isInitialized) {
                kioskChannel.invokeMethod("setFallbackMode", true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling fallback kiosk mode: ${e.message}")
        }
    }

    private fun setupContentAppBlocking() {
        try {
            // The Netflix button and other dedicated app buttons typically work by sending
            // broadcast intents to launch these applications
            
            // Register a broadcast receiver to intercept content app launch intents
            val contentIntentFilter = IntentFilter()
            
            // Add common Android TV content app intents
            contentIntentFilter.addAction("android.intent.action.VIEW")
            contentIntentFilter.addAction("com.netflix.action.NETFLIX")
            contentIntentFilter.addAction("android.intent.action.MAIN")
            contentIntentFilter.addCategory("android.intent.category.LAUNCHER")
            contentIntentFilter.addCategory("android.intent.category.LEANBACK_LAUNCHER")
            
            // Netflix app
            contentIntentFilter.addDataScheme("netflix")
            
            // Register receiver to capture these intents
            contentReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    val action = intent.action
                    val data = intent.dataString
                    
                    Log.i(TAG, "Intercepted content intent: $action, data: $data")
                    
                    // If this is a content app launch attempt, block it
                    if (action == Intent.ACTION_VIEW || 
                        action == "com.netflix.action.NETFLIX" ||
                        (action == Intent.ACTION_MAIN && 
                         (intent.hasCategory(Intent.CATEGORY_LAUNCHER) || 
                          intent.hasCategory("android.intent.category.LEANBACK_LAUNCHER")))) {
                        
                        // Block the intent by setting result
                        if (isOrderedBroadcast) {
                            abortBroadcast()
                        }
                        
                        // Log that we blocked a content app launch
                        Log.i(TAG, "BLOCKED CONTENT APP LAUNCH: $action")
                        
                        // Ensure our app stays in focus
                        val bringToFrontIntent = Intent(context, MainActivity::class.java)
                        bringToFrontIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        context.startActivity(bringToFrontIntent)
                    }
                }
            }
            
            // Register the receiver with high priority
            val priority = 999
            contentIntentFilter.priority = priority
            registerReceiver(contentReceiver, contentIntentFilter)
            Log.i(TAG, "Content app blocking registered with priority $priority")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up content app blocking: ${e.message}")
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            // Simply reapply immersive mode when we gain focus
            hideSystemUI()
        }
    }
    
    override fun onDestroy() {
        try {
            if (homeKeyReceiver != null) {
                unregisterReceiver(homeKeyReceiver)
                homeKeyReceiver = null
                Log.i(TAG, "HOME key broadcast receiver unregistered")
            }
            
            // Stop lock task if active
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    if (am.isInLockTaskMode) {
                        stopLockTask()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error stopping lock task: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onDestroy: ${e.message}")
        }
        super.onDestroy()
    }

    private fun hideSystemUI() {
        // Set fullscreen flag without logging
        window.setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                       WindowManager.LayoutParams.FLAG_FULLSCREEN)
        
        // Apply immersive mode
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
        }
    }

    // Add console log method to help with debugging
    private fun consoleLog(message: String) {
        Log.i(TAG, "============== $message ==============")
    }

    // Handle key events - MAIN ENTRY POINT FOR BLOCKING KEYS
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // Get key details
        val keyCode = event.keyCode
        
        // Check if this is a content app key (like Netflix, YouTube, etc.)
        // We only want to block these specific keys
        val scanCode = event.scanCode
        
        // Create a list of content app keycodes to block
        val contentAppKeyCodes = listOf(
            172, // Netflix button on most remotes
            170, // YouTube button on most remotes
            164, // Prime Video button on some remotes
            165, // Disney+ button on some remotes
            173, // HULU button on some remotes
        )
        
        // Always allow D-pad keys - essential for navigation
        if (keyCode == KeyEvent.KEYCODE_DPAD_UP || 
            keyCode == KeyEvent.KEYCODE_DPAD_DOWN || 
            keyCode == KeyEvent.KEYCODE_DPAD_LEFT || 
            keyCode == KeyEvent.KEYCODE_DPAD_RIGHT || 
            keyCode == KeyEvent.KEYCODE_DPAD_CENTER || 
            keyCode == KeyEvent.KEYCODE_ENTER ||
            keyCode == KeyEvent.KEYCODE_BACK) {
            // Let navigation keys pass through
            return super.dispatchKeyEvent(event)
        }
        
        // Check if this is a content app key
        if (isContentAppKey(keyCode, scanCode) || contentAppKeyCodes.contains(scanCode)) {
            // Block content app keys only if DOWN event (avoid blocking twice)
            if (event.action == KeyEvent.ACTION_DOWN) {
                // Simple approach to prevent app launch
                sendBroadcast(Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS))
                return true // Block the key
            }
        }
        
        // Let all other keys pass through to Flutter
        return super.dispatchKeyEvent(event)
    }
    
    // Extra protection against direct key events
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        // Always block HOME key
        if (keyCode == KeyEvent.KEYCODE_HOME) {
            Log.i(TAG, "HOME KEY BLOCKED in onKeyDown")
            return true
        }
        
        // Allow only navigation keys
        if (!allowedKeyCodes.contains(keyCode)) {
            Log.i(TAG, "KEY BLOCKED in onKeyDown: keyCode=$keyCode")
            return true // Block the key
        }
        
        // Allow navigation keys to pass through
        return super.onKeyDown(keyCode, event)
    }
    
    // Handle long press events (especially for BACK key)
    override fun onKeyLongPress(keyCode: Int, event: KeyEvent): Boolean {
        Log.i(TAG, "Key long press: keyCode=$keyCode")
        
        // Block long press for HOME and BACK
        if (keyCode == KeyEvent.KEYCODE_HOME || keyCode == KeyEvent.KEYCODE_BACK) {
            Log.i(TAG, "LONG PRESS BLOCKED for keyCode=$keyCode")
            return true
        }
        
        return super.onKeyLongPress(keyCode, event)
    }

    private fun isContentAppKey(keyCode: Int, scanCode: Int): Boolean {
        // List of known content app key scan codes
        val contentAppScanCodes = listOf(
            172, // Netflix button on most remotes
            170, // YouTube button on most remotes 
            164, // Prime Video button on some remotes
            165, // Disney+ button on some remotes
            236, // Content app button on some remotes
        )
        
        // Most Netflix buttons have scan code 172
        if (contentAppScanCodes.contains(scanCode)) {
            return true
        }
        
        // Some devices use key codes directly
        return keyCode == 225 || // Netflix on some remotes (KEYCODE_TV_MEDIA_CONTEXT_MENU)
               keyCode == 227 || // Content app key on some remotes
               keyCode == 228    // Content app key on some remotes
    }
    
    private fun blockContentAppLaunch() {
        // Simplified approach that doesn't impact performance as much
        sendBroadcast(Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS))
        
        // We'll avoid starting a new activity instance, as that can cause UI jank
        // Just ensure immersive mode is maintained
        hideSystemUI()
    }
    
    private fun blockContentApps() {
        // Block common content apps via package manager
        try {
            // Block popular streaming apps by disabling their components
            val contentApps = listOf(
                "com.netflix.ninja",           // Netflix
                "com.netflix.mediaclient",     // Netflix alternate
                "com.google.android.youtube.tv", // YouTube TV
                "com.amazon.amazonvideo.livingroom", // Prime Video
                "com.disney.disneyplus"        // Disney+
            )
            
            for (appPackage in contentApps) {
                try {
                    // Try to disable the app's launcher components
                    val pm = packageManager
                    val componentName = ComponentName(appPackage, "$appPackage.MainActivity")
                    pm.setComponentEnabledSetting(
                        componentName,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                    Log.i(TAG, "Disabled content app: $appPackage")
                } catch (e: Exception) {
                    // App might not be installed, that's fine
                    Log.d(TAG, "Could not disable app $appPackage: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error blocking content apps: ${e.message}")
        }
    }
    
    private fun reapplyKioskProtection() {
        // Apply most aggressive kiosk protection methods
        hideSystemUI()
        
        // Re-register broadcast receivers
        try {
            // Unregister if already registered to avoid duplicates
            if (homeKeyReceiver != null) {
                try { unregisterReceiver(homeKeyReceiver) } catch (e: Exception) {}
                homeKeyReceiver = null
            }
            registerHomeKeyReceiver()
            
            // Re-register content receiver
            if (contentReceiver != null) {
                try { unregisterReceiver(contentReceiver) } catch (e: Exception) {}
                contentReceiver = null
            }
            setupContentAppBlocking()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error reapplying protection: ${e.message}")
        }
        
        // Try to enable lock task mode if possible
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                startLockTask()
            } catch (e: Exception) {
                Log.e(TAG, "Could not start lock task: ${e.message}")
            }
        }
    }
    
    private fun blockAllAppsTemporarily() {
        // Temporarily block ALL keys for a short period to prevent key flood
        Log.i(TAG, "Blocking all keys temporarily to prevent key flood")
        
        // Use timer to reset after blocking period
        keyFloodHandler.postDelayed({
            Log.i(TAG, "Key flood protection period ended")
        }, 2000) // 2 seconds
    }

    // Intercept deep links that might launch content apps
    override fun onNewIntent(intent: Intent) {
        val action = intent.action
        val data = intent.dataString
        
        Log.i(TAG, "New intent received: action=$action, data=$data")
        
        // Check if this is an attempt to launch a content app
        if (action == Intent.ACTION_VIEW && data != null) {
            if (data.contains("netflix") || 
                data.contains("youtube") || 
                data.contains("amazon") || 
                data.contains("prime") || 
                data.contains("disney")) {
                
                Log.i(TAG, "Blocked deep link to content app: $data")
                
                // Don't pass this intent to super - effectively blocking it
                // Instead, set our own blank intent
                intent.setAction(Intent.ACTION_MAIN)
                intent.data = null
                intent.replaceExtras(Bundle())
                
                // Take defensive actions
                hideSystemUI()
                return
            }
        }
        
        super.onNewIntent(intent)
    }
    
    // Block certain intents at activity level (another layer of protection)
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (data != null) {
            val action = data.action
            val dataString = data.dataString
            
            if (action == Intent.ACTION_VIEW && dataString != null) {
                if (dataString.contains("netflix") || 
                    dataString.contains("youtube") || 
                    dataString.contains("amazon") || 
                    dataString.contains("prime") || 
                    dataString.contains("disney")) {
                    
                    Log.i(TAG, "Blocked activity result for content app: $dataString")
                    
                    // Return null data
                    super.onActivityResult(requestCode, resultCode, null)
                    return
                }
            }
        }
        
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onResume() {
        super.onResume()
        
        // Ensure UI is hidden without excessive logging
        hideSystemUI()
        
        // Attempt to restart lock task if needed and available
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                if (!am.isInLockTaskMode) {
                    startLockTask()
                }
            } catch (e: Exception) {
                // Silently handle errors for better performance
            }
        }
    }
    
    override fun onPause() {
        Log.i(TAG, "Activity paused - taking defensive measures")
        
        // When app is paused, attempt to regain focus immediately
        try {
            // Force our activity back to foreground
            val intent = Intent(this, MainActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            startActivity(intent)
            
            Log.i(TAG, "Attempting to regain focus in onPause")
        } catch (e: Exception) {
            Log.e(TAG, "Error regaining focus in onPause: ${e.message}")
        }
        
        super.onPause()
    }

    private fun getEthernetIP(): String? {
        try {
            // Get all network interfaces
            val networkInterfaces = NetworkInterface.getNetworkInterfaces()
            
            // First try to find an Ethernet interface
            for (networkInterface in Collections.list(networkInterfaces)) {
                val name = networkInterface.name.lowercase(Locale.getDefault())
                Log.d(TAG, "Checking network interface: $name")
                
                // Look for ethernet interface names (eth0, en0, etc.)
                if (name.startsWith("eth") || name.startsWith("en") || name.equals("lan0")) {
                    // Check if this interface has IP addresses
                    val addresses = networkInterface.inetAddresses
                    for (address in Collections.list(addresses)) {
                        if (!address.isLoopbackAddress && address is java.net.Inet4Address) {
                            val ipAddress = address.hostAddress
                            Log.i(TAG, "Found Ethernet IP: $ipAddress on interface $name")
                            return ipAddress
                        }
                    }
                }
            }
            
            // If no dedicated Ethernet interface is found, try to find any non-wireless interface with IP
            // Get a fresh enumeration of network interfaces instead of using reset()
            val allNetworkInterfaces = NetworkInterface.getNetworkInterfaces()
            for (networkInterface in Collections.list(allNetworkInterfaces)) {
                val name = networkInterface.name.lowercase(Locale.getDefault())
                
                // Skip obvious wireless interfaces
                if (name.startsWith("wlan") || name.startsWith("w") || name.contains("wireless")) {
                    continue
                }
                
                // Skip loopback and virtual interfaces
                if (name.startsWith("lo") || name.startsWith("tun") || 
                    name.startsWith("ppp") || networkInterface.isLoopback) {
                    continue
                }
                
                // Check for IP addresses
                val addresses = networkInterface.inetAddresses
                for (address in Collections.list(addresses)) {
                    if (!address.isLoopbackAddress && address is java.net.Inet4Address) {
                        val ipAddress = address.hostAddress
                        Log.i(TAG, "Found IP address: $ipAddress on interface $name (possibly Ethernet)")
                        return ipAddress
                    }
                }
            }
            
            Log.i(TAG, "No Ethernet IP found")
            return null
        } catch (e: Exception) {
            Log.e(TAG, "Error getting Ethernet IP: ${e.message}")
            return null
        }
    }
} 
