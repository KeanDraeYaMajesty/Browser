//
//  ExtensionManager.swift
//  Browser
//
//  Manages WKWebExtensionController lifecycle, installation, and browser bridging.
//

import AppKit
import Combine
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WebKit

/// Coordinates Chrome/Firefox-compatible web extensions through system WebKit's WKWebExtension APIs.
@MainActor
final class ExtensionManager: NSObject, ObservableObject {
    static let shared = ExtensionManager()

    @Published private(set) var installedExtensions: [InstalledExtension] = []
    @Published private(set) var isReady = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var actionsRevision = 0

    private(set) var controller: WKWebExtensionController?

    private var contexts: [String: WKWebExtensionContext] = [:]
    private var tabAdapters: [UUID: ExtensionTabAdapter] = [:]
    private var windowAdapters: [ObjectIdentifier: ExtensionWindowAdapter] = [:]
    private var windowStateToAdapter: [ObjectIdentifier: ExtensionWindowAdapter] = [:]
    private var enabledState: [String: Bool] = [:]

    weak var activeWindowState: BrowserWindowState?
    var activeModelContext: ModelContext?

    private var popupAnchorView: NSView?
    private var activePopupPopover: NSPopover?

    private override init() {
        super.init()
    }

    // MARK: - Bootstrap

    func start() {
        guard controller == nil else { return }

        let configuration = WKWebExtensionController.Configuration.defaultConfiguration()
        let controller = WKWebExtensionController(configuration: configuration)
        controller.delegate = self
        self.controller = controller

        // Critical: attach the controller to the shared base config. Every tab config
        // must be derived via copy() so content scripts and background pages work.
        SharedWebViewConfiguration.shared.attachWebExtensionController(controller)
        loadPersistedState()

        Task {
            await reloadInstalledExtensions()
            isReady = true
        }
    }

    // MARK: - Paths

    private var extensionsRootURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = appSupport.appendingPathComponent("Zero/Extensions", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private var storeURL: URL {
        extensionsRootURL.appendingPathComponent("installed.json")
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        guard let data = try? Data(contentsOf: storeURL),
              let records = try? JSONDecoder().decode([ExtensionStoreRecord].self, from: data) else {
            return
        }
        enabledState = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.enabled) })
    }

    private func persistState() {
        let records = installedExtensions.map {
            ExtensionStoreRecord(id: $0.id, enabled: $0.isEnabled, relativePath: $0.id)
        }
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    // MARK: - Install / Uninstall / Enable

    func presentInstallPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.zip]
        panel.message = "Choose a Chrome/Firefox extension folder or .zip package"
        panel.prompt = "Install"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                _ = try await installExtension(from: url)
            } catch {
                lastErrorMessage = error.localizedDescription
                presentErrorAlert(error)
            }
        }
    }

    @discardableResult
    func installExtension(from sourceURL: URL) async throws -> InstalledExtension {
        let access = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if access { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let tempID = UUID().uuidString
        let tempDir = extensionsRootURL.appendingPathComponent("temp_\(tempID)", isDirectory: true)
        try? FileManager.default.removeItem(at: tempDir)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        try await extractPackage(from: sourceURL, to: tempDir)

        let manifestURL = findManifest(in: tempDir)
        guard let manifestURL else {
            try? FileManager.default.removeItem(at: tempDir)
            throw ExtensionManagerError.missingManifest
        }

        let packageRoot = manifestURL.deletingLastPathComponent()

        let webExtension = try await WKWebExtension(resourceBaseURL: packageRoot)
        let tempContext = WKWebExtensionContext(for: webExtension)
        let extensionID = tempContext.uniqueIdentifier

        let finalDir = extensionsRootURL.appendingPathComponent(extensionID, isDirectory: true)
        if FileManager.default.fileExists(atPath: finalDir.path) {
            try await uninstallExtension(id: extensionID, persist: false)
            try? FileManager.default.removeItem(at: finalDir)
        }

        try FileManager.default.moveItem(at: packageRoot, to: finalDir)
        if packageRoot != tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let installed = try await loadExtension(at: finalDir, extensionID: extensionID, enabled: true)
        if let index = installedExtensions.firstIndex(where: { $0.id == extensionID }) {
            installedExtensions[index] = installed
        } else {
            installedExtensions.append(installed)
        }
        installedExtensions.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistState()
        actionsRevision &+= 1
        return installed
    }

    func setExtensionEnabled(id: String, enabled: Bool) async {
        guard var item = installedExtensions.first(where: { $0.id == id }) else { return }
        item.isEnabled = enabled
        enabledState[id] = enabled

        if enabled {
            do {
                _ = try await loadExtension(at: item.path, extensionID: id, enabled: true)
            } catch {
                lastErrorMessage = error.localizedDescription
                item.isEnabled = false
                enabledState[id] = false
                presentErrorAlert(error)
            }
        } else if let context = contexts[id] {
            try? controller?.unload(context)
            contexts.removeValue(forKey: id)
        }

        if let index = installedExtensions.firstIndex(where: { $0.id == id }) {
            installedExtensions[index] = item
        }
        persistState()
        actionsRevision &+= 1
    }

    func uninstallExtension(id: String, persist: Bool = true) async {
        if let context = contexts[id] {
            try? controller?.unload(context)
            contexts.removeValue(forKey: id)
        }

        let path = extensionsRootURL.appendingPathComponent(id, isDirectory: true)
        try? FileManager.default.removeItem(at: path)
        installedExtensions.removeAll { $0.id == id }
        enabledState.removeValue(forKey: id)

        if persist {
            persistState()
        }
        actionsRevision &+= 1
    }

    func openOptionsPage(for id: String) {
        guard let context = contexts[id], let optionsURL = context.optionsPageURL else { return }
        openURLInNewTab(optionsURL, usingExtensionConfiguration: context)
    }

    // MARK: - Loading

    private func reloadInstalledExtensions() async {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: extensionsRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            installedExtensions = []
            return
        }

        var loaded: [InstalledExtension] = []
        for url in contents where url.hasDirectoryPath {
            let name = url.lastPathComponent
            if name.hasPrefix("temp_") || name == "installed.json" { continue }
            let enabled = enabledState[name] ?? true
            do {
                let item = try await loadExtension(at: url, extensionID: name, enabled: enabled)
                loaded.append(item)
            } catch {
                print("🧩 Failed to load extension at \(url.path): \(error)")
            }
        }

        installedExtensions = loaded.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        persistState()
        actionsRevision &+= 1
    }

    @discardableResult
    private func loadExtension(at directory: URL, extensionID: String, enabled: Bool) async throws -> InstalledExtension {
        let webExtension = try await WKWebExtension(resourceBaseURL: directory)
        let context = WKWebExtensionContext(for: webExtension)
        context.uniqueIdentifier = extensionID
        context.isInspectable = true
        context.hasAccessToPrivateData = true

        for permission in webExtension.requestedPermissions {
            context.setPermissionStatus(.grantedExplicitly, for: permission)
        }
        for pattern in webExtension.allRequestedMatchPatterns {
            context.setPermissionStatus(.grantedExplicitly, for: pattern)
        }

        if enabled {
            guard let controller else {
                throw ExtensionManagerError.loadFailed("Web extension controller is not ready.")
            }
            if let existing = contexts[extensionID] {
                try? controller.unload(existing)
            }
            try controller.load(context)
            contexts[extensionID] = context
            context.loadBackgroundContent { error in
                if let error {
                    print("🧩 Background load failed for \(webExtension.displayName ?? extensionID): \(error)")
                }
            }
        }

        enabledState[extensionID] = enabled

        return InstalledExtension(
            id: extensionID,
            name: webExtension.displayName ?? directory.lastPathComponent,
            version: webExtension.displayVersion ?? webExtension.version ?? "",
            extensionDescription: webExtension.displayDescription ?? "",
            isEnabled: enabled,
            icon: webExtension.icon(for: CGSize(width: 32, height: 32)),
            path: directory,
            hasOptionsPage: webExtension.hasOptionsPage,
            hasAction: webExtension.displayActionLabel != nil || webExtension.actionIcon(for: CGSize(width: 16, height: 16)) != nil || webExtension.hasInjectedContent
        )
    }

    // MARK: - Package extraction

    private func extractPackage(from sourceURL: URL, to destination: URL) async throws {
        let ext = sourceURL.pathExtension.lowercased()
        if ext == "zip" {
            try extractZip(from: sourceURL, to: destination)
            return
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ExtensionManagerError.unsupportedLocation
        }

        let items = try FileManager.default.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil)
        for item in items {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            try FileManager.default.copyItem(at: item, to: target)
        }
    }

    private func extractZip(from zipURL: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, destination.path]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "zip extract failed"
            throw ExtensionManagerError.loadFailed(message)
        }
    }

    private func findManifest(in root: URL) -> URL? {
        let direct = root.appendingPathComponent("manifest.json")
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }

        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let item = enumerator?.nextObject() as? URL {
            if item.lastPathComponent == "manifest.json" {
                return item
            }
        }
        return nil
    }

    // MARK: - Window / Tab bridging

    @discardableResult
    func registerWindow(state: BrowserWindowState, nsWindow: NSWindow?, isPrivate: Bool) -> ExtensionWindowAdapter {
        let key = ObjectIdentifier(state)
        if let existing = windowStateToAdapter[key] {
            existing.nsWindow = nsWindow
            existing.windowState = state
            existing.isPrivate = isPrivate
            activeWindowState = state
            controller?.didFocusWindow(existing)
            return existing
        }

        let adapter = ExtensionWindowAdapter(windowState: state, nsWindow: nsWindow, isPrivate: isPrivate)
        windowAdapters[ObjectIdentifier(adapter)] = adapter
        windowStateToAdapter[key] = adapter
        activeWindowState = state
        controller?.didOpenWindow(adapter)
        controller?.didFocusWindow(adapter)
        return adapter
    }

    func unregisterWindow(state: BrowserWindowState) {
        let key = ObjectIdentifier(state)
        guard let adapter = windowStateToAdapter.removeValue(forKey: key) else { return }
        windowAdapters.removeValue(forKey: ObjectIdentifier(adapter))
        controller?.didCloseWindow(adapter)
    }

    func focusWindow(_ adapter: ExtensionWindowAdapter) {
        activeWindowState = adapter.windowState
        controller?.didFocusWindow(adapter)
        adapter.nsWindow?.makeKeyAndOrderFront(nil)
    }

    func tabAdapter(for tab: BrowserTab) -> ExtensionTabAdapter {
        if let existing = tabAdapters[tab.id] {
            if existing.windowAdapter == nil, let state = activeWindowState {
                existing.windowAdapter = windowStateToAdapter[ObjectIdentifier(state)]
            }
            return existing
        }

        let windowAdapter = activeWindowState.flatMap { windowStateToAdapter[ObjectIdentifier($0)] }
        let adapter = ExtensionTabAdapter(tab: tab, windowAdapter: windowAdapter)
        tabAdapters[tab.id] = adapter
        return adapter
    }

    func notifyTabOpened(_ tab: BrowserTab) {
        let isNew = tabAdapters[tab.id] == nil
        let adapter = tabAdapter(for: tab)
        guard isNew else { return }
        controller?.didOpenTab(adapter)
    }

    func notifyTabClosed(_ tab: BrowserTab, windowIsClosing: Bool = false) {
        guard let adapter = tabAdapters[tab.id] else { return }
        controller?.didCloseTab(adapter, windowIsClosing: windowIsClosing)
        tabAdapters.removeValue(forKey: tab.id)
    }

    func notifyTabActivated(newTab: BrowserTab?, previousTab: BrowserTab?) {
        guard let newTab else { return }
        let newAdapter = tabAdapter(for: newTab)
        let previousAdapter = previousTab.map { tabAdapter(for: $0) }
        controller?.didActivateTab(newAdapter, previousActiveTab: previousAdapter)
        controller?.didSelectTabs([newAdapter])
        actionsRevision &+= 1
    }

    func notifyTabPropertiesChanged(_ tab: BrowserTab, properties: WKWebExtension.TabChangedProperties) {
        let adapter = tabAdapter(for: tab)
        controller?.didChangeTabProperties(properties, for: adapter)
        if properties.contains(.url) || properties.contains(.title) || properties.contains(.loading) {
            actionsRevision &+= 1
        }
    }

    // MARK: - Actions / Toolbar

    func toolbarActions(for tab: BrowserTab?) -> [(extensionID: String, extensionName: String, action: WKWebExtensionAction)] {
        let adapter = tab.map { tabAdapter(for: $0) }
        var result: [(String, String, WKWebExtensionAction)] = []

        for item in installedExtensions where item.isEnabled {
            guard let context = contexts[item.id],
                  let action = context.action(for: adapter) else { continue }
            result.append((item.id, item.name, action))
        }
        return result
    }

    func performToolbarAction(extensionID: String, for tab: BrowserTab?, anchorView: NSView?) {
        popupAnchorView = anchorView
        guard let context = contexts[extensionID] else { return }
        let adapter = tab.map { tabAdapter(for: $0) }
        context.performAction(for: adapter)
    }

    // MARK: - Helpers

    private func openURLInNewTab(_ url: URL, usingExtensionConfiguration context: WKWebExtensionContext? = nil) {
        guard let space = activeWindowState?.currentSpace,
              let modelContext = activeModelContext else { return }

        let newTab = BrowserTab(
            title: url.host ?? "Extension",
            url: url,
            order: space.tabs.count,
            browserSpace: space
        )
        space.openNewTab(newTab, using: modelContext, select: true)
        notifyTabOpened(newTab)
        notifyTabActivated(newTab: newTab, previousTab: nil)
    }

    private func presentErrorAlert(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Extension Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - WKWebExtensionControllerDelegate

extension ExtensionManager: WKWebExtensionControllerDelegate {
    func webExtensionController(_ controller: WKWebExtensionController, openWindowsFor extensionContext: WKWebExtensionContext) -> [any WKWebExtensionWindow] {
        Array(windowAdapters.values)
    }

    func webExtensionController(_ controller: WKWebExtensionController, focusedWindowFor extensionContext: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        guard let state = activeWindowState else {
            return windowAdapters.values.first
        }
        return windowStateToAdapter[ObjectIdentifier(state)]
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        openNewWindowUsing configuration: WKWebExtension.WindowConfiguration,
        for extensionContext: WKWebExtensionContext,
        completionHandler: @escaping ((any WKWebExtensionWindow)?, (any Error)?) -> Void
    ) {
        // Open requested URLs as tabs in the active window rather than spawning a separate browser window.
        let urls = configuration.tabURLs
        if urls.isEmpty {
            openURLInNewTab(URL(string: "about:blank")!, usingExtensionConfiguration: extensionContext)
        } else {
            for url in urls {
                openURLInNewTab(url, usingExtensionConfiguration: extensionContext)
            }
        }

        let window: (any WKWebExtensionWindow)?
        if let state = activeWindowState {
            window = windowStateToAdapter[ObjectIdentifier(state)]
        } else {
            window = windowAdapters.values.first
        }
        completionHandler(window, nil)
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        openNewTabUsing configuration: WKWebExtension.TabConfiguration,
        for extensionContext: WKWebExtensionContext,
        completionHandler: @escaping ((any WKWebExtensionTab)?, (any Error)?) -> Void
    ) {
        guard let space = activeWindowState?.currentSpace,
              let modelContext = activeModelContext else {
            completionHandler(nil, nil)
            return
        }

        let url = configuration.url ?? URL(string: "about:blank")!
        let newTab = BrowserTab(
            title: url.host ?? "New Tab",
            url: url,
            order: configuration.index == NSNotFound ? space.tabs.count : min(configuration.index, space.tabs.count),
            browserSpace: space
        )
        space.openNewTab(newTab, using: modelContext, select: configuration.shouldBeActive)
        if configuration.shouldBePinned {
            space.pinTab(newTab, using: modelContext)
        }

        let adapter = tabAdapter(for: newTab)
        notifyTabOpened(newTab)
        if configuration.shouldBeActive {
            notifyTabActivated(newTab: newTab, previousTab: nil)
        }
        completionHandler(adapter, nil)
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        openOptionsPageFor extensionContext: WKWebExtensionContext,
        completionHandler: @escaping ((any Error)?) -> Void
    ) {
        if let optionsURL = extensionContext.optionsPageURL {
            openURLInNewTab(optionsURL, usingExtensionConfiguration: extensionContext)
            completionHandler(nil)
        } else {
            completionHandler(nil)
        }
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        promptForPermissions permissions: Set<WKWebExtension.Permission>,
        in tab: (any WKWebExtensionTab)?,
        for extensionContext: WKWebExtensionContext,
        completionHandler: @escaping (Set<WKWebExtension.Permission>, Date?) -> Void
    ) {
        let name = extensionContext.webExtension.displayName ?? "Extension"
        let alert = NSAlert()
        alert.messageText = "\"\(name)\" wants permissions"
        alert.informativeText = permissions.map(\.rawValue).sorted().joined(separator: ", ")
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Deny")
        let allowed = alert.runModal() == .alertFirstButtonReturn ? permissions : []
        completionHandler(allowed, nil)
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        promptForPermissionToAccess urls: Set<URL>,
        in tab: (any WKWebExtensionTab)?,
        for extensionContext: WKWebExtensionContext,
        completionHandler: @escaping (Set<URL>, Date?) -> Void
    ) {
        let name = extensionContext.webExtension.displayName ?? "Extension"
        let alert = NSAlert()
        alert.messageText = "\"\(name)\" wants access to sites"
        alert.informativeText = urls.map(\.absoluteString).sorted().joined(separator: "\n")
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Deny")
        let allowed = alert.runModal() == .alertFirstButtonReturn ? urls : []
        completionHandler(allowed, nil)
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>,
        in tab: (any WKWebExtensionTab)?,
        for extensionContext: WKWebExtensionContext,
        completionHandler: @escaping (Set<WKWebExtension.MatchPattern>, Date?) -> Void
    ) {
        let name = extensionContext.webExtension.displayName ?? "Extension"
        let alert = NSAlert()
        alert.messageText = "\"\(name)\" wants host access"
        alert.informativeText = matchPatterns.map(\.string).sorted().joined(separator: "\n")
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Deny")
        let allowed = alert.runModal() == .alertFirstButtonReturn ? matchPatterns : []
        completionHandler(allowed, nil)
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        didUpdate action: WKWebExtensionAction,
        forExtensionContext context: WKWebExtensionContext
    ) {
        actionsRevision &+= 1
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        presentActionPopup action: WKWebExtensionAction,
        for extensionContext: WKWebExtensionContext,
        completionHandler: @escaping ((any Error)?) -> Void
    ) {
        guard action.presentsPopup, let popover = action.popupPopover else {
            completionHandler(nil)
            return
        }

        activePopupPopover?.performClose(nil)
        activePopupPopover = popover

        if let anchor = popupAnchorView, let window = anchor.window {
            let rect = anchor.convert(anchor.bounds, to: nil)
            popover.show(relativeTo: rect, of: window.contentView ?? anchor, preferredEdge: .maxY)
        } else if let contentView = NSApp.keyWindow?.contentView {
            let rect = CGRect(x: contentView.bounds.midX, y: contentView.bounds.maxY - 40, width: 1, height: 1)
            popover.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }

        action.hasUnreadBadgeText = false
        completionHandler(nil)
    }
}
