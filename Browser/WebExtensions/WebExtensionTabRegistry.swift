//
//  WebExtensionTabRegistry.swift
//  Browser
//
//  Tracks live WKWebView tabs so browser.tabs.* can resolve them.
//

import Foundation
import WebKit

struct WebExtensionTabInfo: Equatable {
    let id: Int
    let url: URL?
    let title: String?
    let active: Bool
    let windowId: Int
    let status: String
}

final class WebExtensionTabRegistry {
    static let shared = WebExtensionTabRegistry()

    private let lock = NSLock()
    private var tabs: [Int: WeakTab] = [:]
    private var nextId = 1
    private var activeTabId: Int?

    private struct WeakTab {
        weak var webView: WKWebView?
        var windowId: Int
        var title: String?
        var url: URL?
        var isLoading: Bool
    }

    @discardableResult
    func register(webView: WKWebView, windowId: Int = 1) -> Int {
        lock.lock()
        defer { lock.unlock() }
        // Reuse id if this webView was already registered
        for (id, entry) in tabs where entry.webView === webView {
            return id
        }
        let id = nextId
        nextId += 1
        tabs[id] = WeakTab(
            webView: webView,
            windowId: windowId,
            title: webView.title,
            url: webView.url,
            isLoading: webView.isLoading
        )
        return id
    }

    func unregister(webView: WKWebView) {
        lock.lock()
        defer { lock.unlock() }
        tabs = tabs.filter { $0.value.webView !== webView }
    }

    func update(webView: WKWebView, title: String? = nil, url: URL? = nil, isLoading: Bool? = nil, active: Bool? = nil) {
        lock.lock()
        defer { lock.unlock() }
        guard let id = tabs.first(where: { $0.value.webView === webView })?.key else { return }
        tabs[id]?.title = title ?? tabs[id]?.title ?? webView.title
        tabs[id]?.url = url ?? tabs[id]?.url ?? webView.url
        if let isLoading {
            tabs[id]?.isLoading = isLoading
        }
        if active == true {
            activeTabId = id
        }
    }

    func setActive(webView: WKWebView) {
        lock.lock()
        defer { lock.unlock() }
        if let id = tabs.first(where: { $0.value.webView === webView })?.key {
            activeTabId = id
        }
    }

    func tabId(for webView: WKWebView) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return tabs.first(where: { $0.value.webView === webView })?.key
    }

    func webView(forTabId id: Int) -> WKWebView? {
        lock.lock()
        defer { lock.unlock() }
        return tabs[id]?.webView
    }

    func allTabInfos() -> [WebExtensionTabInfo] {
        lock.lock()
        defer { lock.unlock() }
        pruneLocked()
        return tabs.map { id, entry in
            WebExtensionTabInfo(
                id: id,
                url: entry.url ?? entry.webView?.url,
                title: entry.title ?? entry.webView?.title,
                active: id == activeTabId,
                windowId: entry.windowId,
                status: (entry.isLoading || entry.webView?.isLoading == true) ? "loading" : "complete"
            )
        }.sorted { $0.id < $1.id }
    }

    func activeTabInfo() -> WebExtensionTabInfo? {
        allTabInfos().first(where: \.active) ?? allTabInfos().first
    }

    private func pruneLocked() {
        tabs = tabs.filter { $0.value.webView != nil }
    }
}
