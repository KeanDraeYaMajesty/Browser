//
//  WebExtensionStore.swift
//  Browser
//
//  Persists installed Firefox-compatible extensions under Application Support.
//

import Foundation

final class WebExtensionStore {
    static let shared = WebExtensionStore()

    let rootURL: URL
    private let indexURL: URL
    private let fileManager = FileManager.default

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        rootURL = appSupport.appendingPathComponent("Zero/WebExtensions", isDirectory: true)
        indexURL = rootURL.appendingPathComponent("index.json")
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    func loadIndex() -> [InstalledWebExtension] {
        guard fileManager.fileExists(atPath: indexURL.path),
              let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([InstalledWebExtension].self, from: data) else {
            return []
        }
        return decoded.filter { fileManager.fileExists(atPath: $0.packageURL(in: rootURL).path) }
    }

    func saveIndex(_ extensions: [InstalledWebExtension]) throws {
        let data = try JSONEncoder().encode(extensions)
        try data.write(to: indexURL, options: .atomic)
    }

    func install(from sourceURL: URL) throws -> InstalledWebExtension {
        let staging = rootURL.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory)

        if sourceURL.pathExtension.lowercased() == "xpi" || sourceURL.pathExtension.lowercased() == "zip" {
            try unzip(sourceURL, to: staging)
        } else if isDirectory.boolValue {
            try copyDirectoryContents(from: sourceURL, to: staging)
        } else {
            throw WebExtensionError.invalidPackage("Select a Firefox .xpi, .zip, or unpacked extension folder.")
        }

        let manifestURL = findManifest(in: staging)
        guard let manifestURL else {
            throw WebExtensionError.invalidPackage("No manifest.json found in the extension package.")
        }

        let packageRoot = manifestURL.deletingLastPathComponent()
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(ExtensionManifest.self, from: data)

        guard manifest.manifestVersion == 2 || manifest.manifestVersion == 3 else {
            throw WebExtensionError.invalidPackage("Only Manifest V2 and V3 extensions are supported.")
        }

        let extensionId = manifest.resolvedExtensionId
        let directoryName = sanitizeDirectoryName(extensionId)
        let destination = rootURL.appendingPathComponent(directoryName, isDirectory: true)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: packageRoot, to: destination)

        return InstalledWebExtension(
            id: extensionId,
            directoryName: directoryName,
            enabled: true,
            installedAt: Date(),
            manifest: manifest
        )
    }

    func removePackage(_ installed: InstalledWebExtension) {
        try? fileManager.removeItem(at: installed.packageURL(in: rootURL))
    }

    private func findManifest(in directory: URL) -> URL? {
        let direct = directory.appendingPathComponent("manifest.json")
        if fileManager.fileExists(atPath: direct.path) { return direct }

        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) else { return nil }
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "manifest.json" {
                return fileURL
            }
        }
        return nil
    }

    private func copyDirectoryContents(from source: URL, to destination: URL) throws {
        let items = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for item in items {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
            try fileManager.copyItem(at: item, to: target)
        }
    }

    private func unzip(_ archive: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-qq", "-o", archive.path, "-d", destination.path]
        let err = Pipe()
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unzip failed"
            throw WebExtensionError.invalidPackage(message)
        }
    }

    private func sanitizeDirectoryName(_ id: String) -> String {
        let cleaned = id.replacingOccurrences(of: "[^A-Za-z0-9._@+-]+", with: "_", options: .regularExpression)
        return cleaned.isEmpty ? UUID().uuidString : cleaned
    }
}

enum WebExtensionError: LocalizedError {
    case invalidPackage(String)
    case runtime(String)

    var errorDescription: String? {
        switch self {
        case .invalidPackage(let message), .runtime(let message):
            return message
        }
    }
}
