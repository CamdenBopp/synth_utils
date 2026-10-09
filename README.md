# DECtalk for Mac

DECtalk for Mac adds the nine classic DECtalk voices to macOS. After you install it, the voices appear with your other system voices. You can use them with the `say` command, in Spoken Content settings, and in apps that use system speech.

The project also includes a small app. You can type text and hear it spoken, read the contents of your clipboard aloud, and have your Mac announce the time on a schedule.

## Learn more

- [Build and install DECtalk](docs/build-and-install.md)
- [Use the DECtalk app](docs/use-the-app.md)
- [Use DECtalk voices on your Mac](docs/use-the-voices.md)
- [If DECtalk doesn't work as expected](docs/troubleshooting.md)

## What you need

- A Mac with macOS 26 or later
- Xcode 27
- An Apple Developer account signed in to Xcode

## Quick start

1. Clone this repository and open `DECtalk.xcodeproj` in Xcode.
2. Select your team for both targets in Signing & Capabilities, then choose Product > Build.
3. Copy the built `DECtalk.app` to your Applications folder and open it once.
4. In Terminal, enter `say -v "DECtalk Paul" "Hello from DECtalk."`

For the full steps, see [Build and install DECtalk](docs/build-and-install.md).

## Voices

Paul, Betty, Harry, Frank, Dennis, Kit, Ursula, Rita, and Wendy. All nine speak US English.

## How the project is organized

The project has two parts that work independently.

- **DECtalk app** (`DECtalk/`). A macOS app with a text input window, a menu bar icon, and a talking clock. It speaks through DECtalk's command-line tool, which is bundled inside the app in `DECtalk/dectalk-dist/`.
- **DECtalk extension** (`DECtalkExtension/`). An Audio Unit speech extension that registers the nine voices with macOS. The app carries the extension inside it, so installing the app installs the voices. The extension uses its own copy of the DECtalk engine in `DECtalkExtension/lib/`.

## Legal

DECtalk and its engine files belong to their respective owners. This repository doesn't grant any rights to them.
