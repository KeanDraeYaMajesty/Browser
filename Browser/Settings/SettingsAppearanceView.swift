//
//  SettingsAppearanceView.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/7/25.
//

import SwiftUI

struct SettingsAppearanceView: View {
    @EnvironmentObject var userPreferences: UserPreferences
    var body: some View {
        Form {
            Section("App") {
                Toggle("Disable Animations", systemImage: "figure.run", isOn: $userPreferences.disableAnimations)

                Picker("Window Background Style", systemImage: "rectangle.fill", selection: $userPreferences.windowBackgroundStyle) {
                    Label("Thin Material", systemImage: "rectangle.fill").tag(UserPreferences.WindowBackgroundStyle.thinMaterial)
                    Label("Liquid Glass", systemImage: "circle.hexagongrid.fill").tag(UserPreferences.WindowBackgroundStyle.liquidGlass)
                }

                if userPreferences.windowBackgroundStyle == .liquidGlass {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Liquid Glass", systemImage: "slider.horizontal.3")
                            Spacer()
                            Text(liquidGlassLabel)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $userPreferences.liquidGlassIntensity, in: 0...1)
                        Text("Clearer refraction on the left (wallpaper envy), stronger tint and chrome readability on the right.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Edge-to-Edge Sidebar", systemImage: "sidebar.left", isOn: $userPreferences.edgeToEdgeSidebar)

                LoadingPlacePicker()
            }

            Section {
                Toggle("Website Transparency", systemImage: "rectangle.on.rectangle.angled", isOn: $userPreferences.webContentTransparency)

                if userPreferences.webContentTransparency {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Readability", systemImage: "text.alignleft")
                            Spacer()
                            Text(readabilityLabel)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $userPreferences.transparencyReadability, in: 0...1)
                        Text("Soft ambient wash and content plates over transparent pages — keep glass, keep contrast. Per-site toggle lives in the sidebar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Website Transparency")
            } footer: {
                Text("Zen Internet / Transparent Zen style theming with a readability dial Linux users usually tune by hand.")
            }

            Section {
                Toggle("Rounded Corners", systemImage: "button.roundedtop.horizontal", isOn: $userPreferences.roundedCorners)
            } header: {
                Text("Web View")
            } footer: {
                Text("Golden Gate uses a uniform continuous corner radius and deeper content shadows for clearer window separation.")
            }
        }
        .formStyle(.grouped)
        .onChange(of: userPreferences.webContentTransparency) { _, _ in
            NotificationCenter.default.post(name: .transparencyPreferencesDidChange, object: nil)
        }
        .onChange(of: userPreferences.transparencyReadability) { _, _ in
            NotificationCenter.default.post(name: .transparencyPreferencesDidChange, object: nil)
        }
    }

    private var liquidGlassLabel: String {
        if userPreferences.liquidGlassIntensity < 0.33 {
            return "Clearer"
        }
        if userPreferences.liquidGlassIntensity > 0.66 {
            return "Tinted"
        }
        return "Balanced"
    }

    private var readabilityLabel: String {
        if userPreferences.transparencyReadability < 0.28 {
            return "Glass"
        }
        if userPreferences.transparencyReadability > 0.68 {
            return "Crisp"
        }
        return "Balanced"
    }
}
