# Cursor Usage

A small native macOS app that keeps your usage, spending, and remaining allowance in Cursor in the menu bar.

[Português (Brasil)](README.pt-BR.md) · [Releases](https://github.com/r-eiras/cursor-usage/releases) · [Report an issue](https://github.com/r-eiras/cursor-usage/issues/new) · [Distribution](DISTRIBUTION.md) · [Integration details](INTEGRATION.md) · [MIT license](LICENSE)

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

## Install

Requires **macOS 14 or later**. The current prebuilt package targets **Apple Silicon (arm64)**. Intel has not been validated.

1. Open this repository's **Releases** page.
2. Download `CursorUsage-<version>-macOS-arm64.zip` and extract it.
3. Move **Cursor Usage.app** to **Applications** and open it.
4. Connect your account in the official Cursor dashboard shown by the app.
5. Use the menu-bar indicator to open the usage card.

The user ZIP contains the compiled app, its image resource, bundle metadata, and local signature. **It contains no tests, source code, build scripts, Python runtime, or account data.** The repository and optional `-source.zip` are for development; users do not install them to run the app.

### macOS security notice

This release is **ad hoc signed and not notarized**. A copy downloaded from GitHub may be blocked by Gatekeeper or require an explicit user decision. Running a locally built copy does not prove that a downloaded copy will open without warnings. Publishing on GitHub does not require App Store submission; warning-free downloaded distribution is a separate signing/notarization step. See [distribution notes](DISTRIBUTION.md) and [Apple's guidance](https://support.apple.com/en-us/102445).

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
- Email and repository columns from the CSV are discarded. A digest identifies the account in imported metrics; exports containing multiple accounts are rejected.
- Temporary CSV files are removed after import. Quota observations are retained for up to 40 days; disconnected account metrics remain in a local archive until removed.
- The project's own code adds no analytics or telemetry service. The official dashboard and sign-in providers retain their own network behavior.

Do not attach account data, cookies, raw exports, authentication URLs, or personal usage files to public issues. See [integration details](INTEGRATION.md) for the data flow.

## Build and test

Current version: **3.1.5, build 11**.

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

About links to this project, its releases, and its issue form. Check for Updates queries the latest public release without a GitHub token and compares numeric versions. When an update is available, you can open its GitHub release page; downloads and installation remain a user action. Report an issue opens a blank issue form and does not upload diagnostics or usage data.

## Contributing and reporting problems

Use GitHub Issues for reproducible bugs or focused suggestions once the repository is public. Include the app/macOS versions, steps, expected result, and actual result. Redact personal data from screenshots. Changes should preserve the distinction between official cycle quota, calculated daily allowance, and historical usage; include regression tests for behavior changes.

## Uninstall

Turn off **Start at login**, quit the app, and remove it from Applications. Removing the app does not automatically remove local history or the WebKit session. See [distribution notes](DISTRIBUTION.md) before resetting local data.

## License

[MIT](LICENSE). Cursor's name and logo belong to their respective owner and identify the service whose usage is shown.

The optional HTTP integration check for release updates is `python3 Tests/ReleaseUpdates/run.py`. It requires Postman CLI 1.73+ for the local simulation; this is a development dependency only and is not bundled with the app.
