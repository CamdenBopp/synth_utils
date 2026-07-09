//
//  ClockScheduler.swift
//  DECtalk
//
//  Recurring talking-clock announcements, gated by Focus mode preferences.
//

import Foundation

final class ClockScheduler {

    private var timer: Timer?
    private let engine: DECtalkCLIEngine
    private let focusDetector = FocusModeDetector()

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: PrefKeys.clockEnabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: PrefKeys.clockEnabled)
            if newValue { startScheduler() } else { stopScheduler() }
        }
    }

    var intervalMinutes: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: PrefKeys.clockInterval)
            return val > 0 ? val : 15
        }
        set {
            UserDefaults.standard.set(newValue, forKey: PrefKeys.clockInterval)
            if isEnabled { restartScheduler() }
        }
    }

    var focusBehavior: FocusBehavior {
        get { FocusBehavior(rawValue: UserDefaults.standard.integer(forKey: PrefKeys.focusBehavior)) ?? .ignoreAllFocus }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: PrefKeys.focusBehavior) }
    }

    var allowedFocusModes: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: PrefKeys.allowedFocusModes) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: PrefKeys.allowedFocusModes) }
    }

    init(engine: DECtalkCLIEngine) { self.engine = engine }

    func startScheduler() {
        stopScheduler()
        guard isEnabled else { return }

        let now = Date()
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: now)
        let second = calendar.component(.second, from: now)

        let interval = intervalMinutes
        let minutesUntilNext = interval - (minute % interval)
        let secondsUntilNext = (minutesUntilNext * 60) - second

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(secondsUntilNext)) { [weak self] in
            self?.fireClockIfAllowed()
            self?.scheduleRepeatingTimer()
        }
    }

    private func scheduleRepeatingTimer() {
        guard isEnabled else { return }
        let interval = TimeInterval(intervalMinutes * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fireClockIfAllowed()
        }
    }

    func stopScheduler() {
        timer?.invalidate()
        timer = nil
    }

    func restartScheduler() {
        stopScheduler()
        startScheduler()
    }

    private func fireClockIfAllowed() {
        guard shouldAnnounce() else { return }
        engine.runAClock { _ in }
    }

    func shouldAnnounce() -> Bool {
        let focusState = focusDetector.getCurrentFocusState()

        switch focusBehavior {
        case .ignoreAllFocus:
            return true
        case .silenceOnAnyFocus:
            return !focusState.isActive
        case .allowSpecificFocus:
            if !focusState.isActive {
                return allowedFocusModes.isEmpty
            }
            if let currentMode = focusState.currentMode {
                return allowedFocusModes.contains(currentMode)
            }
            return false
        }
    }

    func getAvailableFocusModes() -> [String] {
        focusDetector.getAvailableFocusModes()
    }
}
