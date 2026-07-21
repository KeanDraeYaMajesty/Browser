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
                            Text(userPreferences.liquidGlassIntensity < 0.33 ? "Clearer" : userPreferences.liquidGlassIntensity > 0.66 ? "Tinted" : "Balanced")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $userPreferences.liquidGlassIntensity, in: 0...1)
                        Text("Matches the macOS 27 Golden Gate Appearance slider — clearer refraction on the left, stronger tint and readability on the right.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Edge-to-Edge Sidebar", systemImage: "sidebar.left", isOn: $userPreferences.edgeToEdgeSidebar)

                LoadingPlacePicker()
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
    }
}
