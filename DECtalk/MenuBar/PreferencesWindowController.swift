//
//  PreferencesWindowController.swift
//  DECtalk
//

import Cocoa

final class PreferencesWindowController: NSWindowController {

    private var scheduler: ClockScheduler!

    private var voiceMarkersCheckbox: NSButton!
    private var voiceAutocompleteCheckbox: NSButton!

    private var clockEnabledCheckbox: NSButton!
    private var intervalPopup: NSPopUpButton!
    private var focusBehaviorPopup: NSPopUpButton!
    private var focusModesBox: NSBox!
    private var focusModeCheckboxes: [NSButton] = []

    convenience init(scheduler: ClockScheduler) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 470),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "DECtalk Preferences"
        window.center()

        self.init(window: window)
        self.scheduler = scheduler
        setupUI()
        loadCurrentValues()
    }

    private func setupUI() {
        guard let content = window?.contentView else { return }

        let margin: CGFloat = 20
        var yPos: CGFloat = 430

        // Text input section
        let inputHeader = NSTextField(labelWithString: "Text Input")
        inputHeader.font = NSFont.boldSystemFont(ofSize: 13)
        inputHeader.frame = NSRect(x: margin, y: yPos, width: 300, height: 20)
        content.addSubview(inputHeader)
        yPos -= 30

        voiceMarkersCheckbox = NSButton(
            checkboxWithTitle: "Enable voice markers like <Paul> and <voice Harry>",
            target: self,
            action: #selector(voiceMarkersChanged)
        )
        voiceMarkersCheckbox.frame = NSRect(x: margin, y: yPos, width: 420, height: 20)
        content.addSubview(voiceMarkersCheckbox)
        yPos -= 26

        voiceAutocompleteCheckbox = NSButton(
            checkboxWithTitle: "Show completion list when typing <",
            target: self,
            action: #selector(voiceAutocompleteChanged)
        )
        voiceAutocompleteCheckbox.frame = NSRect(x: margin + 20, y: yPos, width: 380, height: 20)
        content.addSubview(voiceAutocompleteCheckbox)
        yPos -= 30

        let sep0 = NSBox(frame: NSRect(x: margin, y: yPos, width: 420, height: 1))
        sep0.boxType = .separator
        content.addSubview(sep0)
        yPos -= 20

        // Talking clock header
        let clockHeader = NSTextField(labelWithString: "Talking Clock")
        clockHeader.font = NSFont.boldSystemFont(ofSize: 13)
        clockHeader.frame = NSRect(x: margin, y: yPos, width: 250, height: 20)
        content.addSubview(clockHeader)
        yPos -= 30

        clockEnabledCheckbox = NSButton(
            checkboxWithTitle: "Enable recurring time announcements",
            target: self,
            action: #selector(clockEnabledChanged)
        )
        clockEnabledCheckbox.frame = NSRect(x: margin, y: yPos, width: 360, height: 20)
        content.addSubview(clockEnabledCheckbox)
        yPos -= 30

        let intervalLabel = NSTextField(labelWithString: "Announce every:")
        intervalLabel.frame = NSRect(x: margin + 20, y: yPos, width: 120, height: 20)
        content.addSubview(intervalLabel)

        intervalPopup = NSPopUpButton(frame: NSRect(x: margin + 145, y: yPos - 2, width: 140, height: 25))
        intervalPopup.addItems(withTitles: ["5 minutes", "10 minutes", "15 minutes", "30 minutes", "60 minutes"])
        intervalPopup.target = self
        intervalPopup.action = #selector(intervalChanged)
        content.addSubview(intervalPopup)
        yPos -= 40

        let sep1 = NSBox(frame: NSRect(x: margin, y: yPos, width: 420, height: 1))
        sep1.boxType = .separator
        content.addSubview(sep1)
        yPos -= 20

        // Focus mode header
        let focusHeader = NSTextField(labelWithString: "Focus Mode Behavior")
        focusHeader.font = NSFont.boldSystemFont(ofSize: 13)
        focusHeader.frame = NSRect(x: margin, y: yPos, width: 300, height: 20)
        content.addSubview(focusHeader)
        yPos -= 30

        focusBehaviorPopup = NSPopUpButton(frame: NSRect(x: margin, y: yPos - 2, width: 320, height: 25))
        for behavior in FocusBehavior.allCases {
            focusBehaviorPopup.addItem(withTitle: behavior.displayName)
        }
        focusBehaviorPopup.target = self
        focusBehaviorPopup.action = #selector(focusBehaviorChanged)
        content.addSubview(focusBehaviorPopup)
        yPos -= 35

        focusModesBox = NSBox(frame: NSRect(x: margin, y: yPos - 140, width: 420, height: 150))
        focusModesBox.title = "Allowed Focus Modes"
        focusModesBox.titlePosition = .atTop
        content.addSubview(focusModesBox)

        let availableModes = scheduler.getAvailableFocusModes()
        var checkboxY: CGFloat = 105

        for mode in availableModes {
            let checkbox = NSButton(checkboxWithTitle: mode, target: self, action: #selector(focusModeCheckboxChanged(_:)))
            checkbox.frame = NSRect(x: 15, y: checkboxY, width: 390, height: 20)
            focusModesBox.contentView?.addSubview(checkbox)
            focusModeCheckboxes.append(checkbox)
            checkboxY -= 25
        }

        if availableModes.count <= 1 {
            let note = NSTextField(labelWithString: "Configure Focus modes in System Settings to see them here.")
            note.font = NSFont.systemFont(ofSize: 11)
            note.textColor = .secondaryLabelColor
            note.frame = NSRect(x: 15, y: 10, width: 390, height: 30)
            note.lineBreakMode = .byWordWrapping
            focusModesBox.contentView?.addSubview(note)
        }
    }

    private func loadCurrentValues() {
        let markers = UserDefaults.standard.bool(forKey: PrefKeys.voiceMarkersEnabled)
        let auto = UserDefaults.standard.bool(forKey: PrefKeys.voiceAutocompleteEnabled)

        voiceMarkersCheckbox.state = markers ? .on : .off
        voiceAutocompleteCheckbox.state = auto ? .on : .off
        voiceAutocompleteCheckbox.isEnabled = markers

        clockEnabledCheckbox.state = scheduler.isEnabled ? .on : .off

        let intervalIndex: Int
        switch scheduler.intervalMinutes {
        case 5: intervalIndex = 0
        case 10: intervalIndex = 1
        case 15: intervalIndex = 2
        case 30: intervalIndex = 3
        case 60: intervalIndex = 4
        default: intervalIndex = 2
        }
        intervalPopup.selectItem(at: intervalIndex)

        focusBehaviorPopup.selectItem(at: scheduler.focusBehavior.rawValue)

        let allowedModes = scheduler.allowedFocusModes
        for checkbox in focusModeCheckboxes {
            checkbox.state = allowedModes.contains(checkbox.title) ? .on : .off
        }

        updateFocusModesVisibility()
        updateIntervalEnabled()
    }

    private func updateFocusModesVisibility() {
        let showModes = scheduler.focusBehavior == .allowSpecificFocus
        focusModesBox.isHidden = !showModes
    }

    private func updateIntervalEnabled() {
        intervalPopup.isEnabled = scheduler.isEnabled
    }

    @objc private func voiceMarkersChanged() {
        let enabled = (voiceMarkersCheckbox.state == .on)
        UserDefaults.standard.set(enabled, forKey: PrefKeys.voiceMarkersEnabled)

        voiceAutocompleteCheckbox.isEnabled = enabled
        if !enabled {
            voiceAutocompleteCheckbox.state = .off
            UserDefaults.standard.set(false, forKey: PrefKeys.voiceAutocompleteEnabled)
        }
    }

    @objc private func voiceAutocompleteChanged() {
        let enabled = (voiceAutocompleteCheckbox.state == .on)
        UserDefaults.standard.set(enabled, forKey: PrefKeys.voiceAutocompleteEnabled)
    }

    @objc private func clockEnabledChanged() {
        scheduler.isEnabled = clockEnabledCheckbox.state == .on
        updateIntervalEnabled()
    }

    @objc private func intervalChanged() {
        let intervals = [5, 10, 15, 30, 60]
        let index = intervalPopup.indexOfSelectedItem
        if index >= 0 && index < intervals.count {
            scheduler.intervalMinutes = intervals[index]
        }
    }

    @objc private func focusBehaviorChanged() {
        let index = focusBehaviorPopup.indexOfSelectedItem
        if let behavior = FocusBehavior(rawValue: index) {
            scheduler.focusBehavior = behavior
            updateFocusModesVisibility()
        }
    }

    @objc private func focusModeCheckboxChanged(_ sender: NSButton) {
        var modes = scheduler.allowedFocusModes
        if sender.state == .on { modes.insert(sender.title) }
        else { modes.remove(sender.title) }
        scheduler.allowedFocusModes = modes
    }
}
