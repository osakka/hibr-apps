# ADR0007: native Blit choice popups

- Date: 2026-10-20
- Status: implemented in pane0.1.8
- Issue: [hibr-apps#2](https://git.home.arpa/itdlabs/hibr-apps/issues/2)

The pane drew native dropdown values but only implemented `_do`, so clicking
advanced an option instead of opening a list. Hibr Control Panel requires the
pane's `_drop` callback to open the existing `dt_droplist` widget.

Implement `blit_drop` and `blit_mouse_drop`, using Hibr's popup positioning,
input, dismissal and menu callbacks without a separate menu implementation.
Choice discovery and validated application are shared with keyboard stepping;
font choices come from the server and device choices retain mixed-capability
pointers. Revalidate at selection time so disappeared choices cannot apply.
The key belongs to the popup's originating window. Busy requests cannot start
a second write. Opening/dismissing does not dirty or save the settings draft.
Font choice still uses the live font API; staged settings still require Save.

Verification uses the installed Hibr UI and Blit pointer input, not a mock
dropdown: open/dismiss unchanged, select a non-adjacent pointer shape, then
Save and read back the exact choice. Main-pane popup and existing dialog,
slider, font-size, credential and callback tests cover adjacent behavior.
Local software-renderer tests are not physical-monitor acceptance. Hibr core
and the Blit server are unchanged.

2026-10-20: `blit_panel_gate.rb`, `blit_mouse_gate.rb`,
`blit_catalogue_gate.rb` and `blit_ui_gate.rb` (both pane selections) pass
with installed Hibr0.99.270/ABI16 and local Blit0.1.582. The actual popup
capture was inspected. Device/primary selections and invalid-choice rejection
also pass callback tests. Physical-host installation/acceptance is pending.
