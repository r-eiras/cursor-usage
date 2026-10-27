# Cursor Usage integration

The app loads `https://cursor.com/dashboard/usage` in a persistent WebKit data store. Authentication takes place in the official dashboard flow. Only HTTPS navigation and the app's own blank page are allowed.

When the embedded page cannot finish a sign-in — typically a passkey that belongs to Google, GitHub, Apple or company SSO, which WKWebView offers only for domains associated with the app — **Sign in with browser (passkey)** runs Cursor's PKCE login in the default browser. The app generates a random verifier, opens `https://cursor.com/loginDeepControl` with its S256 challenge, and polls `https://api2.cursor.sh/auth/poll` every two seconds for up to five minutes; 404 means the sign-in is still pending. The returned access token becomes the dashboard's `WorkosCursorSessionToken` cookie (`<WorkOS user>::<token>`, scoped to `cursor.com`, HTTPS only, expiring with the token) in the same persistent data store, so quota extraction and CSV import run unchanged. The tokens are stored in `browser-session.json` with 0600 permissions and renewed through `https://api2.cursor.sh/oauth/token` within a day of expiry; a refused renewal deletes them. These requests use an ephemeral URLSession.

Cursor does not document these endpoints. The embedded sign-in stays the primary path, a session the dashboard refuses is discarded with a prompt to sign in in the window, and disconnecting deletes the stored tokens along with the WebKit data.

Quota extraction reads the monthly allowance and renewal summary from text nodes, excluding scripts and styles. Export capture accepts only the official Cursor HTTPS host and the exact CSV endpoint `/api/dashboard/export-usage-events-csv`.

The CSV is parsed on a background queue. Import captures the UI's unknown-model label once, so parsing does not read mutable interface-language state. Pending downloads are deduplicated and cancellation invalidates pending callbacks. Partial files are removed on failure or cancellation; completed files are removed after parsing.

Metrics retain dates, model identifiers, cost, kind, and reported token counts. Raw email and repository columns are discarded; a digest identifies the account within an imported dataset. Multiple-account exports are rejected rather than combined.

Refresh intervals are one, five, or ten minutes, with five minutes as default. Countdowns and presentation update locally. Between completed synchronization cycles the dashboard WebView is released entirely. Persistent website storage keeps the session across those releases. Failures preserve prior valid observations and expose a retryable local status.

Goals and daily allowances use US dollars. Cycle/daily/renewal alerts are opt-in and deduplicated. The app does not infer missing daily data or zero usage from failed imports.

Saving presentation preferences updates local rendering without reloading the authentication page. The persistent WebKit session is independent of the system browser; federated accounts may require their organization’s sign-in and MFA policy. The app does not request or validate MFA codes itself.

Update checks run once a day and on demand, as anonymous HTTPS GET requests to the project's public GitHub latest-release endpoint. An ephemeral URLSession has no cookies or credential storage, with a 12-second timeout. Only HTTPS release links under this repository are accepted. Network errors, invalid responses and rate limits are never reported as an up-to-date result. Issue reporting opens the project's new-issue page without attaching data.

A newer release is announced once through a notification with an Update now action, and stays offered at the top of the status menu. Installing downloads `CursorUsage-<version>-macOS-arm64.zip` and `manifest.json` from that release over an ephemeral URLSession, compares the archive with the manifest SHA-256, unpacks it with `ditto` into an item-replacement directory on the same volume, and accepts the bundle only if its identifier matches, its version is the announced one, its code signature validates strictly and it carries no `com.apple.quarantine` attribute. The bundle is then swapped in place with `FileManager.replaceItemAt`; a helper shell waits for the old process to exit and reopens the app. A file the app downloads itself is not quarantined, so Gatekeeper does not reassess the ad hoc signature, for the same reason `install.sh` uses `curl`. Any failure leaves the running version untouched, and a location the app cannot write to falls back to the release page.
