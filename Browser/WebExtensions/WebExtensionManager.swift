//
//  WebExtensionManager.swift
//  Browser
//
//  Loads, enables, and runs Firefox-compatible WebExtensions.
//

import Foundation
import WebKit
import AppKit
import Combine

@MainActor
final class WebExtensionManager: NSObject, ObservableObject {
    static let shared = WebExtensionManager()

    @Published private(set) var extensions: [InstalledWebExtension] = []
    @Published var lastError: String?

    private let store = WebExtensionStore.shared
    private var dispatchers: [String: WebExtensionAPIDispatcher] = [:]
    private var storages: [String: WebExtensionStorage] = [:]
    private var backgrounds: [String: WebExtensionBackgroundRuntime] = [:]
    private var backgroundQueues: [String: DispatchQueue] = [:]
    private var contentBridgeSource: String = ""

    private override init() {
        super.init()
        if let url = Bundle.main.url(forResource: "content-bridge", withExtension: "js"),
           let source = try? String(contentsOf: url, encoding: .utf8) {
            contentBridgeSource = source
        }
        reloadFromDisk()
    }

    func reloadFromDisk() {
        extensions = store.loadIndex()
        restartRuntimes()
        NotificationCenter.default.post(name: .webExtensionDidChange, object: nil)
    }

    @discardableResult
    func install(from url: URL) throws -> InstalledWebExtension {
        let installed = try store.install(from: url)
        var next = extensions.filter { $0.id != installed.id }
        next.append(installed)
        next.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        extensions = next
        try store.saveIndex(extensions)
        restartRuntimes()
        NotificationCenter.default.post(name: .webExtensionDidChange, object: nil)
        return installed
    }

    func setEnabled(_ enabled: Bool, for id: String) throws {
        guard let index = extensions.firstIndex(where: { $0.id == id }) else { return }
        extensions[index].enabled = enabled
        try store.saveIndex(extensions)
        restartRuntimes()
        NotificationCenter.default.post(name: .webExtensionDidChange, object: nil)
    }

    func uninstall(id: String) throws {
        guard let installed = extensions.first(where: { $0.id == id }) else { return }
        store.removePackage(installed)
        extensions.removeAll { $0.id == id }
        try store.saveIndex(extensions)
        restartRuntimes()
        NotificationCenter.default.post(name: .webExtensionDidChange, object: nil)
    }

    var enabledExtensions: [InstalledWebExtension] {
        extensions.filter(\.enabled)
    }

    // MARK: - Content script injection

    func injectContentScripts(into webView: WKWebView, navigationTiming: ContentScriptTiming) {
        guard let url = webView.url else { return }
        let tabId = WebExtensionTabRegistry.shared.tabId(for: webView)
            ?? WebExtensionTabRegistry.shared.register(webView: webView)
        WebExtensionTabRegistry.shared.update(webView: webView, url: url, isLoading: navigationTiming != .documentEnd)

        for installed in enabledExtensions {
            guard let scripts = installed.manifest.contentScripts else { continue }
            let root = installed.packageURL(in: store.rootURL)

            for script in scripts {
                let runAt = ContentScriptTiming(rawValue: script.runAt ?? "document_idle") ?? .documentIdle
                guard runAt == navigationTiming || (navigationTiming == .documentEnd && runAt == .documentIdle) else {
                    continue
                }
                guard WebExtensionMatchPattern.matches(url: url, patterns: script.matches) else { continue }
                if let excluded = script.excludeMatches,
                   WebExtensionMatchPattern.matches(url: url, patterns: excluded) {
                    continue
                }

                // Bridge first
                let bridge = contentBridgeSource.replacingOccurrences(of: "__ZERO_EXTENSION_ID__", with: installed.id)
                webView.evaluateJavaScript(bridge, completionHandler: nil)

                if let cssFiles = script.css {
                    for file in cssFiles {
                        if let css = try? String(contentsOf: root.appendingPathComponent(file), encoding: .utf8) {
                            let escaped = css
                                .replacingOccurrences(of: "\\", with: "\\\\")
                                .replacingOccurrences(of: "`", with: "\\`")
                                .replacingOccurrences(of: "$", with: "\\$")
                            let inject = """
                            (function() {
                              var s = document.createElement('style');
                              s.setAttribute('data-zero-extension', '\(installed.id)');
                              s.textContent = `\(escaped)`;
                              (document.head || document.documentElement).appendChild(s);
                            })();
                            """
                            webView.evaluateJavaScript(inject, completionHandler: nil)
                        }
                    }
                }

                if let jsFiles = script.js {
                    for file in jsFiles {
                        if let source = try? String(contentsOf: root.appendingPathComponent(file), encoding: .utf8) {
                            webView.evaluateJavaScript(source, completionHandler: nil)
                        }
                    }
                }
            }
        }

        _ = tabId
    }

    func ensureMessageHandler(on controller: WKUserContentController) {
        controller.removeScriptMessageHandler(forName: "webExtension")
        controller.add(self, name: "webExtension")
    }

    // MARK: - Messaging

    func deliverMessageToBackground(extensionId: String, message: Any, senderTabId: Int?) async throws -> Any? {
        guard let runtime = backgrounds[extensionId] else { return nil }
        var sender: [String: Any] = ["id": extensionId]
        if let senderTabId,
           let tab = WebExtensionTabRegistry.shared.allTabInfos().first(where: { $0.id == senderTabId }) {
            var tabDict: [String: Any] = [
                "id": tab.id,
                "active": tab.active,
                "windowId": tab.windowId
            ]
            if let url = tab.url?.absoluteString { tabDict["url"] = url }
            if let title = tab.title { tabDict["title"] = title }
            sender["tab"] = tabDict
        }
        return try await runtime.deliverMessage(message, sender: sender)
    }

    func deliverMessageToTab(tabId: Int, extensionId: String, message: Any) async throws -> Any? {
        guard let webView = WebExtensionTabRegistry.shared.webView(forTabId: tabId) else {
            throw WebExtensionError.runtime("Tab \(tabId) not found")
        }
        let messageJSON = try jsonString(from: message)
        var sender: [String: Any] = ["id": extensionId]
        if let url = webView.url?.absoluteString {
            sender["url"] = url
        }
        let senderJSON = try jsonString(from: sender)
        let js = """
        (async function() {
          if (typeof window.__zeroWebExtensionDeliverMessage === 'function' && window.__zeroWebExtensionId === \(jsonEncode(extensionId))) {
            return await window.__zeroWebExtensionDeliverMessage(\(messageJSON), \(senderJSON));
          }
          return null;
        })();
        """
        return try await webView.evaluateJavaScript(js)
    }

    // MARK: - Runtimes

    private func restartRuntimes() {
        backgrounds.removeAll()
        dispatchers.removeAll()
        backgroundQueues.removeAll()

        for installed in enabledExtensions {
            let root = installed.packageURL(in: store.rootURL)
            let storage = storages[installed.id] ?? WebExtensionStorage(extensionId: installed.id, rootURL: store.rootURL)
            storages[installed.id] = storage

            let dispatcher = WebExtensionAPIDispatcher(
                manager: self,
                installed: installed,
                storage: storage,
                packageRoot: root
            )
            dispatchers[installed.id] = dispatcher

            guard let background = installed.manifest.background else { continue }
            let queue = DispatchQueue(label: "zero.extension.background.\(installed.id)")
            backgroundQueues[installed.id] = queue

            queue.async {
                do {
                    let runtime = WebExtensionBackgroundRuntime(
                        extensionId: installed.id,
                        dispatcher: dispatcher,
                        queue: queue
                    )
                    try runtime.start(packageRoot: root, background: background)
                    Task { @MainActor in
                        self.backgrounds[installed.id] = runtime
                    }
                } catch {
                    print("🧩 Failed to start background for \(installed.id):", error)
                    Task { @MainActor in
                        self.lastError = error.localizedDescription
                    }
                }
            }
        }
    }

    private func jsonString(from value: Any) throws -> String {
        if JSONSerialization.isValidJSONObject(value) {
            let data = try JSONSerialization.data(withJSONObject: value)
            return String(data: data, encoding: .utf8) ?? "null"
        }
        if value is NSNull { return "null" }
        if let string = value as? String {
            return jsonEncode(string)
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return "null"
    }

    private func jsonEncode(_ string: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: string)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }
}

enum ContentScriptTiming: String {
    case documentStart = "document_start"
    case documentEnd = "document_end"
    case documentIdle = "document_idle"
}

extension WebExtensionManager: WKScriptMessageHandler {
    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "webExtension" else { return }
        Task { @MainActor in
            await self.handleContentMessage(message)
        }
    }

    @MainActor
    private func handleContentMessage(_ message: WKScriptMessage) async {
        guard let body = message.body as? [String: Any],
              let extensionId = body["extensionId"] as? String,
              let requestId = body["requestId"] as? String,
              let method = body["method"] as? String,
              let dispatcher = dispatchers[extensionId] else { return }

        let args = body["args"] as? [Any] ?? []
        let webView = message.webView
        let tabId = webView.flatMap { WebExtensionTabRegistry.shared.tabId(for: $0) }

        do {
            let result = try await dispatcher.handle(method: method, args: args, senderTabId: tabId)
            try await reply(to: webView, requestId: requestId, result: result, error: nil)
        } catch {
            try? await reply(to: webView, requestId: requestId, result: nil, error: error.localizedDescription)
        }
    }

    private func reply(to webView: WKWebView?, requestId: String, result: Any?, error: String?) async throws {
        guard let webView else { return }
        var payload: [String: Any] = ["requestId": requestId]
        if let error {
            payload["error"] = error
        } else {
            payload["result"] = result ?? NSNull()
        }
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        let js = "window.__zeroWebExtensionHandleNativeResponse && window.__zeroWebExtensionHandleNativeResponse(\(json));"
        try await webView.evaluateJavaScript(js)
    }
}
