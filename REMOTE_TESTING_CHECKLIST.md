# Android TV Remote Testing Checklist

Use this checklist to verify kiosk mode functionality with different Android TV remotes.

## Remote Control Buttons Testing

For each button, mark whether it's blocked properly (✓) or not (✗).

### Standard TV Remote

| Button | Expected Behavior | Blocked | Notes |
|--------|-------------------|---------|-------|
| Up     | Should work       | N/A     |       |
| Down   | Should work       | N/A     |       |
| Left   | Should work       | N/A     |       |
| Right  | Should work       | N/A     |       |
| Select/OK | Should work    | N/A     |       |
| Back   | Should work       | N/A     |       |
| Home   | Should be blocked |         |       |
| Menu   | Should be blocked |         |       |
| Volume Up | Should be blocked |      |       |
| Volume Down | Should be blocked |    |       |
| Mute   | Should be blocked |         |       |
| Power  | Should be blocked (if possible) |   |       |
| Number keys (0-9) | Should be blocked |    |       |

### Smart TV Remote (with App Buttons)

| Button | Expected Behavior | Blocked | Notes |
|--------|-------------------|---------|-------|
| Netflix | Should be blocked |        |       |
| Prime Video | Should be blocked |    |       |
| YouTube | Should be blocked |        |       |
| Disney+ | Should be blocked |        |       |
| Hulu   | Should be blocked |         |       |
| Google Play | Should be blocked |    |       |
| Voice Search | Should be blocked |   |       |
| Google Assistant | Should be blocked |      |       |

### Advanced Features

| Feature | Expected Behavior | Working | Notes |
|---------|-------------------|---------|-------|
| Regain focus after dialog | Should return to app |  |  |
| Prevent screen sleep | Screen should stay on |  |  |
| Block system notifications | No notifications should appear |  |  |
| Boot completion restart | App should restart after reboot |  |  |

## Device-Specific Testing

### Device: [Device Name 1]
- **Android Version**: 
- **Remote Type**: 
- **Special Notes**: 

| Key Code | Scan Code | Button | Blocked | Notes |
|----------|-----------|--------|---------|-------|
|          |           |        |         |       |
|          |           |        |         |       |

### Device: [Device Name 2]
- **Android Version**: 
- **Remote Type**: 
- **Special Notes**: 

| Key Code | Scan Code | Button | Blocked | Notes |
|----------|-----------|--------|---------|-------|
|          |           |        |         |       |
|          |           |        |         |       |

## Common Remote Key Codes

Use the app's key log to identify these values for your specific remote:

| Button | Common Key Code | Common Scan Code |
|--------|----------------|------------------|
| Netflix | Various | 229 |
| Prime Video | Various | 228 |
| YouTube | Various | 227 |
| Home | KeyEvent.KEYCODE_HOME (3) | Various |
| Menu | KeyEvent.KEYCODE_MENU (82) | Various |
| Google Assistant | KeyEvent.KEYCODE_ASSIST (219) | Various |

## Recording New Key Codes

When you encounter a button that isn't properly blocked:

1. Enable the key log using the blue eye icon
2. Press the button on the remote
3. Note the key code and scan code from the log
4. Add these values to the MainActivity.kt file in the appropriate section
5. Rebuild and test again

## Last Tested

**Date**: [Insert Date]
**Tester**: [Name]
**App Version**: [Version Number] 