# Blit Control Panel

## Program Windows, and retired rows (pane 0.1.32)

The **Screens** section is now **Program Windows**, after
`blit-compositor`, which shows programs in desktop windows (Blit ADR 0228).
- **Compositor**: its version on this computer, or not installed.
- **Running**: `Yes, <version>`, `No`, or
  `An older build: Restart Desktop for <version>` when an upgrade has
  replaced the running compositor's file. It is checked at most every 5 s.
- **X programs**: Xwayland's version, or not installed, in which case X
  programs can't open.
- **GPU frames**, and each pane's frames and input route, as before.

The **Wayland Screen bridge** (`blit-gamescope`) and **gamescope** rows
are gone: Blit retired both in 0.3.75.

The Keyboard section's Super row no longer reads the desktop's Shortcut
Key (`DT_MOD`, gone in Hibr 0.99.509, whose shortcuts are literal chords).
Whenever Super is made another key, it says the Start Menu's Super tap
and the desktop's `super-` shortcuts need Super.

Rows that named an old Blit release ("Requires Blit 0.2.27", "Keyboards
other than US need Blit 0.3.93", and so on) are gone. The pane is for a
current Blit, and a field the server doesn't send reads "Not reported by
server". Zoom always snaps to 25 % steps, and the performance panel's
opacity is always shown.

## Keyboards, and one rule with Shortcuts (pane 0.1.31)

Blit Keyboard says what each key is and what it types; what a combination
of keys does is the desktop's Shortcuts pane, and the pane's first line
says so. Its words are the desktop's: **Caps Lock Key Is** and **Super Key
Is** offer Caps Lock, Control, Alt, Super and Nothing (Blit's `meta` is
Super, `none` Nothing). When Super is made another key here, a row says
the Start Menu's Super tap and the desktop's `super-` shortcuts need it
(0.1.32; before, only when the old Shortcut Key used Super).

The **Keyboards** section (Blit 0.3.93, ADR 0231) is live, like the font:
**In Use**, **Remove <name>** and **Add Keyboard** (a layout from **Add
Layout**, every layout the system has, and a **Variant**, Standard or one
such as Arabic (Macintosh, phonetic), typed letter by letter) go to Blit at
once. The draft takes the keyboards as Blit has them, so a Save never puts
back a keyboard the desktop's switcher (its menu bar, Control Strip or
shortcut) changed since. Blit refuses a keyboard the system does not have.
Against an older Blit the section says it needs 0.3.93.

## Blit Keyboard (pane 0.1.30)

A third pane in the bundle, **Blit Keyboard** under Hardware, for the
physical keyboard as Blit keeps it per device. **Device** offers only
keyboards that are present (a keyboard and mouse on one receiver is one of
them). **Repeat Delay** (100 to 2000 ms) and **Repeat Rate** (1 to 100 a
second) show only for a keyboard the kernel repeats for, and read back what
the kernel holds, so a rate can come back a step from the one asked for.
**Caps Lock at Start** and **Num Lock at Start** are unset (the lamp as the
keyboard had it) until set, then off or on. **Caps Lock Key Is** and
**Super Key Is** choose the role Blit gives those keys (Caps Lock as
Control, say); on a Chromebook, Super is the Search key. **Keyboards**
lists the layouts Blit types with: US for now; more come with Blit's ADR
0231. Everything is staged in the shared draft and saved with **Save all
staged Blit settings**.

Save now says when Blit refused part of the document ("Saved, but Blit
refused 1: ..."), rather than reporting it saved. Hibr's own Keyboard pane
keeps how keys reach a terminal, and its Shortcuts pane what the desktop
does with them.

Needs Blit 0.3.90: before it, Blit reported the read-only repeat period in
a keyboard's configuration, and a draft that carried it back had that
keyboard's whole entry refused.

## Screens (pane 0.1.29; Program Windows since 0.1.32, above)

A read-only **Screens** section, after Rendering, for programs shown in a
window through Wayland Screen (Blit's `blit-gamescope`, ADR 0225):
**Wayland Screen bridge** (its version on this computer, or not installed),
**gamescope** (installed or not), and **GPU frames** (whether Blit offers
frames by dmabuf, or why not). Then, for each pane that has received frames
by descriptor, **frames** (how many arrived by the GPU and how many were
copied) and **input** (the input route: live, on but waiting for focus, off
or none, with the events sent and the last error). Nothing here is a
setting: a window's size and its display's refresh decide the bridge's.

## Hinting (pane 0.1.28)

Under **Font**, a **Hinting** row chooses how Blit hints text: `full` (the
default), `light` or `none`. It applies at once and is saved, like the font
and its size, through Blit's font API (`PUT /v1/fonts {"hinting": ...}`), and
needs Blit 0.3.47 or later; with an older Blit the row is not shown. Icons are
fitted by Blit and ignore it. The icon colour choice is not here: it changes
every Blit icon on the desktop, so it lives under Appearance.

## Mask type (pane 0.1.27)

Blit 0.3.35 (ADR 0209) adds the **CRT mask**, a 0..100 slider, and its
**Mask type**: a choice of aperture grille, slot mask or shadow mask,
stored as Blit's 0..2. The type acts only with the mask's strength, so its
row says "with CRT mask". The mask is drawn at the panel's own pixels and
does not grow with zoom.

## Empty panes and burn-in's fade time (pane 0.1.26)

Blit 0.3.34 reports whether a session draws in each pane (`has_view`). A
pane with none gets a **Nothing shown here** row under its heading: the
effects set for it are kept but draw nothing until a session uses it. On
the owner's mini PC the held desktop is one session in DP-1 pane 2, so pane
1's effects were invisible with no hint why. **Burn-in** (Blit 0.3.33, ADR
0208) shows its fade time beside the percentage, e.g. "(50%, fades in
0.8 s)", from 0.16 s + 1.44 s x amount/100.

## Tube colour and static noise (pane 0.1.25)

Blit 0.3.32 (ADR 0207) adds five pane effects, listed by Blit like the
others: **Static noise**, **Chroma**, **Phosphor**, **Brightness** and
**Contrast**. The pane takes each slider's range from Blit, so brightness
and contrast run from -100 to 100 with 0 in the middle (an older Blit sends
no minimum, and 0 is the bottom). **Phosphor** is a choice of white, green
or amber, stored as Blit's 0xRRGGBB value; it tints the picture only
through **Chroma**, so its row says "with Chroma". A pane's "Not drawn here"
row now gives the reason for any effect it cannot draw, not only curvature
and glow, so the new effects on the CPU compositor are explained too.

## Zoom as a slider, and restart after update (pane 0.1.24)

**Restart after update** (Blit 0.3.27, ADR 0205), in the Server section:
`at-login-screen` (Blit restarts itself into a version installed by
`apt upgrade` at the next login screen with nobody signed in) or `manual`
(it only reports). While one is waiting, an **Update waiting** row shows the
installed and running versions. Applied and saved at once. Absent against
an older Blit.


Each display's zoom is a slider on its own heading row ("DP-1 zoom"),
100–400 %, shown while held and applied when let go, as the font size is;
the arrow keys step 25 %. Against Blit 0.3.27 any 25 % step is taken;
against 0.3.26 a position snaps to the nearest of its eight zooms.

## Zoom per display (pane 0.1.23)

Under **Per-display grid**, each display that offers it (Blit 0.3.26,
ADR 0204) shows its zoom on its own heading row ("DP-1 zoom 100%"): 100, 125, 150, 175, 200, 250, 300 or 400 %.
A choice applies at once through `PATCH /v1/displays/{id}` with
`{"configuration":{"zoom":N}}`, and Blit saves it for that monitor. This is
pixel zoom: Blit composes the display at a smaller logical size and
enlarges the image, so text and pictures become blocky, and that display
gets fewer cells (its sessions resize). The pointer and the performance
panel keep their normal size. Against an older Blit the row is absent.

## Panel opacity, and the panel rows fixed (pane 0.1.21–0.1.22)

- **Panel opacity** (0.1.22): a slider, 10–100 %, for the panel's
  background and graph; text and border stay opaque. Shown while held,
  applied when let go. Needs Blit 0.3.25 (`hud.opacity`); against an older
  Blit the row is absent.
- **Panel corner** and **Hibr section** (fixed in 0.1.21) never reached
  Blit in 0.1.20. The corner went as a quoted string inside a string. The
  section list collapsed into one word, because `$(…)` doesn't split into
  words in a hibr `for`. And changing a section wiped the panel's other
  fields. `blit_panel_gate` now drives all four rows against a real Blit
  and checks what it saved.

## Diagnostics: the performance panel (pane 0.1.20)

Blit 0.3.22 draws a small performance panel over everything (Blit ADR
0203). The **Diagnostics** section switches it:
- **Performance panel:** on or off.
- **Panel corner:** top-right, top-left, bottom-right or bottom-left.
- **Hibr section:** whether the panel shows the lines Hibr sends about its
  desktop.

Each change applies at once and is saved, through `PUT /v1/settings` on the
document's `hud` object, like the effects. A draft with staged edits is
rebased rather than lost. Against an older Blit the section says
"Requires Blit 0.3.22".

## Server: Ctrl-Alt-Backspace and Restart Blit (pane 0.1.19)

The Blit pane has a **Server** section:
- **Ctrl-Alt-Backspace stops Blit:** an on/off switch for the zap chord.
  It applies at once through `PUT /v1/control/shutdown-key`, which Blit
  saves itself. The chord and its modifiers stay as configured; only
  `enabled` changes. The row shows only when the server reports the chord.
- **Restart Blit…:** after a confirmation ("every session on it ends, and
  you log in again"), it calls `POST /v1/control/restart`. Blit stops
  cleanly and starts again in place, with no reboot. The pane reconnects by
  itself when the server answers again.

## Blit Effects, live, with switches (pane 0.1.16)

The owner's request: effects that apply as you change them, and switch off
completely.
- **Live.** Every change reaches Blit at once, with no Save: a slider when it
  is let go, a switch or a keyboard step immediately. The pane writes Blit's
  current settings with only `effects` replaced, so nothing staged in Blit
  or Blit Mouse is saved with it. Staged edits are kept, and rebased onto the
  new revision, so their own Save still works.
- **Switches.** **Effects** at the top turns every effect off; each pane's
  **On** turns that pane's off. The values are kept for when it is switched
  back on. Blit then draws exactly what it draws with no effects, at no cost
  (Blit ADR 0187).
- **Every effect Blit has.** The sliders come from Blit's own list: Scanlines,
  Corners, and with Blit 0.2.28, Curvature and Glow. Where a pane cannot draw
  Curvature or Glow (the CPU compositor), it says so.
- **Conflicts.** If somebody else saved the settings meanwhile, the pane reads
  them again and applies the effects once more on top.

`blit_panel_gate` checks live apply, ranges, both switches with their values
kept, a held slider applying on release, staged edits left unsaved and still
savable, and turning an effect off. With `BLIT_PANEL_UI_PANE=blit_effects`,
`blit_ui_gate` drags and steps the corner slider and clicks the master
switch with real input, and checks that each reached Blit with no Save.

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

Since Blit 0.2.36 (ADR 0195), Blit discovers its fonts:
- **Outline text fonts:** any monospaced font in its `text/` folder.
  Shipped: `hack`, `ibm-3270`, `jetbrains-mono-nl`, `fira-code` and
  `ibm-plex-mono`. Iosevka Term shipped in 0.2.36 only.
- **Pixel fonts:** `blit-terminus16` and `blit-spleen16`.

Every font draws icons, symbols and box drawing from Blit's glyph stack.
They all appear in the existing Font selector from API discovery; no
panel-specific font list is maintained. The pixel-size slider continues to use the same API. Config-only
563 does not have these profiles. `BLIT_PANEL_UI_FONT=hack` and
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
is drawn by Blit's KMS presentation, on the GPU or the CPU compositor alike,
with matching hotspots. The pane also exposes
present pointer devices, including mixed keyboard/pointer devices, and stages
sensitivity, flat/adaptive acceleration, natural scrolling and wheel steps.
Other devices and unedited fields are preserved.

**Shake to Find** (Blit 0.3.102, ADR 0234): shaking the mouse grows the
pointer, the harder the shake the bigger, and it eases back as the shaking
calms. On by default; **Largest When Shaken** (64–256 px) and **Shake
Sensitivity** (1, a hard shake, to 10, a light one) tune it, and with Blit
0.3.104 **Shrink Back Over** (150–3000 ms, default 900) sets how quickly it
shrinks back once the shaking calms. The rows are
offered when Blit reports the setting, so older servers show none.

**Busy Pointer** (Blit 0.3.106, ADR 0235): a program in a window that
stops answering shows a ring of spokes going round over its windows until
it answers, as on a Mac. On by default; **Busy After** (500–10000 ms,
default 2000) is how long a program may go without answering, and **Spin
Once Every** (400–3000 ms, default 1000) is how fast it goes round (also
for programs that ask for the busy pointer themselves). Offered when Blit
reports the setting.

A touchpad has three more rows, shown only when the device offers them
(Blit 0.2.34, ADR 0193):
- **Tap to Click,** off by default.
- **Tap and Drag,** on by default. A tap holds the button for a moment, so
  a second touch drags, for example a window by its title bar.
- **Disable While Typing,** on by default. The pad is ignored for half a
  second after each key typed.

Blit saves the last two only when they are switched off. So the pane offers
them by the device's live configuration, not by the saved draft.

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

Blit's native KMS reconciles connected monitors without a restart: a monitor
plugged in while it runs gets its panes, and one unplugged is retired (Blit
`docs/api.md`, "Display hotplug"). The panel refreshes server observations
every 15 seconds while selected; it does not discover hardware itself, it shows
what Blit reports.

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
uses Hibr's installed desktop UI libraries and a Blit server on its DRM mock
(the CPU compositor), opens/closes
dialogs with keyboard input, verifies masking in terminal cells and drags the
layout sliders through actual Blit pointer input. Set
`BLIT_PANEL_UI_OUTPUT` to retain its screenshots. These local tests do not
claim physical-monitor acceptance.
