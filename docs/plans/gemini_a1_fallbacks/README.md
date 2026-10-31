# Act 1 Narrator fallbacks (a1-polish)

- `brief.md`: one brief to Gemini (gemini-4-argon-medium, ai-bridge project `ai-bridge`; the `crooked-moon` project refused the send with
  "Could not uniquely identify newly created Antigravity project"). `reply_raw.json`: the raw reply, untouched.
- Asked: one plain (untagged) variant for each Narrator key that only has class- or name-tagged variants, so any party hears something.
- Edits made to the draft: `bd_headstones` lost "bleedin'" (read as a curse, not a drawl) and now says the stems are green; `g7_open_cage` lost the
  "lock snapped clean in two" (a prop detail the map does not have); `g5_gambler_letter` says "was blotted" for "'s been"; `g1_windows` "damp" for
  "condensation" (a modern word); `g8_pipes` "them" for "'em". The rest went in as drafted. Dropped g: 3 lines of 10.
- Not drafted: `examine:g6_druskenvald_trunks`. The prop starts a dialogue, and `_use_prop` returns to the dialogue before it looks for an
  `examine:` line, so that key (and `examine:grille_g1`) never plays; the dialogue opens with its own Narrator lines.
- Orphans: `examine:g1_grille` renamed `examine:grille_g1` (text unchanged, same voice key); `examine:wr_locomotive` removed (first person, "I built her",
  and no prop with that id exists).
