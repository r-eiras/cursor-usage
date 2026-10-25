# Cursor Usage integration

The app loads `https://cursor.com/dashboard/usage` in a persistent WebKit data store. Authentication takes place in the official dashboard flow. Only HTTPS navigation and the app's own blank page are allowed.

Quota extraction reads the monthly allowance and renewal summary from text nodes, excluding scripts and styles. Export capture accepts only the official Cursor HTTPS host and the exact CSV endpoint `/api/dashboard/export-usage-events-csv`.

The CSV is parsed on a background queue. Import captures the UI's unknown-model label once, so parsing does not read mutable interface-language state. Pending downloads are deduplicated and cancellation invalidates pending callbacks. Partial files are removed on failure or cancellation; completed files are removed after parsing.

Metrics retain dates, model identifiers, cost, kind, and reported token counts. Raw email and repository columns are discarded; a digest identifies the account within an imported dataset. Multiple-account exports are rejected rather than combined.

Refresh intervals are one, five, or ten minutes, with five minutes as default. Countdowns and presentation update locally. Between completed synchronization cycles the dashboard WebView is released entirely. Persistent website storage keeps the session across those releases. Failures preserve prior valid observations and expose a retryable local status.

Goals and daily allowances use US dollars. Cycle/daily/renewal alerts are opt-in and deduplicated. The app does not infer missing daily data or zero usage from failed imports.

Saving presentation preferences updates local rendering without reloading the authentication page. The persistent WebKit session is independent of the system browser; federated accounts may require their organization’s sign-in and MFA policy. The app does not request or validate MFA codes itself.

Manual update checks use anonymous HTTPS GET requests to the project's public GitHub latest-release endpoint. An ephemeral URLSession has no cookies or credential storage, with a 12-second timeout. Only HTTPS release links under this repository are accepted. Network errors, invalid responses and rate limits are never reported as an up-to-date result. Issue reporting opens the project's new-issue page without attaching data.
