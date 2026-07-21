//
//  ContentView.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/18/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State var browserWindowState = BrowserWindowState()
    @EnvironmentObject var userPreferences: UserPreferences
    
    @ViewBuilder
    private var mainFrameWithBackground: some View {
        if userPreferences.windowBackgroundStyle == .liquidGlass {
            MainFrame()
                .background(Color.clear.glassEffect(in: .rect(cornerRadius: 10.0)))
        } else {
            MainFrame()
                .background(.thinMaterial)
        }
    }

    var body: some View {
        mainFrameWithBackground
            .ignoresSafeArea(.all)
            .focusedSceneValue(\.browserActiveWindowState, browserWindowState)
            .environment(browserWindowState)
            .sheet(isPresented: $browserWindowState.showURLQRCode) {
                if let currentTab = browserWindowState.currentSpace?.currentTab {
                    URLQRCodeView(browserTab: currentTab)
                }
            }
            .popover(
                isPresented: $browserWindowState.showAcknowledgements,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .top
            ) {
                Acknowledgments()
                    .environment(browserWindowState)
                    .frame(width: 500, height: 300)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
            }
            .onAppear {
                ExtensionManager.shared.activeWindowState = browserWindowState
                ExtensionManager.shared.registerWindow(
                    state: browserWindowState,
                    nsWindow: NSApp.keyWindow,
                    isPrivate: browserWindowState.isNoTraceWindow
                )
            }
            .onDisappear {
                ExtensionManager.shared.unregisterWindow(state: browserWindowState)
            }
            .background(ExtensionWindowBridge())
    }
}

/// Keeps ExtensionManager's active model context / window wiring in sync with the SwiftUI hierarchy.
private struct ExtensionWindowBridge: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BrowserWindowState.self) private var browserWindowState
    @State private var previousTabID: UUID?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                ExtensionManager.shared.activeModelContext = modelContext
                ExtensionManager.shared.activeWindowState = browserWindowState
                previousTabID = browserWindowState.currentSpace?.currentTab?.id
            }
            .onChange(of: browserWindowState.currentSpace?.currentTab?.id) { _, newValue in
                let space = browserWindowState.currentSpace
                let previousTab = previousTabID.flatMap { id in
                    space?.allTabs.first(where: { $0.id == id })
                }
                let newTab = space?.currentTab
                ExtensionManager.shared.activeWindowState = browserWindowState
                ExtensionManager.shared.activeModelContext = modelContext
                ExtensionManager.shared.notifyTabActivated(newTab: newTab, previousTab: previousTab)
                previousTabID = newValue
            }
    }
}
