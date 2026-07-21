//
//  BrowserSpace.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/28/25.
//

import SwiftUI
import SwiftData

/// `BrowserSpace` represents a space in the browser that contains tabs.
@Model
final class BrowserSpace: Identifiable {
    
    @Attribute(.unique) var id: UUID
    var name: String
    var systemImage: String
    var order: Int
    var colors: [String]
    var grainOpacity: Double
    var colorOpacity: Double
    var colorScheme: String

    /// Persisted so relaunch can restore the last selected tab in this space.
    var lastSelectedTabID: UUID?
    
    @Relationship(deleteRule: .cascade, inverse: \BrowserTab.browserSpace) private var unorderedTabs: [BrowserTab]?
    @Relationship(deleteRule: .cascade) private var unorderedPinnedTabs: [BrowserTab]?
    
    var tabs: [BrowserTab] {
        get {
            (unorderedTabs ?? []).filter { !$0.isClosed }.sorted()
        } set {
            let closedTabs = (unorderedTabs ?? []).filter { $0.isClosed }
            newValue.enumerated().forEach { index, tab in
                tab.order = index
            }
            unorderedTabs = newValue + closedTabs
        }
    }
    
    var pinnedTabs: [BrowserTab] {
        get {
            (unorderedPinnedTabs ?? []).filter { !$0.isClosed }.sorted()
        } set {
            let closedTabs = (unorderedPinnedTabs ?? []).filter { $0.isClosed }
            newValue.enumerated().forEach { index, tab in
                tab.order = index
            }
            unorderedPinnedTabs = newValue + closedTabs
        }
    }
    
    var allTabs: [BrowserTab] {
        tabs + pinnedTabs
    }
    
    var pinnedTabsVisible: Bool = true
    
    var recentlyClosedTabs: [BrowserTab] {
        let allUnordered = (unorderedTabs ?? []) + (unorderedPinnedTabs ?? [])
        return allUnordered.filter { $0.isClosed }
            .sorted { ($0.closedAt ?? .distantPast) > ($1.closedAt ?? .distantPast) }
    }
    
    @Attribute(.ephemeral) var currentTab: BrowserTab? = nil
    @Transient var loadedTabs: [BrowserTab] = []
    @Attribute(.ephemeral) var isEditing: Bool = false
    
    init(name: String, systemImage: String, order: Int, colors: [Color], grainOpacity: Double = 0.0, colorOpacity: Double = 1.0, colorScheme: String) {
        self.id = UUID()
        self.name = name
        self.systemImage = systemImage
        self.colors = colors.map { $0.hexString() }
        self.grainOpacity = grainOpacity
        self.colorOpacity = colorOpacity
        self.order = order
        self.colorScheme = colorScheme
        self.unorderedTabs = []
        self.currentTab = nil
    }
    
    /// Returns the text color of the space based on the colors of the space and the color scheme
    func textColor(in colorScheme: ColorScheme) -> Color {
        // If the space has no colors, return the primary color (black on light mode, white on dark mode)
        if colors.isEmpty { return .primary }
        
        // Return white or black depending on the luminance of the first color
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(getColors[0]).getRed(&r, green: &g, blue: &b, alpha: &a)
        a = colorOpacity
        
        // Convert the color to sRGB
        func sRGB(_ c: CGFloat) -> CGFloat {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        
        r = sRGB(r)
        g = sRGB(g)
        b = sRGB(b)
        
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let backgroundLuminance: CGFloat = colorScheme == .light ? 1 : 0
        
        let finalLuminance = sqrt((1 - a) * backgroundLuminance + a * luminance)
        
        return finalLuminance > 0.3 ? .black : .white
    }
    
    /// This is a computed property that returns the colors of the space as `Color` objects
    @Transient var getColors: [Color] {
        colors.map { Color(hex: $0) ?? .clear }
    }

    func selectTab(_ tab: BrowserTab?) {
        currentTab = tab
        lastSelectedTabID = tab?.id
    }

    /// Restore the last selected tab after relaunch / space switch.
    func restoreSelectedTab() {
        guard currentTab == nil else { return }
        if let lastSelectedTabID,
           let tab = allTabs.first(where: { $0.id == lastSelectedTabID }) {
            currentTab = tab
        } else {
            currentTab = allTabs.first
            lastSelectedTabID = currentTab?.id
        }
    }
    
    /// Removes a tab from the ZStack of WebViews of the space and discards its WebKit process.
    @MainActor
    func unloadTab(_ tab: BrowserTab) {
        loadedTabs.removeAll(where: { $0.id == tab.id })
        tab.viewController?.tearDownWebView(notifyExtensions: false)
        tab.webview = nil
        tab.viewController = nil
    }

    /// Soft-close a tab: keep metadata for Cmd+Shift+T restore, discard WebView memory.
    @MainActor
    private func softClose(_ tab: BrowserTab, using modelContext: ModelContext) {
        unloadTab(tab)
        tab.isClosed = true
        tab.closedAt = .now
        tab.isSuspended = false
        tab.clearError()
        ExtensionManager.shared.notifyTabClosed(tab)

        // Purge old closed tabs if there are too many (keep last 50)
        let closed = recentlyClosedTabs
        if closed.count > 50 {
            for i in 50..<closed.count {
                let oldTab = closed[i]
                unloadTab(oldTab)
                modelContext.delete(oldTab)
            }
        }
    }
    
    /// Closes a tab from the space and selects the next tab
    /// For pinned tabs: suspends if not suspended, closes if suspended
    @MainActor
    func closeTab(_ tab: BrowserTab, using modelContext: ModelContext) {
        let isPinned = pinnedTabs.contains(tab)
        
        if isPinned && !tab.isSuspended {
            // Suspend the pinned tab (discard WebView, keep tab in sidebar)
            tab.isSuspended = true
            unloadTab(tab)
            try? modelContext.save()
            
            // Select next tab if current tab was suspended
            if currentTab == tab {
                let availableTabs = allTabs.filter { !$0.isSuspended && $0.id != tab.id }
                selectTab(availableTabs.first)
            }
        } else {
            let closingCurrent = currentTab?.id == tab.id
            
            // Neighbor selection uses the pre-close ordered list so we pick the
            // next/previous tab correctly (not an index into the filtered array).
            var nextTab: BrowserTab? = currentTab
            if closingCurrent {
                let snapshot = allTabs
                if let index = snapshot.firstIndex(where: { $0.id == tab.id }) {
                    if index + 1 < snapshot.count {
                        nextTab = snapshot[index + 1]
                    } else if index > 0 {
                        nextTab = snapshot[index - 1]
                    } else {
                        nextTab = nil
                    }
                }
            }
            
            do {
                softClose(tab, using: modelContext)
                try modelContext.save()
            } catch {
                print("Error closing tab: \(error)")
            }
            
            if closingCurrent {
                withAnimation(.browserDefault) {
                    selectTab(nextTab)
                }
            }
        }
    }

    @MainActor
    func reopenTab(_ tab: BrowserTab, using modelContext: ModelContext) {
        withAnimation(.browserDefault) {
            tab.isClosed = false
            tab.closedAt = nil
            tab.isSuspended = false
            tab.clearError()
            // Ensure a fresh WebView is created on select.
            unloadTab(tab)
            selectTab(tab)
            try? modelContext.save()
        }
    }

    /// Soft-close many tabs (Clear / Close Above/Below) so they remain undoable.
    @MainActor
    func softCloseTabs(_ tabsToClose: [BrowserTab], using modelContext: ModelContext) {
        guard !tabsToClose.isEmpty else { return }
        let closingCurrent = tabsToClose.contains(where: { $0.id == currentTab?.id })
        let remaining = allTabs.filter { tab in !tabsToClose.contains(where: { $0.id == tab.id }) }

        withAnimation(.browserDefault) {
            for tab in tabsToClose {
                softClose(tab, using: modelContext)
            }
            if closingCurrent {
                selectTab(remaining.first)
            }
            try? modelContext.save()
        }
    }
    
    @MainActor
    func clear(using modelContext: ModelContext) {
        let deletedTabs = tabs.filter {
            UserDefaults.standard.bool(forKey: "clear_selected_tab") ? true : $0 != currentTab
        }
        softCloseTabs(deletedTabs, using: modelContext)
    }
    
    /// Opens a new tab in the space
    /// - Parameters:
    ///  - browserTab: The tab to open
    ///  - modelContext: The model context to save the changes
    func openNewTab(_ browserTab: BrowserTab, using modelContext: ModelContext, select: Bool = true) {
        do {
            tabs.insert(browserTab, at: browserTab.order)
            try modelContext.save()
            if select {
                selectTab(browserTab)
            } else {
                loadedTabs.append(browserTab)
            }
        } catch {
            print("Error opening new tab: \(error)")
        }
    }
    
    func pinTab(_ browserTab: BrowserTab, using modelContext: ModelContext) {
        do {
            guard let index = tabs.firstIndex(of: browserTab) else { return }
            pinnedTabs.append(tabs.remove(at: index))
            // Cancel suspend timer for pinned tab
            browserTab.viewController?.cancelSuspendTimer()
            try modelContext.save()
        } catch {
            print("Error pinning tab: \(error)")
        }
    }
    
    func unpinTab(_ browserTab: BrowserTab, using modelContext: ModelContext) {
        do {
            guard let index = pinnedTabs.firstIndex(of: browserTab) else { return }
            tabs.append(pinnedTabs.remove(at: index))
            tabs.last?.browserSpace = self
            // Start suspend timer for unpinned tab
            browserTab.viewController?.startSuspendTimer()
            try modelContext.save()
        } catch {
            print(error.localizedDescription)
        }
    }
}
