# AGENTS.md

## Cursor Cloud specific instructions

### This is a macOS-only Xcode app — it cannot be built or run on the Linux Cloud Agent VM

Zero is a **native macOS desktop browser**. It is a single Xcode project (`Zero.xcodeproj`, shared scheme `Browser`, product `Zero.app`, bundle id `sameerasw.browser`).

- Build system: **Xcode** (`SDKROOT = macosx`, `MACOSX_DEPLOYMENT_TARGET = 26.0`).
- Dependencies are **Swift Package Manager** packages resolved by Xcode (see `Zero.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`): `KeyboardShortcuts`, `SymbolPicker`.
- Sources import Apple-only frameworks: `SwiftUI`, `AppKit`, `WebKit`, `SwiftData`, `PDFKit`, `UniformTypeIdentifiers`, `CoreImage`, `CoreGraphics`, `Combine`.

Because the Cursor Cloud Agent VM runs **Linux (Ubuntu, x86_64)**, this project **cannot be built, run, linted, or tested here**:

- Xcode and the macOS SDK are Apple-proprietary and only run on macOS.
- Swift-for-Linux exists but cannot compile against `SwiftUI`/`AppKit`/`WebKit`/`SwiftData`, so it does not help.
- There is no dependency-install step to run on Linux — SPM packages are fetched/resolved by Xcode on a Mac.

There is intentionally **no update script** configured for this repo, because there is nothing installable on the Linux VM that enables building or running the app.

### How to actually build/run (requires macOS + Xcode)

Per `README.md`, on a Mac with a recent Xcode:

1. Open `Zero.xcodeproj`.
2. Select the shared `Browser` scheme.
3. Run with ⌘R (Debug configuration).

CLI equivalent on macOS:

```
xcodebuild -project Zero.xcodeproj -scheme Browser -configuration Debug build
```

There are no unit/UI tests, no lint/format config, and no CI workflows in the repo.

### Editing on Linux

Code edits and static review are still possible on the Linux VM, but any verification (compile/build/run) must happen on macOS. Do not attempt to install Xcode/Swift toolchains on the Linux VM to "make it work" — it will not.
