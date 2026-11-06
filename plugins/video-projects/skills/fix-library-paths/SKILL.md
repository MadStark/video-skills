---
name: fix-library-paths
description: Check or repair Final Cut Pro libraries in /Volumes/Recordings/Edits whose backup, media or cache locations point to the template or another project instead of their own folder. Use when backups land in the wrong place, after copying a project, or for an audit.
argument-hint: "[project | all] [--check]"
allowed-tools: Bash, AskUserQuestion
---

# Fix FCP library storage locations

Arguments: `$ARGUMENTS`. Pass a project (number, partial name or path) or `all`. If nothing was given, default to `all`.

The helper script is `${CLAUDE_PLUGIN_ROOT}/scripts/vp.sh`. Always run it with `bash` (it may not be executable). If `${CLAUDE_PLUGIN_ROOT}` is not expanded, find it with `find ~/.claude/plugins -path "*video-projects/scripts/vp.sh" | head -1`.

## Steps

1. **Check first:** `bash vp.sh relink <target> --check`. Each library's `backupLocation`, `mediaLocation` and `cacheLocation` is listed as `ok`, `BAD` (it points into another folder under Edits) or default.
2. Summarise the BAD ones for Antoine and ask before fixing. Point out that **media** locations only affect *future* imports and generated media. Clips already in the library keep their own paths; this does not move footage. Old backups found in the wrong backup folder (matched by library name) are moved into the project's `99_BACKUPS`.
3. Ask him to quit Final Cut Pro, then run `bash vp.sh relink <target>`, and finally the `--check` again to confirm.
4. If a project's `01_LIBRARY` holds a stray `Template.fcpbundle` next to the real library, mention it but don't delete it.
