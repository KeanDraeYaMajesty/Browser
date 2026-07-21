//
//  MainFrame.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/23/25.
//

import SwiftUI
import SwiftData

/// Main frame of the browser.
struct MainFrame: View {

    @Environment(BrowserWindowState.self) var browserWindowState
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var userPreferences: UserPreferences
    @StateObject private var splitState = SplitViewState()

    @State var sidebarModel = SidebarModel()

    @Query(sort: \BrowserSpace.order) var browserSpaces: [BrowserSpace]

    var isImmersive: Bool {
        browserWindowState.isFullScreen && sidebarModel.sidebarCollapsed
    }

    var body: some View {
        @Bindable var browserWindowState = browserWindowState

        NavigationSplitView(columnVisibility: $splitState.columnVisibility) {
            sidebarView
        } detail: {
            pageView
        }
        .navigationSplitViewStyle(.balanced)
        .animation(.easeInOut(duration: 0.3), value: splitState.columnVisibility)

        .onChange(of: splitState.columnVisibility) { oldValue, newValue in
            NSApp.setBrowserWindowControls(hidden: newValue == .detailOnly)
        }

        .frame(maxWidth: .infinity)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .background {
            if let currentSpace = browserWindowState.currentSpace {
                SidebarSpaceBackground(browserSpace: currentSpace, isSidebarCollapsed: false)
            }
        }
        .popover(
            isPresented: .init(
                get: { browserWindowState.searchOpenLocation != .none },
                set: { newValue in
                    if !newValue {
                        browserWindowState.searchOpenLocation = .none
                    }
                }
            ),
        ) {
            SearchView()
                .environment(browserWindowState)
                .frame(width: browserWindowState.searchPanelSize.width,
                       height: browserWindowState.searchPanelSize.height)
        }

        // Show the tab switcher as a pop-out
        .overlay {
            if browserWindowState.showTabSwitcher {
                ZStack {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            browserWindowState.showTabSwitcher = false
                        }

                    VStack {
                        TabSwitcher(browserSpaces: browserSpaces)
                            .environment(browserWindowState)
                            .frame(width: 700, height: 200)
                            .background(.ultraThinMaterial)
                            .clipShape(.rect(cornerRadius: GoldenGateMetrics.windowCornerRadius))
                            .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .zIndex(999)
                .animation(userPreferences.disableAnimations ? nil : .spring(), value: browserWindowState.showTabSwitcher)
            }
        }

        .environment(sidebarModel)
        .focusedSceneValue(\.sidebarModel, sidebarModel)
        .environmentObject(splitState)
        .focusedSceneValue(\.splitViewState, splitState)
        .focusedSceneValue(\.userPreferences, userPreferences)
        .foregroundStyle(browserWindowState.currentSpace?.textColor(in: colorScheme) ?? .primary)
        .ignoresSafeArea(.all)
    }

    var sidebar: some View {
        Sidebar(browserSpaces: browserSpaces)
            .frame(width: sidebarModel.currentSidebarWidth)
            .readingWidth(width: $sidebarModel.currentSidebarWidth)
    }

    // MARK: - Sidebar
    /// Golden Gate edge-to-edge sidebar: flush to the window edge instead of a floating inset sheet.
    @ViewBuilder
    private var sidebarView: some View {
        Sidebar(browserSpaces: browserSpaces)
            .padding(.horizontal, userPreferences.edgeToEdgeSidebar ? 2 : 8)
            .padding(.top, userPreferences.edgeToEdgeSidebar ? 10 : 24)
            .padding(.bottom, userPreferences.edgeToEdgeSidebar ? 6 : 0)
            .ignoresSafeArea(.all)
            .modifier(ConditionalToolbarRemover(shouldRemove: splitState.columnVisibility == .detailOnly))
    }

    // MARK: - Detail (WebView)
    @ViewBuilder
    private var pageView: some View {
        PageWebView(browserSpaces: browserSpaces)
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(isImmersive ? 0 : 0.22), radius: shadowRadius, y: isImmersive ? 0 : 4)
            .ignoresSafeArea(edges: userPreferences.extendedSidebarStyle ? .all : [.top, .bottom, .trailing])
            .animation(.easeInOut(duration: 0.3), value: userPreferences.extendedSidebarStyle)
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
                withAnimation(.browserDefault) {
                    browserWindowState.isFullScreen = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
                withAnimation(.browserDefault) {
                    browserWindowState.isFullScreen = false
                }
            }
            .actionAlert()
    }

    // MARK: - Computed properties
    private var cornerRadius: CGFloat {
        isImmersive ? 0 : (userPreferences.roundedCorners ? GoldenGateMetrics.contentCornerRadius : 0)
    }

    private var shadowRadius: CGFloat {
        isImmersive ? 0 : GoldenGateMetrics.contentShadowRadius
    }

}

struct ConditionalToolbarRemover: ViewModifier {
    let shouldRemove: Bool
    @Environment(BrowserWindowState.self) var browserWindowState

    func body(content: Content) -> some View {
        if shouldRemove {
            content.toolbar(removing: .sidebarToggle)
        } else {
            content.toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        browserWindowState.backButtonAction()
                    } label: {
                        Label("Back", systemImage: "arrow.left")
                    }
                    .help("Go back")

                    Button {
                        browserWindowState.forwardButtonAction()
                    } label: {
                        Label("Forward", systemImage: "arrow.right")
                    }
                    .help("Go forward")

                    Button {
                        browserWindowState.refreshButtonAction()
                    } label: {
                        Label("Reload", systemImage: "arrow.trianglehead.clockwise")
                    }
                    .help("Reload")

                    ExtensionToolbarButtons()
                }
            }
        }
    }
}
