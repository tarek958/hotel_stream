# Kiosk Mode Troubleshooting Guide

This guide covers common issues you might encounter when setting up and using kiosk mode, along with their solutions.

## Device Owner Issues

### Cannot Set Device Owner

**Symptoms:**
- "Error: Not allowed to set the device owner because there are already several users on the device" message
- "Error: Not allowed to set the device owner because there are already some accounts on the device" message
- Generic "Can't set package as device owner" error

**Solutions:**
1. Factory reset the device
2. During initial setup, skip adding Google account
3. Verify no users are configured:
   ```bash
   adb shell pm list users
   ```
   You should only see the primary user (UserInfo{0:Owner:c13})
4. Try setting device owner again:
   ```bash
   adb shell dpm set-device-owner com.hotelstream.hotel_stream/flutter.lock.task.flutter_lock_task.DeviceAdmin
   ```

**If Device Owner Setup Is Impossible:**
1. Use the fallback kiosk mode:
   ```bash
   adb shell cmd package set-home-activity com.hotelstream.hotel_stream/.MainActivity
   ```
2. The app will automatically detect that it can't use lock task mode and will use fallback mode
3. You'll see an orange lock icon instead of green, indicating limited kiosk functionality

**Fallback Mode Limitations:**
- The app will launch whenever the Home button is pressed (as it's the default launcher)
- System keys are blocked through regular key interception (less secure than device owner)
- Users may still be able to access system UI in some cases
- Immersive mode will be used to hide system bars, but they can be revealed

### Device Owner Lost After App Update

**Symptoms:**
- Kiosk mode stopped working after app update
- Cannot enable lock task mode

**Solutions:**
1. Check if app is still device owner:
   ```bash
   adb shell dumpsys device_policy
   ```
2. If not, you'll need to:
   - Uninstall app completely
   - Reinstall app
   - Set device owner again
3. Consider using app update methods that preserve device owner status
4. If device owner can't be set, the app will automatically switch to fallback mode

## Key Blocking Issues

### Specific Buttons Not Blocked

**Symptoms:**
- Netflix button still working
- Other media buttons still working
- Remote keys bypass kiosk mode

**Solutions:**
1. Enable key logging in the app (tap blue eye icon)
2. Press the problematic button
3. Note the keyCode and scanCode from the log
4. Add these codes to MainActivity.kt:
   ```kotlin
   // In dispatchKeyEvent method, add:
   if (keyCode == YOUR_KEY_CODE || scanCode == YOUR_SCAN_CODE) {
       Log.i(TAG, "BLOCKED CUSTOM KEY: keyCode=$keyCode, scanCode=$scanCode")
       return true // Block the key
   }
   ```
5. Rebuild and test again

### Back Button Issues

**Symptoms:**
- Back button exits the app
- Back button behavior inconsistent

**Solutions:**
1. Ensure `WillPopScope` is implemented correctly in Flutter
2. Consider customizing back button behavior in MainActivity.kt:
   ```kotlin
   // For full kiosk mode, block back completely:
   if (keyCode == KeyEvent.KEYCODE_BACK) {
       Log.i(TAG, "BACK KEY BLOCKED")
       return true
   }
   
   // Or, for limited navigation:
   if (keyCode == KeyEvent.KEYCODE_BACK) {
       channel.invokeMethod("dpadEvent", "back")
       return true // Let Flutter handle it
   }
   ```

## Lock Task Mode Issues

### Lock Task Doesn't Activate

**Symptoms:**
- "Failed to start lock task" error in logs
- App doesn't stay in foreground

**Solutions:**
1. Verify app is device owner (see above)
2. Check Android version (must be Android 5.0+)
3. For Android 9.0+, add package to allowed packages:
   ```bash
   adb shell dpm set-lock-task-features [admin-component] [flags]
   ```
4. Check logs for specific errors:
   ```bash
   adb logcat -s HotelStreamKiosk
   ```

### App Still Exits to Home Screen

**Symptoms:**
- Home button still works despite kiosk mode
- System buttons bypass kiosk mode

**Solutions:**
1. Implement broadcast receiver for `ACTION_CLOSE_SYSTEM_DIALOGS`
2. Use immersive sticky mode for UI
3. Consider using additional flags in window layout:
   ```kotlin
   window.setFlags(
       WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
       WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
       WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
       WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
       WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
       WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
   )
   ```

## System Dialogs and Notifications

### System Dialogs Appear Over App

**Symptoms:**
- System alerts appear over kiosk app
- "App not responding" dialogs break kiosk mode

**Solutions:**
1. Implement `onWindowFocusChanged` to regain focus
2. Send `ACTION_CLOSE_SYSTEM_DIALOGS` broadcast
3. Optimize app performance to prevent ANR dialogs
4. Add permission in manifest:
   ```xml
   <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
   ```

### System Updates Break Kiosk Mode

**Symptoms:**
- System update notifications appear
- Updates install and restart device

**Solutions:**
1. Disable automatic updates in system settings
2. Consider using an MDM solution to control updates
3. If possible, temporarily disable update service:
   ```bash
   adb shell pm disable-user com.google.android.gms/.update.SystemUpdateService
   ```
   (Requires device owner or root)

## Boot and Restart Issues

### App Doesn't Auto-Start

**Symptoms:**
- App doesn't start after device reboot
- Need to manually launch app

**Solutions:**
1. Check boot receiver is registered in manifest:
   ```xml
   <receiver
       android:name=".BootReceiver"
       android:enabled="true"
       android:exported="true">
       <intent-filter>
           <action android:name="android.intent.action.BOOT_COMPLETED" />
           <category android:name="android.intent.category.DEFAULT" />
       </intent-filter>
   </receiver>
   ```
2. Verify boot permissions:
   ```xml
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
   ```
3. Test boot receiver manually:
   ```bash
   adb shell am broadcast -a android.intent.action.BOOT_COMPLETED
   ```

## Emergency Exit Procedure

For development and testing purposes, you may need an emergency exit from kiosk mode:

1. Connect ADB (USB debugging must be enabled)
2. Run:
   ```bash
   adb shell am force-stop com.hotelstream.hotel_stream
   ```
3. Or, remove device admin:
   ```bash
   adb shell dpm remove-active-admin com.hotelstream.hotel_stream/flutter.lock.task.flutter_lock_task.DeviceAdmin
   ```

If ADB is not available, try this factory reset sequence (may vary by device):
1. Power off device
2. Hold Volume Up + Power
3. Select factory reset option

## Additional Resources

- [Android Developer Documentation: Lock Task Mode](https://developer.android.com/work/dpc/dedicated-devices/lock-task-mode)
- [Flutter Lock Task Package Documentation](https://pub.dev/packages/flutter_lock_task)
- [Android Device Policy Controller Guide](https://developers.google.com/android/management/create-dpc)
- [Android EMM Community Discussion](https://groups.google.com/forum/#!forum/android-emm-apis) 