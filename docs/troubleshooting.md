# If DECtalk doesn't work as expected

Find solutions to common problems with DECtalk. Sections that apply only to iPhone and iPad say so in the heading.

## If you don't see the DECtalk voices

Try these steps in order. After each one, check again with `say -v '?' | grep DECtalk`.

1. Make sure `DECtalk.app` is in your Applications folder. Voices from an app that you open from Xcode's build folder don't appear.
2. Open DECtalk from the Applications folder. The voices register the first time you open the app.
3. Quit DECtalk, then open it again.
4. Check that macOS recognizes the extension. In Terminal, enter the following command:

   ```
   pluginkit -m -v -p com.apple.AudioUnit-Speech
   ```

   The list should include `CamdenBopp.DECtalk.DECtalkExtension`, or the identifier you chose if you changed it. If it isn't listed, rebuild the app and install it again.
5. Restart your Mac.

## If DECtalk Voice finds no voices (iPhone and iPad)

DECtalk Voice shows "DECtalk voices found" followed by a number near the top of the screen. If the number is 0, try these steps in order.

1. Wait about 10 seconds, close DECtalk Voice, and open it again. After a fresh install, iOS can take a moment to register the extension, so the first launch can show 0 while the second shows 9.
2. Tap Refresh.
3. Delete DECtalk Voice from your device, then build and install it again.
4. Restart your device.
5. If you build the app yourself, confirm that the extension is inside the app. In the built app, the `PlugIns` folder should contain `DECtalkVoiceExtension.appex`. If it doesn't, the extension isn't being embedded, and iOS can't find it.

**Note:** The Activation diagnostics section can say "Components found: 0" and "Instantiate succeeded: no" even when the voices are registered. Use the voice count near the top of the screen to decide whether the voices are installed.

## If a voice doesn't speak

Save the speech to a file and check the length of the recording:

```
say -v "DECtalk Paul" -o test.aiff "Testing."
afinfo test.aiff
```

If the file is empty or the length is close to zero, the voice is registered but isn't producing audio. Delete `DECtalk.app` from the Applications folder, build the app again, and install the new copy.

## If Xcode says you need to agree to a license

If the build stops with a message that includes "PLA Update available," your Apple Developer account has a new Program License Agreement to accept. This isn't an Xcode problem. You can't fix it from the command line.

1. Go to developer.apple.com/account and sign in.
2. Review and accept the agreement.
3. Build again.

## If Xcode can't sign the extension

If you see "Embedded binary's bundle identifier is not prefixed with the parent app's bundle identifier," the extension's bundle identifier doesn't start with the app's. For example, if the Mac app is `com.example.DECtalk`, the extension must be `com.example.DECtalk.DECtalkExtension`. The same rule applies to the iPhone and iPad version.

If a message says a provisioning profile doesn't include your signing certificate, select your team for both the DECtalk and DECtalkExtension targets. Then build again with automatic signing on.

## If the menu bar icon is hidden behind the clock

On some versions of macOS, including macOS 27 beta, macOS can place the DECtalk icon at the far right of the menu bar, where the clock covers it. You can't click or drag the icon there. DECtalk doesn't control where macOS places menu bar icons.

You can still use every command:

- Open DECtalk from Spotlight, the Dock, or the Applications folder. Every command in the menu bar icon's menu is also in the DECtalk menu in the menu bar.
- To ask macOS to lay out the menu bar again, restart Control Center. In Terminal, enter `killall ControlCenter`. The menu bar flashes briefly, and the icon sometimes lands in a visible spot.

## If the talking clock doesn't speak

- Choose DECtalk > Talking Clock and make sure Enable Recurring Clock has a checkmark.
- Open Settings and check Focus Mode Behavior. If it's set to Silence During Any Focus, the clock stays quiet while a Focus is on.
- Choose Talking Clock > Announce Time Now. If DECtalk speaks, the clock is working and is waiting for the next scheduled time.

## If Speak Clipboard says there's nothing to speak

The clipboard doesn't contain text. Copy some text, then try again. If you copied an image or a file, DECtalk can't read it.

## Learn more

- [Build and install DECtalk on your Mac](build-and-install.md)
- [Use the DECtalk app](use-the-app.md)
- [Build and install DECtalk on iPhone and iPad](ios-build-and-install.md)
