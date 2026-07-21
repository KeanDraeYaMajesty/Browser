//
//  SharedWebViewConfiguration.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/2/25.
//

import WebKit

/// Shared base configuration for WKWebView instances.
///
/// Tab configurations **must** be derived via ``makeConfiguration(noTrace:)`` (a copy of this
/// base) so they share the same process pool and `webExtensionController`. Creating a fresh
/// `WKWebViewConfiguration()` and only assigning the controller breaks extension content scripts.
class SharedWebViewConfiguration {
    static let shared = SharedWebViewConfiguration()

    /// Base configuration that owns the shared process pool and extension controller attachment point.
    let configuration: WKWebViewConfiguration

    private var contentRuleList: WKContentRuleList?
    private var cachedUserAgent: String?

    private init() {
        configuration = WKWebViewConfiguration()

        configuration.allowsAirPlayForMediaPlayback = true
        configuration.websiteDataStore = .default()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.upgradeKnownHostsToHTTPS = true
        configuration.applicationNameForUserAgent = "Zero"

        let preferences = WKPreferences()
        preferences.isElementFullscreenEnabled = true
        preferences.isTextInteractionEnabled = true
        configuration.preferences = preferences

        let webPagePreferences = WKWebpagePreferences()
        webPagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = webPagePreferences

        compileContentBlockers()
    }

    /// User agent string from the system WebKit build, with the app name appended.
    var userAgent: String {
        if let cachedUserAgent, !cachedUserAgent.isEmpty {
            return cachedUserAgent
        }
        let webView = WKWebView(frame: .zero, configuration: makeConfiguration())
        let value = webView.value(forKey: "userAgent") as? String ?? ""
        cachedUserAgent = value
        return value
    }

    /// Attach the shared web extension controller so every derived tab config inherits it.
    func attachWebExtensionController(_ controller: WKWebExtensionController) {
        configuration.webExtensionController = controller
    }

    /// Creates a per-tab configuration derived from the shared base.
    /// - Parameter noTrace: When true, uses a non-persistent data store (No-Trace / Temporary windows).
    func makeConfiguration(noTrace: Bool = false) -> WKWebViewConfiguration {
        let config: WKWebViewConfiguration
        if let copied = configuration.copy() as? WKWebViewConfiguration {
            config = copied
        } else {
            // Extremely unlikely — WKWebViewConfiguration is NSCopying — but never crash.
            config = WKWebViewConfiguration()
            config.processPool = configuration.processPool
            config.websiteDataStore = configuration.websiteDataStore
            config.userContentController = configuration.userContentController
            config.webExtensionController = configuration.webExtensionController
            config.preferences = configuration.preferences
            config.defaultWebpagePreferences = configuration.defaultWebpagePreferences
            config.upgradeKnownHostsToHTTPS = configuration.upgradeKnownHostsToHTTPS
            config.applicationNameForUserAgent = configuration.applicationNameForUserAgent
            config.allowsAirPlayForMediaPlayback = configuration.allowsAirPlayForMediaPlayback
            config.mediaTypesRequiringUserActionForPlayback = configuration.mediaTypesRequiringUserActionForPlayback
        }

        if let contentRuleList {
            config.userContentController.removeAllContentRuleLists()
            config.userContentController.add(contentRuleList)
        }

        if noTrace {
            config.websiteDataStore = .nonPersistent()
        }

        return config
    }

    private func compileContentBlockers() {
        do {
            guard let adawayURL = Bundle.main.url(forResource: "adaway", withExtension: "json") else { return }
            let contentBlockers = try String(contentsOf: adawayURL, encoding: .utf8)
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "BrowserContentBlockers",
                encodedContentRuleList: contentBlockers
            ) { [weak self] list, error in
                if let error {
                    print("🚫 Error compiling content blockers:", error)
                    return
                }
                guard let self, let list else { return }
                self.contentRuleList = list
                self.configuration.userContentController.removeAllContentRuleLists()
                self.configuration.userContentController.add(list)
            }
        } catch {
            print("🚫 Error loading content blockers:", error)
        }
    }
}
