# AGENTS.md

## Cursor Cloud specific instructions

### Fork-only git policy (required)

This checkout is the owner's fork: **`KeanDraeYaMajesty/Browser`**.

- **`origin` must remain the fork.** All commits, branches, and PRs go to `KeanDraeYaMajesty/Browser` only.
- **Never push, force-push, or open PRs against upstream** (`sameerasw/Browser`). Do not add upstream as a push remote.
- Base PRs on the fork's `main` (or the fork branch the user names). Do not target `sameerasw/Browser`.
- **Do not sync from the original browser by default.** Only fetch/merge/rebase from upstream when the user explicitly asks for a **major/big upstream update**. Small upstream noise should be ignored unless requested.
- If upstream must be referenced for a one-off big sync, use a fetch-only remote (e.g. `upstream`) and merge into a fork branch; still open the PR on the fork.

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

### Update script

No meaningful Linux dependency refresh — SPM packages are resolved by Xcode on macOS.
