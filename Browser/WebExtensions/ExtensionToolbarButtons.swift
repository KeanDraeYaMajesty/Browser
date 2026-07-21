//
//  ExtensionToolbarButtons.swift
//  Browser
//
//  Toolbar buttons that trigger extension actions / popups.
//

import AppKit
import SwiftUI
import WebKit

struct ExtensionToolbarButtons: View {
    @Environment(BrowserWindowState.self) private var browserWindowState
    @ObservedObject private var extensionManager = ExtensionManager.shared

    private var currentTab: BrowserTab? {
        browserWindowState.currentSpace?.currentTab
    }

    var body: some View {
        let _ = extensionManager.actionsRevision
        let actions = extensionManager.toolbarActions(for: currentTab)

        ForEach(actions, id: \.extensionID) { item in
            ExtensionActionButton(
                extensionID: item.extensionID,
                extensionName: item.extensionName,
                action: item.action,
                tab: currentTab
            )
        }
    }
}

private struct ExtensionActionButton: View {
    let extensionID: String
    let extensionName: String
    let action: WKWebExtensionAction
    let tab: BrowserTab?

    var body: some View {
        Button {
            ExtensionManager.shared.performToolbarAction(
                extensionID: extensionID,
                for: tab,
                anchorView: NSApp.keyWindow?.contentView
            )
        } label: {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let icon = action.icon(for: CGSize(width: 18, height: 18)) {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "puzzlepiece.extension")
                    }
                }

                if !action.badgeText.isEmpty {
                    Text(action.badgeText)
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.red))
                        .foregroundStyle(.white)
                        .offset(x: 6, y: -6)
                }
            }
        }
        .disabled(!action.isEnabled)
        .help(action.label.isEmpty ? extensionName : action.label)
    }
}
