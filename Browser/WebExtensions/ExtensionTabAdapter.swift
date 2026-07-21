//
//  ExtensionTabAdapter.swift
//  Browser
//
//  Bridges BrowserTab to WKWebExtensionTab so extensions can query and control tabs.
//

import AppKit
import WebKit

@MainActor
final class ExtensionTabAdapter: NSObject, WKWebExtensionTab {
    let tab: BrowserTab
    weak var windowAdapter: ExtensionWindowAdapter?

    init(tab: BrowserTab, windowAdapter: ExtensionWindowAdapter?) {
        self.tab = tab
        self.windowAdapter = windowAdapter
        super.init()
    }

    func window(for extensionContext: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        windowAdapter
    }

    func indexInWindow(for extensionContext: WKWebExtensionContext) -> Int {
        guard let space = tab.browserSpace else { return NSNotFound }
        return space.allTabs.firstIndex(where: { $0.id == tab.id }) ?? NSNotFound
    }

    func webView(for extensionContext: WKWebExtensionContext) -> WKWebView? {
        tab.webview
    }

    func title(for extensionContext: WKWebExtensionContext) -> String? {
        tab.title
    }

    func isPinned(for extensionContext: WKWebExtensionContext) -> Bool {
        tab.browserSpace?.pinnedTabs.contains(where: { $0.id == tab.id }) ?? false
    }

    func setPinned(_ pinned: Bool, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        guard let space = tab.browserSpace,
              let modelContext = ExtensionManager.shared.activeModelContext else {
            completionHandler(nil)
            return
        }

        if pinned {
            space.pinTab(tab, using: modelContext)
        } else {
            space.unpinTab(tab, using: modelContext)
        }
        completionHandler(nil)
    }

    func size(for extensionContext: WKWebExtensionContext) -> CGSize {
        tab.webview?.bounds.size ?? .zero
    }

    func zoomFactor(for extensionContext: WKWebExtensionContext) -> Double {
        Double(tab.webview?.pageZoom ?? 1.0)
    }

    func setZoomFactor(_ zoomFactor: Double, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        tab.webview?.pageZoom = CGFloat(zoomFactor)
        completionHandler(nil)
    }

    func url(for extensionContext: WKWebExtensionContext) -> URL? {
        tab.webview?.url ?? tab.url
    }

    func isLoadingComplete(for extensionContext: WKWebExtensionContext) -> Bool {
        !(tab.webview?.isLoading ?? tab.isLoading)
    }

    func loadURL(_ url: URL, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        tab.url = url
        tab.clearError()
        tab.webview?.load(URLRequest(url: url))
        completionHandler(nil)
    }

    func reload(fromOrigin fromOrigin: Bool, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        if fromOrigin {
            tab.webview?.reloadFromOrigin()
        } else {
            tab.reload()
        }
        completionHandler(nil)
    }

    func goBack(for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        tab.webview?.goBack()
        completionHandler(nil)
    }

    func goForward(for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        tab.webview?.goForward()
        completionHandler(nil)
    }

    func activate(for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        tab.browserSpace?.selectTab(tab)
        if let windowAdapter {
            ExtensionManager.shared.focusWindow(windowAdapter)
        }
        completionHandler(nil)
    }

    func isSelected(for extensionContext: WKWebExtensionContext) -> Bool {
        tab.browserSpace?.currentTab?.id == tab.id
    }

    func setSelected(_ selected: Bool, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        if selected {
            tab.browserSpace?.selectTab(tab)
        }
        completionHandler(nil)
    }

    func close(for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        guard let space = tab.browserSpace,
              let modelContext = ExtensionManager.shared.activeModelContext else {
            completionHandler(nil)
            return
        }
        space.closeTab(tab, using: modelContext)
        completionHandler(nil)
    }

    func shouldGrantPermissionsOnUserGesture(for extensionContext: WKWebExtensionContext) -> Bool {
        true
    }
}
