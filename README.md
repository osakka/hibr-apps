# hibr apps

The catalogue the `apps` command installs from — everything the
[hibr](https://github.com/osakka/hibr) desktop scans for: applications, the
desktop's own system apps, Control Panel panes, Control Strip modules,
screen savers, themes, colour schemes and languages. The five that are
scripts you can read before you run; the three that are data have nothing
to run at all.

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
| `index.json` | the catalogue: one object per entry under `entries`, keyed by `kind/name`, and the same again under `apps` keyed by name for an older `apps` |
| `index.html` | the same thing as a page, at <https://osakka.github.io/hibr-apps> |
| `bundles/KIND/NAME/NAME-VERSION.{hibr,json,tar.gz}` | every version ever published; the index offers the newest of each |
| `addapp` | put a file in as a bundle, with the version it last changed in |
| `mkindex` | rebuild `index.json` and `index.html` from what is in `bundles/` |

An entry says `title`, `version`, `kind`, `bundle`, `sha256`, `about`,
`author` and `licence`. An **application** deliberately carries no `hibr`
or `abi` field: which release it needs is whatever desktop API it calls,
which is not written in the file, and the release it last changed in is a
plausible-looking guess rather than an answer — `apps info` saying "needs
hibr any" is the honest version of not knowing.

A **theme, colour scheme or language** does carry `hibr`, because there
that requirement is known exactly rather than guessed: the desktop did not
look in the data folder those install into until 0.99.187, so an older
`apps` would fetch one, verify it, put it where it belongs and show
nothing. It refuses with a reason instead —
`themes/classic: needs hibr 0.99.187 or newer, and this is 0.99.186`.

`kind` is which of the desktop's eight scan roots the entry installs into:
`apps`, `system`, `control-panel`, `control-strip`, `savers`, `themes`,
`colours` or `lang`. It is the root the source file lived in, taken from its
path rather than from what it registers — an application and one of the
desktop's own system apps both register with `dt_app`, so nothing inside the
file can tell them apart. The kind also decides the extension: `.hibr` for
the five that are scripts, `.json` for the three that are data.

A name is unique inside a root and nowhere else, so `clock` is both an
application and a screen saver. That is why an entry's id is `kind/name` and
why `apps install savers/clock` is how you ask for the other one; a name
that means one thing is still enough on its own.

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

Something that brings other files with it travels as a tarball instead of a
bare file: `app.json` inside it says which member is the thing itself and
which root each part belongs in, and `apps install` checks every member
before it writes anything. `addapp` reads the parts from the source — a
script declares them in its header (`# part: control-panel/mailset.hibr`),
and a theme cannot, having no comments, so its picture is read out of the
theme's own `image` field.

A part is counted rather than owned: two apps that bring the same Control
Panel pane both install it, and `apps remove` leaves it alone until the last
of them has gone.

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
