# Zero Sample Extension

Minimal Manifest V3 package (Firefox `gecko` id + Chrome-compatible fields) for verifying Zero's `WKWebExtension` integration.

## Install in Zero

1. Build and run Zero from `Zero.xcodeproj` (scheme `Browser`) on **macOS 27 Golden Gate**.
2. Open **Settings → Extensions** (sidebar puzzle button, **Zero → Extensions…**, or ⌘⇧E).
3. Choose this folder (`Examples/ZeroSampleExtension`), a `.zip`, or a Firefox `.xpi` — or click **Install Bundled Demo Extension**.
4. Allow permissions if prompted.
5. Confirm:
   - A toolbar action button appears.
   - Clicking it opens the popup.
   - On any webpage, DevTools console shows the content-script log.
   - `<html data-zero-sample-extension="1">` (sample) or `<html data-hello-zero="1">` (bundled demo) is present.
