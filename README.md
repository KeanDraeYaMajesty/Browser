# Zero - A minimal fancy browser

![CleanShot 2025-10-08 at 3  44 10@2x Large](https://github.com/user-attachments/assets/0053365a-76c3-478b-aea5-ec8754e95c22)

## Motivation

A browser made to use with keystrokes but happen to have a pleasing UI with website specific custom themes built-in. Brings the vertical tabs from Arc, Website modifications by Zen Internet and Transparent Zen, Blazingly fast and efficient webkit rendering, Zero becomes my perfect browser for personal use. 

## Technologies

- _SwiftUI_: Powers the app's entire user interface.
- _SwiftData_: Persists data such as Spaces and Tabs.
- _WebKit_: The Browser's Engine (system WebKit on the latest macOS / Safari).
- _WKWebExtension_: Chrome/Firefox-compatible extensions via system WebKit.

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
- [x] Liquid glass and latest design to feel at home
- [x] Middle click
- [x] Smooth tab switching and UI animations
- [x] Focus mode with 0 visible UI for an immersive browsing experience
- [x] Search in Page
- [x] Reorder Tabs By Dragging
- [x] Export Page as PDF, Image, etc...  
- [x] Pinned Tabs    
- [x] Tab Suspension 
- [x] Multiple Windows
- [x] Web Extensions (Chrome/Firefox MV2/MV3 via WKWebExtension)
- [ ] Grid Layout
- [ ] Undo and Redo Closed Tabs

## Building

The project links against the **system-provided WebKit** (no custom WebKit.framework checkout). Open `Zero.xcodeproj` and build the `Browser` scheme with the latest Xcode on macOS 26+.

User agent, HTTPS upgrades, and extension support all come from the current system WebKit build, so updating macOS/Safari updates the browser engine.

### Extensions

1. Open **Settings → Extensions** (or **Zero → Install Extension…**).
2. Choose an unpacked extension folder or a `.zip` package that contains a `manifest.json`.
3. Grant any requested permissions when prompted.
4. Extension action buttons appear in the toolbar; options pages open as tabs.

Extensions are stored under `~/Library/Application Support/Zero/Extensions/`. Tab WebViews derive their `WKWebViewConfiguration` from a shared base that owns the `WKWebExtensionController`, which is required for content scripts and background pages to work correctly.

A minimal test package lives at `Examples/ZeroSampleExtension` — install that folder from Settings → Extensions to verify content scripts, the background service worker, and the action popup.

Credits to [LeonardoLarranaga/Browser](https://github.com/LeonardoLarranaga/Browser) for the open browser source <3
