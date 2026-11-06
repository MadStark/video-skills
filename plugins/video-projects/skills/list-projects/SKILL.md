---
name: list-projects
description: List Antoine's video projects in /Volumes/Recordings/Edits with size, clip count and whether each FCP library's backup/media paths are correct. Use when he asks what projects he has, how big they are, or which need fixing.
argument-hint: ""
allowed-tools: Bash
---

# List video projects

The helper script is `${CLAUDE_PLUGIN_ROOT}/scripts/vp.sh`. Always run it with `bash` (it may not be executable). If `${CLAUDE_PLUGIN_ROOT}` is not expanded, find it with `find ~/.claude/plugins -path "*video-projects/scripts/vp.sh" | head -1`.

Run `bash vp.sh status`. It may take a minute because it measures folder sizes. Show the table as-is, newest project first. If any row says `BAD`, suggest `/fix-library-paths`. Also mention the next project number, from `bash vp.sh next`.
