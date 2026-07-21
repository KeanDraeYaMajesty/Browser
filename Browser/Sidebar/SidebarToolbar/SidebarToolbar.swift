//
//  SidebarToolbar.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/23/25.
//

import SwiftUI
import AppKit

/// Toolbar with buttons (traffic lights, web navigation) for the sidebar
struct SidebarToolbar: View {
    
    @Environment(\.modelContext) var modelContext
    
    @Environment(SidebarModel.self) var sidebarModel
    
    @EnvironmentObject var userPreferences: UserPreferences
    @Environment(BrowserWindowState.self) var browserWindowState
    @ObservedObject private var extensionManager = WebExtensionManager.shared
    
    let browserSpaces: [BrowserSpace]
    
    var currentTab: BrowserTab? {
        browserWindowState.currentSpace?.currentTab
    }
    
    /// Check if styles are enabled for the current website
    var areStylesEnabledForCurrentSite: Bool {
        guard let url = currentTab?.url else { return false }
        return StyleManager.shared.areStylesEnabled(for: url)
    }
    
    var body: some View {
            HStack {
                Button(action: { 
                    if let url = currentTab?.url {
                        StyleManager.shared.toggleStyles(for: url)
                        // Reapply styles to current tab
                        if let viewController = currentTab?.viewController {
                            viewController.applyTransparency()
                        }
                    }
                }) {
                    Image(systemName: areStylesEnabledForCurrentSite ? "app.background.dotted" : "app.translucent")
                }
                .buttonStyle(.sidebarHover(enabledColor: .primary, disabled: currentTab == nil, disabledColor: .primary))

                ForEach(extensionManager.enabledExtensions.filter { $0.manifest.toolbarAction != nil }) { ext in
                    Button {
                        openExtensionAction(ext)
                    } label: {
                        if let image = ext.icon(in: WebExtensionStore.shared.rootURL, size: 14) {
                            Image(nsImage: image)
                                .resizable()
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "puzzlepiece.extension")
                        }
                    }
                    .help(ext.manifest.toolbarAction?.defaultTitle ?? ext.displayName)
                    .buttonStyle(.sidebarHover(enabledColor: .primary, disabled: false, disabledColor: .primary))
                }
            }
        }

    private func openExtensionAction(_ ext: InstalledWebExtension) {
        if let popup = ext.manifest.toolbarAction?.defaultPopup {
            let url = ext.resourceURL(popup, in: WebExtensionStore.shared.rootURL)
            if FileManager.default.fileExists(atPath: url.path) {
                NSWorkspace.shared.open(url)
                return
            }
        }
        browserWindowState.presentActionAlert(
            message: "\(ext.displayName) has no popup",
            systemImage: "puzzlepiece.extension"
        )
    }
}
