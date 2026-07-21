//
//  WKWebViewController.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/2/25.
//

import SwiftUI
import WebKit
import SwiftData

/// Main view controller that contains a WKWebView
class WKWebViewController: NSViewController {

    @Bindable var tab: BrowserTab
    @Bindable var browserSpace: BrowserSpace
    var userPreferences: UserPreferences

    var webView: MyWKWebView
    let configuration: WKWebViewConfiguration

    weak var coordinator: WKWebViewControllerRepresentable.Coordinator?

    var activeDownloads: [(download: WKDownload, bookmarkData: Data, fileName: String)] = []

    private var suspendTimer: DispatchSourceTimer?
    private var didTearDown = false

    init(tab: BrowserTab, browserSpace: BrowserSpace, noTrace: Bool = false, using modelContext: ModelContext, userPreferences: UserPreferences) {
        self.tab = tab
        self.browserSpace = browserSpace
        self.userPreferences = userPreferences

        self.configuration = SharedWebViewConfiguration.shared.makeConfiguration(noTrace: noTrace)

        self.webView = MyWKWebView(frame: .zero, configuration: self.configuration)

        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        view = webView

        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.allowsLinkPreview = true // TODO: Implement my own preview later...
        webView.isInspectable = true

        // Make webView background transparent
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.clear.cgColor

        webView.navigationDelegate = self
        webView.uiDelegate = self

        webView.searchWebAction = { [weak self] query in
            self?.coordinator?.searchWebAction(query)
        }
        webView.openLinkInNewTabAction = { [weak self] url in
            self?.coordinator?.openLinkInNewTabAction(url)
        }
        webView.presentActionAlert = { [weak self] message, systemImage in
            self?.coordinator?.presentActionAlert(message: message, systemImage: systemImage)
        }

        coordinator?.observeWebView(webView)

        webView.load(URLRequest(url: tab.url))

        startSuspendTimer()
    }

    deinit {
        print("🔵 WKWebViewController deinit \(tab.title)")
        tearDownWebView(notifyExtensions: false)
    }

    /// Fully discard the WebView process so closed/suspended tabs do not retain memory.
    func tearDownWebView(notifyExtensions: Bool) {
        guard !didTearDown else { return }
        didTearDown = true

        cancelSuspendTimer()
        removeScriptMessageHandlers()

        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        webView.removeFromSuperview()

        coordinator?.stopObservingWebView(notifyClosed: notifyExtensions)

        tab.webview = nil
        if tab.viewController === self {
            tab.viewController = nil
        }
    }

    func cleanup() {
        // Only tear down when the tab is no longer kept in the live stack.
        if !browserSpace.loadedTabs.contains(where: { $0.id == tab.id }) {
            tearDownWebView(notifyExtensions: false)
        }
    }

    private func removeScriptMessageHandlers() {
        let controller = configuration.userContentController
        controller.removeScriptMessageHandler(forName: "hoverURL")
        controller.removeScriptMessageHandler(forName: "middleClickLink")
    }

    func startSuspendTimer() {
        guard UserDefaults.standard.bool(forKey: "automatic_page_suspension") else {
            return
        }

        // Don't start timer for pinned tabs
        if browserSpace.pinnedTabs.contains(tab) {
            return
        }

        suspendTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 60 * 10) // 10 minutes
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            // Don't suspend if the tab is currently active.
            if self.browserSpace.currentTab == self.tab {
                self.resetSuspendTimer()
            } else {
                self.tab.isSuspended = true
                self.browserSpace.unloadTab(self.tab)
            }
        }

        suspendTimer = timer
        timer.resume()
    }

    func resetSuspendTimer() {
        startSuspendTimer()
    }

    func cancelSuspendTimer() {
        suspendTimer?.cancel()
        suspendTimer = nil
    }

    func applyTransparency() {
        guard let url = webView.url else { return }

        let js: String
        // Global master switch + per-site enable, composed with readability wash.
        if userPreferences.webContentTransparency,
           StyleManager.shared.areStylesEnabled(for: url),
           let style = StyleManager.shared.composedTransparencyCSS(
            for: url,
            readability: userPreferences.transparencyReadability
           ) {
            let escapedCSS = style
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            
            js = """
            (function() {
                var style = document.getElementById('transparency-style');
                if (!style) {
                    style = document.createElement('style');
                    style.id = 'transparency-style';
                    document.head.appendChild(style);
                }
                style.textContent = `\(escapedCSS)`;
            })();
            """
        } else {
            js = """
            (function() {
                var style = document.getElementById('transparency-style');
                if (style) {
                    style.remove();
                }
            })();
            """
        }
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
