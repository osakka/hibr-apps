# hibr apps

The application catalogue the `apps` command installs from — applications
for the [hibr](https://github.com/osakka/hibr) desktop, each one a script
you can read before you run it.

## Use it

```text
apps list
apps info snake
apps install snake
```

Installing places the app where the desktop already looks
(`$XDG_DATA_HOME/hibr/apps`), so it is on the Applications menu the next
time the desktop starts; `apps remove` takes it away again, and
`apps update` offers whatever has a newer version here than on disk.

The catalogue in force is `apps index`, and any copy of this folder is a
catalogue: `apps index https://your.host/hibr-apps/index.json` points at
yours. A bundle's address in the index is relative, so a mirror is a copy
of one folder rather than a rewrite of every entry.

## What is in here

| | |
|---|---|
| `index.json` | the catalogue: one object per app under `apps`, keyed by name |
| `index.html` | the same thing as a page, at <https://osakka.github.io/hibr-apps> |
| `bundles/NAME/NAME-VERSION.hibr` | every version ever published; the index offers the newest of each |
| `addapp` | put an app's file in as a bundle, with the version it last changed in |
| `mkindex` | rebuild `index.json` and `index.html` from what is in `bundles/` |

An entry says `title`, `version`, `kind`, `bundle`, `sha256`, `about`,
`author` and `licence`. There is deliberately no `hibr` or `abi` field:
which release an app needs is whatever desktop API it calls, which is not
written in the file, and the release it last changed in is a
plausible-looking guess rather than an answer — `apps info` saying "needs
hibr any" is the honest version of not knowing.

`kind` is which of the desktop's five scan roots the app installs into:
`apps`, `system`, `control-panel`, `control-strip` or `savers`. It is read
from the registration the app makes (`dt_app`, `cp_pane`, `cs_module`,
`sv_saver`) rather than declared twice.

## Publish

```text
./addapp ../hibr/examples/desktop/apps/Games/snake.hibr
./mkindex
git add -A && git commit -m "snake 0.99.93" && git push
```

`addapp` reads the version from the source tree's own git log — a commit
subject in hibr is `0.99.181: what it did`, so a bundle's version moves
when the *app* moves and not when anything else does. Give a version as a
second argument to override it.

Nothing in the index is written by hand. `mkindex` derives every field from
the bundle it describes — the title from the app's own `dt_app` line, the
prose from the file's own header comment, the kind from its registration,
the sha256 from the bytes as they will be fetched — so the catalogue cannot
drift from the code it offers. Run it after every `addapp`.

An app that brings files with it travels as a tarball instead of a bare
`.hibr`: `app.json` inside it says which member is the app, and everything
else lands under `<kind>/NAME/`. `addapp` does not make one, because
nothing here needs one yet.

This repository lives at `itdlabs/hibr-apps` and mirrors itself to GitHub,
where Pages serves it. Push to the first one only.

## What you are trusting

An app is a hibr script and runs with everything your own shell can do:
there is no sandbox, and there are no signatures here. TLS says which
server the index came from, and the `sha256` in the index says the bundle
was not changed on the way — neither says who wrote it. `apps install`
refuses a bundle whose sha256 does not match, one holding a symbolic link,
a `.so`, an absolute path or a path that climbs with `..`, and it refuses
the whole bundle rather than skipping the bad member.

The bundles are plain files in this repository. Read one before you install
it — that is the point of an app being a script.

See [ADR 0041](https://github.com/osakka/hibr/blob/main/docs/adr/0041-an-app-is-a-folder-of-files-a-bundle-is-how-it-travels.md)
for why an app is a folder of files and a bundle is how it travels, and
[docs/apps.md](https://github.com/osakka/hibr/blob/main/docs/apps.md) for
the command.

MIT licensed, as hibr is.
