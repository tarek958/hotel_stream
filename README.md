# Hotel Stream TV App

A TV-optimized application for hotel streaming services.

## Kiosk Mode Setup

This app uses kiosk mode to lock the device to single-app usage, preventing users from accessing system buttons and other apps.

### Setting Up Kiosk Mode

1. **Android Permissions and Configuration**
   - The app requires device admin privileges for full kiosk mode
   - All needed permissions are already configured in the AndroidManifest.xml file
   - The app is pre-configured to intercept and block all system keys except navigation keys (up, down, left, right, OK, back)

2. **Setting Device Owner (Required for full kiosk functionality)**
   
   For Android TV devices or tablets running Android 6.0+, you need to set the app as device owner. This requires ADB access.

   ```
   # First uninstall any existing version of the app
   adb uninstall com.hotelstream.hotel_stream
   
   # Then install the app
   adb install app-release.apk
   
   # Then set as device owner (one-time setup)
   adb shell dpm set-device-owner com.hotelstream.hotel_stream/flutter.lock.task.flutter_lock_task.DeviceAdmin
   ```

   **Note:** To view your package name from the app, tap the blue eye icon in the top left corner to show the key log, then tap the info icon in the log panel.

3. **Fallback Kiosk Mode**

   If setting device owner isn't possible (e.g., on retail TVs or devices with permanent Google accounts), you can use the fallback mode:

   ```
   # Set the app as the default home screen
   adb shell cmd package set-home-activity com.hotelstream.hotel_stream/.MainActivity
   ```

   Fallback Mode Limitations:
   - The app will be the default launcher, so Home button will launch the app
   - System keys are blocked via regular key interception (not as secure)
   - The orange lock icon indicates fallback mode is active
   - User can still access system UI in some cases

4. **Important Notes:**
   - Make sure to remove any accounts from the device before setting device owner
   - This is typically a one-time setup per device
   - Once device owner is set, kiosk mode will be fully functional

5. **Usage in the App**
   - The app automatically starts in kiosk mode when opened
   - A small green lock icon indicates when full kiosk mode is active
   - An orange lock icon indicates fallback kiosk mode is active
   - Kiosk mode can be toggled using the lock icon in the corner (only shown in development mode)
   - All system keys are blocked except for navigation keys

## Troubleshooting

If you encounter issues with kiosk mode:

1. Check if the app is set as device owner:
   ```
   adb shell dumpsys device_policy
   ```
   Look for your package name in the output.

2. If you need to remove device owner status:
   ```
   adb shell dpm remove-active-admin com.hotelstream.hotel_stream/flutter.lock.task.flutter_lock_task.DeviceAdmin
   ```

3. If setting device owner fails, use the fallback mode by setting as default launcher:
   ```
   adb shell cmd package set-home-activity com.hotelstream.hotel_stream/.MainActivity
   ```

4. For development and testing, you can toggle kiosk mode using the lock icon in the top left corner.

## Development

During development, the key log can be shown/hidden using the blue eye icon. The log displays all key presses and whether they were blocked.

### Supported Keys
- Arrow Up, Down, Left, Right
- Enter, Select
- Back button

### Blocked Keys
- Home
- Menu
- Netflix button
- App selection buttons
- Voice buttons
- All media keys
- All vendor-specific buttons
