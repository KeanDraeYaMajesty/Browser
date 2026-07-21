# Zero Sample Extension

Minimal Manifest V3 package for verifying Zero's `WKWebExtension` integration.

## Install in Zero

1. Build and run Zero from `Zero.xcodeproj` (scheme `Browser`).
2. Open **Settings → Extensions** (or **Zero → Install Extension…**).
3. Choose this folder (`Examples/ZeroSampleExtension`).
4. Allow permissions if prompted.
5. Confirm:
   - A toolbar action button appears.
   - Clicking it opens the popup ("WKWebExtension is working.").
   - On any webpage, DevTools console shows `[Zero Sample Extension] content script active…`
   - `<html data-zero-sample-extension="1">` is present on the page.
