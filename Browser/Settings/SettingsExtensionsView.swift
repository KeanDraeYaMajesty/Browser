//
//  SettingsExtensionsView.swift
//  Browser
//
//  Settings UI for installing and managing web extensions.
//

import SwiftUI

struct SettingsExtensionsView: View {
    @ObservedObject private var extensionManager = ExtensionManager.shared

    var body: some View {
        Form {
            Section {
                Text("Zero loads Chrome and Firefox compatible extensions through the system WebKit WKWebExtension APIs. Content scripts, background pages/service workers, declarativeNetRequest, and action popups share the same engine as Safari.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            Section("Installed Extensions") {
                if extensionManager.installedExtensions.isEmpty {
                    ContentUnavailableView(
                        "No Extensions Installed",
                        systemImage: "puzzlepiece.extension",
                        description: Text("Install a .zip package or an unpacked extension folder.")
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
