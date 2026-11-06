---
name: import-media
description: Batch import action-cam footage (default the DJI card at /Volumes/DJI/DCIM) into a video project. Moves MP4s into 02_MEDIA/01_CAMERAS/<first free letter>_GOPRO, deletes them from the card after a verified copy, and permanently deletes the LRF proxy files. Use when Antoine wants to offload or import a camera card.
argument-hint: "[project] [source dir] [label]"
allowed-tools: Bash, AskUserQuestion
---

# Import camera media into a project

Arguments: `$ARGUMENTS`. Interpret them loosely, in this order: **project** (number like `15`, part of the name like `chamonix`, or a full path), **source** (default `/Volumes/DJI/DCIM`), **label** (default `GOPRO`, e.g. `DRONE`, `IPHONE`).

The helper script is `${CLAUDE_PLUGIN_ROOT}/scripts/vp.sh`. Always run it with `bash` (it may not be executable). If `${CLAUDE_PLUGIN_ROOT}` is not expanded, find it with `find ~/.claude/plugins -path "*video-projects/scripts/vp.sh" | head -1`.

## Steps

1. **Project.** If none was given, run `bash vp.sh projects` and ask Antoine which one, offering the 3 most recent as options. If the source isn't mounted (`/Volumes/DJI/DCIM` missing), tell him to plug in the card and stop.
2. **Dry run first, always:**
   `bash vp.sh import --project "<p>" --source "<src>" --label <LABEL> --delete-lrf --dry-run`
   It shows the destination folder, for example "rename A_CAM -> A_GOPRO". The rule: take the first letter A, B, C and so on whose folder is still an empty `X_CAM` (or empty `X_<LABEL>`), and rename it. If no such folder exists, create the next letter. It also shows the MP4 count and size, the LRF count, and free space.
3. **Confirm.** Show Antoine the plan. Say clearly that the MP4s will be removed from the card after each copy is size-verified, and that the LRF files will be **permanently deleted** (no Trash). Ask for a yes. If he wants to keep LRFs, drop `--delete-lrf`. If he wants a specific folder, add `--into B_GOPRO`. If he wants extra safety, add `--checksum`, which compares SHA-256 hashes and is slower.
4. **Run** the same command without `--dry-run`. It can take a while for many GB, so use a long timeout or run it in the background and wait.
5. **Report** the final `DONE:` line. Exit code 2 means some files were skipped (name clash or mismatch) and are still on the card; list them. Remind him to import into FCP with "Leave files in place".

## Rules

- Never delete anything from the card yourself with `rm`; only the script deletes, and only after a verified copy.
- Don't run it while Final Cut Pro is open (the script checks).
