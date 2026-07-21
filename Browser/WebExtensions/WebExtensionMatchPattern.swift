//
//  WebExtensionMatchPattern.swift
//  Browser
//
//  Match-pattern matching for Firefox-style content_scripts.
//  https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Match_patterns
//

import Foundation

enum WebExtensionMatchPattern {
    static func matches(url: URL, patterns: [String]) -> Bool {
        patterns.contains { matches(url: url, pattern: $0) }
    }

    static func matches(url: URL, pattern: String) -> Bool {
        if pattern == "<all_urls>" {
            guard let scheme = url.scheme?.lowercased() else { return false }
            return ["http", "https", "ws", "wss", "file", "ftp"].contains(scheme)
        }

        // scheme://host/path
        guard let schemeEnd = pattern.firstIndex(of: ":") else { return false }
        let schemePart = String(pattern[..<schemeEnd])
        let rest = pattern[pattern.index(schemeEnd, offsetBy: 3)...] // skip "://"
        guard pattern.dropFirst(schemePart.count).hasPrefix("://") else { return false }

        let pathStart = rest.firstIndex(of: "/") ?? rest.endIndex
        let hostPart = String(rest[..<pathStart])
        let pathPart = pathStart < rest.endIndex ? String(rest[pathStart...]) : "/*"

        guard let urlScheme = url.scheme?.lowercased() else { return false }
        if schemePart != "*" && schemePart.lowercased() != urlScheme {
            return false
        }
        if schemePart == "*" && !["http", "https", "ws", "wss", "file", "ftp"].contains(urlScheme) {
            return false
        }

        let host = url.host ?? ""
        if !hostMatches(host: host, pattern: hostPart) {
            return false
        }

        let path = url.path.isEmpty ? "/" : url.path
        return pathMatches(path: path, pattern: pathPart)
    }

    private static func hostMatches(host: String, pattern: String) -> Bool {
        if pattern == "*" { return true }
        if pattern.hasPrefix("*.") {
            let suffix = String(pattern.dropFirst(2))
            return host == suffix || host.hasSuffix("." + suffix)
        }
        return host.caseInsensitiveCompare(pattern) == .orderedSame
    }

    private static func pathMatches(path: String, pattern: String) -> Bool {
        let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*") + "$"
        guard let regex = try? NSRegularExpression(pattern: regexPattern) else { return false }
        let range = NSRange(path.startIndex..., in: path)
        return regex.firstMatch(in: path, range: range) != nil
    }
}
