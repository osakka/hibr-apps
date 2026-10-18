# ADR 0002: quiet, bounded Control Panel refresh

- Status: accepted
- Date: 2026-10-18
- Related: ADR0001, hibr-apps#1, Blit#100

The user reports continual visible refresh. Pane0.1.1 schedules a desktop
wake every second, fetches two snapshots every three seconds and replaces
its visible status with `Working: refresh` for each background request.
Those are independent of any backend state change.

Use one shared, deadline-driven background job as before. Refresh an active
pane at most once per15 seconds after completion; preserve its visible
status while an automatic refresh is in flight. Explicit Connect/Reload and
mutations retain their progress messages. Refresh after Apply/font actions
to observe their result, without retrying mutations. Failed reads back off
to15/30/60 seconds; successful reads reset backoff. Validate/schedule before
launch so invalid URLs or missing curl cannot retry on every drawing call.

Ask Hibr for the actual next refresh deadline, or250ms while a job is pending,
not a permanent one-second wake. Search scratch-row generation must not
launch jobs or schedule desktop wakes. The pane remains an API observer, not
a second hardware monitor or settings store. No Hibr-core modification.

Regression acceptance checks actual callbacks against Blit: no request after
four idle seconds, quiet due refresh, deadline-sized wake, bounded busy poll,
read-error backoff, explicit reload, and the existing mutation/error/draft
tests. This does not promise zero redraws in Hibr's shared frame loop.
