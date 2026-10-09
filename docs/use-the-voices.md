# Use DECtalk voices on your Mac

After you install DECtalk, its nine voices work like the other voices on your Mac.

## Before you begin

Install DECtalk and open it once. For steps, see [Build and install DECtalk on your Mac](build-and-install.md).

## See which voices are available

In Terminal, enter the following command:

```
say -v '?' | grep DECtalk
```

Each voice appears with the name you use to select it, such as `DECtalk Paul`.

## Hear a voice in Terminal

Enter `say` with the `-v` option and the name of the voice in quotation marks:

```
say -v "DECtalk Betty" "Good morning."
```

## Save speech to a file

Add the `-o` option to save the speech as an audio file instead of playing it:

```
say -v "DECtalk Harry" -o harry.aiff "This is Harry."
```

To check that the file contains audio, enter `afinfo harry.aiff`. The output includes the length of the recording.

## Choose a DECtalk voice in System Settings

1. Choose Apple menu > System Settings.
2. Click Accessibility, then click Spoken Content.
3. Choose a DECtalk voice from the System voice menu.

Apps that use your system voice then speak with the voice you chose.

## About the voices

| Name | Language |
| --- | --- |
| DECtalk Paul | English (US) |
| DECtalk Betty | English (US) |
| DECtalk Harry | English (US) |
| DECtalk Frank | English (US) |
| DECtalk Dennis | English (US) |
| DECtalk Kit | English (US) |
| DECtalk Ursula | English (US) |
| DECtalk Rita | English (US) |
| DECtalk Wendy | English (US) |

The voices render speech at 11.025 kHz in mono, which is the format DECtalk produces. DECtalk reads plain text. If an app sends text with markup, DECtalk removes the markup and speaks the words.

## Learn more

- [Use the DECtalk app](use-the-app.md)
- [Use DECtalk voices on iPhone and iPad](ios-use-the-voices.md)
- [If DECtalk doesn't work as expected](troubleshooting.md)
