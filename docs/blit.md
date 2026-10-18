# Blit Control Panel

Install with `catalogue install control-panel/blit`, then open Control Panel
and select **Blit** under Hardware. Remove it with
`catalogue remove control-panel/blit`. The canonical bundle belongs here;
Hibr core and the Blit Debian package do not carry another copy.

The pane requires Blit0.1.543's auxiliary API, Hibr's Control Panel framework,
and `curl`. Callback/API acceptance includes Hibr0.99.241 and0.99.244, ABI16;
the latter is retested against the0.1.544 server binary. The default
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

## Additional physical displays

With direct KMS Blit0.1.544 or newer, the backend reconciles live monitor
connections on its selected DRM device. The pane exposes new panes on its
next quiet refresh (up to15 seconds after the preceding read); it does not
restart the server or become a separate hardware watcher. Select auxiliaries,
Apply and Save as Default as usual. Saved bindings wait for absent connectors
and may provision new standbys after they return and native ownership is
authenticated. Primary migration is not automatic. Inspect the API's
`diagnostics.render.hotplug` for observer status and activation/teardown errors.
Actual physical multi-output/unplug/replug acceptance is separate from the
server's deterministic mocked-DRM lifecycle tests.

With Blit0.1.543's SDL backend, display discovery runs at server startup;
live display add/remove reconciliation is not implemented. Plugging in another
monitor while the service is running is therefore not promised to add its
panes to the API or this panel. The panel refreshes server observations every
15 seconds while selected, but it cannot discover hardware independently of Blit.

For monitors detected at startup, the panel lists their panes. Select the
desired auxiliary panes, **Apply auxiliaries now**, and **Save as Default**
if that selection should survive restart. A new monitor is not automatically
authorized as a desktop client merely because it is connected. A saved
connector/pane binding can provision its standby once the output is discovered
and authenticated native desktop ownership is ready. Hibr Displays owns later
arrangement. Current pane layout and font controls are global, not separate
per-monitor layout/font editors. Physical multi-output and unplug/replug
acceptance remain separate from the local controller tests.

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
Those measurements do not establish a monitor-wide performance guarantee.
Automatic refresh does not replace the visible status with `Working`; explicit
actions still show progress. Successful reads schedule the next refresh after
15 seconds, failures back off to15/30/60 seconds, and only an in-flight job
requests250ms completion checks. There is no permanent one-second desktop wake.
Search scratch rows perform no I/O. See[ADR0002](adr/0002-quiet-bounded-background-refresh.md).

Run `ruby tests/blit_panel_gate.rb` with `BLIT_ROOT` pointing to Blit's checkout
to test actual Hibr callbacks against a local Blit binary. Catalogue lifecycle
and UI capture acceptance are separate from callback tests.

`ruby tests/blit_catalogue_gate.rb` tests install/update/remove through the
installed catalogue client in an isolated scope. `ruby tests/blit_ui_gate.rb`
uses Hibr's installed desktop UI libraries and Blit SDL software, opens/closes
dialogs with keyboard input, and verifies masking in terminal cells. Set
`BLIT_PANEL_UI_OUTPUT` to retain its screenshots. These local tests do not
claim physical-monitor acceptance.
