//
//  DECtalkApp.swift
//  DECtalk
//
//  Created by Camden Bopp on 12/4/25.
//

import SwiftUI

@main
struct DECtalkApp: App {
    // MenuBarAppDelegate owns all window management (menu bar item, text
    // input window, preferences, AU validator) directly via AppKit, so
    // there's no SwiftUI window scene to declare here.
    @NSApplicationDelegateAdaptor(MenuBarAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
