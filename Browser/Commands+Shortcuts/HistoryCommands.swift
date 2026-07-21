//
//  HistoryCommands.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 2/16/25.
//

import SwiftUI
import SwiftData
import KeyboardShortcuts

/// Commands for the history menu
struct HistoryCommands: Commands {
    
    @Environment(\.modelContext) var modelContext
    
    @FocusedValue(\.browserActiveWindowState) var browserWindowState: BrowserWindowState?
    
    var body: some Commands {
        CommandMenu("History") {
            if let webView = browserWindowState?.currentSpace?.currentTab?.webview {
                
                Button("Go Back") { webView.goBack() }
                    .disabled(!webView.canGoBack)
                    .globalKeyboardShortcut(.goBack)
                
                Button("Go Forward") { webView.goForward() }
                    .disabled(!webView.canGoForward)
                    .globalKeyboardShortcut(.goForward)
            }
            
            Divider()
            
            Button("Reopen Closed Tab") {
                _ = browserWindowState?.reopenLastClosedTab(using: modelContext)
            }
            .globalKeyboardShortcut(.reopenClosedTab)
            .disabled(browserWindowState?.currentSpace?.recentlyClosedTabs.isEmpty != false)

            Button("Show History", action: showHistory)
                .globalKeyboardShortcut(.showHistory)
            
            Button("Clear History") {
                BrowserHistoryEntry.deleteAllHistory(using: modelContext)
            }
            .globalKeyboardShortcut(.clearHistory)
        }
    }
    
    func showHistory() {
        let favicon = ImageRenderer(content: Image(systemName: "arrow.counterclockwise.square.fill").resizable().frame(width: 32, height: 32).scaledToFit().foregroundStyle(.gray)).nsImage?.pngData
        guard let historyURL = URL(string: "History") else { return }
        let historyTab = BrowserTab(title: "History", favicon: favicon, url: historyURL, order: 0, browserSpace: browserWindowState?.currentSpace, type: .history)
        
        do {
            browserWindowState?.currentSpace?.tabs.append(historyTab)
            try modelContext.save()
            browserWindowState?.currentSpace?.selectTab(historyTab)
        } catch {
            print("Error saving history tab: \(error)")
        }
    }
}

extension KeyboardShortcuts.Name {
    static let goBack = Self("go_back", default: .init(.leftBracket, modifiers: .command))
    static let goForward = Self("go_forward", default: .init(.rightBracket, modifiers: .command))
    
    static let showHistory = Self("show_history", default: .init(.y, modifiers: .command))
    static let clearHistory = Self("clear_history")
    static let reopenClosedTab = Self("reopen_closed_tab", default: .init(.t, modifiers: [.command, .shift]))
}

extension [KeyboardShortcuts.Name] {
    static let allHistoryCommands: [KeyboardShortcuts.Name] = [.goBack, .goForward, .showHistory, .clearHistory, .reopenClosedTab]
}
