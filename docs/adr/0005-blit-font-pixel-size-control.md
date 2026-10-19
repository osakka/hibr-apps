# ADR 0005: expose canonical font-cell pixel sizing

- Date: 2026-10-19
- Status: implemented in pane0.1.6
- Issues: itdlabs/blit#107, itdlabs/hibr-apps#1

Replace the legacy scale slider with Font size, backed directly by Blit's
existing `PUT /v1/fonts` `size_px` field (8–64). Discover support from
`active.size_px`; unsupported servers show an upgrade notice. Never derive
pixel sizing from rounded scale or offer two conflicting size controls.
Font selection remains independent and sends only `font_id`.

Use the native horizontal slider and one-pixel keyboard steps. The existing
11-position track cannot represent all57 values by dragging, so document its
5–6px sampling; every integer remains keyboard-selectable. Coalesce pending
values through the existing bounded worker, including repeated key presses.

Blit is the sole persistence owner. Copy the returned font policy into the
shared canonical draft, replacing the whole font object so obsolete scale
does not coexist with size_px. Preserve unrelated staged edits and the old
base revision; do not silently rebase over a concurrent settings update.
Existing conflict/Reload semantics apply after automatic font saves.

Verify actual callbacks against released Blit0.1.561, including bounds,
unsupported capability, draft preservation and coalescing; drive the installed
Hibr native UI with actual pointer and keyboard input. Regress the shared
Mouse pane and catalogue install/update/removal. No Hibr core changes.
