//
//  ExtensionModels.swift
//  Browser
//
//  Models for installed web extensions managed via WKWebExtension.
//

import AppKit
import Foundation

/// Lightweight UI model for an installed Chrome/Firefox-compatible web extension.
struct InstalledExtension: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var version: String
    var extensionDescription: String
    var isEnabled: Bool
    var icon: NSImage?
    var path: URL
    var hasOptionsPage: Bool
    var hasAction: Bool

    static func == (lhs: InstalledExtension, rhs: InstalledExtension) -> Bool {
        lhs.id == rhs.id && lhs.isEnabled == rhs.isEnabled && lhs.name == rhs.name && lhs.version == rhs.version
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Persisted metadata for installed extensions (enabled state + install path).
struct ExtensionStoreRecord: Codable, Equatable {
    var id: String
    var enabled: Bool
    var relativePath: String
}

enum ExtensionManagerError: LocalizedError {
    case invalidPackage
    case missingManifest
    case loadFailed(String)
    case unsupportedLocation

    var errorDescription: String? {
        switch self {
        case .invalidPackage:
            return "The selected file is not a valid web extension package."
        case .missingManifest:
            return "No manifest.json was found in the extension package."
        case .loadFailed(let message):
            return "Failed to load extension: \(message)"
        case .unsupportedLocation:
            return "Extensions can only be installed from local folders or .zip archives."
        }
    }
}
