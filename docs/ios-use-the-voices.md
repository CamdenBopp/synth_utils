# Use DECtalk voices on iPhone and iPad

After you install DECtalk Voice, its nine voices work like the other voices on your device. You can choose one as the voice for VoiceOver.

## Before you begin

Install DECtalk Voice and open it once. For steps, see [Build and install DECtalk on iPhone and iPad](ios-build-and-install.md).

## Use a DECtalk voice with VoiceOver

1. Open Settings and tap Accessibility.
2. Tap VoiceOver, then tap Speech.
3. Tap Voice and choose a DECtalk voice.

VoiceOver now speaks with the voice you chose. You can also find DECtalk voices in Settings > Accessibility > Spoken Content > Voices.

## What DECtalk follows from VoiceOver

DECtalk honors these settings and requests from VoiceOver.

- **Speaking rate.** When you change the speaking rate, DECtalk speeds up or slows down. DECtalk's normal rate is 180 words per minute. It supports 75 to 600 words per minute.
- **Pauses.** When VoiceOver asks for a pause, such as the gap before a hint, DECtalk waits. DECtalk shortens requested pauses to about two thirds of their length, because DECtalk's speech already includes a little silence around each phrase.
- **Spacing in labels.** Some apps put special space characters in their labels, such as a non-breaking space. DECtalk treats these as normal spaces, so the words don't run together.

## Try a voice in the app

DECtalk Voice has a few controls you can use to test the voices.

1. Choose a voice from the voice menu.
2. Type or paste text in the text box.
3. Tap Speak.

Two buttons test specific behavior:

- **Speak with 1s pause (SSML break test).** Speaks one phrase, pauses, then speaks a second phrase. The pause is about 0.65 seconds because of the shortening described above.
- **Speak "Send button" with non-breaking space.** Speaks "Send button" as two separate words.

To check for newly registered voices, tap Refresh.

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

The voices render speech at 11.025 kHz in mono. DECtalk reads plain text and removes any other markup before it speaks.

## Learn more

- [Use DECtalk voices on your Mac](use-the-voices.md)
- [If DECtalk doesn't work as expected](troubleshooting.md)
