# Build and install DECtalk on iPhone and iPad

Build DECtalk in Xcode, install it on your device, and confirm that iOS recognizes the voices.

## Before you begin

Make sure you have the following:

- Xcode 27
- An Apple Developer account signed in to Xcode. To sign in, choose Xcode > Settings, click Accounts, then click the add button.
- An iPhone or iPad with iOS or iPadOS 17 or later. The project has been tested on an iPhone running iOS 27.
- A USB or wireless connection between your Mac and the device, with Developer Mode turned on. To turn it on, go to Settings > Privacy & Security > Developer Mode on the device.

The iPhone and iPad version lives in the `ios/DECtalkVoice` folder of the repository.

## Build and install DECtalk in Xcode

1. Clone the repository:

   ```
   git clone https://github.com/CamdenBopp/synth_utils.git
   ```

2. Open `ios/DECtalkVoice/DECtalkVoice.xcodeproj` in Xcode.
3. In the project navigator, select the DECtalkVoice project. Then select the **DECtalkVoice** target.
4. Click Signing & Capabilities, then choose your team from the Team menu.
5. Select the **DECtalkVoiceExtension** target and choose your team the same way.
6. Choose your device from the run destination menu in the toolbar.
7. Choose Product > Run.

**Note:** The extension's bundle identifier must start with the app's bundle identifier. If you change one, change the other to match. For example, if the app is `com.example.DECtalkVoice`, the extension must be `com.example.DECtalkVoice.DECtalkVoiceExtension`.

## Build and install DECtalk from the command line

1. In Terminal, go to the `ios/DECtalkVoice` folder.
2. To find your device's identifier, enter the following command:

   ```
   xcrun devicectl list devices
   ```

3. Build the app. Replace `DEVICE_ID` with the identifier from the previous step:

   ```
   xcodebuild -project DECtalkVoice.xcodeproj -scheme DECtalkVoice -configuration Debug -destination 'id=DEVICE_ID' -derivedDataPath build -allowProvisioningUpdates build
   ```

4. Install the app on the device:

   ```
   xcrun devicectl device install app --device DEVICE_ID build/Build/Products/Debug-iphoneos/DECtalkVoice.app
   ```

## Confirm that the voices are installed

1. Unlock your device and open DECtalk Voice.
2. Check the line near the top of the screen. It says "DECtalk voices found," followed by a number. You should see 9.

The first time you install the app, the number can be 0. Wait about 10 seconds, then close DECtalk Voice and open it again. iOS registers the extension in the background after installation.

To hear a voice, choose it from the voice menu and tap Speak.

If the number stays at 0, see [If DECtalk Voice finds no voices](troubleshooting.md#if-dectalk-voice-finds-no-voices-iphone-and-ipad).

## Remove DECtalk

1. Touch and hold the DECtalk Voice icon on the Home Screen.
2. Tap Remove App, then tap Delete App.

The voices are removed along with the app.

## Learn more

- [Use DECtalk voices on iPhone and iPad](ios-use-the-voices.md)
- [If DECtalk doesn't work as expected](troubleshooting.md)
