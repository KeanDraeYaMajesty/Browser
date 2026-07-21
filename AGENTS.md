# AGENTS.md

## Cursor Cloud specific instructions

### macOS-only Xcode app

Zero is a **native macOS desktop browser** (`Zero.xcodeproj`, scheme `Browser`, product `Zero.app`). It cannot be built or run on the Linux Cloud Agent VM (requires Xcode + SwiftUI/AppKit/WebKit/SwiftData).

Local Mac workflow: open `Zero.xcodeproj` → scheme `Browser` → ⌘R.

### Firefox WebExtensions

Experimental Firefox-compatible extension runtime lives under `Browser/WebExtensions/`. Manage installs in **Settings → Extensions**. Bundled demo: `Browser/WebExtensions/Demo/hello-zero`.

Supported surface is documented in `README.md` (content scripts, background scripts via JavaScriptCore, `runtime` / `storage.local` / partial `tabs`). Do not expect full AMO / `webRequest` parity yet.

### Update script

No meaningful Linux dependency refresh — SPM packages are resolved by Xcode on macOS.
