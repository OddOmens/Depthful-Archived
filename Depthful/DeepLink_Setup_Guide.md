# Depthful App Event Deeplinks Setup Guide

## URL Schemes Added
Your app now supports these App Event deeplinks:
- `depthful://languages` - For Language-related App Events
- `depthful://voice-notes` - For Voice Notes-related App Events

## Xcode Configuration Required

### 1. Add URL Scheme to Info.plist
1. Open your project in Xcode
2. Select your app target
3. Go to the **Info** tab
4. Under **URL Types**, click the **+** button
5. Add the following:
   - **Identifier**: `com.yourcompany.depthful.deeplink`
   - **URL Schemes**: `depthful`
   - **Role**: `Editor`

### 2. Alternative: Direct Info.plist Edit
You can also add this directly to your `Info.plist` file:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.depthful.deeplink</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>depthful</string>
        </array>
        <key>CFBundleURLIconFile</key>
        <string></string>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
    </dict>
</array>
```

## Testing the Deeplinks

### 1. Simulator Testing
```bash
# Open Languages App Event
xcrun simctl openurl booted "depthful://languages"

# Open Voice Notes App Event  
xcrun simctl openurl booted "depthful://voice-notes"
```

### 2. Device Testing
- Use Safari and type: `depthful://languages`
- Use Safari and type: `depthful://voice-notes`
- Or use any URL testing app

### 3. App Store Connect App Events
When setting up App Events in App Store Connect, use these URLs:
- **Languages Event**: `depthful://languages`
- **Voice Notes Event**: `depthful://voice-notes`

## Code Behavior
- ✅ App opens when deeplink is triggered
- ✅ Shows alert confirming which App Event was used (for testing)
- ✅ Logs deeplink information to console
- ✅ Ready for future navigation enhancements

## Next Steps
1. Add the URL scheme to your Xcode project Info.plist
2. Test the deeplinks using the methods above
3. Create your App Events in App Store Connect using these URLs
4. (Optional) Remove the test alert once everything is working

## Future Enhancements
The code is structured to easily add specific navigation:
- Navigate to Settings for Languages deeplink
- Navigate to Voice Recording for Voice Notes deeplink
- Add more App Event types as needed 