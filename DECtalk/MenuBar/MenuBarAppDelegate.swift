//
//  MenuBarAppDelegate.swift
//  DECtalk
//
//  Drives the menu-bar-first experience: manual launch shows the text input
//  window and appears in Cmd-Tab; --background launches menu-bar-only.
//  Cmd+Q closes the window (stays in menu bar); Cmd+Shift+Q quits.
//
//  Hooked into the SwiftUI App lifecycle via @NSApplicationDelegateAdaptor
//  in DECtalkApp.swift, so this owns all window management directly
//  (the App's Scene is just Settings {} / empty).
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

    private var clockEnabledMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {

        UserDefaults.standard.register(defaults: [
            PrefKeys.clockEnabled: false,
            PrefKeys.clockInterval: 15,
            PrefKeys.focusBehavior: FocusBehavior.ignoreAllFocus.rawValue,
            PrefKeys.allowedFocusModes: [],

            PrefKeys.voiceMarkersEnabled: true,
            PrefKeys.voiceAutocompleteEnabled: true
        ])

        scheduler = ClockScheduler(engine: engine)

        installMainMenu()
        setupStatusItem()

        // Start as regular so Cmd-Tab works when we show the window.
        NSApp.setActivationPolicy(.regular)

        // Decide mode based on args (reliable)
        if forceBackground && !forceWindow {
            // Menu-bar only
            switchToAccessoryMode()
        } else {
            // Normal/manual launch => show window
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

    private func switchToAccessoryMode() {
        NSApp.setActivationPolicy(.accessory)
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"

        let closeWindowItem = NSMenuItem(
            title: "Close Window",
            action: #selector(closeWindowToMenuBar),
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

    @objc private func closeWindowToMenuBar() {
        inputWindow?.close()
        preferencesController?.close()
        auValidatorWindowController?.close()
        switchToAccessoryMode()
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            let inputVisible = (self.inputWindow?.isVisible == true)
            let prefsVisible = (self.preferencesController?.window?.isVisible == true)
            let auVisible = (self.auValidatorWindowController?.window?.isVisible == true)
            if !inputVisible && !prefsVisible && !auVisible {
                self.switchToAccessoryMode()
            }
        }
    }

    // Menu items need explicit targets to work reliably in menu-bar apps.
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.title = "DT"
            button.toolTip = "DECtalk"
            button.setAccessibilityLabel("DECtalk Menu Bar")
            button.setAccessibilityHelp("Open the DECtalk menu")
        }

        let menu = NSMenu()
        menu.delegate = self

        let speakClipboardItem = NSMenuItem(title: "Speak Clipboard", action: #selector(speakClipboard), keyEquivalent: "")
        speakClipboardItem.target = self
        menu.addItem(speakClipboardItem)

        let openInputItem = NSMenuItem(title: "Open Text Input…", action: #selector(openTextInputFromMenu), keyEquivalent: "")
        openInputItem.target = self
        menu.addItem(openInputItem)

        menu.addItem(.separator())

        let clockMenu = NSMenu()

        clockEnabledMenuItem = NSMenuItem(title: "Enable Recurring Clock", action: #selector(toggleClockEnabled), keyEquivalent: "")
        clockEnabledMenuItem?.target = self
        clockMenu.addItem(clockEnabledMenuItem!)

        clockMenu.addItem(.separator())

        let announceItem = NSMenuItem(title: "Announce Time Now", action: #selector(runAClock), keyEquivalent: "")
        announceItem.target = self
        clockMenu.addItem(announceItem)

        let clockMenuItem = NSMenuItem(title: "Talking Clock", action: nil, keyEquivalent: "")
        clockMenuItem.submenu = clockMenu
        menu.addItem(clockMenuItem)

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
        if let scheduler = scheduler {
            clockEnabledMenuItem?.state = scheduler.isEnabled ? .on : .off
        }
    }
}
