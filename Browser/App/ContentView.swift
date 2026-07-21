//
//  ContentView.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/18/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var browserWindowState: BrowserWindowState
    @EnvironmentObject var userPreferences: UserPreferences

    init(windowID: String = "BrowserWindow") {
        _browserWindowState = State(initialValue: BrowserWindowState(windowID: windowID))
    }

    var body: some View {
        // Inject BrowserWindowState as early as possible so NavigationSplitView
        // columns, toolbars, and backgrounds all see it on first layout.
        rootContent
            .environment(browserWindowState)
            .ignoresSafeArea(.all)
            .focusedSceneValue(\.browserActiveWindowState, browserWindowState)
            .sheet(isPresented: $browserWindowState.showURLQRCode) {
                if let currentTab = browserWindowState.currentSpace?.currentTab {
                    URLQRCodeView(browserTab: currentTab)
                        .environment(browserWindowState)
                }
            }
            .popover(
                isPresented: $browserWindowState.showAcknowledgements,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .top
            ) {
                Acknowledgments()
                    .environment(browserWindowState)
                    .frame(width: 500, height: 300)
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: GoldenGateMetrics.windowCornerRadius))
            }
            .onAppear {
                ExtensionManager.shared.activeWindowState = browserWindowState
                ExtensionManager.shared.registerWindow(
                    state: browserWindowState,
                    nsWindow: NSApp.keyWindow,
                    isPrivate: browserWindowState.usesNonPersistentWebsiteData
                )
            }
            .onDisappear {
                ExtensionManager.shared.unregisterWindow(state: browserWindowState)
            }
            .background {
                ExtensionWindowBridge(browserWindowState: browserWindowState)
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch userPreferences.windowBackgroundStyle {
        case .liquidGlass:
            MainFrame()
                .background {
                    GoldenGateGlassBackground(intensity: userPreferences.liquidGlassIntensity)
                }
        case .thinMaterial:
            MainFrame()
                .background(.thinMaterial)
        }
    }
}

/// macOS 27 Golden Gate liquid glass: clearer refraction, stronger edge contrast, tunable tint.
/// Tuned so wallpaper glass rivals Hyprland/KDE forceblur while chrome text stays crisp.
private struct GoldenGateGlassBackground: View {
    let intensity: Double

    var body: some View {
        let tint = min(max(intensity, 0), 1)
        let clearBias = 1 - tint

        Color.clear
            .glassEffect(in: .rect(cornerRadius: GoldenGateMetrics.windowCornerRadius))
            .overlay {
                // Specular rim — bright top edge, soft depth at the bottom.
                RoundedRectangle(cornerRadius: GoldenGateMetrics.windowCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.42 + (0.22 * clearBias)),
                                .white.opacity(0.10 + (0.06 * clearBias)),
                                .black.opacity(0.10 + (0.18 * tint))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            }
            .overlay {
                // Hairline inner highlight for depth without muddying the glass.
                RoundedRectangle(cornerRadius: GoldenGateMetrics.windowCornerRadius - 0.5, style: .continuous)
                    .strokeBorder(
                        .white.opacity(0.10 + (0.12 * clearBias)),
                        lineWidth: 0.5
                    )
                    .padding(0.75)
                    .allowsHitTesting(false)
            }
            .overlay {
                // Soft readability wash — stays airy at low tint, denser when dialed up.
                RoundedRectangle(cornerRadius: GoldenGateMetrics.windowCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .background.opacity(0.03 + (0.10 * tint)),
                                .background.opacity(0.06 + (0.26 * tint))
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
            }
    }
}

enum GoldenGateMetrics {
    /// Uniform, slightly less dramatic corner radius from macOS 27 Golden Gate.
    static let windowCornerRadius: CGFloat = 12
    static let contentCornerRadius: CGFloat = 12
    static let controlCornerRadius: CGFloat = 10
    static let contentShadowRadius: CGFloat = 12
}

/// Keeps ExtensionManager's active model context / window wiring in sync with the SwiftUI hierarchy.
private struct ExtensionWindowBridge: View {
    @Environment(\.modelContext) private var modelContext
    let browserWindowState: BrowserWindowState
    @State private var previousTabID: UUID?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                ExtensionManager.shared.activeModelContext = modelContext
                ExtensionManager.shared.activeWindowState = browserWindowState
                previousTabID = browserWindowState.currentSpace?.currentTab?.id
            }
            .onChange(of: browserWindowState.currentSpace?.currentTab?.id) { _, newValue in
                let space = browserWindowState.currentSpace
                let previousTab = previousTabID.flatMap { id in
                    space?.allTabs.first(where: { $0.id == id })
                }
                let newTab = space?.currentTab
                ExtensionManager.shared.activeWindowState = browserWindowState
                ExtensionManager.shared.activeModelContext = modelContext
                ExtensionManager.shared.notifyTabActivated(newTab: newTab, previousTab: previousTab)
                previousTabID = newValue
            }
    }
}
