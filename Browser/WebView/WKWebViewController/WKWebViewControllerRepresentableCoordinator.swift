//
//  WKWebViewControllerRepresentableCoordinator.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/22/25.
//

import Combine
import SwiftUI
import SwiftData
import WebKit

extension WKWebViewControllerRepresentable {
    /// Coordinator class to handle view controller events between SwiftUI and WebKit.
    @MainActor
    final class Coordinator: NSObject {
        var parent: WKWebViewControllerRepresentable
        
        private var cancellables = Set<AnyCancellable>()
        
        init(_ parent: WKWebViewControllerRepresentable) {
            self.parent = parent
        }
        
        /// Calculates the correct insertion order for a new tab based on whether the current tab is pinned
        private func calculateInsertionOrder() -> Int {
            let isCurrentTabPinned = self.parent.browserSpace.pinnedTabs.contains(self.parent.tab)
            return isCurrentTabPinned ? self.parent.browserSpace.tabs.count : self.parent.tab.order + 1
        }
        
        /// Presents an alert with a message and a system image
        func presentActionAlert(message: String, systemImage: String) {
            self.parent.browserWindowState.presentActionAlert(message: message, systemImage: systemImage)
        }
        
        /// Starts a Google search with the query in a new tab
        func searchWebAction(_ query: String) {
            let insertionOrder = calculateInsertionOrder()
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            guard let url = URL(string: "https://www.google.com/search?q=\(encoded)") else { return }
            let newTab = BrowserTab(title: query, url: url, order: insertionOrder, browserSpace: self.parent.browserSpace)
            self.parent.browserSpace.openNewTab(newTab, using: self.parent.modelContext)
        }
        
        /// Opens a link in a new tab
        func openLinkInNewTabAction(_ url: URL) {
            let insertionOrder = calculateInsertionOrder()
            let newTab = BrowserTab(title: url.cleanHost, url: url, order: insertionOrder, browserSpace: self.parent.browserSpace)
            self.parent.browserSpace.openNewTab(newTab, using: self.parent.modelContext, select: false)
        }
        
        func addTabToHistory() {
            // Never record history from No-Trace / Temporary windows.
            guard NSApp.isKeyWindowOfTypeMain,
                  !self.parent.browserWindowState.isNoTraceWindow,
                  !self.parent.browserWindowState.isTemporaryWindow else { return }
            do {
                var fetchDescriptor = FetchDescriptor<BrowserHistoryEntry>(
                    sortBy: [.init(\.date, order: .reverse)],
                )
                fetchDescriptor.fetchLimit = 1
                
                let lastHistoryEntry = try self.parent.modelContext.fetch(fetchDescriptor).first
                
                if let lastHistoryEntry, lastHistoryEntry.url == self.parent.tab.url {
                    lastHistoryEntry.date = Date()
                } else {
                    let historyEntry = BrowserHistoryEntry(title: self.parent.tab.title, url: self.parent.tab.url, favicon: self.parent.tab.favicon)
                    self.parent.modelContext.insert(historyEntry)
                }
                
                try self.parent.modelContext.save()
            } catch {
                print("Error saving history tab: \(error)")
            }
        }
        
        func toggleDownloadAnimation() {
            self.parent.sidebarModel.isAnimatingDownloads.toggle()
        }
        
        func createNewTabFromAction(_ navigationAction: WKNavigationAction) {
            if let url = navigationAction.request.url {
                let insertionOrder = calculateInsertionOrder()
                let newTab = BrowserTab(title: url.cleanHost, url: url, order: insertionOrder, browserSpace: self.parent.browserSpace)
                self.parent.browserSpace.openNewTab(newTab, using: self.parent.modelContext, select: false)
                self.parent.browserSpace.selectTab(newTab)
            }
        }
        
        /// Observes the webview to update the tab's properties, such as the title, favicon, url, and navigation buttons...
        func observeWebView(_ webview: MyWKWebView) {
            self.parent.tab.webview = webview
            ExtensionManager.shared.notifyTabOpened(self.parent.tab)
                        
            webview.publisher(for: \.canGoBack)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] canGoBack in
                    Task { @MainActor in
                        self?.parent.tab.canGoBack = canGoBack
                    }
                }
                .store(in: &cancellables)
            
            webview.publisher(for: \.canGoForward)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] canGoForward in
                    Task { @MainActor in
                        self?.parent.tab.canGoForward = canGoForward
                    }
                }
                .store(in: &cancellables)
            
            webview.publisher(for: \.url)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] url in
                    guard let url else { return }
                    Task { @MainActor in
                        self?.handleURLChange(url)
                    }
                }
                .store(in: &cancellables)
            
            webview.publisher(for: \.title)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] title in
                    Task { @MainActor in
                        self?.handleTitleChange(title)
                    }
                }
                .store(in: &cancellables)
            
            webview.publisher(for: \.estimatedProgress)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] estimatedProgress in
                    Task { @MainActor in
                        self?.parent.tab.estimatedProgress = estimatedProgress
                    }
                }
                .store(in: &cancellables)

            webview.publisher(for: \.isLoading)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isLoading in
                    Task { @MainActor in
                        self?.handleLoadingChange(isLoading)
                    }
                }
                .store(in: &cancellables)
        }

        private func handleURLChange(_ url: URL) {
            parent.tab.url = url
            // SDK spells this OptionSet case as `.URL` (capitalized).
            ExtensionManager.shared.notifyTabPropertiesChanged(parent.tab, properties: .URL)
        }

        private func handleTitleChange(_ title: String?) {
            if let title, !title.isEmpty {
                parent.tab.title = title
            } else {
                parent.tab.title = parent.tab.url.cleanHost
            }
            ExtensionManager.shared.notifyTabPropertiesChanged(parent.tab, properties: .title)
        }

        private func handleLoadingChange(_ isLoading: Bool) {
            parent.tab.isLoading = isLoading
            ExtensionManager.shared.notifyTabPropertiesChanged(parent.tab, properties: .loading)
        }
        
        func stopObservingWebView(notifyClosed: Bool = false) {
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
            // Only tell extensions the tab closed when the tab is truly closed —
            // not when it is suspended / discarded for memory.
            if notifyClosed {
                ExtensionManager.shared.notifyTabClosed(self.parent.tab)
            } else {
                ExtensionManager.shared.notifyTabSuspended(self.parent.tab)
            }
        }
        
        func setHoverURL(to url: String) {
            self.parent.hoverURL.wrappedValue = url
        }
    }
}
