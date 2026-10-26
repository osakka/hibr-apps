# Blit Control Panel

## Blit Effects, its own entry (pane 0.1.15)

Pane effects move out of the Blit pane into their own Control Panel entry,
**Blit Effects**, so the Blit pane stays readable and Save sits right above
the sliders. It shares the connection, the quiet refresh and the settings
draft with Blit and Blit Mouse: **Save all settings** saves everything staged
in any of the three, with the same revision guard.

## Pane effects (pane 0.1.14)

Blit 0.2.27 adds per-pane effects (Blit ADR 0186). Each live pane, by output
and pane number, is read from `GET /v1/effects` and has two sliders:
- **Corners**: a rounded-corner radius, 0–64 px.
- **Scanlines**: a darkening of every second pixel row, 0–100%.

A slider at 0 turns that effect off. The values are staged in the draft's
`effects` section, like the per-display grid. Saving applies them live and
saves them, with no restart. Effects saved for an output that is not
connected are kept, and come back with it.

On a server without the effects endpoint, the pane says it requires Blit
0.2.27. `blit_panel_gate` checks staging, range limits, the pane's layout and
callbacks, Save applying them on a real Blit, and turning one off.
`blit_ui_gate` with `BLIT_PANEL_UI_PANE=blit_effects` drags and steps the
corner slider with real pointer and keyboard input, and clicks Save.

## Native KMS only (pane0.1.13)

Blit 0.2.22 removes SDL (Blit ADR 0184): native KMS is its only presentation
path. The Presentation section drops the rows that described SDL -- Requested
backend, Active renderer, SDL video driver and Restart required -- and keeps
Active backend, Backend source and Startup default; Rendering still says
whether the GPU or the CPU draws each display. An invalid startup default now
reads `Invalid; display disabled`. `blit_panel_gate` asserts the SDL rows are
gone, and the Blit gates run against Blit's own DRM mock instead of SDL's dummy
driver.

## Rendering (pane0.1.12)

The Presentation section gains **Rendering**: one line per display saying what
draws its frames, from `render.outputs[].compositor` in Blit's diagnostics --
`GPU (GLES): <renderer>` or `Software (CPU)`, with the reason when the GPU was
requested and is not drawing (Blit ADR 0181). Two settings follow, staged like
the rest and written by Save as Default: **Compositor** (`gles`/`cpu`,
`server.kms_compositor`, applies at Blit's next restart) and **Frame timing**
(`immediate`/`late`, `server.kms_frame_timing`, Blit 0.2.20+, applies when
saved; Blit ADR 0183). A server that does not report a setting shows no control
for it. `blit_panel_gate` covers the GPU, software and fallback lines, both
selectors (invalid values ignored, keyboard stepping) and that Save writes them.

## Native dropdown menus (pane0.1.8)

Clicking the value/caret opens Hibr's native popup for primary pane, fallback,
font, pointer shape/palette/device and acceleration. Dismissal changes nothing;
choosing a value uses the same validated choice list as keyboard stepping.
Font selection remains live; other settings retain their staged Save behavior.
Booleans and sliders are unchanged. See
[ADR0007](adr/0007-blit-native-dropdowns.md) and
[hibr-apps#2](https://git.home.arpa/itdlabs/hibr-apps/issues/2).

Update with `catalogue refresh` then `catalogue update control-panel/blit`.
An already-loaded desktop pane may need a desktop restart to load the new
functions. Publication does not imply installation on the live machine.

## Presentation source (pane0.1.7)

With Blit0.1.563+, the read-only Presentation section distinguishes requested
and active backends, configuration source, active renderer/video driver,
startup-default validity and pending restart. Older servers show `Not reported
by server` where provenance is unavailable, rather than guessing.

Saved API settings own presentation intent. `BLIT_DISPLAY_BACKEND=kms` is a
startup fallback, not an override. The panel does not create a competing
backend preference store. (Since pane 0.1.13 the SDL rows are gone; see above.)
See [ADR0006](adr/0006-blit-presentation-source-is-read-only.md).

2026-10-19 verification: actual callbacks pass against563 and561 fallback;
actual panel UI, Mouse callbacks and signed catalogue install/update/remove
pass. Panel0.1.7 is catalogue-updated on10.54 as osakka; its installed SHA256
matches the signed index. Server563 reports ready native KMS, saved-settings
ownership, validkms environment fallback and SDL not applicable. This records
configuration/API evidence, not visual acceptance of every desktop mode.

Font-capable Blit0.1.564 adds `blit-modern` (native antialiased text/colour
glyphs) and `blit-hibr-spleen16` (intentional retro pixel-art). Both appear in
the existing Font selector from API discovery; no panel-specific font list is
maintained. The pixel-size slider continues to use the same API. Config-only
563 does not have these profiles. `BLIT_PANEL_UI_FONT=blit-modern` and
`BLIT_FONT_ROOT=/path/to/blit/assets/fonts` run the actual UI gate with modern
rasterization;564 passes native slider drag19px and keyboard+1/-1, with captures
under the Blit build's `font564-panel-evidence/`. This is local software/UI
evidence, not physical-display acceptance.

Blit564 is now API-deployed on10.54/native KMS. Both profiles are discovered
by the unchanged0.1.7 pane. Both pass17/19/23px physical geometry/capture
checks; a sampled actual native menu glyph has11 intermediate coverage levels
on Modern versus0 on Retro. A later external22px selection was preserved and
saved. The operator confirmed restarting Hibr during previews; observed
session replacement is not attributed to Blit. This is representative raster
evidence, not a claim of every glyph or whole-desktop resize acceptance.


Install with `catalogue install control-panel/blit`, then open Control Panel
and select **Blit** under Hardware. Remove it with
`catalogue remove control-panel/blit`. The canonical bundle belongs here;
Hibr core and the Blit Debian package do not carry another copy.

Pane0.1.7 registers **Blit** and **Blit Mouse** under Hardware in the same
catalogue bundle. Use Blit0.1.550 for pointer appearance (549 was superseded
before deployment), and Blit0.1.561+ for pixel font sizing;0.1.546 introduced
durable independent-grid startup migration. Requirements remain Hibr0.99.244
or newer (ABI16) and `curl`. Actual callbacks, private credential/native
preference restoration, Mouse slider/save and isolated catalogue lifecycle
were retested with installed Hibr0.99.250 against final0.1.550/source a1ce53d.
The server package is API-deployed on10.54; catalogue publication is not an
assertion that the user's installed app has been updated. The default
server is `http://127.0.0.1:8080`; set Server and API Token in the pane for a
network server. The token is masked and remembered in a user-private0600
JSON file at `$XDG_CONFIG_HOME/hibr/blit/connection.json` (default
`~/.config/hibr/blit/connection.json`), within a0700 directory. The URL uses
Hibr's normal `dt_keep`/`cp_save` settings. The token is bound to that exact
URL and is not sent to another host after changing Server. Unsafe ownership,
permissions or symlinks are refused; save failures appear in the pane. This
is filesystem-protected plaintext, not encrypted storage.
The credential is loaded on first use after Hibr restores the saved URL, not
while panes are initially sourced. **Reload** rereads it after any filesystem
permission repair. This fixes custom-network-URL restoration in pane0.1.3.
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

## Blit Mouse

Choose arrow, hand or precision; pearl, obsidian, neon or amber; pixel size
24–64 and optional shadow. Size is independent of font scale. The same artwork
is cached by SDL and direct KMS, with matching hotspots. The pane also exposes
present pointer devices, including mixed keyboard/pointer devices, and stages
sensitivity, flat/adaptive acceleration, natural scrolling and wheel steps.
Other devices and unedited fields are preserved.

**Save all staged Blit settings** applies and saves the shared draft from both
Blit panes with the original revision guard. This is not a separate mouse
preferences file or polling worker. Appearance requires the server's
`settings.effective.pointer`; older servers show an upgrade notice. Hibr's
existing Mouse pane still owns window-manager behaviour. Appearance is not a
claim that the physical pointer performance issue is resolved.

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
arrangement. Per-display **Columns** and **Rows** sliders stage independent
1–8 by1–8 grids; **Save as Default** applies and persists them. For example,
1column/2rows is stacked,2columns/1row is side-by-side. Newly hotplugged
unconfigured monitors default to1x1; your existing split survives upgrade.
Blit permits64 live panes but16 simultaneous terminals. Removing an occupied
pane reports409: detach it explicitly rather than losing its process. Font
selection/size remain global. Physical multi-output and unplug/replug
acceptance remain separate from the local controller tests.

**Font size** is the terminal cell height in pixels, not screen scaling or
display resolution. Its native horizontal slider covers8–64px. Keyboard
arrows change exactly1px; the11-position drag track samples that range in
5–6px steps. The current value is labelled in pixels. **Font** selects the
profile independently, preserving its sizing policy. These controls use
`PUT /v1/fonts` with either `size_px` or `font_id`; the panel never sends a
competing legacy `scale`. Older servers without `active.size_px` show an
upgrade notice rather than an approximate scale conversion.

Blit owns automatic durable saving; Storage reports its receipt. Repeated
keyboard steps and drags coalesce the latest requested size behind the one
bounded worker, without parallel mutations. A successful font change updates
only the font in the shared draft, preserving other edits and the revision
guard. If an automatic save changes that revision while edits are staged,
Reload is required before saving; it explicitly discards those edits.
See[ADR0005](adr/0005-blit-font-pixel-size-control.md).
Export writes the staged document; Import stages a draft
and performs no network mutation. A stale Save reports409 and retains the
draft. Reload explicitly discards it. Offline, authentication, timeout and
save failures remain visible; mutations are not silently retried.

Pane0.1.6 is tested with installed Hibr0.99.258/ABI16 and the released
Blit0.1.561 binary: actual callbacks,8/64px boundaries, one-pixel keyboard
steps, latest-value drag coalescing, staged-edit preservation, older-server
capability handling, native UI pointer/keyboard interaction, and Mouse
regressions. Catalogue publication does not update an already installed pane:
run `catalogue refresh` then `catalogue update control-panel/blit`.

The native UI gate also accepts `BLIT_GATE_FONT` for renderer integration
checks. Candidate Blit0.1.562 with the new `blit-modern` native antialiased
profile passes the actual slider/+1/-1 interaction at19/20px with installed
Hibr0.99.259/ABI16. This is isolated UI evidence, not a physical deployment
claim. The panel still uses the same profile and pixel-size APIs; there is
no extra modern-font configuration path or Hibr core modification.

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
dialogs with keyboard input, verifies masking in terminal cells and drags the
layout sliders through actual Blit pointer input. Set
`BLIT_PANEL_UI_OUTPUT` to retain its screenshots. These local tests do not
claim physical-monitor acceptance.
