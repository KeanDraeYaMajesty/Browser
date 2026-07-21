//
//  InstalledWebExtension.swift
//  Browser
//

import Foundation
import AppKit

struct InstalledWebExtension: Identifiable, Codable, Equatable {
    var id: String
    var directoryName: String
    var enabled: Bool
    var installedAt: Date
    var manifest: ExtensionManifest

    var displayName: String { manifest.name }
    var version: String { manifest.version }
    var extensionDescription: String { manifest.description ?? "" }

    func packageURL(in root: URL) -> URL {
        root.appendingPathComponent(directoryName, isDirectory: true)
    }

    func resourceURL(_ relativePath: String, in root: URL) -> URL {
        packageURL(in: root).appendingPathComponent(relativePath)
    }

    func icon(in root: URL, size: CGFloat = 32) -> NSImage? {
        let candidates: [String?] = [
            manifest.toolbarAction?.defaultIcon?.preferredPath,
            manifest.icons?["128"],
            manifest.icons?["96"],
            manifest.icons?["64"],
            manifest.icons?["48"],
            manifest.icons?["32"],
            manifest.icons?["16"],
            manifest.icons?.values.first
        ]
        for candidate in candidates.compactMap({ $0 }) {
            let url = resourceURL(candidate, in: root)
            if let image = NSImage(contentsOf: url) {
                image.size = NSSize(width: size, height: size)
                return image
            }
        }
        return nil
    }
}
