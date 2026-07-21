//
//  SidebarURL.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/20/25.
//

import SwiftUI

struct SidebarURL: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(BrowserWindowState.self) var browserWindowState
    @EnvironmentObject var userPreferences: UserPreferences
    
    @State var hover = false

    private var glassTint: Double {
        min(max(userPreferences.liquidGlassIntensity, 0), 1)
    }
    
    var body: some View {
        HStack {
            if let currentTab = browserWindowState.currentSpace?.currentTab {
                Text(currentTab.url.cleanHost)
                    .padding(.leading, 8)
                    .fontWeight(.medium)
                    .shadow(
                        color: colorScheme == .dark
                            ? .black.opacity(0.35 + (0.2 * glassTint))
                            : .white.opacity(0.45 + (0.15 * (1 - glassTint))),
                        radius: 0.6
                    )

                Spacer()
                
                if hover {
                    Button("Copy URL To Clipboard", systemImage: "link", action: browserWindowState.copyURLToClipboard)
                        .buttonStyle(.sidebarHover(hoverStyle: AnyShapeStyle(.ultraThinMaterial) ,cornerRadius: 7))
                        .padding(.trailing, .sidebarPadding)
                        .browserTransition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .contentShape(Rectangle())
        .background(.clear)
        .glassEffect(in: .rect(cornerRadius: GoldenGateMetrics.controlCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: GoldenGateMetrics.controlCornerRadius, style: .continuous)
                .fill(.background.opacity(0.06 + (0.16 * glassTint)))
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: GoldenGateMetrics.controlCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.34 + (0.16 * (1 - glassTint))),
                            .white.opacity(0.08),
                            .black.opacity(0.12 + (0.12 * glassTint))
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            if userPreferences.loadingIndicatorPosition == .onURL && browserWindowState.currentSpace?.currentTab?.isLoading == true {
                ProgressView(value: browserWindowState.currentSpace?.currentTab?.estimatedProgress ?? 0)
                    .progressViewStyle(.linear)
                    .frame(height: 2)
                    .tint(browserWindowState.currentSpace?.getColors.first ?? .accentColor)
            }
        }
        .clipShape(.rect(cornerRadius: GoldenGateMetrics.controlCornerRadius, style: .continuous))
        .onTapGesture {
            browserWindowState.searchOpenLocation = .fromURLBar
        }
        .onHover { hover in
            withAnimation(.browserDefault?.speed(2)) {
                self.hover = hover
            }
        }
        .zIndex(-1)
    }
}

#Preview {
    SidebarURL()
}
