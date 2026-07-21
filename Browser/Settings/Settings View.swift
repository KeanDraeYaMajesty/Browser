//
//  SettingsView.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/18/25.
//

import SwiftUI

enum SettingsTab: String, Hashable, CaseIterable {
    case general
    case appearance
    case extensions
    case shortcuts
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("General", systemImage: "gear", value: .general) {
                GeneralSettingsView()
            }

            Tab("Appearance", systemImage: "paintpalette", value: .appearance) {
                SettingsAppearanceView()
            }

            Tab("Extensions", systemImage: "puzzlepiece.extension", value: .extensions) {
                SettingsExtensionsView()
            }

            Tab("Keyboard Shortcuts", systemImage: "command", value: .shortcuts) {
                SettingsShortcutsView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openExtensionsSettings)) { _ in
            selectedTab = .extensions
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: "open_extensions_settings_once") {
                UserDefaults.standard.set(false, forKey: "open_extensions_settings_once")
                selectedTab = .extensions
            }
        }
    }
}

extension Notification.Name {
    static let openExtensionsSettings = Notification.Name("OpenExtensionsSettings")
}

#Preview {
    SettingsView()
}
