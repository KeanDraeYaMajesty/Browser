//
//  WebExtensionAPIDispatcher.swift
//  Browser
//
//  Handles browser.* method calls from content scripts and background pages.
//

import Foundation
import WebKit

@MainActor
final class WebExtensionAPIDispatcher {
    weak var manager: WebExtensionManager?
    let installed: InstalledWebExtension
    let storage: WebExtensionStorage
    let packageRoot: URL

    init(manager: WebExtensionManager, installed: InstalledWebExtension, storage: WebExtensionStorage, packageRoot: URL) {
        self.manager = manager
        self.installed = installed
        self.storage = storage
        self.packageRoot = packageRoot
    }

    func handle(method: String, args: [Any], senderTabId: Int?) async throws -> Any? {
        switch method {
        case "runtime.getManifest":
            return try manifestDictionary()

        case "runtime.getURL":
            let path = (args.first as? String) ?? ""
            return "zero-extension://\(installed.id)/\(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"

        case "runtime.sendMessage":
            return try await handleSendMessage(args: args, senderTabId: senderTabId)

        case "storage.local.get":
            return storage.get(args.first ?? nil)

        case "storage.local.set":
            if let items = args.first as? [String: Any] {
                storage.set(items)
            }
            return nil

        case "storage.local.remove":
            storage.remove(args.first ?? nil)
            return nil

        case "storage.local.clear":
            storage.clear()
            return nil

        case "tabs.query":
            return queryTabs(args.first as? [String: Any] ?? [:])

        case "tabs.get":
            let tabId = intValue(args.first)
            guard let tab = WebExtensionTabRegistry.shared.allTabInfos().first(where: { $0.id == tabId }) else {
                throw WebExtensionError.runtime("Tab not found")
            }
            return tabDictionary(tab)

        case "tabs.getCurrent":
            if let senderTabId,
               let tab = WebExtensionTabRegistry.shared.allTabInfos().first(where: { $0.id == senderTabId }) {
                return tabDictionary(tab)
            }
            if let tab = WebExtensionTabRegistry.shared.activeTabInfo() {
                return tabDictionary(tab)
            }
            return NSNull()

        case "tabs.create":
            return try await createTab(args.first as? [String: Any] ?? [:])

        case "tabs.sendMessage":
            let tabId = intValue(args.first)
            let message = args.count > 1 ? args[1] : NSNull()
            return try await manager?.deliverMessageToTab(
                tabId: tabId,
                extensionId: installed.id,
                message: message
            )

        case "tabs.executeScript":
            return try await executeScript(args: args)

        default:
            throw WebExtensionError.runtime("Unsupported API: \(method)")
        }
    }

    private func handleSendMessage(args: [Any], senderTabId: Int?) async throws -> Any? {
        // browser.runtime.sendMessage(message) or (extensionId, message)
        let targetId: String
        let message: Any
        if args.count >= 2, let explicitId = args[0] as? String {
            targetId = explicitId
            message = args[1]
        } else {
            targetId = installed.id
            message = args.first ?? NSNull()
        }

        guard let manager else { return nil }
        if targetId == installed.id {
            return try await manager.deliverMessageToBackground(
                extensionId: installed.id,
                message: message,
                senderTabId: senderTabId
            )
        }
        return try await manager.deliverMessageToBackground(
            extensionId: targetId,
            message: message,
            senderTabId: senderTabId
        )
    }

    private func queryTabs(_ query: [String: Any]) -> [[String: Any]] {
        var tabs = WebExtensionTabRegistry.shared.allTabInfos()
        if let active = query["active"] as? Bool {
            tabs = tabs.filter { $0.active == active }
        }
        if let windowId = intValueOptional(query["windowId"]) {
            tabs = tabs.filter { $0.windowId == windowId }
        }
        if let currentWindow = query["currentWindow"] as? Bool, currentWindow {
            let activeWindow = WebExtensionTabRegistry.shared.activeTabInfo()?.windowId ?? 1
            tabs = tabs.filter { $0.windowId == activeWindow }
        }
        if let urlPattern = query["url"] as? String {
            tabs = tabs.filter { tab in
                guard let url = tab.url else { return false }
                return WebExtensionMatchPattern.matches(url: url, pattern: urlPattern)
            }
        }
        return tabs.map(tabDictionary)
    }

    private func createTab(_ properties: [String: Any]) async throws -> [String: Any] {
        let urlString = properties["url"] as? String
        guard let urlString, let url = URL(string: urlString) else {
            throw WebExtensionError.runtime("tabs.create requires a url")
        }
        await MainActor.run {
            NotificationCenter.default.post(
                name: .webExtensionOpenURL,
                object: nil,
                userInfo: ["url": url, "active": properties["active"] as? Bool ?? true]
            )
        }
        // Best-effort: return a synthetic tab descriptor; real id appears after load.
        return [
            "id": -1,
            "url": urlString,
            "active": properties["active"] as? Bool ?? true,
            "windowId": 1,
            "status": "loading"
        ]
    }

    private func executeScript(args: [Any]) async throws -> [Any?] {
        let tabId: Int?
        let details: [String: Any]
        if let first = args.first as? Int {
            tabId = first
            details = args.dropFirst().first as? [String: Any] ?? [:]
        } else if args.first is NSNull || args.first == nil {
            tabId = WebExtensionTabRegistry.shared.activeTabInfo()?.id
            details = args.dropFirst().first as? [String: Any] ?? (args.first as? [String: Any] ?? [:])
        } else {
            tabId = WebExtensionTabRegistry.shared.activeTabInfo()?.id
            details = args.first as? [String: Any] ?? [:]
        }

        guard let tabId, let webView = WebExtensionTabRegistry.shared.webView(forTabId: tabId) else {
            throw WebExtensionError.runtime("No tab available for executeScript")
        }

        var code = details["code"] as? String
        if code == nil, let file = details["file"] as? String {
            let fileURL = packageRoot.appendingPathComponent(file)
            code = try String(contentsOf: fileURL, encoding: .utf8)
        }
        guard let code else {
            throw WebExtensionError.runtime("executeScript requires code or file")
        }

        let result = try await webView.evaluateJavaScript(code)
        return [result]
    }

    private func manifestDictionary() throws -> [String: Any] {
        let data = try Data(contentsOf: packageRoot.appendingPathComponent("manifest.json"))
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }

    private func tabDictionary(_ tab: WebExtensionTabInfo) -> [String: Any] {
        var dict: [String: Any] = [
            "id": tab.id,
            "active": tab.active,
            "windowId": tab.windowId,
            "status": tab.status,
            "index": tab.id
        ]
        if let url = tab.url?.absoluteString { dict["url"] = url }
        if let title = tab.title { dict["title"] = title }
        return dict
    }

    private func intValue(_ value: Any?) -> Int {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let d = value as? Double { return Int(d) }
        return -1
    }

    private func intValueOptional(_ value: Any?) -> Int? {
        if value == nil || value is NSNull { return nil }
        return intValue(value)
    }
}

extension Notification.Name {
    static let webExtensionOpenURL = Notification.Name("WebExtensionOpenURL")
    static let webExtensionDidChange = Notification.Name("WebExtensionDidChange")
}
