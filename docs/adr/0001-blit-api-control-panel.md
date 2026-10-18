# ADR 0001: Blit's Control Panel uses its public API

- Status: accepted
- Date: 2026-10-17
- Issues: hibr-apps#1, Blit#99
- Related: Blit ADRs0124 and0128

The canonical source is `bundles/control-panel/blit.hibr`, distributed through
this catalogue and hosted by the existing `cp_pane` row/dialog APIs. Blit owns
persistence and auxiliary reconciliation. This pane keeps only a draft and
observed server state in the current desktop process.

Apply sends the volatile auxiliary set. Save replaces the durable document
with If-Match. Font controls name the existing endpoint's live/automatic-save
semantics explicitly. Import stages configuration; failed/conflicting saves
preserve it. Hibr Displays owns subsequent native placement.

Requests run in bounded background Hibr jobs. `curl` supplies HTTP/TLS,
deadlines and response limits. Credentials reach curl through stdin, avoiding
argv, request files and exports, and are masked in the editor. The pane never
uses updater credentials or service-management commands. No Hibr-core changes.

`tests/blit_panel_gate.rb` tests actual Hibr callbacks against Blit, including
Apply/Save separation, import/export, stale revisions, authentication, offline
behavior, scale1.1 and masking. `mkindex` generates catalogue metadata and
hashes through the existing detached-signature workflow.
