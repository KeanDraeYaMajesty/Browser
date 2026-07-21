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

Local Mac workflow: open `Zero.xcodeproj` → scheme `Browser` → ⌘R.

### Firefox WebExtensions

Experimental Firefox-compatible extension runtime lives under `Browser/WebExtensions/`. Manage installs in **Settings → Extensions** (also **Zero → Extensions…** / ⌘⇧E, or the sidebar puzzle-piece button). Bundled demo: `Browser/WebExtensions/Demo/hello-zero`.

Work for extensions + system WebKit lives on fork branch `cursor/firefox-webextensions-4db6` until merged to the fork's `main`.

Supported surface is documented in `README.md` (content scripts, background scripts via JavaScriptCore, `runtime` / `storage.local` / partial `tabs`). Do not expect full AMO / `webRequest` parity yet.

### Update script

No meaningful Linux dependency refresh — SPM packages are resolved by Xcode on macOS.
