//
//  DECtalkApp.swift
//  DECtalk
//
//  Created by Camden Bopp on 12/4/25.
//

import SwiftUI

@main
struct DECtalkApp: App {
    private let hostModel = AudioUnitHostModel()

    var body: some Scene {
        WindowGroup {
            ContentView(hostModel: hostModel)
        }
    }
}
