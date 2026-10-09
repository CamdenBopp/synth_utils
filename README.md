# DECtalk for Mac, iPhone, and iPad

This project adds the nine classic DECtalk voices to your Apple devices. After you install it, the voices appear with your other system voices. On a Mac, you can use them with the `say` command, in Spoken Content settings, and in apps that use system speech. On an iPhone or iPad, you can choose one as the voice for VoiceOver.

The Mac version also includes a small app. You can type text and hear it spoken, read the contents of your clipboard aloud, and have your Mac announce the time on a schedule.

## Learn more

**Mac**

- [Build and install DECtalk on your Mac](docs/build-and-install.md)
- [Use the DECtalk app](docs/use-the-app.md)
- [Use DECtalk voices on your Mac](docs/use-the-voices.md)

**iPhone and iPad**

- [Build and install DECtalk on iPhone and iPad](docs/ios-build-and-install.md)
- [Use DECtalk voices on iPhone and iPad](docs/ios-use-the-voices.md)

**Both**

- [If DECtalk doesn't work as expected](docs/troubleshooting.md)

## What you need

- Xcode 27
- An Apple Developer account signed in to Xcode
- For the Mac version, a Mac with macOS 26 or later
- For the iPhone and iPad version, a device with iOS or iPadOS 17 or later

## Quick start for Mac

1. Clone this repository and open `DECtalk.xcodeproj` in Xcode.
2. Select your team for both targets in Signing & Capabilities, then choose Product > Build.
3. Copy the built `DECtalk.app` to your Applications folder and open it once.
4. In Terminal, enter `say -v "DECtalk Paul" "Hello from DECtalk."`

For the full steps, see [Build and install DECtalk on your Mac](docs/build-and-install.md). To install the iPhone and iPad version, see [Build and install DECtalk on iPhone and iPad](docs/ios-build-and-install.md).

## Voices

Paul, Betty, Harry, Frank, Dennis, Kit, Ursula, Rita, and Wendy. All nine speak US English.

## How the project is organized

The Mac version lives at the top level of the repository. It has two parts that work independently.

- **DECtalk app** (`DECtalk/`). A macOS app with a text input window, a menu bar icon, and a talking clock. It speaks through DECtalk's command-line tool, which is bundled inside the app in `DECtalk/dectalk-dist/`.
- **DECtalk extension** (`DECtalkExtension/`). An Audio Unit speech extension that registers the nine voices with macOS. The app carries the extension inside it, so installing the app installs the voices. The extension uses its own copy of the DECtalk engine in `DECtalkExtension/lib/`.

The iPhone and iPad version lives in `ios/DECtalkVoice/`. It has the same two-part shape: a small app that carries an Audio Unit speech extension. The extension on iOS compiles the DECtalk engine from source (`ios/DECtalkVoice/DECtalkVoiceExtension/Engine/`) instead of loading a prebuilt library.

## Legal

DECtalk and its engine files belong to their respective owners. This repository doesn't grant any rights to them.

The engine source in `ios/DECtalkVoice/DECtalkVoiceExtension/Engine/` comes from the [DECtalkMini](https://github.com/dectalk/DECtalkMini) project and keeps its original copyright notices.
