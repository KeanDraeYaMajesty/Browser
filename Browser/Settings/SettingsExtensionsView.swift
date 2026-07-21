//
//  SettingsExtensionsView.swift
//  Browser
//
//  Settings UI for installing and managing Firefox/Chrome web extensions
//  through system WebKit's WKWebExtension APIs.
//

import SwiftUI

struct SettingsExtensionsView: View {
    @ObservedObject private var extensionManager = ExtensionManager.shared
    @State private var statusMessage: String?
    @State private var isInstallingDemo = false

    var body: some View {
        Form {
            Section {
                Text("Zero runs Firefox and Chrome WebExtensions (Manifest V2/V3) through the system WebKit engine — the same WKWebExtension stack Safari uses. Install an unpacked folder, a .zip, or a Firefox .xpi.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            Section("Installed Extensions") {
                if extensionManager.installedExtensions.isEmpty {
                    ContentUnavailableView(
                        "No Extensions Installed",
                        systemImage: "puzzlepiece.extension",
                        description: Text("Install a Firefox .xpi, .zip package, or unpacked extension folder.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    ForEach(extensionManager.installedExtensions) { item in
                        ExtensionRow(item: item)
                    }
                }
            }

            Section {
                Button("Install Extension…", systemImage: "plus.circle") {
                    extensionManager.presentInstallPanel()
                }

                Button {
                    Task { await installDemo() }
                } label: {
                    Label(
                        isInstallingDemo ? "Installing Demo…" : "Install Bundled Demo Extension",
                        systemImage: "sparkles"
                    )
                }
                .disabled(isInstallingDemo)

                Button("Reveal Extensions Folder", systemImage: "folder") {
                    extensionManager.revealExtensionsFolder()
                }
            }

            if let statusMessage {
                Section("Status") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }

            if let message = extensionManager.lastErrorMessage {
                Section("Last Error") {
                    Text(message)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }

    @MainActor
    private func installDemo() async {
        isInstallingDemo = true
        defer { isInstallingDemo = false }
        do {
            let installed = try await extensionManager.installBundledDemoExtension()
            statusMessage = "Installed \(installed.name) \(installed.version). Reload open pages to run content scripts."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private struct ExtensionRow: View {
    let item: InstalledExtension

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "puzzlepiece.extension")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                    if !item.version.isEmpty {
                        Text("v\(item.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !item.extensionDescription.isEmpty {
                    Text(item.extensionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Toggle(
                "Enabled",
                isOn: Binding(
                    get: { item.isEnabled },
                    set: { newValue in
                        Task { await ExtensionManager.shared.setExtensionEnabled(id: item.id, enabled: newValue) }
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)

            if item.hasOptionsPage {
                Button("Options") {
                    ExtensionManager.shared.openOptionsPage(for: item.id)
                }
                .disabled(!item.isEnabled)
            }

            Button(role: .destructive) {
                Task { await ExtensionManager.shared.uninstallExtension(id: item.id) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Uninstall")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsExtensionsView()
}
