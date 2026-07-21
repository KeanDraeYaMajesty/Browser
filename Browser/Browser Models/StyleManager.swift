//
//  StyleManager.swift
//  Browser
//
//  Created by Browser on 10/8/25.
//

import Foundation
import SwiftUI

/// Represents the JSON structure for remote styles
struct RemoteStyles: Codable {
    let website: [String: [String: String]]
}

/// Manages website-specific CSS themes from remote JSON
@Observable
class StyleManager {
    /// Shared singleton instance
    static let shared = StyleManager()

    /// Dictionary mapping domain names to their CSS content
    private(set) var styleCache: [String: String] = [:]

    /// Fallback CSS content
    private(set) var fallbackStyle: String = ""
    
    /// Set of domains where styles are disabled (website-specific toggle)
    private(set) var disabledWebsites: Set<String> = []

    /// URL for remote styles JSON
    private let remoteStylesURL = "https://sameerasw.github.io/my-internet/styles.json"

    /// UserDefaults key for cached styles
    private let cachedStylesKey = "cached_remote_styles"
    
    /// UserDefaults key for disabled websites
    private let disabledWebsitesKey = "disabled_websites_for_styles"

    private init() {
        // Load disabled websites list
        loadDisabledWebsites()
        // Load cached styles first for immediate use
        loadCachedStyles()
        // Fetch fresh styles in background
        fetchRemoteStyles()
    }

    /// Fetches remote styles from the hosted JSON
    func fetchRemoteStyles() {
        print("� Fetching styles from remote URL: \(remoteStylesURL)")

        guard let url = URL(string: remoteStylesURL) else {
            print("⚠️ Invalid remote URL")
            return
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    print("⚠️ Failed to fetch remote styles: Invalid response")
                    return
                }

                // Parse JSON
                let decoder = JSONDecoder()
                let remoteStyles = try decoder.decode(RemoteStyles.self, from: data)

                // Save to UserDefaults for caching
                if let jsonString = String(data: data, encoding: .utf8) {
                    UserDefaults.standard.set(jsonString, forKey: cachedStylesKey)
                    print("💾 Cached remote styles to UserDefaults")
                }

                // Process and update cache
                await MainActor.run {
                    processRemoteStyles(remoteStyles)
                }

            } catch {
                print("⚠️ Failed to fetch remote styles: \(error.localizedDescription)")
            }
        }
    }

    /// Loads cached styles from UserDefaults
    private func loadCachedStyles() {
        guard let jsonString = UserDefaults.standard.string(forKey: cachedStylesKey),
              let data = jsonString.data(using: .utf8) else {
            print("ℹ️ No cached styles found")
            return
        }

        do {
            let decoder = JSONDecoder()
            let remoteStyles = try decoder.decode(RemoteStyles.self, from: data)
            processRemoteStyles(remoteStyles)
            print("✓ Loaded cached styles")
        } catch {
            print("⚠️ Failed to load cached styles: \(error.localizedDescription)")
        }
    }
    
    /// Loads disabled websites from UserDefaults
    private func loadDisabledWebsites() {
        if let array = UserDefaults.standard.array(forKey: disabledWebsitesKey) as? [String] {
            disabledWebsites = Set(array)
            print("✓ Loaded \(disabledWebsites.count) disabled website(s)")
        }
    }
    
    /// Saves disabled websites to UserDefaults
    private func saveDisabledWebsites() {
        UserDefaults.standard.set(Array(disabledWebsites), forKey: disabledWebsitesKey)
        print("💾 Saved \(disabledWebsites.count) disabled website(s)")
    }
    
    /// Toggle styles for a specific website (enable/disable)
    func toggleStyles(for url: URL) {
        guard let host = url.host else { return }
        let normalizedHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        
        if disabledWebsites.contains(normalizedHost) {
            disabledWebsites.remove(normalizedHost)
            print("✅ Enabled styles for: \(normalizedHost)")
        } else {
            disabledWebsites.insert(normalizedHost)
            print("🚫 Disabled styles for: \(normalizedHost)")
        }
        saveDisabledWebsites()
    }
    
    /// Check if styles are enabled for a specific website
    func areStylesEnabled(for url: URL) -> Bool {
        guard let host = url.host else { return false }
        let normalizedHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return !disabledWebsites.contains(normalizedHost)
    }

    /// Process remote styles and populate the cache
    private func processRemoteStyles(_ remoteStyles: RemoteStyles) {
        styleCache.removeAll()
        fallbackStyle = ""

        print("🎨 Processing \(remoteStyles.website.count) website(s)")

        for (websiteKey, features) in remoteStyles.website {
            // Combine all CSS features for this website
            let combinedCSS = features.values.joined(separator: "\n\n")

            // Remove .css extension if present
            let domainKey = websiteKey.hasSuffix(".css")
                ? String(websiteKey.dropLast(4))
                : websiteKey

            // Check if this is the example.com fallback style
            if domainKey == "example.com" || domainKey == "+example.com" || domainKey == "-example.com" {
                fallbackStyle = combinedCSS
                print("  ✓ Loaded fallback style: \(domainKey) (\(combinedCSS.count) chars, \(features.count) features)")
            } else {
                styleCache[domainKey] = combinedCSS
//                print("  ✓ Loaded style for: \(domainKey) (\(combinedCSS.count) chars, \(features.count) features)")
            }
        }

        print("🎨 Style processing complete. \(styleCache.count) website(s) + fallback loaded")
        print("🎨 Available domains: \(styleCache.keys.sorted())")
    }

    /// Legacy method for backwards compatibility - now fetches from remote
    func scanStyles() {
        fetchRemoteStyles()
    }

    /// Get CSS for a specific domain, or fallback if not found
    func getStyle(for url: URL) -> String? {
        guard let host = url.host else { return fallbackStyle }
        
        // Normalize domain by removing www. prefix
        let normalizedHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        
        // Check if styles are disabled for this website
        if disabledWebsites.contains(normalizedHost) {
            print("🚫 Styles disabled for: \(host)")
            return nil
        }

        print("🔍 Looking for style for host: \(host)")
//        print("🔍 Available cache keys: \(styleCache.keys.sorted())")

        // Try to find matching styles with prefix handling
        for (key, css) in styleCache {
            // Handle + prefix: matches subdomains (e.g., +adobe.com matches in.adobe.com, www.adobe.com)
            if key.hasPrefix("+") {
                let domain = String(key.dropFirst()) // Remove the +
                if normalizedHost.hasSuffix(domain) || normalizedHost == domain {
                    print("🎨 Using custom style for: \(key) (subdomain match)")
                    return css
                }
            }
            // Handle - prefix: matches different TLDs (e.g., -google.com matches google.lk, google.co.uk)
            else if key.hasPrefix("-") {
                let domain = String(key.dropFirst()) // Remove the -
                // Extract the base domain without TLD from the pattern
                if let baseDomain = extractBaseDomain(from: domain),
                   let hostBaseDomain = extractBaseDomain(from: normalizedHost) {
                    // Also check that both domains have similar structure (same number of parts)
                    // google.com vs google.lk (both 2 parts) = match ✓
                    // google.com vs translate.google.com (2 vs 3 parts) = no match ✗
                    let domainParts = domain.split(separator: ".").count
                    let hostParts = normalizedHost.split(separator: ".").count
                    
                    if baseDomain == hostBaseDomain && domainParts == hostParts {
                        print("🎨 Using custom style for: \(key) (TLD match)")
                        return css
                    }
                }
            }
            // Exact match (with or without www.)
            else if key == normalizedHost || key == host {
                print("🎨 Using custom style for: \(key) (exact match)")
                return css
            }
        }

        // Try fallback (example.com) if available, otherwise return nil
        if !fallbackStyle.isEmpty {
            print("🎨 Using fallback (example.com) style for: \(host)")
            return fallbackStyle
        } else {
            print("ℹ️ No style found for: \(host)")
            return nil
        }
    }

    /// Compose site transparency CSS with a tunable readability wash.
    /// - Parameters:
    ///   - url: Page URL used for site-specific styles.
    ///   - readability: 0 = maximum see-through, 1 = strongest soft wash for crisp reading.
    /// - Returns: Combined CSS, or `nil` when styles are disabled for the site.
    func composedTransparencyCSS(for url: URL, readability: Double) -> String? {
        guard let siteCSS = getStyle(for: url) else { return nil }
        let overlay = readabilityOverlayCSS(intensity: readability)
        if overlay.isEmpty {
            return siteCSS
        }
        return siteCSS + "\n\n/* Zero readability overlay */\n" + overlay
    }

    /// Soft ambient wash + content plates so wallpaper glass stays visible while text stays sharp.
    /// Tuned to beat typical Linux Transparent Zen defaults on contrast without muddying the glass.
    func readabilityOverlayCSS(intensity: Double) -> String {
        let clamped = min(max(intensity, 0), 1)
        guard clamped > 0.02 else { return "" }

        // Light/dark ambient veils sit *behind* page content (html::before).
        let lightVeil = String(format: "%.3f", 0.04 + (0.22 * clamped))
        let darkVeil = String(format: "%.3f", 0.06 + (0.28 * clamped))
        // Content plates only kick in past a gentle threshold so clear glass stays clear.
        let plateBoost = max(0, (clamped - 0.18) / 0.82)
        let lightPlate = String(format: "%.3f", 0.10 + (0.38 * plateBoost))
        let darkPlate = String(format: "%.3f", 0.14 + (0.42 * plateBoost))
        // Hairline text edge for dense copy over busy wallpapers — barely there at low intensity.
        let shadowAlpha = String(format: "%.3f", 0.08 + (0.22 * clamped))
        let shadowBlur = String(format: "%.2f", 0.35 + (0.55 * clamped))

        return """
        html {
          background-color: transparent !important;
          background: transparent !important;
        }
        body {
          background-color: transparent !important;
          background: transparent !important;
        }
        html::before {
          content: "" !important;
          position: fixed !important;
          inset: 0 !important;
          z-index: -1 !important;
          pointer-events: none !important;
          background: light-dark(
            rgba(252, 252, 253, \(lightVeil)),
            rgba(8, 10, 14, \(darkVeil))
          ) !important;
        }
        article,
        main,
        [role="main"],
        #content,
        #main,
        #main-content,
        .content,
        .post,
        .post-content,
        .entry-content,
        .markdown-body,
        .ProseMirror,
        .cm-editor,
        .reader-content,
        .page-content,
        .mw-body-content {
          background-color: light-dark(
            rgba(255, 255, 255, \(lightPlate)),
            rgba(14, 16, 20, \(darkPlate))
          ) !important;
          background-image: none !important;
        }
        body, p, li, td, th, label, h1, h2, h3, h4, h5, h6 {
          text-shadow: 0 0 \(shadowBlur)px light-dark(
            rgba(255, 255, 255, \(shadowAlpha)),
            rgba(0, 0, 0, \(shadowAlpha))
          ) !important;
        }
        """
    }

    /// Extract base domain from a domain string (e.g., google.com -> google)
    private func extractBaseDomain(from domain: String) -> String? {
        let components = domain.split(separator: ".")
        guard components.count >= 2 else { return nil }
        return String(components[components.count - 2])
    }

    /// Check if styles are available (either domain-specific or fallback)
    var hasStyles: Bool {
        return !styleCache.isEmpty || !fallbackStyle.isEmpty
    }
}
