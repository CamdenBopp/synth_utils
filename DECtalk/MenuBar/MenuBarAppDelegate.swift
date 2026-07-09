//
//  MenuBarAppDelegate.swift
//  DECtalk
//
//  Drives the menu-bar-first experience: manual launch shows the text input
//  window and appears in Cmd-Tab; --background launches menu-bar-only.
//  Cmd+Q closes the window (stays in menu bar); Cmd+Shift+Q quits.
//
//  Installed as the NSApplication delegate by the plain AppKit entry point
//  in DECtalkApp.swift; owns all window management and the main menu
//  directly (no SwiftUI app lifecycle involved).
//

import Cocoa
import SwiftUI
import AVFoundation
import AVFAudio

final class MenuBarAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextViewDelegate {

    private let engine = DECtalkCLIEngine.shared
    private var scheduler: ClockScheduler?

    private var statusItem: NSStatusItem?

    private var inputWindow: NSWindow?
    private var inputTextView: NSTextView?
    private var inputStatusLabel: NSTextField?
    private var speakButton: NSButton?
    private var stopButton: NSButton?

    private var preferencesController: PreferencesWindowController?

    // Also used to host the existing AUv3 validation/test harness UI,
    // reachable from the menu without it being the app's default window.
    private let auHostModel = AudioUnitHostModel()
    private var auValidatorWindowController: NSWindowController?

    private var forceBackground: Bool { ProcessInfo.processInfo.arguments.contains("--background") }
    private var forceWindow: Bool { ProcessInfo.processInfo.arguments.contains("--window") }

    // Speak Clipboard / Talking Clock live in both the status item's menu
    // and a regular top-level "Speech" menu (see installMainMenu), so
    // they're reachable even if the status item itself lands somewhere
    // unreachable — its on-screen position is decided by macOS's own
    // menu bar layout and isn't fully controllable from here. Each menu
    // gets its own "Enable Recurring Clock" item, so keep every instance
    // to update its checkmark state together.
    private var clockEnabledMenuItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {

        UserDefaults.standard.register(defaults: [
            PrefKeys.clockEnabled: false,
            PrefKeys.clockInterval: 15,
            PrefKeys.focusBehavior: FocusBehavior.ignoreAllFocus.rawValue,
            PrefKeys.allowedFocusModes: [],

            PrefKeys.voiceMarkersEnabled: true,
            PrefKeys.voiceAutocompleteEnabled: true
        ])

        seedStatusItemPositionIfNeeded()

        scheduler = ClockScheduler(engine: engine)

        installMainMenu()
        setupStatusItem()

        // Always .regular, permanently — never .accessory. Flipping to
        // .accessory on window close used to hide the Dock icon and drop
        // the app's menu bar ownership, which is exactly what VoiceOver's
        // VO+M (jump to menu bar) needs to still be there: with no window
        // open and the app demoted to .accessory, VO+M had nothing of
        // this app's to land on, which read as the app "disappearing".
        // Staying .regular keeps Cmd-Tab, the Dock icon, and the main
        // menu (including the Speech menu) always present and navigable.
        NSApp.setActivationPolicy(.regular)

        if !forceBackground || forceWindow {
            showInputWindow()
        }

        scheduler?.startScheduler()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showInputWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler?.stopScheduler()
    }

    // macOS only writes "NSStatusItem Preferred Position <autosaveName>"
    // after the user successfully Command-drags the item to a new spot —
    // it is NOT written just because autosaveName is set. On this machine
    // the item has been landing far enough right (overlapping the system
    // clock) that it's unclickable, so that drag can never happen and the
    // key never gets created — a chicken-and-egg trap. Seeding it once,
    // in-process (the sandboxed-safe way to do this — Terminal `defaults
    // write` would target the wrong domain), gives AppKit a starting
    // position in the open band the other third-party extras already use
    // (measured ~1144–1282pt) before Control Center has a chance to park
    // it somewhere unreachable. This is the same technique Hammerspoon
    // uses for the identical problem.
    private func seedStatusItemPositionIfNeeded() {
        let key = "NSStatusItem Preferred Position CamdenBopp.DECtalk.StatusItem"
        guard UserDefaults.standard.object(forKey: key) == nil else { return }
        UserDefaults.standard.set(1200.0, forKey: key)
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"

        // Everything the status item's own menu has, also here, so none of
        // it depends on the status item being reachable.
        addSpeechItems(to: appMenu)
        appMenu.addItem(.separator())

        let closeWindowItem = NSMenuItem(
            title: "Close Window",
            action: #selector(closeWindow),
            keyEquivalent: "q"
        )
        closeWindowItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(closeWindowItem)

        appMenu.addItem(.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        prefsItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(prefsItem)

        let auValidatorItem = NSMenuItem(
            title: "AU Validator (Debug)",
            action: #selector(showAUValidator),
            keyEquivalent: ""
        )
        auValidatorItem.target = self
        appMenu.addItem(auValidatorItem)

        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command, .shift]
        appMenu.addItem(quitItem)

        NSApp.mainMenu = mainMenu
    }

    // Shared by the main app menu and the status item's own menu, so both
    // always carry identical content — nothing lives only behind the
    // status item, which macOS may or may not place somewhere reachable.
    private func addSpeechItems(to menu: NSMenu) {
        let speakClipboardItem = NSMenuItem(title: "Speak Clipboard", action: #selector(speakClipboard), keyEquivalent: "")
        speakClipboardItem.target = self
        menu.addItem(speakClipboardItem)

        let openInputItem = NSMenuItem(title: "Open Text Input…", action: #selector(openTextInputFromMenu), keyEquivalent: "")
        openInputItem.target = self
        menu.addItem(openInputItem)

        menu.addItem(.separator())

        let clockMenu = NSMenu()

        let clockEnabledItem = NSMenuItem(title: "Enable Recurring Clock", action: #selector(toggleClockEnabled), keyEquivalent: "")
        clockEnabledItem.target = self
        clockMenu.addItem(clockEnabledItem)
        clockEnabledMenuItems.append(clockEnabledItem)

        clockMenu.addItem(.separator())

        let announceItem = NSMenuItem(title: "Announce Time Now", action: #selector(runAClock), keyEquivalent: "")
        announceItem.target = self
        clockMenu.addItem(announceItem)

        let clockMenuItem = NSMenuItem(title: "Talking Clock", action: nil, keyEquivalent: "")
        clockMenuItem.submenu = clockMenu
        menu.addItem(clockMenuItem)
    }

    @objc private func closeWindow() {
        inputWindow?.close()
        preferencesController?.close()
        auValidatorWindowController?.close()
    }

    // Menu items need explicit targets to work reliably in menu-bar apps.
    private func setupStatusItem() {
        // .squareLength, not .variableLength: the label is a fixed 2-char
        // "DT", so there's nothing to size dynamically. variableLength made
        // AppKit compute width on the fly, which could race with the very
        // first menu bar layout pass at launch and get placed wherever
        // there was leftover room that instant — including jammed up
        // against the clock — rather than a stable, predictable slot.
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // Without a stable autosaveName, macOS has nothing reliable to key
        // the user's dragged position to across launches, so a manually
        // repositioned icon doesn't reliably stay put session to session.
        item.autosaveName = "CamdenBopp.DECtalk.StatusItem"
        // Explicitly opt into Control Center's modern management of
        // third-party status items (user can Cmd-drag it, and it's
        // slotted among other extras the same way theirs are) rather than
        // leaving this unset and falling back to whatever legacy handling
        // macOS applies to unmanaged items — measured behavior was landing
        // far to the right of every other third-party item with hundreds
        // of points of open space skipped over, which points at exactly
        // this kind of legacy/unmanaged placement path.
        item.behavior = [.removalAllowed]
        statusItem = item

        if let button = item.button {
            // A plain text title ("DT") is unusual for a menu bar extra —
            // almost every well-behaved one uses a template image icon
            // instead, and macOS's newer Control-Center-hosted layout for
            // third-party status items is built/tested around that case.
            // Text-title items are the more likely of the two to hit edge
            // cases in that layout (which matches the icon landing crammed
            // against the clock instead of in its own slot).
            let symbolName = "waveform"
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "DECtalk") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "DT"
            }
            button.toolTip = "DECtalk"
            // VoiceOver announces AXTitle for interactive elements like a
            // status-bar button — not AXDescription (accessibilityLabel).
            // With only an image and no text button.title, AXTitle was
            // empty, so VO had nothing to say for this item even though it
            // was visually present and had a label/description set.
            button.setAccessibilityTitle("DECtalk")
            button.setAccessibilityLabel("DECtalk Menu Bar")
            button.setAccessibilityHelp("Open the DECtalk menu")
        }

        let menu = NSMenu()
        menu.delegate = self
        addSpeechItems(to: menu)
        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: "")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        // Quit can use default target (goes to NSApp via responder chain)
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        menu.addItem(quitItem)

        item.menu = menu
    }

    @objc private func toggleClockEnabled() {
        guard let scheduler = scheduler else { return }
        scheduler.isEnabled = !scheduler.isEnabled
    }

    @objc private func showPreferences() {
        guard let scheduler = scheduler else { return }

        if preferencesController == nil {
            preferencesController = PreferencesWindowController(scheduler: scheduler)
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        preferencesController?.showWindow(nil)
        preferencesController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func showAUValidator() {
        if auValidatorWindowController == nil {
            let hosting = NSHostingController(rootView: ContentView(hostModel: auHostModel))
            let window = NSWindow(contentViewController: hosting)
            window.title = "DECtalk AU Validator"
            window.setContentSize(NSSize(width: 480, height: 420))
            window.center()
            window.delegate = self
            auValidatorWindowController = NSWindowController(window: window)
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        auValidatorWindowController?.showWindow(nil)
        auValidatorWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func openTextInputFromMenu() {
        showInputWindow()
    }

    private func showInputWindow() {
        if inputWindow == nil {
            buildInputWindow()
        }
        guard let win = inputWindow else { return }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
    }

    private func buildInputWindow() {
        let windowWidth: CGFloat = 560
        let windowHeight: CGFloat = 340

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "DECtalk Input"
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 460, height: 240)
        win.delegate = self

        guard let content = win.contentView else {
            inputWindow = win
            return
        }

        let margin: CGFloat = 12

        let scroll = NSScrollView(frame: NSRect(
            x: margin,
            y: 70,
            width: windowWidth - margin * 2,
            height: windowHeight - 120
        ))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.autoresizingMask = [.width, .height]

        let tv = DectalkTextView(frame: scroll.bounds)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width, .height]
        tv.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.string =
"""
Type text here, then press Speak.

Examples:
  <Paul> Hello there.
  <Harry> This is Huge Harry.
  <voice Betty> Another form.

DECtalk commands like [:nh] also work.
"""
        tv.delegate = self

        scroll.documentView = tv
        content.addSubview(scroll)

        let speakBtn = NSButton(frame: NSRect(x: margin, y: 24, width: 80, height: 32))
        speakBtn.title = "Speak"
        speakBtn.bezelStyle = .rounded
        speakBtn.target = self
        speakBtn.action = #selector(speakFromInputWindow)
        speakBtn.autoresizingMask = [.maxYMargin]
        content.addSubview(speakBtn)
        self.speakButton = speakBtn

        let stopBtn = NSButton(frame: NSRect(x: margin + 90, y: 24, width: 80, height: 32))
        stopBtn.title = "Stop"
        stopBtn.bezelStyle = .rounded
        stopBtn.target = self
        stopBtn.action = #selector(stopPlayback)
        stopBtn.autoresizingMask = [.maxYMargin]
        stopBtn.isEnabled = false
        content.addSubview(stopBtn)
        self.stopButton = stopBtn

        let status = NSTextField(labelWithString: "Ready.")
        status.frame = NSRect(
            x: margin + 180,
            y: 30,
            width: windowWidth - (margin + 180) - margin,
            height: 20
        )
        status.lineBreakMode = .byTruncatingTail
        status.autoresizingMask = [.width, .maxYMargin]
        content.addSubview(status)

        inputWindow = win
        inputTextView = tv
        inputStatusLabel = status
    }

    // NSTextViewDelegate completions (signature MUST match protocol: index is optional)
    func textView(_ textView: NSTextView,
                  completions words: [String],
                  forPartialWordRange charRange: NSRange,
                  indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {

        let markersEnabled = UserDefaults.standard.bool(forKey: PrefKeys.voiceMarkersEnabled)
        let completionEnabled = UserDefaults.standard.bool(forKey: PrefKeys.voiceAutocompleteEnabled)
        guard markersEnabled && completionEnabled else { return [] }

        let ns = textView.string as NSString
        guard charRange.location >= 0,
              charRange.location + charRange.length <= ns.length else { return [] }

        let partial = ns.substring(with: charRange)
        guard partial.hasPrefix("<") else { return [] }

        let all = VoiceMarker.completions()
        let needle = partial.lowercased()
        let matches = all.filter { $0.lowercased().hasPrefix(needle) }

        index?.pointee = 0
        return matches
    }

    @objc private func speakFromInputWindow() {
        guard let tv = inputTextView else { return }

        let text = tv.string
        inputStatusLabel?.stringValue = "Speaking…"
        stopButton?.isEnabled = true

        engine.speakText(text) { result in
            switch result {
            case .success:
                self.inputStatusLabel?.stringValue = "Playing."
                self.monitorPlayback()
            case .failure(let error):
                self.inputStatusLabel?.stringValue = "\(error)"
                self.stopButton?.isEnabled = false
                self.showOneShotAlert(title: "DECtalk Error", message: "\(error)")
            }
        }
    }

    private func monitorPlayback() {
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if !self.engine.isPlaying {
                timer.invalidate()
                self.stopButton?.isEnabled = false
                if self.inputStatusLabel?.stringValue == "Playing." {
                    self.inputStatusLabel?.stringValue = "Ready."
                }
            }
        }
    }

    @objc private func stopPlayback() {
        engine.stop()
        stopButton?.isEnabled = false
        inputStatusLabel?.stringValue = "Stopped."
    }

    @objc private func speakClipboard() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showOneShotAlert(title: "Nothing to Speak", message: "Clipboard does not contain text.")
            return
        }

        engine.speakText(text) { result in
            if case .failure(let error) = result {
                self.showOneShotAlert(title: "DECtalk Error", message: "\(error)")
            }
        }
    }

    @objc private func runAClock() {
        engine.runAClock { result in
            if case .failure(let error) = result {
                self.showOneShotAlert(title: "aclock Error", message: "\(error)")
            }
        }
    }

    private func showOneShotAlert(title: String, message: String) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - NSMenuDelegate for updating menu item states
extension MenuBarAppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let scheduler = scheduler else { return }
        for item in clockEnabledMenuItems {
            item.state = scheduler.isEnabled ? .on : .off
        }
    }
}
