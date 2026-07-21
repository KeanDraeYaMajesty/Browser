//
//  ExtensionWindowAdapter.swift
//  Browser
//
//  Bridges BrowserWindowState / NSWindow to WKWebExtensionWindow.
//

import AppKit
import WebKit

@MainActor
final class ExtensionWindowAdapter: NSObject, WKWebExtensionWindow {
    let id = UUID()
    weak var windowState: BrowserWindowState?
    weak var nsWindow: NSWindow?
    var isPrivate: Bool

    init(windowState: BrowserWindowState, nsWindow: NSWindow?, isPrivate: Bool) {
        self.windowState = windowState
        self.nsWindow = nsWindow
        self.isPrivate = isPrivate
        super.init()
    }

    func tabs(for extensionContext: WKWebExtensionContext) -> [any WKWebExtensionTab] {
        guard let space = windowState?.currentSpace else { return [] }
        return space.allTabs.compactMap { ExtensionManager.shared.tabAdapter(for: $0) }
    }

    func activeTab(for extensionContext: WKWebExtensionContext) -> (any WKWebExtensionTab)? {
        guard let tab = windowState?.currentSpace?.currentTab else { return nil }
        return ExtensionManager.shared.tabAdapter(for: tab)
    }

    func windowType(for extensionContext: WKWebExtensionContext) -> WKWebExtension.WindowType {
        .normal
    }

    func windowState(for extensionContext: WKWebExtensionContext) -> WKWebExtension.WindowState {
        guard let window = nsWindow else { return .normal }
        if window.isMiniaturized { return .minimized }
        if window.styleMask.contains(.fullScreen) { return .fullscreen }
        if windowState?.isFullScreen == true { return .fullscreen }
        return .normal
    }

    func setWindowState(_ state: WKWebExtension.WindowState, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        guard let window = nsWindow else {
            completionHandler(nil)
            return
        }

        switch state {
        case .minimized:
            window.miniaturize(nil)
        case .fullscreen:
            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        case .normal, .maximized:
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
            if state == .maximized {
                window.zoom(nil)
            }
        @unknown default:
            break
        }
        completionHandler(nil)
    }

    func isPrivate(for extensionContext: WKWebExtensionContext) -> Bool {
        isPrivate
    }

    func screenFrame(for extensionContext: WKWebExtensionContext) -> CGRect {
        nsWindow?.screen?.frame ?? .null
    }

    func frame(for extensionContext: WKWebExtensionContext) -> CGRect {
        nsWindow?.frame ?? .null
    }

    func setFrame(_ frame: CGRect, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        nsWindow?.setFrame(frame, display: true)
        completionHandler(nil)
    }

    func focus(for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        nsWindow?.makeKeyAndOrderFront(nil)
        completionHandler(nil)
    }

    func close(for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        nsWindow?.close()
        completionHandler(nil)
    }
}
