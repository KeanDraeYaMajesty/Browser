//
//  WebExtensionStorage.swift
//  Browser
//
//  browser.storage.local backed by a JSON file per extension.
//

import Foundation

final class WebExtensionStorage {
    private let fileURL: URL
    private let lock = NSLock()
    private var values: [String: Any] = [:]

    init(extensionId: String, rootURL: URL) {
        let dir = rootURL.appendingPathComponent("storage", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = extensionId.replacingOccurrences(of: "[^A-Za-z0-9._@+-]+", with: "_", options: .regularExpression)
        fileURL = dir.appendingPathComponent("\(safe).json")
        load()
    }

    func get(_ keys: Any?) -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        guard let keys else { return values }
        if let key = keys as? String {
            if let value = values[key] { return [key: value] }
            return [:]
        }
        if let keyList = keys as? [String] {
            var result: [String: Any] = [:]
            for key in keyList {
                if let value = values[key] { result[key] = value }
            }
            return result
        }
        if let defaults = keys as? [String: Any] {
            var result = defaults
            for (key, value) in values {
                result[key] = value
            }
            return result
        }
        return values
    }

    func set(_ items: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }
        for (key, value) in items {
            values[key] = value
        }
        saveLocked()
    }

    func remove(_ keys: Any?) {
        lock.lock()
        defer { lock.unlock() }
        if let key = keys as? String {
            values.removeValue(forKey: key)
        } else if let keyList = keys as? [String] {
            keyList.forEach { values.removeValue(forKey: $0) }
        }
        saveLocked()
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        values.removeAll()
        saveLocked()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else { return }
        values = dict
    }

    private func saveLocked() {
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted]) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
