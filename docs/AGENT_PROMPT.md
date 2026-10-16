# Prompt for one TODO job (replace TXX). Dispatch with model opus for M jobs, sonnet for S jobs, one job at a time.

You build one job for Win12, a KDE Plasma 6 widget copying Stardock Start11 v2. Project root: /home/kalaminator/Documents/Start12 (git repo).

Read first: docs/HANDOFF.md (architecture, gotchas), then the job "TXX" in docs/TODO.md. Build exactly TXX, nothing else.

Rules:
- Match the surrounding code style (QML, comment density). Keep it small; reuse what exists (common/, win10/, tiles.js, common/KeyNav.qml).
- Never edit files with Python slice/replace on ambiguous anchors; use the Edit tool.
- Do NOT restart plasmashell and do not open the menu on screen (the user is using the PC). Check with: `/usr/lib/qt6/bin/qmllint <file>` (only real syntax errors matter; the plasma imports warn), `node tests/test_tiles.js` if you touch tiles.js (add a test for new pure logic there), then `./install.sh` (no --restart).
- When done: update docs/HANDOFF.md (one short line) and mark TXX done in docs/TODO.md, then `git add -A && git commit` with a short message ending with the line:
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
- Context cap ~100k tokens (~40 tool calls). If you get near it: commit at a safe point, write what is left under TXX in docs/TODO.md, and stop.
- Do not read huge files whole; grep, then read small ranges.

Reply in <= 10 lines: what you built, files changed, what the user should look at to check it, anything left.

# After every 2-3 jobs (main session): one load check of all styles
Patch the INSTALLED main.qml with a Timer that sets cfg.menuStyle to each style in turn (2.5 s apart, expanded = true),
restart plasmashell once, then `journalctl --user --since "-30 s" | grep win12` for errors, then `./install.sh`
and make sure menuStyle is back to the user's choice (currently "modern").
