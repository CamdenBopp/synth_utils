# Use the DECtalk app

Type text and hear it spoken, read your clipboard aloud, and set up a talking clock.

## Open DECtalk

When you open DECtalk, the DECtalk Input window appears. A waveform icon also appears in the menu bar.

DECtalk keeps running after you close the window, so the clock keeps announcing the time. If you open the app again from Spotlight, the Dock, or the Applications folder, the window comes back.

## Speak text

1. In the DECtalk Input window, type or paste your text.
2. Click Speak.
3. To stop speaking, click Stop.

The line next to the buttons shows what DECtalk is doing, such as "Speaking," "Playing," or "Ready."

## Change voices in your text

DECtalk speaks in Paul by default. To switch voices partway through your text, type a voice marker before the words you want that voice to speak.

```
<Paul> Hello there. <Harry> This is Harry. <voice Betty> And this is Betty.
```

You can write a marker as `<Name>` or as `<voice Name>`. Names aren't case sensitive.

| Voice | Marker |
| --- | --- |
| Paul | `<Paul>` |
| Betty | `<Betty>` |
| Harry | `<Harry>` |
| Frank | `<Frank>` |
| Dennis | `<Dennis>` |
| Kit | `<Kit>` |
| Ursula | `<Ursula>` |
| Rita | `<Rita>` |
| Wendy | `<Wendy>` |

You can also type DECtalk's own commands directly. For example, `[:nh]` switches to Harry.

When you type `<`, a list of markers appears. Choose one to complete it. To turn the list off, see [Change settings](#change-settings).

## Speak the clipboard

1. Copy some text in any app.
2. Choose DECtalk > Speak Clipboard, or click the DECtalk icon in the menu bar and choose Speak Clipboard.

If the clipboard doesn't contain text, DECtalk tells you there's nothing to speak.

## Use the talking clock

The talking clock announces the date and time. At the top of the hour, it says the date first.

- To hear the time once, choose Talking Clock > Announce Time Now.
- To have DECtalk announce the time on a schedule, choose Talking Clock > Enable Recurring Clock. A checkmark appears next to the item when the clock is on.

You can find Talking Clock in the DECtalk menu in the menu bar, and in the menu bar icon's menu.

To choose how often DECtalk announces the time, or to silence it during a Focus, see [Change settings](#change-settings).

## Change settings

1. Choose DECtalk > Settings, or press Command-Comma.
2. Change any of the following:

   - **Enable voice markers.** Turns `<Paul>` and `<voice Harry>` markers on or off. This is on by default.
   - **Show completion list when typing <.** Shows the list of markers as you type. This is on by default and requires voice markers.
   - **Enable recurring time announcements.** Turns the scheduled clock on or off. This is off by default.
   - **Announce every.** Choose 5, 10, 15, 30, or 60 minutes. The default is 15 minutes.
   - **Focus Mode Behavior.** Choose how the clock behaves when a Focus is on.

3. Close the Settings window. Your changes are saved.

### Focus Mode Behavior

| Choice | What the clock does |
| --- | --- |
| Ignore Focus Modes | Announces the time no matter which Focus is on. |
| Silence During Any Focus | Stays quiet whenever any Focus is on. |
| Only During Specific Focus Modes | Announces the time only during the Focus modes you select. |

If you choose Only During Specific Focus Modes, a list of your Focus modes appears. Select the ones where you want announcements.

## Close the window or quit DECtalk

- To close the window and leave DECtalk running, choose DECtalk > Close Window, or press Command-Q.
- To quit DECtalk, choose DECtalk > Quit DECtalk, or press Command-Shift-Q.

**Note:** In DECtalk, Command-Q closes the window instead of quitting. This keeps the talking clock running.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Command-Q | Close the window and keep DECtalk running |
| Command-Shift-Q | Quit DECtalk |
| Command-Comma | Open Settings |

## Open DECtalk without the window

To start DECtalk without opening the input window, use the `--background` option in Terminal:

```
open /Applications/DECtalk.app --args --background
```

The menu bar icon and the talking clock still start. To open the window later, choose DECtalk > Open Text Input, or open DECtalk again from Spotlight.

## Check the extension with AU Validator

Choose DECtalk > AU Validator (Debug) to open a window that loads the voice extension and shows whether it passes validation. This is useful if you're changing the extension's code.

## Learn more

- [Use DECtalk voices on your Mac](use-the-voices.md)
- [If DECtalk doesn't work as expected](troubleshooting.md)
