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

If the sign-in page in that window doesn't work — for example, your Google account asks for a passkey — click **Sign in with external browser** at the top right of the window. Cursor's login opens in your default browser, where passkeys work, and the app picks up the session when you finish. See [Sign in with an external browser](#sign-in-with-an-external-browser).

That command is the way to install the app, and the same command updates it later. [Why only this command](#why-only-this-command) has the reason, if you want it.

**Current version: 3.4.4 · build 20 · Apple Silicon · macOS 14 Sonoma or later · free and open source**

| You need | Requirement |
| --- | --- |
| Mac | Apple Silicon: M1 or later. Intel is not supported by this download. |
| macOS | Version 14 (Sonoma) or later. |
| Account | A Cursor account with usage available in the official dashboard. |
| Connection | Internet access to sign in and refresh usage. |

No Python, Node.js, Xcode, API key, or build tools are needed to run the app. To install a specific version, pass it: `bash install.sh 3.4.4`. Developers can build from source instead; see [Build and test](#build-and-test).

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

### Sign in with an external browser

The sign-in window can't show a passkey for Cursor's sites: macOS lets an app's built-in browser use passkeys only for websites tied to that app. **Sign in with external browser**, at the top right of that window, runs Cursor's own login in your default browser instead, where passkeys, Google and company SSO work, and the app picks up the session when you finish.

The window stays the first option, because it relies only on Cursor's public pages; the external-browser sign-in uses endpoints Cursor's own apps call but does not document. The **[external browser sign-in guide](LOGIN.md)** covers when to use it, step by step, what happens to the session and what each error means.

### Update

The app checks for a new version every hour. When one is out, it sends a notification, adds a dot in your accent color after the reading in the menu bar, and shows **Update to …** in the card's footer and at the top of the right-click menu; all of them stay until you update. The dot and the button do not depend on notifications, so they still show when Focus or a notification utility hides the notice. Click the notification, or either of those: the app downloads the release, checks it against the release's checksums and its signature, replaces itself and reopens in a few seconds. Your preferences and account session stay as they were. **Settings → App → Check for Updates** does the same on demand.

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
- Colors the menu bar icon by how much is used: the bar's own color below 30%, yellow up to 60%, orange up to 90% and red from there. **Icon color** follows the cycle or today's allowance, or can be turned off; it uses the share consumed even when the menu shows what remains.
- Notifications, Finder and the app switcher show the app's own gauge icon.
- Displays spending, request counts, reported tokens, and model rankings in the usage card.
- Provides reports for today, this week, the last three or seven days, and the current calendar month. New installations start with the current month.
- Supports a personal spending limit, cycle/daily threshold alerts, renewal alerts, and optional notification sounds.
- Alerts by model: a model's first use, a model spending well above your costliest model, and goals for the models you choose.
- Includes explicit disconnect, optional start at login, and Brazilian Portuguese/English interfaces.

**Today is a calculated daily allowance, not an official daily quota supplied by Cursor.** The app spreads the available cycle budget across the remaining calendar days. A personal limit changes this planning reference; it does not change your Cursor plan or stop charges.

Some exported requests have no reported token count. Those requests still count as requests and retain their reported cost; the token total is marked as partial instead of inventing a number. A request row is not necessarily one user message.

## Use it

### Menu bar and card

Click the indicator, or hover if that behavior is enabled. In the card:

- **Summary** shows the selected period's spending, activity, and pacing information.
- **Models** ranks usage by spending or reported tokens. Rest the pointer on a model to see all of its numbers beside the card: cost and share, requests, average cost per request, and each kind of token.
- **Goal** explains the personal limit, daily planning allowance, and alert settings.

The period selector changes the historical report. It does not change the subscription-cycle balance in the menu bar. Right-click the indicator for About, Settings, account disconnect, update status, and Quit.

### Settings

| Tab | Controls |
| --- | --- |
| **Menu bar** | Number format, consumed/remaining values, layout, hover/click behavior, icon, icon color by cycle or daily usage, optional Today/Cycle labels, and a native preview. |
| **Alerts** | Personal spending limit, cycle and calculated-daily thresholds, sounds, renewal alerts, and per-model alerts with monitored models. |
| **App** | Refresh interval, language, start at login, About, and update status. |

**Save** applies the draft settings; **Cancel** discards them. Start at login is applied immediately. Keep the app in a stable location before enabling it. Opening the menu-bar card temporarily hides Settings without saving the draft.

Usage alerts start disabled. Per-model alerts start on, because they need no setup; the first one asks macOS for notification permission once. Notifications require the app to be open, and Focus settings can affect delivery. Repeated readings do not repeatedly notify for the same threshold. A personal limit is optional; without it, cycle alerts use the Cursor allowance.

Clicking a notice opens where it belongs: an update notice installs the update, a goal or renewal notice opens the card's budget, a model notice opens the model list, and **Monitor this model** opens Settings with that model listed.

How long a notice stays on screen is a macOS setting the app cannot change. **Temporary** banners leave after a few seconds and go to Notification Center; **Persistent** ones stay until you close them. **Settings → Alerts** shows which style macOS is using for the app and has **Notification settings in macOS…**, which opens that page. Utilities that move notifications elsewhere, such as Vorssaint with notch notifications set to dismiss the native ones, remove them from Notification Center about a second after they appear; turn that option off if notices from this app vanish.

### Per-model alerts

Your Cursor allowance is shared by every model, so these alerts are about where the money goes, not about a Cursor limit.

- **First use of a model.** When a model shows up that this account has never used, you get a notification with what it has spent so far, and a **Monitor this model** action that opens Settings with it already listed. The first sync only learns the models you use, so you don't get a burst of notices when you install the app.
- **Spending above your costliest model.** The app learns how much each model usually spends in 15 minutes, from the median of the last 14 days, and takes the costliest one as the reference. If any model spends more than that reference plus a threshold you choose — 50% by default — in the last 15 minutes, you get one notice that day, naming both models and, when it applies, how much more each request costs. It needs a few sessions of history before it can compare anything, and it ignores bursts under US$ 1.
- **Monitored models.** Pick models from those you use and give each a daily limit, a cycle limit, or both. Each row shows what the model spent today and in the cycle, each beside its own limit. Leave a field empty for no limit; each filled one notifies once when that amount is passed.

Model data comes from the usage history the app imports, so these alerts arrive within your refresh interval, not instantly.

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
- The names of the models this account has used are kept in `models-seen.json`, so a first use can be recognized. Disconnecting archives it with the account's other metrics.
- After a browser sign-in, the session is kept in `browser-session.json` in that folder, readable only by your user, and renewed about a day before it expires. Disconnecting the account deletes it.
- Email and repository columns from the CSV are discarded. A digest identifies the account in imported metrics; exports containing multiple accounts are rejected.
- Temporary CSV files are removed after import. Quota observations are retained for up to 40 days; disconnected account metrics remain in a local archive until removed.
- The project's own code adds no analytics or telemetry service. The official dashboard and sign-in providers retain their own network behavior.

Do not attach account data, cookies, raw exports, authentication URLs, or personal usage files to public issues. See [integration details](INTEGRATION.md) for the data flow.

## Build and test

Current version: **3.4.4, build 20**.

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
