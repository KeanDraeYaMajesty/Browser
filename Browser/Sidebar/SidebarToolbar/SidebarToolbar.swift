//
//  SidebarToolbar.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/23/25.
//

import SwiftUI

/// Toolbar with buttons (traffic lights, web navigation) for the sidebar
struct SidebarToolbar: View {
    
    @Environment(\.modelContext) var modelContext
    
    @Environment(SidebarModel.self) var sidebarModel
    
    @EnvironmentObject var userPreferences: UserPreferences
    @Environment(BrowserWindowState.self) var browserWindowState
    
    let browserSpaces: [BrowserSpace]
    
    var currentTab: BrowserTab? {
        browserWindowState.currentSpace?.currentTab
    }
    
    /// Check if styles are enabled for the current website
    var areStylesEnabledForCurrentSite: Bool {
        guard let url = currentTab?.url else { return false }
        return StyleManager.shared.areStylesEnabled(for: url)
    }

    private var transparencyActive: Bool {
        userPreferences.webContentTransparency && areStylesEnabledForCurrentSite
    }
    
    var body: some View {
            HStack {
                Button(action: {
                    if !userPreferences.webContentTransparency {
                        // First tap turns on the global master switch for Transparent Zen-style glass.
                        userPreferences.webContentTransparency = true
                        NotificationCenter.default.post(name: .transparencyPreferencesDidChange, object: nil)
                    } else if let url = currentTab?.url {
                        StyleManager.shared.toggleStyles(for: url)
                        currentTab?.viewController?.applyTransparency()
                    }
                }) {
                    Image(systemName: transparencyActive ? "app.background.dotted" : "app.translucent")
                }
                .help(transparencyHelp)
                .buttonStyle(.sidebarHover(enabledColor: .primary, disabled: currentTab == nil, disabledColor: .primary))
                .opacity(userPreferences.webContentTransparency ? 1.0 : 0.55)
                .contextMenu {
                    Button(userPreferences.webContentTransparency ? "Disable Website Transparency" : "Enable Website Transparency") {
                        userPreferences.webContentTransparency.toggle()
                        NotificationCenter.default.post(name: .transparencyPreferencesDidChange, object: nil)
                    }
                    if userPreferences.webContentTransparency, let url = currentTab?.url {
                        Button(areStylesEnabledForCurrentSite ? "Disable for This Site" : "Enable for This Site") {
                            StyleManager.shared.toggleStyles(for: url)
                            currentTab?.viewController?.applyTransparency()
                        }
                    }
                }
            }
        }

    private var transparencyHelp: String {
        if !userPreferences.webContentTransparency {
            return "Enable website transparency"
        }
        if areStylesEnabledForCurrentSite {
            return "Disable transparency for this site"
        }
        return "Enable transparency for this site"
    }
}
