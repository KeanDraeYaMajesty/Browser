//
//  ClosedTabsList.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 12/22/25.
//

import SwiftUI
import SwiftData

struct ClosedTabsList: View {
    
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(BrowserWindowState.self) var browserWindowState
    
    var closedTabs: [BrowserTab] {
        browserWindowState.currentSpace?.recentlyClosedTabs ?? []
    }
    
    var body: some View {
        VStack {
            if closedTabs.isEmpty {
                ContentUnavailableView("No recently closed tabs", systemImage: "xmark.app")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List {
                    ForEach(closedTabs) { tab in
                        HStack(spacing: 15) {
                            if let closedAt = tab.closedAt {
                                Text(closedAt.formatted(date: .omitted, time: .shortened))
                                    .bold()
                                    .frame(width: 44)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Group {
                                if let favicon = tab.favicon, let nsImage = NSImage(data: favicon) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    Image(systemName: "globe")
                                        .resizable()
                                        .scaledToFit()
                                }
                            }
                            .frame(width: 16, height: 16)
                            .clipShape(.rect(cornerRadius: 4))
                            
                            Text(tab.title)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Spacer()
                            
                            Text(tab.url.absoluteString)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(.secondary)
                                .font(.system(.callout, design: .monospaced))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            browserWindowState.currentSpace?.reopenTab(tab, using: modelContext)
                        }
                        .help("Click to restore tab")
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.sidebar)
            }
        }
        .foregroundColor(colorScheme == .dark ? .white : .black)
    }
}
