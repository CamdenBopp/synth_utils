# Build and install DECtalk

Build DECtalk in Xcode, install it in your Applications folder, and confirm that macOS recognizes the voices.

## Before you begin

Make sure you have the following:

- A Mac with macOS 26 or later
- Xcode 27
- An Apple Developer account signed in to Xcode. To sign in, choose Xcode > Settings, click Accounts, then click the add button.

## Build DECtalk in Xcode

1. Clone the repository:

   ```
   git clone https://github.com/CamdenBopp/synth_utils.git
   ```

2. Open `DECtalk.xcodeproj` in Xcode.
3. In the project navigator, select the DECtalk project. Then select the **DECtalk** target.
4. Click Signing & Capabilities, then choose your team from the Team menu.
5. Select the **DECtalkExtension** target and choose your team the same way.
6. Choose Product > Build.

**Note:** The extension's bundle identifier must start with the app's bundle identifier. If you change one, change the other to match. For example, if the app is `com.example.DECtalk`, the extension must be `com.example.DECtalk.DECtalkExtension`.

## Build DECtalk from the command line

1. In Terminal, go to the folder that contains `DECtalk.xcodeproj`.
2. Enter the following command:

   ```
   xcodebuild -project DECtalk.xcodeproj -scheme DECtalk -configuration Release -destination 'platform=macOS' -derivedDataPath build -allowProvisioningUpdates build
   ```

When the build finishes, the app is at `build/Build/Products/Release/DECtalk.app`.

If the build stops with a message about a Program License Agreement, see [If Xcode says you need to agree to a license](troubleshooting.md#if-xcode-says-you-need-to-agree-to-a-license).

## Install DECtalk

1. Copy `DECtalk.app` to the Applications folder on your Mac.
2. Open DECtalk from the Applications folder.

Opening the app once is what registers the voices with macOS. After that, you can quit the app. The voices stay available.

**Important:** Install DECtalk in the Applications folder. If you open the app directly from Xcode's build folder, macOS lists the extension but doesn't offer its voices.

## Confirm that the voices are installed

1. Open Terminal.
2. Enter the following command:

   ```
   say -v '?' | grep DECtalk
   ```

   You should see nine voices, from DECtalk Betty to DECtalk Wendy.

3. To hear a voice, enter the following command:

   ```
   say -v "DECtalk Paul" "Hello from DECtalk."
   ```

If the voices don't appear, see [If you don't see the DECtalk voices](troubleshooting.md#if-you-dont-see-the-dectalk-voices).

## Remove DECtalk

1. Quit DECtalk if it's open.
2. Drag `DECtalk.app` from the Applications folder to the Trash.

The voices are removed along with the app.
