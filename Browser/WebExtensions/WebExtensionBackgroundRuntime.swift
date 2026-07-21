//
//  WebExtensionBackgroundRuntime.swift
//  Browser
//
//  Runs Firefox extension background scripts in JavaScriptCore.
//

import Foundation
import JavaScriptCore

final class WebExtensionBackgroundRuntime {
    let extensionId: String
    private let context: JSContext
    private let dispatcher: WebExtensionAPIDispatcher
    private let queue: DispatchQueue

    init(extensionId: String, dispatcher: WebExtensionAPIDispatcher, queue: DispatchQueue) {
        self.extensionId = extensionId
        self.dispatcher = dispatcher
        self.queue = queue
        self.context = JSContext()!
        context.name = "ZeroExtension:\(extensionId)"
        context.exceptionHandler = { _, exception in
            print("🧩 [\(extensionId)] JS exception:", exception?.toString() ?? "unknown")
        }
        installNativeBridge()
    }

    func start(packageRoot: URL, background: ExtensionManifest.Background) throws {
        // Caller must already be on `queue`.
        guard let bridgeURL = Bundle.main.url(forResource: "background-bridge", withExtension: "js"),
              let bridge = try? String(contentsOf: bridgeURL, encoding: .utf8) else {
            throw WebExtensionError.runtime("Missing background-bridge.js")
        }
        context.evaluateScript(bridge)

        var scripts = background.scripts ?? []
        if let serviceWorker = background.serviceWorker {
            scripts.append(serviceWorker)
        }
        if scripts.isEmpty, let page = background.page {
            print("🧩 [\(extensionId)] background.page (\(page)) is not fully supported; prefer background.scripts")
        }

        for relative in scripts {
            let fileURL = packageRoot.appendingPathComponent(relative)
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            context.evaluateScript(source, withSourceURL: fileURL)
        }
    }

    func deliverMessage(_ message: Any, sender: [String: Any]) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    guard let deliver = self.context.globalObject.objectForKeyedSubscript("__zeroBackgroundDeliverMessage"),
                          !deliver.isUndefined else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let messageJSON = try Self.jsonString(from: message)
                    let senderJSON = try Self.jsonString(from: sender)
                    let resultValue = deliver.call(withArguments: [messageJSON, senderJSON])

                    if let resultValue, resultValue.hasProperty("then") {
                        let thenBlock: @convention(block) (JSValue?) -> Void = { value in
                            do {
                                if let value, let json = value.toString(), let data = json.data(using: .utf8) {
                                    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                    continuation.resume(returning: object?["result"])
                                } else {
                                    continuation.resume(returning: nil)
                                }
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                        let catchBlock: @convention(block) (JSValue?) -> Void = { error in
                            continuation.resume(throwing: WebExtensionError.runtime(error?.toString() ?? "background message failed"))
                        }
                        resultValue.invokeMethod("then", withArguments: [unsafeBitCast(thenBlock, to: AnyObject.self)])
                        resultValue.invokeMethod("catch", withArguments: [unsafeBitCast(catchBlock, to: AnyObject.self)])
                        return
                    }

                    if let json = resultValue?.toString(), let data = json.data(using: .utf8),
                       let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        continuation.resume(returning: object["result"])
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func installNativeBridge() {
        let extensionId = self.extensionId
        let dispatcher = self.dispatcher

        let native = JSValue(newObjectIn: context)!
        let callBlock: @convention(block) (String?, String?) -> String = { method, argsJSON in
            guard let method else {
                return #"{"error":"missing method"}"#
            }
            let args: [Any]
            if let argsJSON, let data = argsJSON.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                args = parsed
            } else {
                args = []
            }

            let semaphore = DispatchSemaphore(value: 0)
            var response = #"{"result":null}"#
            Task { @MainActor in
                do {
                    let result = try await dispatcher.handle(method: method, args: args, senderTabId: nil)
                    response = try Self.successJSON(result)
                } catch {
                    response = Self.errorJSON(error.localizedDescription)
                }
                semaphore.signal()
            }
            // Runs on the extension background queue (never the main thread).
            _ = semaphore.wait(timeout: .now() + 10)
            return response
        }

        let idBlock: @convention(block) () -> String = { extensionId }
        let logBlock: @convention(block) (String?) -> Void = { message in
            print("🧩 [\(extensionId)]", message ?? "")
        }

        native.setObject(unsafeBitCast(callBlock, to: AnyObject.self), forKeyedSubscript: "call" as NSString)
        native.setObject(unsafeBitCast(idBlock, to: AnyObject.self), forKeyedSubscript: "extensionId" as NSString)
        native.setObject(unsafeBitCast(logBlock, to: AnyObject.self), forKeyedSubscript: "log" as NSString)
        context.setObject(native, forKeyedSubscript: "ZeroNative" as NSString)
    }

    private static func successJSON(_ result: Any?) throws -> String {
        let payload: [String: Any] = ["result": result ?? NSNull()]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.fragmentsAllowed])
        return String(data: data, encoding: .utf8) ?? #"{"result":null}"#
    }

    private static func errorJSON(_ message: String) -> String {
        let payload = ["error": message]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else {
            return #"{"error":"unknown"}"#
        }
        return string
    }

    private static func jsonString(from value: Any) throws -> String {
        if value is NSNull { return "null" }
        if JSONSerialization.isValidJSONObject(value) {
            let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
            return String(data: data, encoding: .utf8) ?? "null"
        }
        // Allow JSON fragments (string/number/bool)
        let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
        return String(data: data, encoding: .utf8) ?? "null"
    }
}
