//
//  SettingsView.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/18/25.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralSettingsView()
            }
            
            Tab("Appearance", systemImage: "paintpalette") {
                SettingsAppearanceView()
            }

            Tab("Extensions", systemImage: "puzzlepiece.extension") {
                SettingsExtensionsView()
            }
            
            Tab("Keyboard Shortcuts", systemImage: "command") {
                SettingsShortcutsView()
            }
        }
    }
}

#Preview {
    SettingsView()
}
