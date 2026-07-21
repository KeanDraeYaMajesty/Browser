# AGENTS.md

## Cursor Cloud specific instructions

### Standalone repository (required)

`KeanDraeYaMajesty/Browser` is a **standalone** repository (left the fork network of `sameerasw/Browser` by agreement — Zero is taking a different product direction).

- **`origin` is this repo only.** All commits, branches, and PRs go to `KeanDraeYaMajesty/Browser`.
- **Do not treat `sameerasw/Browser` as upstream.** Do not add it as a remote, fetch/merge/rebase from it, or open PRs against it unless the owner explicitly asks.
- Historical credit for earlier open-source browser work may remain in `README.md`; that does not imply an active fork relationship.
- Base PRs on this repo's `main` (or the branch the user names).

### macOS-only Xcode app

Zero is a **native macOS desktop browser** (`Zero.xcodeproj`, scheme `Browser`, product `Zero.app`). It cannot be built or run on the Linux Cloud Agent VM (requires Xcode + SwiftUI/AppKit/WebKit/SwiftData).

Local Mac workflow: open `Zero.xcodeproj` → scheme `Browser` → ⌘R on **macOS 27 Golden Gate**.

### System WebKit + Firefox WebExtensions

- Link **only** against system WebKit. Do not restore custom `WebKit.framework` search paths.
- Deployment target is **macOS 27.0**.
- Extension runtime uses `WKWebExtension` / `WKWebExtensionController` under `Browser/WebExtensions/`.
- Manage installs in **Settings → Extensions** (also **Zero → Extensions…** / ⌘⇧E, or the sidebar puzzle-piece button).
- Supported packages: unpacked folders, `.zip`, Firefox `.xpi`.
- Bundled demo: `Browser/WebExtensions/Demo/hello-zero` (also mirrored docs in `Examples/ZeroSampleExtension`).

### Golden Gate UI

Prefer edge-to-edge sidebar, uniform continuous corner radii (`GoldenGateMetrics`), deeper content shadows, and Liquid Glass with the intensity slider in Appearance settings. Avoid floating inset-sidebar chrome unless the user disables edge-to-edge.

Website transparency is gated by `web_content_transparency` (Appearance → Website Transparency). Pair it with `transparency_readability` for a soft ambient wash and content plates over site CSS from StyleManager — clear glass at low values, crisp reading at high. Per-site enable/disable stays on the sidebar transparency button.

### Stability

Prioritize Zen-class reliability: recover from WebContent process termination, discard WebViews on close/suspend (keep soft-close metadata for ⌘⇧T), restore last selected tab per space, isolate No-Trace/Temporary website data, and never treat suspension as an extension tab-close.

### Update script

No meaningful Linux dependency refresh — SPM packages are resolved by Xcode on macOS.
