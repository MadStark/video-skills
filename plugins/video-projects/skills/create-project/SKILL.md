---
name: create-project
description: Create a new Final Cut Pro video project in /Volumes/Recordings/Edits by duplicating "ZZZ - Template 2.0", renaming the folder and library, and re-pointing the library's backup/media/cache locations to the new project. Use when Antoine wants to start a new video project.
argument-hint: "[project title]"
allowed-tools: Bash, AskUserQuestion
---

# Create a video project

Arguments: `$ARGUMENTS` (the project title, e.g. `Ski Chamonix Jan 2027`).

The helper script is `${CLAUDE_PLUGIN_ROOT}/scripts/vp.sh`. Always run it with `bash` (it may not be executable). If `${CLAUDE_PLUGIN_ROOT}` is not expanded, find it with `find ~/.claude/plugins -path "*video-projects/scripts/vp.sh" | head -1`.

## Steps

1. **Title.** If no title was given, ask Antoine for one. Mention the next number with `bash vp.sh next`, so he sees e.g. "it will be **16 - <title>**". The title can't contain `/` or `:`. Don't include the number in the title; the script adds it. If he gives one like `16 - Foo`, strip the number and pass it as the second argument.
2. **Final Cut must be closed.** The script refuses to run while Final Cut Pro is open, because the template library would be locked. If it says so, ask Antoine to quit FCP, then retry. Never set `VP_FORCE` unless he explicitly insists.
3. Run: `bash vp.sh create "<title>"` (optionally followed by a number).
   The script:
   - copies `ZZZ - Template 2.0` to `<N> - <title>` with `ditto`, drops the FCP lock files and any backups
   - renames `01_LIBRARY/Template.fcpbundle` to `01_LIBRARY/<title>.fcpbundle`
   - rewrites `backupLocation`, `mediaLocation` and `cacheLocation` in the library's `Settings.plist`. They are absolute macOS bookmarks, so a plain copy keeps pointing at the template. Anything under the template is re-pointed to the same sub-path in the new project.
   - re-checks the locations and prints `PROJECT=` / `LIBRARY=`.
4. Report the new folder and that backups now go to `<project>/99_BACKUPS`. Offer to open the library: `open "<LIBRARY path>"`. Then suggest `/import-media` if a card is plugged in.

## If something fails

- An `osascript`/bookmark error means the paths were not rewritten. Tell Antoine and give him the manual fallback: in FCP select the library, open Library Properties, choose Modify Settings for Storage Locations, and set Backups to `<project>/99_BACKUPS`.
- Never delete the template or an existing project folder to "retry". If the destination exists, ask for a different title.
