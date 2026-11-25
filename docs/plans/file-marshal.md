# File marshal: one owner for each file, edits with context, durable history

Decided 2026-11-23: writes are allowed as well as edits; the history is
durable, with a way to clear it; binary edits are for flat binaries (formats
with internal offsets or checksums are edited at their own level, through the
deflate and zip packages); and an edit that works says how far it moved the
positions after it, so queued edits and stale clients can correct their hints.

## The problem

Programs that write the same file lose each other's updates (the last write
wins), or leave a file half written. A file marshal puts one owner in front of
each file. Clients send it operations, not bytes, and it applies them one at a
time, in an order it numbers.

## Operations

Each applies to the file's current version, and gives the new version's number
or a refusal with its reason.

- **edit**: replace what lies between a context before (P) and a context after
  (S) with new text Z: for text, `the curly ` + `haired` + ` dog` becomes
  `the curly furry dog`. The old middle (X) may be given too, and must then
  match. P + X + S must be found exactly once, so an edit to an unrelated part
  of the file still applies whatever came before it, and one whose context has
  gone, or appears twice, is refused with the reason and the text around the
  place it was expected.
- **position hint**: an edit may give the offset N where it expects its context.
  The search starts there and widens. For text the context must still be
  unique in the whole file; for a flat binary, unique within a window around N
  (the window is part of the edit).
- **write if version V**: the whole file, refused unless the file is still at
  version V.
- **append**: no condition, applied in the order they arrive (logs).
- **batch**: several edits, to one file or several, applied all or none, as
  `tools/edit_files.py` applies a spec.

## Shifts

An edit that works removes `a` bytes at offset `o` and inserts `b`. Each version
in the history records its edits as `[o, a, b]`, in the order applied.

- A position `n` after the edited region (`n >= o + a`) moves by `b - a`; one
  before it (`n < o`) stays; one inside it has no image, and the edit is
  reported as overlapping rather than guessed at.
- **Queued edits**: the owner moves the position hint of each edit still waiting
  for this file by every edit applied before it, so the search starts where its
  context now is.
- **Stale clients**: a client that read version V can ask for the shifts since V
  and carry its own positions forward (`fm_map_position`), whether or not it has
  anything queued.

## History

- Every version is kept: its number, the operations that made it (edits as
  their context and new text, writes as the whole new content, by its hash
  and a stored copy), the shifts, the time, and the client's name.
- It is durable: one append-only log per file (`append_file_bytes`, added to
  the runtime for this), in a directory the owner keeps, each record appended
  before the file is replaced. A crash between the two is found on start by
  the file's hash being that of the version before the last record, and the
  last version is written (`fh_recover`); a file whose hash is neither is
  recorded as an outside change. A record cut short at the log's end is left
  out when the log is read.
- Nothing is flushed to the disk by the program, so the history survives a
  crash of the program and not a power cut. A `file_sync` in the runtime would
  close that; it is not there yet.
- `clear history PATH [keep N]` drops all but the last N versions (at least
  the last is kept), with the owner's token, as QUIT needs one in
  port_marshal. The oldest kept version gets a whole copy, the log is written
  again under another name and renamed over the old one, and version numbers
  go on from where they were.
- Reading an old version replays the log from the nearest whole copy, and the
  result is checked against the hash recorded. Whole contents (the base, writes,
  outside changes) are whole copies; a whole copy is also kept every 64
  versions, so a replay is at most 63 records.

## Writing a file

The new content goes to a temporary file beside it, which is then renamed over
the original (`try_rename_file`), so a reader never sees half an edit. A file
changed by something that does not go through the owner (an editor, `git`) is
found by its hash before each operation, and recorded as a version of its own
("outside"): a write if version then fails, and context edits still apply.

## Readers

A read gives the content and its version. A client may subscribe to a file
and is told each new version's number and shifts as they happen.

## Where it runs

A service registered with the port marshaller as `files`, so it needs no port of
its own, with STATUS and QUIT as port_marshal has. Paths are under roots the
service is started with, and a path that leaves them (`..`, a link out) is
refused.

## Order of work

1. **A local edits library** (`packages/file_marshal/edits.patlang`): context edits
   on text and on bytes, with a position hint, a binary window, and the old
   middle optional; batches applied all or none; refusals that say why; the
   shifts each edit makes, and `fm_map_position` over a list of them. Useful at
   once, for the repository's own scripted edits among other things. Tests
   first, including an O(n) check that an edit near the end of a 1 MB file
   costs about what one near the start does.
2. **The history** (`history.patlang`, done 2026-11-23): the append-only log,
   replay, clearing, crash recovery, a torn record, and a cost check that
   recording a version does not grow with the history.
   **Undo** (`fh_undo_file`, `fh_revert_file`, done 2026-11-23): undoing version
   k applies the inverse of its edits or append to the file as it is now,
   each found by 16 bytes of context on either side, and records an "undo"
   version, which replays and shifts as edits do and can itself be undone. A
   later edit that changed the same bytes or their context makes it refused.
   A whole write is not undone; the file is reverted to a version instead.
3. **The service** (`service.patlang`, done 2026-11-23): one control thread
   applies every operation in the order it arrives, so each file's versions
   have one order. An edit names the version its hints were made against, and
   the hints are carried past the shifts since then, which is the queued case
   and the stale client's alike. Write if version, append, undo, revert, clear
   with the token, status and quit; an outside change found by the file's hash
   before each operation; paths kept under the root. Requests and replies are
   values in the history's encoding, so binary passes untouched. A slow
   operation holds up the others: an owner thread for each file is the next
   step if that matters.
   **Finding lazily** (done 2026-11-23): in the edits library, a finder
   (`fm_finder`, `fm_finder_next`, `fm_finder_close`) is a fibre yielding each
   offset where a pattern starts, one each time it is resumed, so it scans only
   as far as the matches asked for; closing it early resumes it with a stop, so
   no paused fibre is left. Across the service a search is a cursor, not a
   fibre, since the file can change between two calls and a fibre in the
   service could be neither carried nor sent: `["find", path, pattern,
   [version, position]]` gives the next match and the cursor after it, the
   position carried past the shifts since its version (one inside a change
   goes to the change's start). A scenario edits the file before the first
   match between two finds, and fails with the carrying turned off. The
   uniqueness check still collects every candidate: its refusal lists them all,
   which tells the client where to put a hint, and stopping at the second would
   lose that.
4. **Subscriptions.**
