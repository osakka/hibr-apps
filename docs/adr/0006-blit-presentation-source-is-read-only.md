# ADR0006: display Blit presentation ownership without duplicating settings

- Date: 2026-10-19
- Status: implemented in pane0.1.7
- Tracking: Blit108, hibr-apps1

The server owns saved presentation intent. The pane shows active/requested
backend, backend source, active renderer, actual SDL driver, startup default
validity/override and pending restart from the existing observation snapshot.
Native DRM/KMS is not SDL/KMSDRM; its SDL video driver is not applicable.
No extra polling, preference file, environment editor or second settings owner.

Servers0.1.563+ expose effective.presentation_configuration metadata. Older
servers show "Not reported by server" for unknown source/default provenance,
not a guess from a materialized settings document. Never render arbitrary
invalid environment text into the terminal; show invalid/ignored state instead.
Foreground/native identity comes from effective/server data already available.

Test the real Hibr callbacks against both561 and config-only563, including
source/driver rows and invalid-shadowed metadata, plus the native UI gate and
catalogue install/update/removal. Publish from the canonical hibr-apps bundle;
the Blit Debian package does not acquire a second pane copy.
