# Blit Glyphs Control Panel

## What it shows (pane 0.1.0)

**Blit Glyphs** (`control-panel/blitglyphs.hibr`, in the Hardware group
beside the Blit panes) shows the Blit display server's fonts and glyph
sets. It is read-only: it changes nothing in Blit and keeps no setting of
its own (Blit ADR 0245, section 12, phase 1).

- **Connection**: the server, what the last read found, and **Read
  again**. It is read every 30 s. After a failure it waits twice as long
  each time, up to four times as long.
- **Summary**: Blit's version and how many text fonts, faces and glyph
  sets it has.
- **Text font in use**: its title, its id and its cell height.
- **Text fonts**: every text font in `GET /v1/fonts` `profiles`, with its
  id and `source` (`shipped` or `local`; `missing` when the file is
  gone).
- **Faces Blit ships, by role**: every face in `registry`, by family and
  id, with its role (`text`, `icons`, `nerd`, `symbols`, `unifont`,
  `colour`, `text_emoji`, `arabic_words`, `pixel_fallback`,
  `pixel_wide`). Every registry face is shipped.
- **Glyph sets**: every set in `GET /v1/fonts/sets`, in Blit's order, with
  how many names it lists, its owner, its scope (`portable` or
  `terminal-local`) and its version (a SHA-256 is cut to 8 characters).
  - **Browse** lists the sets. Choosing one, from Browse or from its own
    row, shows its names.
  - A last row says that installing and removing sets come later, from
    the Catalogue.
- **Look up a name**: **Set and name** asks for `blit/bluetooth` or
  `nerd-fa/bluetooth`. A name alone is looked up in the set being
  browsed. The answer row gives the glyph and its codepoint, with these
  marks:
  - `alias of`;
  - `deprecated, use` and the replacement;
  - which cell of a larger picture it is.

  Otherwise it says `unknown name`, `unknown set`, `retired`, or `not a
  set and name`. An address Blit's grammar would refuse is never sent.
- **Names in a set**: 128 names a page (`GET /v1/fonts/sets/{set}`), with
  **Next page** and **Previous page**. Each row is a name with its glyph,
  drawn by Blit in the row, its codepoint (`U+101006`), and `alias of`
  where it applies. Blit lists deprecated names only when they are looked
  up.

## The connection is the Blit pane's

The pane uses the server and API token saved in the **Blit** pane
(`~/.config/hibr/blit/connection.json`), so the token is entered once,
there. It checks that file as the Blit pane does: it belongs to you, it is
not a symlink, the folder is 0700 and the file 0600. It reads the file and
never writes it. The bundle needs `control-panel/blit` (`# needs:`).

- **No saved connection:** the pane says Blit is not connected and to set
  up the server and token in the Blit pane. It makes no request until
  they are saved.
- **The Blit pane changed servers without saving a token for the new
  one:** the pane says so, rather than sending the old token to the new
  server.
- **HTTP 401** says to enter the token again in the Blit pane.
- **An offline or silent server** reads `Offline or request timed out`.
- **A Blit older than 0.3.134** has no glyph sets. The fonts are shown,
  and **Glyph sets need Blit 0.3.134 or newer** takes the sets' place.

Every request is Hibr's own `dav` request in a background job of the
desktop's (`dt_job`), never in the draw, with a 6 s timeout. The rows of a
read and of a page are made once, when they arrive. The search's scratch
rows start no request.

## Icon and Hibr

The pane's icon is `@blit:▦`: Blit's logo (glyph id `blit`, U+101000)
under the blit glyph set, and `▦` everywhere else. Hibr releases up to
0.99.557 show an icon written this way literally. The pane needs the first
Hibr release with `dt_iconof` (hibr commit c3d85c86, ADR 0050).

## Tests

`ruby tests/blit_glyphs_gate.rb` runs the real pane in the installed Hibr
(or `HIBR_BIN` and `HIBR_DESKTOP`) with the Blit pane loaded beside it. It
runs against a blit-server from `BLIT_ROOT` (`BLIT_GATE_BINARY`) and
against Blit 0.3.133. Set that older server with `BLIT_GLYPHS_OLD_BINARY`;
otherwise the gate builds it once from `releases/0.3.133.yaml`'s source
commit with `git archive` and `tools/build-tcc.sh`, which needs
`BLIT_ROOT/build/hibr-ime-0.1.5` or `BLIT_GLYPHS_OLD_IME_ROOT`.

The rows the panel builds (`cp_rowsbuild`) are compared with what the
gate reads from Blit itself:

- every set and its count;
- the first two pages of `blit` and the first page of `nerd-dev`;
- the lookups: `blit/bluetooth` is U+101006, `nerd-fa/bluetooth` is
  U+F293, an unknown name, a deprecated name, an alias, a bare name and a
  malformed address;
- the setup row, with no connection and after the Blit pane changes
  servers;
- 401, offline and a server that never answers;
- that drawing never waits on the network.
