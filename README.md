# Cursor Usage

See how much of your Cursor plan you have used, right in the Mac menu bar.

[Português (Brasil)](README.pt-BR.md) · [What's new](https://github.com/r-eiras/cursor-usage/releases/latest) · [Report a problem](https://github.com/r-eiras/cursor-usage/issues/new)

**Version 3.5.1 · Apple Silicon Mac (M1 or later) · macOS 14 Sonoma or later · free and open source**

This is an independent project. It is not made or endorsed by Cursor (Anysphere).

## What it does

- Shows your Cursor usage next to the clock, as a percentage, in dollars, or both.
- Shows two numbers: **today** and the **cycle** (your plan's billing month).
- Changes color as you use more: normal, then yellow, orange and red.
- Warns you when you pass a goal, when your plan renews, and when a model spends much more than usual.
- Updates itself.

## Corporate or personal account

The app finds out which kind of Cursor account you connected and shows what that account offers.

| | Corporate (team plan) | Personal (Free, Plus, Premium…) |
| --- | --- | --- |
| What Cursor shows | Your spending in dollars, out of the plan's limit | Only the share of your included usage, as a percentage |
| Menu bar | %, dollars or both; today and the cycle | Only the % of the included usage |
| Today's allowance | Yes | No |
| Personal spending goal | Yes | No |
| Usage alerts | By cycle and by day | By the included usage only |
| Renewal alert | Yes | Yes |
| Models in the card | Yes | Yes, when Cursor's export has data |
| Extra money (on-demand) | Part of the dollar spending | Shown in the Goal tab, with its limit, when the plan has it on |
| Model pace and dollar limits | Yes | No |
| New model alert | Yes | Yes |

Options a personal account can't use are greyed out in Settings, with a note under the tabs. The app never invents a number Cursor doesn't show.

## Install

1. Open **Terminal** (press ⌘ Space, type "Terminal", press Return).
2. Paste this line and press Return:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/r-eiras/cursor-usage/main/install.sh | bash
   ```

3. Open **Cursor Usage** from Applications.
4. Sign in with your Cursor account. The numbers appear near the clock.

If your company or your tools block that line, use these three instead. They do the same thing:

```sh
curl -fsSL -O https://raw.githubusercontent.com/r-eiras/cursor-usage/main/install.sh
less install.sh    # optional: read it first
bash install.sh
```

> **Use the command, not a browser download or Homebrew.** macOS removes copies of this app downloaded those ways. See [The app vanished](#the-app-vanished-or-no-icon-appears).

## Use it

**Click the numbers** near the clock (or just hover, if you turn that on) to open the card:

- **Summary**: what you spent in the period and how fast you are going.
- **Models**: which models cost the most. Sort by cost, tokens or **pace** (what a model usually spends in 15 minutes, the same number the model alerts use). Rest the pointer on one to see its details.
- **Goal**: your spending goal and today's allowance.

**Right-click** the numbers for Settings, updates, disconnect and Quit.

**Today** is not a Cursor limit. The app takes what is left in your cycle and divides it by the days until it renews, so you know how much you can spend today and stay on track.

## Settings

| Tab | What you set |
| --- | --- |
| **Menu bar** | Percentage or dollars, used or remaining, layout, icon, colors by usage, Today/Cycle labels. A preview shows the result. |
| **Alerts** | Your spending goal, usage alerts, renewal alert, sounds and model alerts. |
| **App** | How often to sync, language, open at login, check for updates. |

Changes apply when you click **Save**.

### Layouts

| Layout | Shows |
| --- | --- |
| **Detailed (today and cycle)** | Both numbers. |
| **Compact (cycle)** | Only the cycle. |
| **Compact (today)** | Only today. |
| **Logos only** | Only the icon. Click it to see the numbers. |

### Colors by usage

| Used | Color |
| --- | --- |
| under 30% | normal |
| 30% to 60% | yellow |
| 60% to 90% | orange |
| 90% or more | red |

Choose whether the **icon** follows the cycle or today, or has no color. Tick **Numbers too** to color today and the cycle, each by its own usage. Colors always follow what you **used**, even if the menu shows what is left.

## Alerts

Notifications only work while the app is open.

**Usage alerts** (off until you turn them on):
- When you reach a share of your cycle, or of today's allowance.
- When your plan renews.

**Model alerts** (on from the start):
- **New model**: the first time you use a model.
- **Spending fast**: when a model spends far more in 15 minutes than a reference model usually does. You choose how much more, in % or dollars, and the reference: your most expensive model or any model you used this cycle. Settings show the reference's usual spend.
- **Your limits**: pick models and give each a daily or cycle limit. Each row shows what it spent today and this cycle.

Clicking a notification opens the right place: an update installs, a usage alert opens the card, a model alert opens Settings or the model list.

## Updates

The app looks for a new version every hour. When one is out you see:

- a notification,
- a colored dot after the numbers in the menu bar,
- an **Update to …** button in the card.

Click any of them. The app checks the download, replaces itself and reopens in a few seconds. Your settings and sign-in stay. If something fails, the old version keeps running.

## Problems

### The app vanished, or no icon appears

macOS removes copies of this app that came from a browser or Homebrew, a few seconds after they open. It is not a crash. Empty those copies from the Trash and install with the [command above](#install).

Why: the app is not notarized by Apple. macOS checks apps downloaded by browsers and Homebrew and removes ones that are not notarized. The install command downloads with `curl`, which macOS does not check. It does not turn off any protection on your Mac. See [DISTRIBUTION.md](DISTRIBUTION.md) for details.

### Sign-in asks for a passkey and nothing happens

Click **Sign in with external browser** at the top right of the sign-in window. Cursor's login opens in your normal browser, where passkeys, Google and company sign-in work. See the [external browser sign-in guide](LOGIN.md).

### Notifications disappear too fast

How long they stay is a macOS setting. In **Settings → Alerts**, click **Notification settings in macOS…** and choose **Persistent**. Apps that move notifications to the notch, such as Vorssaint, can also hide them; turn off their option to hide system notifications.

### An older version does not update itself

Versions before 3.3.0 cannot. Run the [install command](#install) once.

## Privacy

- Everything stays on your Mac, in `~/Library/Application Support/CursorUsage/`.
- No API key. You sign in on Cursor's own page.
- Emails and repository names from Cursor's export are thrown away.
- No analytics or tracking.
- **Disconnect account** (Settings or right-click) signs out and archives that account's data.

Never post your account data, cookies or exports in a public issue.

## Uninstall

Turn off **Open at login**, quit the app, and delete it from Applications. Your data stays in `~/Library/Application Support/CursorUsage/` until you delete it.

## For developers

Build and run all tests (needs Python 3 and Apple's Command Line Tools):

```sh
python3 build.py --ui-tests
python3 package_release.py
```

- [INTEGRATION.md](INTEGRATION.md): how the app reads Cursor's dashboard, stores data and updates itself.
- [DISTRIBUTION.md](DISTRIBUTION.md): signing, the install script and release files.
- [LOGIN.md](LOGIN.md): the external browser sign-in.

The app reads Cursor's dashboard and its usage export. If Cursor changes them, the app may need an update. Forecasts are estimates, not bills.

## License

[MIT](LICENSE). Cursor's name and logo belong to their owner.
