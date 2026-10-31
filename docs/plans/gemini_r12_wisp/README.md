# R12 wisp.dialogue (narrative/crooked_house/wisp.dialogue)

- `brief.md`: the brief sent to Gemini (gemini-4-argon-medium) through ai-bridge project `ai-bridge`; the `crooked-moon` project refused the send (HTTP 400), as it did for lane a1-polish. `reply_raw.json`: the raw reply, untouched.
- Asked: lines only (Narrator, the character, interjects), node by node with exact counts; the menus, checks, flags and statements were added afterwards by the lane (r12-dialogue-c) from the R12 contract.
- Edits made to the draft: start Narrator "followin' you" for "y'all"; insight_ok "Behind those golden eyes" for "Behind them"; insight_miss lost "I reckon"; perf_1_ok "across them" for "'em";
  finale: Wisp's first line lost "and my lady will be pleased beyond measure" (the brief kept his plan hidden until the riddle) and the Narrator rest line says "over you" for "over y'all";
  threat: "heavy-handed" lower case. Everything else as drafted. Dropped: none.
- Added by the lane: all option texts and tale subjects, the checks and DCs, the quest, flag and combat lines and the Hit Dice boon (`hit_dice restore all party`; it was a `time +60` stand-in until r12-statements, and the book's +4 per die has no statement); no flag beyond the contract is needed (the tale slot is wisp_tales).
