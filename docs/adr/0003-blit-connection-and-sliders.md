# ADR 0003: remembered Blit connection and native sliders

- Status: implemented; pane0.1.4
- Date: 2026-10-18
- Issue: hibr-apps#1

The user explicitly requests persistent API credentials, superseding the
memory-only choice in the original pane. The URL uses Hibr's `dt_keep` and
`cp_save` conventions. The API token does not: desktop settings are executable
text and their writer does not enforce secret permissions.

Store the API token, bound to its exact server URL, as data-only JSON in
`$XDG_CONFIG_HOME/hibr/blit/connection.json` (default `~/.config/...`). The
directory is user-owned 0700 and the file user-owned 0600, written through a
private same-directory temporary file and rename. Refuse symlinks and unsafe
files on load. A changed URL never receives another server's remembered token.
This is local plaintext protected by filesystem permissions, not encryption.
No token enters exports, process arguments, logs, or the privileged updater.
Persistence errors are visible and do not claim a successful save.

Use Control Panel's `slider` row type and `_slide` callback for scale and
independent per-display columns/rows. Font drag requests are latest-value
coalesced through the existing single bounded worker. Layout sliders edit the
existing Blit settings draft, with revision-protected Save and visible errors.

Callback/API tests use native `dt_keep`/`cp_save`, restore the URL/token in a
new process and reject origin/permission mistakes. Native UI tests drag the
actual widgets through Blit pointer input, including live font reflow.

The installed session sources panes before `dt_open` calls `dt_load`.
Pane0.1.4 therefore defers credential loading until first use, after the saved
URL is restored, and reloads whenever the connection origin changes. Explicit
Reload also retries the private file (for example after fixing permissions).
The native-order regression is red against0.1.3 and green against0.1.4.
