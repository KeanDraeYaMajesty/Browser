# Zero - A minimal fancy browser

![CleanShot 2025-10-08 at 3  44 10@2x Large](https://github.com/user-attachments/assets/0053365a-76c3-478b-aea5-ec8754e95c22)

## Motivation

A browser made to use with keystrokes but happen to have a pleasing UI with website specific custom themes built-in. Brings the vertical tabs from Arc, Website modifications by Zen Internet and Transparent Zen, Blazingly fast and efficient webkit rendering, Zero becomes my perfect browser for personal use. 

## Technologies

- _SwiftUI_: Powers the app's entire user interface.
- _SwiftData_: Persists data such as Spaces and Tabs.
- _WebKit_: The Browser's Engine (system WebKit + `WKWebExtension`).

<img width="1512" alt="Browser with No-Trace Window" src="https://github.com/user-attachments/assets/a761c164-ece6-4f6d-bba6-e012d307a670" />

## Features

- [x] Multiples Spaces
- [x] No-Trace Window
- [x] Temporary Window
- [x] Translate websites
- [x] History
- [x] Keyboard Shortcuts
- [x] Ad Blocker
- [x] Web Inspector
- [x] **Website search with autosuggestions _on some websistes_**

https://github.com/user-attachments/assets/90738982-651a-4991-8580-866325d1d128

- [x] Picture-in-Picutre
- [x] Built in custom website themes and transparency
- [x] Liquid Glass tuned for **macOS 27 Golden Gate** (edge-to-edge sidebar, uniform corners, deeper shadows, glass intensity)
- [x] Middle click
- [x] Smooth tab switching and UI animations
- [x] Focus mode with 0 visible UI for an immersive browsing experience
- [x] Search in Page
- [x] Reorder Tabs By Dragging
- [x] Export Page as PDF, Image, etc...  
- [x] Pinned Tabs    
- [x] Tab Suspension 
- [x] Multiple Windows
- [x] **Firefox / Chrome WebExtensions** (MV2/MV3 via system `WKWebExtension`, including `.xpi`)
- [ ] Grid Layout
- [ ] Undo and Redo Closed Tabs

## Building

Requires **macOS 27 Golden Gate** and a recent Xcode. The project links against the **system-provided WebKit** (no custom `WebKit.framework` checkout). Open `Zero.xcodeproj` and build the `Browser` scheme.

User agent, HTTPS upgrades, and extension support all come from the current system WebKit / Safari stack — updating macOS updates the browser engine.

## Firefox & Chrome Extensions

Zero installs WebExtensions through WebKit's `WKWebExtensionController`:

1. Open **Settings → Extensions** (sidebar puzzle button, **Zero → Extensions…**, or ⌘⇧E).
2. Install an unpacked folder, a `.zip`, or a Firefox `.xpi` — or click **Install Bundled Demo Extension**.
3. Grant permissions when prompted.
4. Extension action buttons appear in the toolbar; options pages open as tabs.

Extensions are stored under `~/Library/Application Support/Zero/Extensions/`. Every tab `WKWebViewConfiguration` is copied from a shared base that owns the `webExtensionController`, which is required for content scripts and background workers.

A minimal Firefox-compatible MV3 package lives at `Examples/ZeroSampleExtension`. The same demo is also bundled under `Browser/WebExtensions/Demo/hello-zero`.

Originally based on open browser work from [LeonardoLarranaga/Browser](https://github.com/LeonardoLarranaga/Browser); Zero is now a standalone project on its own path.
