# Signing in with an external browser

[Português (Brasil)](LOGIN.pt-BR.md) · [Back to the README](README.md)

Cursor Usage reads your usage from Cursor's dashboard, which it opens in its own sign-in window. Most accounts sign in there. When that window can't finish — usually because your account uses a passkey — **Sign in with external browser** does the login in Safari, Chrome or whatever your default browser is.

## When to use it

Use it if the sign-in window gets stuck, for example when:

- your Google, GitHub or Apple account asks for a **passkey** and no passkey prompt appears;
- Google refuses to sign in inside the app;
- your company's sign-in (SSO) needs something the window doesn't offer.

If you sign in with email and a code, the window works and you don't need this.

## How to sign in

1. Open **Cursor Usage**. If it isn't signed in yet, the sign-in window opens.
2. At the top right of that window, click **Sign in with external browser**.
3. Cursor's login page opens in your browser. Sign in as you normally do, with your passkey, Google, GitHub or SSO.
4. When the browser says you're done, go back to the app. It picks up the session by itself within a few seconds, closes the window and shows your usage near the clock.

You have five minutes to finish in the browser. While the app waits, the button reads **Cancel external browser sign-in**; click it to stop.

## Why the window can't show a passkey

macOS lets an app's built-in browser use passkeys only for websites tied to that app. Cursor's sign-in runs on Cursor's sites and its identity providers', which a third-party app can never be tied to. So inside the window, a passkey prompt for those sites never appears.

Your default browser has no such limit. The external-browser sign-in runs Cursor's own login there — the same flow the Cursor editor uses — and then hands the result to the app.

## What happens to your session

- The app receives a session from Cursor and gives it to its sign-in window, so reading your quota and history works exactly as after a normal sign-in.
- The session is saved in `browser-session.json` in `~/Library/Application Support/CursorUsage/`, readable only by your macOS user.
- A session lasts about two months. The app renews it about a day before it expires, so you don't have to sign in again.
- **Disconnect account** deletes it, together with the rest of the sign-in data.
- The app never sees your password, passkey or MFA code. They stay between you, your browser and Cursor.

## If something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| "The time to finish signing in in the browser ran out" | Five minutes passed without a finished sign-in. | Click the button again and finish in the browser. |
| "Could not reach Cursor" | The app couldn't talk to Cursor's servers. | Check your connection or VPN and try again. |
| "Cursor did not accept the browser sign-in" | Cursor's dashboard refused the session the browser produced. | Sign in in the window with email and a code. |
| "Cursor answered in a way the app does not recognize" | Cursor changed how its login responds. | Sign in in the window with email and a code, and [report the problem](https://github.com/r-eiras/cursor-usage/issues/new). |

Company accounts can also be blocked by an organization policy that only allows sign-ins from approved devices or apps. In that case your company decides, not the app.

## Limits

The sign-in window is still the first option, because it relies only on Cursor's public pages. The external-browser sign-in uses endpoints that Cursor's own apps call but Cursor does not document, so a change on Cursor's side can break it until the app is updated. When that happens, signing in in the window with email and a code keeps working.

Technical details of the flow are in [INTEGRATION.md](INTEGRATION.md).
