//
//  SettingsExtensionsView.swift
//  Browser
//
//  Install and manage Firefox-compatible WebExtensions (.xpi / unpacked).
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct SettingsExtensionsView: View {
    @ObservedObject private var manager = WebExtensionManager.shared
    @State private var isImporterPresented = false
    @State private var alertMessage: String?

    var body: some View {
        Form {
            Section {
                Text("Zero can load Firefox WebExtensions (Manifest V2/V3). Supported APIs today: content scripts, background scripts, browser.runtime, browser.storage.local, and a subset of browser.tabs.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            Section("Installed") {
                if manager.extensions.isEmpty {
                    ContentUnavailableView(
                        "No Extensions",
                        systemImage: "puzzlepiece.extension",
                        description: Text("Install a Firefox .xpi, .zip, or unpacked extension folder.")
                    )
                    .frame(minHeight: 120)
                } else {
                    ForEach(manager.extensions) { ext in
                        ExtensionRow(ext: ext) {
                            toggle(ext)
                        } onRemove: {
                            remove(ext)
                        }
                    }
                }
            }

            Section {
                Button("Install Extension…", systemImage: "plus.circle") {
                    isImporterPresented = true
                }
                Button("Install Bundled Demo Extension", systemImage: "sparkles") {
                    installDemo()
                }
                Button("Reveal Extensions Folder", systemImage: "folder") {
                    NSWorkspace.shared.open(WebExtensionStore.shared.rootURL)
                }
            }

            if let lastError = manager.lastError {
                Section("Last Error") {
                    Text(lastError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.zip, .folder, UTType(filenameExtension: "xpi") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                install(url: url)
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
        .alert("Extensions", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func install(url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let installed = try manager.install(from: url)
            alertMessage = "Installed \(installed.displayName) \(installed.version)"
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func installDemo() {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "WebExtensions/Demo/hello-zero")?
                .deletingLastPathComponent(),
            Bundle.main.resourceURL?
                .appendingPathComponent("WebExtensions/Demo/hello-zero", isDirectory: true),
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/WebExtensions/Demo/hello-zero", isDirectory: true)
        ]
        guard let demo = candidates.compactMap({ $0 }).first(where: {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("manifest.json").path)
        }) else {
            alertMessage = "Demo extension not found in the app bundle."
            return
        }
        install(url: demo)
    }

    private func toggle(_ ext: InstalledWebExtension) {
        do {
            try manager.setEnabled(!ext.enabled, for: ext.id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func remove(_ ext: InstalledWebExtension) {
        do {
            try manager.uninstall(id: ext.id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

private struct ExtensionRow: View {
    let ext: InstalledWebExtension
    let onToggle: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            extensionIcon
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(ext.displayName)
                    .font(.body.weight(.medium))
                Text(ext.extensionDescription.isEmpty ? ext.id : ext.extensionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("v\(ext.version)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Toggle("Enabled", isOn: Binding(
                get: { ext.enabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove extension")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var extensionIcon: some View {
        if let image = ext.icon(in: WebExtensionStore.shared.rootURL) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: 32, height: 32)
                .cornerRadius(6)
        } else {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
        }
    }
}
