# Obsidian Capture

Capture a note or a task into today's daily note, from anywhere, without
leaving what you were doing.

Built for Obsidian — it writes into your vault, respects your frontmatter,
and never touches anything it did not add. But it has no Obsidian
dependency: it reads and writes **plain Markdown**, so any folder of `.md`
files works just as well — Logseq, Foam, Zettlr, or a plain directory in
your editor of choice.

## What it does

Two prompts, one job each:

| command | result |
|---|---|
| `dms ipc call obsidianCapture note` | prompt, then append under `## Notes` |
| `dms ipc call obsidianCapture task` | prompt, then append under `## Tasks` as `- [ ] …` |
| `dms ipc call obsidianCapture add note "text"` | no prompt — scriptable capture |
| `dms ipc call obsidianCapture add task "text"` | same, as a task |

Today's file is created on first capture with both sections. One file per
day, named `YYYY-MM-DD daily.md` by default.

Your own edits are safe: the plugin inserts at the end of the target
section and never reformats, reorders, or touches anything else in the
file — including sections you added yourself.

## Keybinds

Nothing is bound by default. For niri:

```kdl
binds {
    Mod+Ctrl+N hotkey-overlay-title="Obsidian: Note" { spawn "dms" "ipc" "call" "obsidianCapture" "note"; }
    Mod+Ctrl+T hotkey-overlay-title="Obsidian: Task" { spawn "dms" "ipc" "call" "obsidianCapture" "task"; }
}
```

The settings pane has copy-boxes for these.

## Settings

Plugins → Obsidian Capture:

- **Daily notes folder** — where the file is written. Created if missing.
- **Filename suffix** — `2026-09-13<suffix>.md`.
- **Frontmatter type** — the `type:` value in new files.
- **Notes / Tasks heading** — rename the sections.
- **Note / Task prefix** — the bullet or checkbox each line gets.
- **Notify on capture** — toast confirming what was added.
- **Default mode** — used when invoked without `note`/`task`.

## Design

Self-contained. The modal is the shell's own `InputModal`, so it matches
every other dms prompt and follows your theme; the plugin contains no
styling of its own. Writes go through `FileView` with `atomicWrites`, so a
crash mid-write cannot leave a half-written note. A failed write raises an
error toast containing your text rather than losing it silently.

No external scripts, no network, no shell execution.

## Bar widget

Add **Obsidian Capture** in Settings → Bar → Widgets. The pill shows how
many tasks are still open today; clicking it opens today's note:

- Tick a task off by clicking its row.
- Add a note or task inline without opening the modal.

Edits re-read the file first and refuse to write if it changed underneath —
your editor can have the same file open safely.

## Requirements

dms ≥ 1.6.0. Permissions: `settings_read`, `settings_write`.
