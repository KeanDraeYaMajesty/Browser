//
//  ContentView.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/18/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State var browserWindowState = BrowserWindowState()
    @EnvironmentObject var userPreferences: UserPreferences

    @ViewBuilder
    private var mainFrameWithBackground: some View {
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

    var body: some View {
        mainFrameWithBackground
            .ignoresSafeArea(.all)
            .focusedSceneValue(\.browserActiveWindowState, browserWindowState)
            .environment(browserWindowState)
            .sheet(isPresented: $browserWindowState.showURLQRCode) {
                if let currentTab = browserWindowState.currentSpace?.currentTab {
                    URLQRCodeView(browserTab: currentTab)
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
                    isPrivate: browserWindowState.isNoTraceWindow
                )
            }
            .onDisappear {
                ExtensionManager.shared.unregisterWindow(state: browserWindowState)
            }
            .background(ExtensionWindowBridge())
    }
}

/// macOS 27 Golden Gate liquid glass: clearer refraction, stronger edge contrast, tunable tint.
private struct GoldenGateGlassBackground: View {
    let intensity: Double

    var body: some View {
        let tint = min(max(intensity, 0), 1)
        Color.clear
            .glassEffect(in: .rect(cornerRadius: GoldenGateMetrics.windowCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: GoldenGateMetrics.windowCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.34 + (0.18 * (1 - tint))),
                                .white.opacity(0.08),
                                .black.opacity(0.12 + (0.16 * tint))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: GoldenGateMetrics.windowCornerRadius, style: .continuous)
                    .fill(.background.opacity(0.08 + (0.22 * tint)))
                    .allowsHitTesting(false)
            }
    }
}

enum GoldenGateMetrics {
    /// Uniform, slightly less dramatic corner radius from macOS 27 Golden Gate.
    static let windowCornerRadius: CGFloat = 12
    static let contentCornerRadius: CGFloat = 12
    static let controlCornerRadius: CGFloat = 10
    static let contentShadowRadius: CGFloat = 10
}

/// Keeps ExtensionManager's active model context / window wiring in sync with the SwiftUI hierarchy.
private struct ExtensionWindowBridge: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BrowserWindowState.self) private var browserWindowState
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
