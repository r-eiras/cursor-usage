# Cursor app distribution

Version 3.1.6 targets macOS 14 or later. Builds use the host architecture; validate Intel separately before publishing an Intel artifact.

1. Extract `Cursor Usage.app` and move it to Applications.
2. Open it and connect through the official Cursor dashboard.
3. Configure the menu format, period, language, goals, and optional alerts.
4. Keep the app in a stable location before enabling Open at login.

The current build uses an ad hoc signature. Developer ID signing and notarization are required for normal downloaded-app distribution without Gatekeeper blocking. Local signature verification is not proof of notarization or acceptance on another Mac.

## GitHub releases

Publishing on GitHub does not require App Store submission or Apple Developer Program membership. The current app is ad hoc signed and not notarized: a browser-downloaded copy may be blocked by Gatekeeper or require an explicit user decision. A successful local launch is not proof of a warning-free downloaded installation. This project does not disable Gatekeeper or alter download quarantine.

Run `python3 package_release.py` after building. Use the following release assets:

- `CursorUsage-<version>-macOS-<architecture>.zip`: the user download; only the compiled app, Cursor image, bundle metadata and signature. No tests, source code, build scripts, account data, or development dependencies.
- `CursorUsage-<version>-source.zip`: optional developer archive; includes source, tests, documentation and build tools. Users do not install this to run the app.
- `manifest.json`: checksums for the tested files and archives.

Python and the Apple developer toolchain are needed only to build from source, not to run the app. Packaging rejects unexpected runtime files or symbolic links before creating the user ZIP.

Publish only these generated archives and manifest for the tested source candidate. The source archive contains source files, tests, the Cursor asset, build tools, documentation, `.gitignore`, and the license. It excludes account state, screenshots, local backups, and Git history.

To uninstall, turn off Open at login, quit the app, and remove it from Applications. Preserve a private backup before resetting `~/Library/Application Support/CursorUsage/`. WebKit sessions and macOS preferences belong to the bundle identifier `local.cursorusage.CursorUsage`.

A clean-account login, notification permission prompt, reboot/login startup, visibility on physical displays, and another Mac are separate acceptance checks. A successful source build does not establish those results.

## Homebrew tap

`Casks/cursor-usage.rb` is the project-owned cask, served from this repository using an explicit tap URL. It downloads the release ZIP and checks SHA-256, requires Apple Silicon and macOS 14+, and installs only the app. Update its version and checksum for every release after creating the app ZIP. Keep the direct README download links in sync. This tap does not imply acceptance into the official Homebrew catalog or bypass macOS security protections.
