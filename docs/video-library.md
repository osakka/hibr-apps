# The video library: what every video app writes, and the Library reads

One file, the same for every provider (YouTube, Tubi, Bilibili, ...), so a title watched in any of them is in one list, newest first, with
where it was left.

    ~/.local/share/hibr/library/watched.tsv      (VL_FILE overrides it; XDG_DATA_HOME is honoured)

One line per title, newest LAST, tab-separated, at most 1000 lines (the oldest go):

    epoch  provider  kind  key  title  sub  pos  dur

| field | meaning |
|---|---|
| epoch | seconds since 1970 when it was last watched (`EPOCHSECONDS`) |
| provider | the app's name: `youtube`, `tubi`, `bilibili` ... lower case, no spaces; the Library launches the app of this name |
| kind | `video`, `movie`, `episode`, ... as the provider says it |
| key | what the provider calls it by: YouTube's video id, Tubi's path (`/movies/100039855/the-baxter`), Bilibili's BV id. Unique within a provider |
| title, sub | its name, and what goes beside it (channel, season and episode, ...); tabs and newlines become spaces |
| pos, dur | whole seconds: where it was left (0 when watched to the end) and how long it is (0 unknown) |

Rules every writer keeps:
- A title already in the file (same provider and key) is replaced, so the line moves to the end.
- A writer rewrites the file whole and quietly: a file it cannot write is not an error for the player.
- A reader tolerates fields it does not know (extra columns at the end) and skips a line with fewer than 8 fields.
- The provider's own history file stays as it is: the Library is read-only over this one and never needed to play anything.

Opening a title from the Library: it launches the provider's app with the argument `play:KEY`; an app that does not know that argument treats it
as a search, so an older app shows a search for the key instead of failing.
