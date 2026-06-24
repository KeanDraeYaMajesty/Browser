//
//  SharedWebViewConfiguration.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/2/25.
//

import WebKit

/// Shared configuration for WKWebView instances
class SharedWebViewConfiguration {
    // Singleton to ensure a single shared configuration across tabs
    static let shared = SharedWebViewConfiguration()

    // Shared configuration with cache, cookies, and other settings
    let configuration: WKWebViewConfiguration

    private init() {
        configuration = WKWebViewConfiguration()

        configuration.allowsAirPlayForMediaPlayback = true
        configuration.websiteDataStore = .default()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.upgradeKnownHostsToHTTPS = true
        configuration.applicationNameForUserAgent = "Zero"

        // Configure content blockers
        do {
            if let adawayURL = Bundle.main.url(forResource: "adaway", withExtension: "json") {
                let contentBlockers = try String(contentsOf: adawayURL, encoding: .utf8)
                WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "BrowserContentBlockers", encodedContentRuleList: contentBlockers) { list, error in
                    if let error {
                        print("🚫 Error compiling content blockers:", error)
                    } else if let list {
                        self.configuration.userContentController.add(list)
                    }
                }
            }
        } catch {
            print("🚫 Error loading content blockers:", error)
        }

        let preferences = WKPreferences()
        preferences.isElementFullscreenEnabled = true
        preferences.isTextInteractionEnabled = true
        configuration.preferences = preferences

        let webPagePreferences = WKWebpagePreferences()
        webPagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = webPagePreferences
    }

    /// User agent string from the system WebKit build, with the app name appended.
    var userAgent: String {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        return webView.value(forKey: "userAgent") as? String ?? ""
    }
}
