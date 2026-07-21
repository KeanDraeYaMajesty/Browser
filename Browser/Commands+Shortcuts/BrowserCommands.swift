//
//  BrowserCommands.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/7/25.
//

import SwiftUI

struct BrowserCommands: Commands {
    
    @FocusedValue(\.browserActiveWindowState) var browserActiveWindowState
    @Environment(\.openSettings) private var openSettings
    
    var isDefaultBrowser: Bool {
        NSWorkspace.shared.urlForDefaultBrowser == Bundle.main.bundleURL
    }
    
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Acknowledgements...") {
                browserActiveWindowState?.showAcknowledgements.toggle()
            }

            Button("Extensions...") {
                UserDefaults.standard.set(true, forKey: "open_extensions_settings_once")
                openSettings()
                // Also notify an already-open Settings window.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotificationCenter.default.post(name: .openExtensionsSettings, object: nil)
                }
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            
            Button("Set as Default Browser") {
                let appURL = Bundle.main.bundleURL
                let schemes = ["http", "https", "html"]
                for scheme in schemes {
                    NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: scheme)
                }
            }
            .disabled(isDefaultBrowser)
        }
        
        FileCommands()
        EditCommands()
        ViewCommands()
        HistoryCommands()
    }
}
