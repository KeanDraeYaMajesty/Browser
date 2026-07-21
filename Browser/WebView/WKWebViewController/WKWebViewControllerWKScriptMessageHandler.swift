//
//  WKWebViewControllerWKScriptMessageHandler.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 3/24/25.
//
import WebKit

extension WKWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "hoverURL":
            handleHoverURL(message.body)
        case "middleClickLink":
            handleMiddleClickLink(message.body)
        default:
            break
        }
    }

    func addHoverURLListener() {
        guard let hoverURLListenerScriptURL = Bundle.main.url(forResource: "HoverURLListener", withExtension: "js"),
              let script = try? String(contentsOf: hoverURLListenerScriptURL, encoding: .utf8) else { return }

        let controller = configuration.userContentController

        controller.removeScriptMessageHandler(forName: "hoverURL")
        controller.add(self, name: "hoverURL")

        // Replace rather than accumulate — user scripts were previously appended on every navigation.
        let existing = controller.userScripts.filter { !$0.source.contains("/* zero:hover-url */") }
        controller.removeAllUserScripts()
        existing.forEach { controller.addUserScript($0) }
        let wrapped = "/* zero:hover-url */\n" + script
        controller.addUserScript(WKUserScript(source: wrapped, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    }

    func addMiddleClickLinkListener() {
        guard let middleClickScriptURL = Bundle.main.url(forResource: "MiddleClickLinkListener", withExtension: "js"),
              let script = try? String(contentsOf: middleClickScriptURL, encoding: .utf8) else { return }

        let controller = configuration.userContentController

        controller.removeScriptMessageHandler(forName: "middleClickLink")
        controller.add(self, name: "middleClickLink")

        let existing = controller.userScripts.filter { !$0.source.contains("/* zero:middle-click */") }
        controller.removeAllUserScripts()
        existing.forEach { controller.addUserScript($0) }
        let wrapped = "/* zero:middle-click */\n" + script
        controller.addUserScript(WKUserScript(source: wrapped, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    }

    func handleHoverURL(_ body: Any) {
        guard let url = body as? String, !url.isEmpty else { return }
        self.coordinator.setHoverURL(to: url)
    }

    func handleMiddleClickLink(_ body: Any) {
        guard let urlString = body as? String, let url = URL(string: urlString) else { return }
        self.coordinator.openLinkInNewTabAction(url)
    }
}
