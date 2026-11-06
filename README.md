# video-skills

Claude Code plugin marketplace with skills for Antoine's Final Cut Pro video projects
(`/Volumes/Recordings/Edits`, template `ZZZ - Template 2.0`).

| Skill | What it does |
|---|---|
| `/create-project [title]` | Duplicates the template into `<N> - <title>`, renames the library, re-points backups/media/cache to the new project |
| `/import-media [project] [source] [label]` | Moves MP4s from the card (default `/Volumes/DJI/DCIM`) to `02_MEDIA/01_CAMERAS/<X>_GOPRO`, size-verified, deletes from card, deletes LRFs |
| `/fix-library-paths [project\|all]` | Audits/repairs libraries whose backup/media/cache bookmarks point to another folder |
| `/list-projects` | Size, clip count and path health of every project |

The skills are namespaced as `/video-projects:<skill>`; the short form works when no other skill has the same name.

## Install

```sh
claude plugin marketplace add ~/Dev/video-skills
claude plugin install video-projects@antoine-video
```

After editing the repo: `claude plugin marketplace update antoine-video`.

## Why the bookmark rewrite

FCP stores a library's storage locations in `<lib>.fcpbundle/Settings.plist` as absolute macOS
bookmarks (`backupLocation`, `mediaLocation`, `cacheLocation`). Duplicating a project folder keeps
them pointing at the original. `scripts/bookmark.js` (JXA) reads and creates these bookmarks.
`scripts/vp.sh` rewrites any location under `Edits/<other folder>/…` to `Edits/<this project>/…`.

All the logic is in `scripts/vp.sh`; run it with no arguments for usage.
