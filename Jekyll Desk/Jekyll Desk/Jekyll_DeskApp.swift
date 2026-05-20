//
//  Jekyll_DeskApp.swift
//  Jekyll Desk
//
//  Created by master on 2026/5/16.
//

import SwiftUI
import AppKit

@main
struct Jekyll_DeskApp: App {
    init() {
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
    }

    var body: some Scene {
        WindowGroup("Jekyll Desk") {
            MainWindowView()
                .preferredColorScheme(.light)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
