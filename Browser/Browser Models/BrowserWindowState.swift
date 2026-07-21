//
//  BrowserWindowState.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/28/25.
//

import SwiftUI
import SwiftData

/// The BrowserWindowState is an Observable class that holds the current state of the browser window
@Observable class BrowserWindowState {
    
    var currentSpace: BrowserSpace? = nil {
        didSet {
            if isMainBrowserWindow && !isNoTraceWindow && !isTemporaryWindow {
                if let newValue = currentSpace {
                    UserDefaults.standard.set(newValue.id.uuidString, forKey: "currentBrowserSpace")
                } else {
                    UserDefaults.standard.removeObject(forKey: "currentBrowserSpace")
                }
            } else if isNoTraceWindow {
                print("No Trace Window", currentSpace?.name as Any)
            }
        }
    }
    var viewScrollState: UUID?
    
    var searchOpenLocation: SearchOpenLocation? = .none
    var searchPanelOrigin: CGPoint {
        searchOpenLocation == .fromNewTab ? .zero : CGPoint(x: 5, y: 50)
    }
    var searchPanelSize: CGSize {
        searchOpenLocation == .fromNewTab ? CGSize(width: 700, height: 300) : CGSize(width: 400, height: 300)
    }
    
    var showURLQRCode = false
    var showAcknowledgements = false
    
    var actionAlertMessage = ""
    var actionAlertSystemImage = ""
    var showActionAlert = false
    
    var isFullScreen = false
    
    var showTabSwitcher = false

    private(set) var windowID: String
    private(set) var isMainBrowserWindow: Bool
    private(set) var isNoTraceWindow: Bool
    private(set) var isTemporaryWindow: Bool

    /// True when website data must not persist (No-Trace or Temporary windows).
    var usesNonPersistentWebsiteData: Bool {
        isNoTraceWindow || isTemporaryWindow
    }
    
    init(windowID: String = "BrowserWindow") {
        self.windowID = windowID
        self.isMainBrowserWindow = windowID.hasPrefix("BrowserWindow")
        self.isNoTraceWindow = windowID.hasPrefix("BrowserNoTraceWindow")
        self.isTemporaryWindow = windowID.hasPrefix("BrowserTemporaryWindow")
    }
    
    /// Loads the current space from the UserDefaults and restores its last selected tab.
    @Sendable
    func loadCurrentSpace(browserSpaces: [BrowserSpace]) {
        guard let spaceId = UserDefaults.standard.string(forKey: "currentBrowserSpace"),
              let uuid = UUID(uuidString: spaceId) else { return }
        
        if let space = browserSpaces.first(where: { $0.id == uuid }) {
            goToSpace(space)
            space.restoreSelectedTab()
        }
    }
    
    /// Toggles the search open location between the URL bar and the new tab
    func toggleNewTabSearch() {
        if spaceCanOpenNewTab() {
            searchOpenLocation = searchOpenLocation == .fromNewTab ? .none : .fromNewTab
        } else {
            searchOpenLocation = .none
        }
    }
    
    /// Checks if the current space can open a new tab
    func spaceCanOpenNewTab() -> Bool {
        !(currentSpace == nil || currentSpace?.name.isEmpty == true)
    }
    
    /// Goes to a space in the browser
    func goToSpace(_ space: BrowserSpace?) {
        withAnimation(.browserDefault) {
            self.currentSpace = space
            self.viewScrollState = space?.id
        }
        space?.restoreSelectedTab()
    }
    
    /// Copies the URL of the current tab to the clipboard
    func copyURLToClipboard() {
        if let currentTab = currentSpace?.currentTab {
            currentTab.copyLink()
            presentActionAlert(message: "Copied Current URL", systemImage: "link")
        }
    }
    
    /// Presents an action alert with a message and a system image
    func presentActionAlert(message: String, systemImage: String) {
        actionAlertMessage = message
        actionAlertSystemImage = systemImage
        withAnimation(.browserDefault) {
            showActionAlert = true
        }
    }
    
    func backButtonAction() {
        guard let currentSpace = currentSpace,
              let currentTab = currentSpace.currentTab,
              let backItem = currentTab.webview?.backForwardList.backItem
        else { return }
        
        if NSEvent.modifierFlags.contains(.command) {
            let isCurrentTabPinned = currentSpace.pinnedTabs.contains(currentTab)
            let insertionIndex = isCurrentTabPinned ? currentSpace.tabs.count : currentTab.order + 1
            let newTab = BrowserTab(title: backItem.title ?? "", favicon: nil, url: backItem.url, browserSpace: currentSpace)
            currentSpace.tabs.insert(newTab, at: insertionIndex)
            currentSpace.selectTab(newTab)
        } else {
            currentTab.webview?.goBack()
        }
    }
    
    func forwardButtonAction() {
        guard let currentSpace = currentSpace,
              let currentTab = currentSpace.currentTab,
              let forwardItem = currentTab.webview?.backForwardList.forwardItem
        else { return }
        
        if NSEvent.modifierFlags.contains(.command) {
            let isCurrentTabPinned = currentSpace.pinnedTabs.contains(currentTab)
            let insertionIndex = isCurrentTabPinned ? currentSpace.tabs.count : currentTab.order + 1
            let newTab = BrowserTab(title: forwardItem.title ?? "", favicon: nil, url: forwardItem.url, browserSpace: currentSpace)
            currentSpace.tabs.insert(newTab, at: insertionIndex)
            currentSpace.selectTab(newTab)
        } else {
            currentTab.webview?.goForward()
        }
    }
    
    func refreshButtonAction() {
        guard let currentSpace = currentSpace,
              let currentTab = currentSpace.currentTab
        else { return }
        
        if NSEvent.modifierFlags.contains(.command) {
            let isCurrentTabPinned = currentSpace.pinnedTabs.contains(currentTab)
            let insertionIndex = isCurrentTabPinned ? currentSpace.tabs.count : currentTab.order + 1
            let newTab = BrowserTab(title: currentTab.title, favicon: currentTab.favicon, url: currentTab.url, browserSpace: currentSpace)
            currentSpace.tabs.insert(newTab, at: insertionIndex)
            currentSpace.selectTab(newTab)
        } else {
            currentTab.reload()
        }
    }

    /// Reopen the most recently closed tab in the current space (Cmd+Shift+T).
    @discardableResult
    func reopenLastClosedTab(using modelContext: ModelContext) -> Bool {
        guard let space = currentSpace,
              let tab = space.recentlyClosedTabs.first else { return false }
        space.reopenTab(tab, using: modelContext)
        presentActionAlert(message: "Reopened Tab", systemImage: "arrow.uturn.backward.circle")
        return true
    }
}
