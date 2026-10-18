# ADR 0004: Blit Mouse shares the canonical Blit controller

- Status: implementation in progress, pane0.1.5
- Date: 2026-10-18
- Issues: itdlabs/blit#102, hibr-apps#1

Register a second native `blit_mouse` pane in the canonical Blit bundle, not
another downloadable application/controller. Both panes share the URL-bound
private credential, bounded worker, observer, polling deadline and staged
settings document. Installation/removal of that bundle owns both registrations.
Hibr's separate Mouse pane continues to configure window-manager behaviour.

Appearance stages shape/palette/physical pixel size/shadow in the Blit settings
document. Physical-device selection considers every present pointer, including
mixed keyboard/pointer devices. Device controls stage stable-ID configuration
for sensitivity10–1000%, flat/adaptive acceleration, natural wheel direction
and wheel step1–10. Preserve unedited configuration fields. Save submits the
shared draft with its existing revision guard, not a new preferences file.
Name the button "Save all staged Blit settings" because edits in either pane
belong to that same draft. Discard/refresh and conflict behaviour are shared.

Appearance support is discovered from `settings.effective.pointer`; older
servers show an explicit upgrade notice. Sliders use native horizontal drag
callbacks and keyboard adjustment. Device identity/selection is not a node
path, and disconnection cannot silently retarget a pending configuration.
Visual quality and measured physical pointer latency are separate acceptance
boundaries; no appearance controls promise to fix the open performance issue.
