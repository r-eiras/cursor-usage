# Cursor Usage

Your Cursor usage and remaining allowance, in the macOS menu bar.

[Português (Brasil)](README.pt-BR.md) · [Release notes](https://github.com/r-eiras/cursor-usage/releases/latest) · [Report a problem](https://github.com/r-eiras/cursor-usage/issues/new)

## Install

Paste this one line into Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/r-eiras/cursor-usage/main/install.sh | bash
```

Some shells, company security tools and AI coding agents refuse a script piped into a shell. If yours does, download it first and run it from the file — same result:

```sh
curl -fsSL -O https://raw.githubusercontent.com/r-eiras/cursor-usage/main/install.sh
less install.sh    # optional: read it before you run it
bash install.sh
```

Then open **Cursor Usage** from Applications and sign in on Cursor's official page. The indicator appears in the menu bar, near the clock. There is no permanent Dock icon.

If the sign-in page in that window doesn't work — for example, your Google account asks for a passkey — click **Sign in with browser (passkey)** at the top right of the window. Cursor's login opens in your default browser, where passkeys work, and the app picks up the session when you finish. [Why a passkey can't work inside the window](#signing-in-with-a-passkey).

That command is the way to install the app, and the same command updates it later. [Why only this command](#why-only-this-command) has the reason, if you want it.

**Current version: 3.3.0 · build 14 · Apple Silicon · macOS 14 Sonoma or later · free and open source**

| You need | Requirement |
| --- | --- |
| Mac | Apple Silicon: M1 or later. Intel is not supported by this download. |
| macOS | Version 14 (Sonoma) or later. |
| Account | A Cursor account with usage available in the official dashboard. |
| Connection | Internet access to sign in and refresh usage. |

No Python, Node.js, Xcode, API key, or build tools are needed to run the app. To install a specific version, pass it: `bash install.sh 3.3.0`. Developers can build from source instead; see [Build and test](#build-and-test).

### The app vanishes, or no icon appears

You see one or more of these:

- You open Cursor Usage and nothing appears near the clock.
- The app disappears from Applications a few seconds after you open it.
- The Trash holds a copy with a time in its name, such as `Cursor Usage 16-29-25-877.app`.
- There is no crash report anywhere.

**This is macOS removing the app, not the app failing.** It happens to a copy that was downloaded in a browser or installed with Homebrew. To get a working install:

1. Remove those copies from the Trash, so you do not mistake one for a working install later.
2. Run the install command above.
3. Open the app. The indicator appears near the clock.

If you would rather keep a copy macOS has already flagged, you can allow it yourself in **System Settings → Privacy & Security**, under the message about the blocked app. See [Apple's opening-app guidance](https://support.apple.com/en-us/102445).

### Why only this command

This release is **ad hoc signed and not notarized**, and that has a concrete consequence.

macOS attaches an attribute called `com.apple.quarantine` to files written by browsers and by package managers such as Homebrew Cask. That attribute is what makes Gatekeeper assess an app the first time it runs. When a Mac is set to allow apps from the App Store and identified developers — the default, and what managed Macs normally enforce — the assessment rejects an ad hoc signature. The app is terminated a few seconds after launch and **its bundle is moved to the Trash**, which looks like the app deleting itself. No crash report is written, because it is a policy termination rather than a crash.

Tools that write files directly, such as `curl`, do not set that attribute, so a copy fetched by the install script is never assessed. The script does not disable Gatekeeper, does not change any system setting, and never strips the attribute; it refuses to install a flagged copy instead.

That is why this project offers no browser download link and no Homebrew cask: both produce a copy macOS removes on first launch. The release still publishes the app ZIP, because the script downloads it, but downloading that ZIP in a browser reproduces the problem.

Notarizing the app with an Apple Developer ID is the only change that would make every route work. See the [distribution notes](DISTRIBUTION.md).

### Signing in with a passkey

The app reads your usage from Cursor's dashboard, which it opens in its own window. macOS lets an app's built-in browser use passkeys only for websites tied to that app, so a passkey that belongs to Google, GitHub, Apple or your company's sign-in never appears there, and the sign-in stalls at the passkey step.

**Sign in with browser (passkey)**, at the top right of the sign-in window, runs Cursor's own login in your default browser instead, the same way the Cursor editor signs in. Passkeys work there. When you finish, the app receives the session and goes on reading the dashboard as usual.

The window stays the first option, because it relies only on Cursor's public pages. The browser sign-in uses endpoints that Cursor's own apps call but Cursor does not document. If Cursor changes them, sign in in the window with email and a code.

### Update

The app checks for a new version once a day. When one is out, it sends a notification and adds **Update to …** at the top of the right-click menu. Choose **Update now**: the app downloads the release, checks it against the release's checksums and its signature, replaces itself and reopens in a few seconds. Your preferences and account session stay as they were. **Settings → App → Check for Updates** does the same on demand.

The first notification asks macOS for permission once, even if you never turned on usage alerts. If you decline, the menu item still offers the update.

If an update cannot finish, the current version keeps running and nothing is changed. You can always reinstall with the install command:

```sh
curl -fsSL https://raw.githubusercontent.com/r-eiras/cursor-usage/main/install.sh | bash
```

Versions before 3.3.0 can't update themselves; run that command once to get there.

## Why this app exists

It is easy to stay focused on a task and lose track of how much of your Cursor allowance is left. Checking a dashboard repeatedly interrupts that work, and a subscription allowance may be larger than the amount you actually want to spend.

Cursor Usage makes the useful numbers available at a glance: your remaining or consumed quota, today's usage, and the pace of the billing cycle. Optional spending goals and alerts help you notice your limits earlier. The aim is a simple menu-bar companion, with clear settings and local data storage.

This is an independent project. It is not affiliated with or endorsed by Anysphere.

## What it does

- Shows percentages, US-dollar amounts, or both, as consumed or remaining values.
- Offers three menu-bar layouts: **Detailed** (today and cycle), **Compact** (cycle), and **Icons only**.
- Lets you choose the app's gauge icon or the original Cursor logo, and open the card by click or hover.
- Displays spending, request counts, reported tokens, and model rankings in the usage card.
- Provides reports for today, this week, the last three or seven days, and the current calendar month. New installations start with the current month.
- Supports a personal spending limit, cycle/daily threshold alerts, renewal alerts, and optional notification sounds.
- Includes explicit disconnect, optional start at login, and Brazilian Portuguese/English interfaces.

**Today is a calculated daily allowance, not an official daily quota supplied by Cursor.** The app spreads the available cycle budget across the remaining calendar days. A personal limit changes this planning reference; it does not change your Cursor plan or stop charges.

Some exported requests have no reported token count. Those requests still count as requests and retain their reported cost; the token total is marked as partial instead of inventing a number. A request row is not necessarily one user message.

## Use it

### Menu bar and card

Click the indicator, or hover if that behavior is enabled. In the card:

- **Summary** shows the selected period's spending, activity, and pacing information.
- **Models** ranks usage by spending or reported tokens.
- **Goal** explains the personal limit, daily planning allowance, and alert settings.

The period selector changes the historical report. It does not change the subscription-cycle balance in the menu bar. Right-click the indicator for About, Settings, account disconnect, update status, and Quit.

### Settings

| Tab | Controls |
| --- | --- |
| **Menu bar** | Number format, consumed/remaining values, layout, hover/click behavior, icon, optional Today/Cycle labels, and a native preview. |
| **Alerts** | Personal spending limit, cycle and calculated-daily thresholds, sounds, and renewal alerts. |
| **App** | Refresh interval, language, start at login, About, and update status. |

**Save** applies the draft settings; **Cancel** discards them. Start at login is applied immediately. Keep the app in a stable location before enabling it. Opening the menu-bar card temporarily hides Settings without saving the draft.

Alerts start disabled and need macOS notification permission. Notifications require the app to be open, and Focus settings can affect delivery. Repeated readings do not repeatedly notify for the same threshold. A personal limit is optional; without it, cycle alerts use the Cursor allowance.

To switch accounts, use **Disconnect account** in Settings or the right-click menu, then connect again. Disconnect clears this app's website session and archives account-specific metrics locally. It preserves presentation settings.

## How it works

The app opens the official `https://cursor.com/dashboard/usage` page in an embedded WebKit session. It reads the monthly quota summary and imports usage from Cursor's own CSV export. CSV parsing runs in the background. The dashboard WebView is released between completed synchronization cycles; WebKit retains the session.

| Technology | Purpose |
| --- | --- |
| **Swift** | Application logic, parsing, calculations, and persistence. |
| **AppKit** | Native menu-bar item, popover, settings, and vector gauge icon. |
| **WebKit** | Official dashboard authentication and usage export. |
| **UserNotifications** | Local threshold and renewal notifications. |
| **ServiceManagement** | Optional start at login through `SMAppService`. |
| **Foundation / CryptoKit** | Dates, CSV/JSON handling, local files, and account digests. |
| **Python 3 / Apple command-line tools** | Build, tests, packaging, and release checksums; development only. |

No third-party runtime packages, Node.js, Electron, or Python installation are required to run the prebuilt app.

## Privacy

- Usage metrics and preferences stay in `~/Library/Application Support/CursorUsage/`.
- The app does not request an API key or run another AI tool to collect usage.
- Authentication happens in the official Cursor flow. The app does not handle MFA codes itself.
- After a browser sign-in, the session is kept in `browser-session.json` in that folder, readable only by your user, and renewed about a day before it expires. Disconnecting the account deletes it.
- Email and repository columns from the CSV are discarded. A digest identifies the account in imported metrics; exports containing multiple accounts are rejected.
- Temporary CSV files are removed after import. Quota observations are retained for up to 40 days; disconnected account metrics remain in a local archive until removed.
- The project's own code adds no analytics or telemetry service. The official dashboard and sign-in providers retain their own network behavior.

Do not attach account data, cookies, raw exports, authentication URLs, or personal usage files to public issues. See [integration details](INTEGRATION.md) for the data flow.

## Build and test

Current version: **3.3.0, build 14**.

Building requires Python 3 and compatible Apple Command Line Tools. There are no external Python packages to install.

```sh
python3 build.py
python3 build.py --ui-tests
```

The first command runs the core tests and packaging-content tests, then builds an optimized app. The second also runs AppKit/WebKit fixtures in a graphical macOS session. Fixtures use fictional accounts and amounts, not a live login. A compatible SDK can be selected with `--sdk /path/to/compatible/MacOSX.sdk`.

```sh
python3 package_release.py
```

Packaging checks the signature and an explicit runtime-file allowlist, then creates the user ZIP, a separate developer source ZIP, and `manifest.json` with SHA-256 checksums. App bundles, release output, and temporary build files are ignored by Git. Tests belong in the source repository and run during development; their executables are temporary and are not linked into the app.

## Current limits

Quota reading depends on the monthly usage summary and CSV format exposed by Cursor's dashboard. Dashboard changes may require an app update. Missing, stale, or incomplete data is not a new zero-usage reading. Forecasts are estimates, not billing guarantees.

The release source targets macOS 14+. Another physical Mac, Intel, clean-account authentication, notification delivery under different Focus settings, and startup after an actual reboot are separate acceptance checks. Local tests do not establish those outcomes.

About links to this project, its releases, and its issue form. Check for Updates queries the latest public release without a GitHub token and compares numeric versions. When an update is available, the app can install it in place after verifying the release checksum and the bundle signature, or you can open its GitHub release page. Report an issue opens a blank issue form and does not upload diagnostics or usage data.

## Contributing and reporting problems

Use GitHub Issues for reproducible bugs or focused suggestions once the repository is public. Include the app/macOS versions, steps, expected result, and actual result. Redact personal data from screenshots. Changes should preserve the distinction between official cycle quota, calculated daily allowance, and historical usage; include regression tests for behavior changes.

## Uninstall

Turn off **Start at login**, quit the app, and remove it from Applications. Removing the app does not automatically remove local history or the WebKit session. See [distribution notes](DISTRIBUTION.md) before resetting local data.

## License

[MIT](LICENSE). Cursor's name and logo belong to their respective owner and identify the service whose usage is shown.

The optional HTTP integration check for release updates is `python3 Tests/ReleaseUpdates/run.py`. It requires Postman CLI 1.73+ for the local simulation; this is a development dependency only and is not bundled with the app.
