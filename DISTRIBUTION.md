# Cursor app distribution

Version 3.1.6 targets macOS 14 or later. Builds use the host architecture; validate Intel separately before publishing an Intel artifact.

1. Install with `install.sh`, or build from source and move `Cursor Usage.app` to Applications.
2. Open it and connect through the official Cursor dashboard.
3. Configure the menu format, period, language, goals, and optional alerts.
4. Keep the app in a stable location before enabling Open at login.

The current build uses an ad hoc signature. Developer ID signing and notarization are required for normal downloaded-app distribution without Gatekeeper blocking. Local signature verification is not proof of notarization or acceptance on another Mac.

## GitHub releases

Publishing on GitHub does not require App Store submission or Apple Developer Program membership. The current app is ad hoc signed and not notarized: a browser-downloaded copy may be blocked by Gatekeeper or require an explicit user decision. A successful local launch is not proof of a warning-free downloaded installation. This project does not disable Gatekeeper or alter download quarantine.

Observed behavior on macOS 26 with the default "App Store and identified developers" policy: a copy carrying `com.apple.quarantine` is terminated a few seconds after launch and its bundle is moved to the Trash. The system log records `Gatekeeper policy blocked execution` from `launchd` and `Security policy would not allow process` from the kernel's `AppleSystemPolicy`. No crash report is produced, because this is a policy termination rather than a crash. Expect this on any Mac that has not been set to allow the app explicitly.

## Install script

`install.sh` is the only supported way for users to install a prebuilt copy. It resolves the latest release through the GitHub API, or takes a version argument, downloads the app ZIP and `manifest.json` with `curl`, compares the archive against the manifest SHA-256, verifies the signature, installs to Applications with `ditto`, and reopens the app when it was already running. It exits non-zero on any failure and leaves an existing installation untouched.

`curl` does not set `com.apple.quarantine`, so a copy it fetches is not assessed by Gatekeeper. This avoids the assessment; it does not pass it. The script never removes the attribute and never changes a system setting: it aborts if the download or the installed bundle carries it. Keep that behavior, because stripping the attribute would turn a documented limitation into a silent security bypass on the user's machine.

This is a workaround for the missing notarization, not a substitute for it. Signing with a Developer ID and notarizing is the only change that would make a browser download or a package manager work for every user. The tooling for it (`notarytool`, `stapler`) ships with the Command Line Tools; what is missing is Apple Developer Program membership and a Developer ID Application certificate.

Keep the version in the `install.sh` examples in the READMEs in sync with each release.

## Routes that were removed

The project previously offered a direct ZIP download link in the README and a Homebrew cask in `Casks/`. Both were removed, because both write the app with `com.apple.quarantine` and therefore deliver a copy that macOS terminates and moves to the Trash on first launch. Keeping them meant advertising installation routes that cannot work on a Mac with the default policy.

Homebrew's `--no-quarantine` option is gone: Homebrew 7.0.10 answers `Error: invalid option: --no-quarantine`, and a cask cannot opt out on the user's behalf. Do not restore the cask or a browser download link before the app is notarized, and do not document an `xattr -d` step as a substitute. The release still publishes the app ZIP, because `install.sh` downloads it.

## Packaging

Run `python3 package_release.py` after building. Use the following release assets:

- `CursorUsage-<version>-macOS-<architecture>.zip`: the user download; only the compiled app, Cursor image, bundle metadata and signature. No tests, source code, build scripts, account data, or development dependencies.
- `CursorUsage-<version>-source.zip`: optional developer archive; includes source, tests, documentation and build tools. Users do not install this to run the app.
- `manifest.json`: checksums for the tested files and archives.

Python and the Apple developer toolchain are needed only to build from source, not to run the app. Packaging rejects unexpected runtime files or symbolic links before creating the user ZIP.

Publish only these generated archives and manifest for the tested source candidate. The source archive contains source files, tests, the Cursor asset, build tools, documentation, `.gitignore`, and the license. It excludes account state, screenshots, local backups, and Git history.

To uninstall, turn off Open at login, quit the app, and remove it from Applications. Preserve a private backup before resetting `~/Library/Application Support/CursorUsage/`. WebKit sessions and macOS preferences belong to the bundle identifier `local.cursorusage.CursorUsage`.

A clean-account login, notification permission prompt, reboot/login startup, visibility on physical displays, and another Mac are separate acceptance checks. A successful source build does not establish those results.

Distributing through Homebrew, or any route that writes the app with a quarantine attribute, becomes possible again once the app is notarized. See "Routes that were removed" above.
