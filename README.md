# hibr apps

The catalogue the `catalogue` command installs from — everything the
[hibr](https://github.com/osakka/hibr) desktop scans for: applications, the
desktop's own system apps, Control Panel panes, Control Strip modules,
screen savers, themes, colour schemes and languages. The five that are
scripts you can read before you run; the three that are data have nothing
to run at all.

## Use it

```text
catalogue list
catalogue info snake
catalogue install snake
```

`catalogue install control-panel/blit` adds **Blit Displays** to Control Panel.
It configures Blit's API-owned display policy, fonts and login defaults, with
live state and diagnostics. See [Blit setup and behavior](docs/blit.md).

Installing places the app where the desktop already looks
(`$XDG_DATA_HOME/hibr/apps`), so it is on the Applications menu the next
time the desktop starts; `catalogue remove` takes it away again, and
`catalogue update` offers whatever has a newer version here than on disk.

`catalogue --system install` puts it in the machine's own scope instead,
for every user of it: `$HIBR_SYSDIR`, which the shell is built with, so
the place a thing is installed to and the place it is looked for in
cannot drift apart. That is `/var/lib/hibr` where hibr is installed the
way a distribution installs one, and `<prefix>/var/lib/hibr` for a
prefixed install such as Homebrew's — a prefixed install creates nothing
outside its own prefix (hibr 0.99.215). Each scan root is read `~/.config/hibr`, then the
system scope, then your own, then the shipped copy — so an administrator's
install is authoritative and a copy of your own cannot override it, while a
file you wrote by hand still wins over both (ADR 0045, hibr 0.99.197).

The catalogue in force is `catalogue index`, and any copy of this folder is a
catalogue: `catalogue index https://your.host/hibr-apps/index.json` points at
yours. A bundle's address in the index is relative, so a mirror is a copy
of one folder rather than a rewrite of every entry.

## What is in here

| | |
|---|---|
| `index.json` | the catalogue: one object per entry under `entries`, keyed by `kind/name`, and the same again under `apps` keyed by name for a client older than 0.99.195 |
| `index.html` | the same thing as a page, at <https://osakka.github.io/hibr-apps> |
| `bundles/KIND/[DIR/]NAME.{hibr,json}` | one plain file per entry, overwritten when a new version is published — git holds every previous one. An application keeps the folder it lives in (`bundles/apps/Internet/mail.hibr`), which is what puts it back in its own submenu when it is installed |
| `addapp` | put a file in as a bundle, reading the version the thing declares |
| `mkindex` | rebuild `index.json` and `index.html` from what is in `bundles/` |
| `stale` | both directions: which bundles are behind the hibr tree they were copied from, which have moved folder, which have no file there any more — and, since it only ever looked at what was published, which files in the tree were **never** published at all. A `.hibr` with no `app` line declares no version and is not a thing the catalogue can carry, so it is exempt: `control-panel/screenshots` is rows of the Desktop pane and `control-panel/wallpaper` is a dialog Appearance opens |
| `archof.hibr` | the machine an object was built for, read from its header — shared by `addapp` and `mkindex` so one table of magic numbers decides both where a module lands and what the index says about it |

An entry says `title`, `version`, `kind`, `bundle`, `sha256`, `about`,
`author` and `licence`, and `parts` where it brings other files with it. An
**application** deliberately carries no `hibr` or `abi` field: which
release it needs is whatever desktop API it calls, which is not written in
the file, and the release it last changed in is a plausible-looking guess
rather than an answer — `catalogue info` saying "needs hibr any" is the honest
version of not knowing.

**`version` is the thing's own**, declared where it says what it is: an app
and a Control Panel pane on their `app` line, a theme, a colour scheme or a
language in their own `version` field. It used to be the hibr release the
file last changed in, which told you which shell you were running and
nothing about the app.

A **theme, colour scheme or language** does carry `hibr`, because there
that requirement is known exactly rather than guessed: the desktop did not
look in the data folder those install into until 0.99.187, so an older
client would fetch one, verify it, put it where it belongs and show
nothing. It refuses with a reason instead —
`themes/classic: needs hibr 0.99.187 or newer, and this is 0.99.186`.

`kind` is which scan root the entry installs into: `apps`, `system`,
`control-panel`, `control-strip`, `savers`, `themes`, `colours`, `lang`
or `mods`. It is the root the source file lived in, taken from its path
rather than from what it registers — an application and one of the
desktop's own system apps both register with `dt_app`, so nothing inside
the file can tell them apart. The kind also decides the extension:
`.hibr` for the five that are scripts, `.json` for the three that are
data, and `.so` for a module.

**`mods` is for somebody else's module, and never for one of hibr's.**
hibr ships every module it builds, in every packaging of it — `brew`
has no bottle and runs `make`, the AUR `PKGBUILD` runs `make`, and
`make install` places them all — because a module is **bytes** and a
source install compiles its own. Publishing some of hibr's own here
would mean either a build per architecture that nobody has, or a deb
machine behaving differently from a Mac; the split was decided and then
refused for exactly that, and
[ADR 0045](https://github.com/osakka/hibr/blob/main/docs/adr/0045-a-thing-has-a-scope.md)
records the measurements. A third party has no such problem: they
publish the builds they have, and a client on any other machine is
refused by name rather than handed bytes it cannot load.

So a module is filed under the machine it was built for —
`bundles/mods/<arch>/NAME.so`, the architecture read from the object's
own header (ELF's `e_machine`, Mach-O's `cputype`) rather than from
whoever ran `addapp` — and the index names which `(arch, abi)` pairs
exist so a client can take the one it can load.

A name is unique inside a root and nowhere else, so `clock` is both an
application and a screen saver. That is why an entry's id is `kind/name` and
why `catalogue install savers/clock` is how you ask for the other one; a name
that means one thing is still enough on its own.

## Publish

```text
./addapp ../hibr/programs/desktop/apps/Games/snake.hibr
./mkindex
git add -A && git commit -m "snake 0.99.93" && git push
```

`addapp` reads the version the thing declares, and **refuses to publish
changed content under an unchanged version** — bump it where it is
declared, or pass `--same` to replace what is there. Without that check a
hand-kept version drifts and is worse than reading a git log. Give a
version as a second argument to override it.

A bundle's path is **stable**: it is overwritten when a new version is
published, and git holds every previous one, which is where anybody
reverting would look. The cost is named rather than hidden — a static host
caches the index and each bundle independently, so for a few minutes after
a publish a client can pair an old index with a new bundle and `catalogue
install` refuses on the `sha256`, saying so. Measured on GitHub Pages: ten
minutes each, a query string is not part of the cache key, and
`Cache-Control: no-cache` is ignored, so no client can ask for a fresh one.

Nothing in the index is written by hand. `mkindex` derives every field from
the bundle it describes — the title from the app's own `dt_app` line, the
prose from the file's own header comment, the kind from its registration,
the sha256 from the bytes as they will be fetched — so the catalogue cannot
drift from the code it offers. Run it after every `addapp`.

Something that brings other files with it brings them as **plain files of
their own**, and the index says which parts belong to which entry — each
with its kind, the filename it lands as, the path to fetch it from and its
own `sha256`. `catalogue install` fetches every part and verifies them all
**before it places any**, so an entry with one bad part installs nothing at
all. There are no tarballs here: a `.tar.gz` carrying an `app.json` was a
container for a manifest of files, which is what the index already is, and
a binary nothing can diff.

`addapp` reads the parts from the source — a script declares them in its
header (`# part: control-panel/mailset.hibr`), and a theme cannot, having
no comments, so its picture is read out of the theme's own `image` field.
A part that is itself installable lands where its own publish would put it,
so the two agree by construction.

A part is counted rather than owned: two apps that bring the same Control
Panel pane both install it, and `catalogue remove` leaves it alone until the last
of them has gone.

This repository lives at `itdlabs/hibr-apps` and mirrors itself to GitHub,
where Pages serves it. Push to the first one only.

## What you are trusting

An app is a hibr script and runs with everything your own shell can do:
there is no sandbox, and there are no signatures here. TLS says which
server the index came from, and the `sha256` in the index says the bundle
was not changed on the way — neither says who wrote it. `catalogue install`
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
