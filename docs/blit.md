# Blit Displays Control Panel

Install with `catalogue install control-panel/blit`, then open Control Panel
and select **Blit Displays** under Hardware. Remove it with
`catalogue remove control-panel/blit`. The canonical bundle belongs here;
Hibr core and the Blit Debian package do not carry another copy.

The pane requires Blit0.1.543's auxiliary API, Hibr's Control Panel framework,
and `curl`. Callback/API tests use installed Hibr0.99.241, ABI16. The default
server is `http://127.0.0.1:8080`; set Server and API Token in the pane for a
network server. The token is masked and kept only in this desktop's memory.
The privileged updater token is not used. Configuration exports omit the
connection credentials.

Available panes have staged auxiliary checkboxes. For a vertical split,
choose the upper auxiliary and save the lower preferred primary.
**Apply auxiliaries now** sends the staged auxiliary set to the live API.
**Save as Default** saves Blit's complete settings document using the revision
originally read. Login enabled/preferred/fallback choices apply on restart.
Hibr Displays owns subsequent native placement. Live rows show the server's
effective states and reasons. **Retry stopped auxiliaries** explicitly permits
a new attempt. The pane runs no reconnect controller and saves no second
configuration file.

Font/profile and tenth-step scale controls use Blit's live font API, which
queues its own automatic settings save. Storage status reports the server's
durability receipt. Export writes the staged document; Import stages a draft
and performs no network mutation. A stale Save reports409 and retains the
draft. Reload explicitly discards it. Offline, authentication, timeout and
save failures remain visible; mutations are not silently retried.

Requests run in one background job with a two-second connection timeout,
six-second per-request deadline and bounded response size. Callbacks poll
completed files in a private temporary directory. Measured frame rate, render
duration, backend and native readiness come from Blit's observation resource.
They do not establish a monitor-wide performance guarantee.

Run `ruby tests/blit_panel_gate.rb` with `BLIT_ROOT` pointing to Blit's checkout
to test actual Hibr callbacks against a local Blit binary. Catalogue lifecycle
and UI capture acceptance are separate from callback tests.

`ruby tests/blit_catalogue_gate.rb` tests install/update/remove through the
installed catalogue client in an isolated scope. `ruby tests/blit_ui_gate.rb`
uses Hibr's installed desktop UI libraries and Blit SDL software, opens/closes
dialogs with keyboard input, and verifies masking in terminal cells. Set
`BLIT_PANEL_UI_OUTPUT` to retain its screenshots. These local tests do not
claim physical-monitor acceptance.
