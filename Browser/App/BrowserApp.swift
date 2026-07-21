//
//  BrowserApp.swift
//  Browser
//
//  Created by Leonardo Larrañaga on 1/18/25.
//

import SwiftUI
import SwiftData

@main
struct BrowserApp: App {
    
    @NSApplicationDelegateAdaptor(BrowserAppDelegate.self) var appDelegate
        
    var body: some Scene {
        BrowserWindow("BrowserWindow")
        BrowserWindow("BrowserTemporaryWindow", inMemory: true)
        BrowserWindow("BrowserNoTraceWindow", inMemory: true)
            .commands {
                BrowserCommands()
            }
        
        SettingsWindow()
    }
    
    @SceneBuilder
    func BrowserWindow(_ id: String, inMemory: Bool = false) -> some Scene {
        WindowGroup(id: id) {
            ContentView(windowID: id)
                .environmentObject(appDelegate.userPreferences)
                .transaction {
                    $0.disablesAnimations = appDelegate.userPreferences.disableAnimations
                }
                .frame(minWidth: 400, minHeight: 200)
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(Self.makeModelContainer(inMemory: inMemory))
    }
    
    @SceneBuilder
    func SettingsWindow() -> some Scene {
        Settings {
            SettingsView()
                .frame(width: 750, height: 550)
                .environmentObject(appDelegate.userPreferences)
        }
    }

    /// Build a ModelContainer that recovers from incompatible SwiftData stores
    /// (common after schema changes while keeping the same bundle id).
    private static func makeModelContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema([BrowserSpace.self, BrowserTab.self, BrowserHistoryEntry.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("⚠️ SwiftData store failed to open (\(error)). Resetting persistent store…")
            if !inMemory {
                Self.deletePersistentStoreFiles()
            }
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                print("⚠️ SwiftData recovery failed (\(error)). Falling back to in-memory store.")
                let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
                // Last resort — never crash launch on store open.
                return try! ModelContainer(for: schema, configurations: [fallback])
            }
        }
    }

    private static func deletePersistentStoreFiles() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        // SwiftData/default stores typically live under Application Support for the bundle.
        let candidates = (try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil)) ?? []
        for url in candidates {
            let name = url.lastPathComponent.lowercased()
            if name.contains("default.store")
                || name.contains("swiftdata")
                || name.hasSuffix(".store")
                || name.hasSuffix(".store-shm")
                || name.hasSuffix(".store-wal") {
                try? fm.removeItem(at: url)
            }
        }
    }
}
