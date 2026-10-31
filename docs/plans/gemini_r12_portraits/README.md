# R12 portraits.dialogue (nodes lockwood, lockwood_held, lockwood_cursed, lockwood_again, lockwood_menu, lockwood_plaque, druskenvald, _held, _cursed, _again, party, _held, _cursed, _again)

Gemini (gemini-4-argon-medium) through ai-bridge. The `crooked-moon` project refused the send (HTTP 400 on the message post), so the brief went to project `ai-bridge`, as lane a1-polish did. `brief.md` is the brief as sent; `reply_raw.json` is the raw reply, untouched.

- Asked: caption lines for the three portrait pictures, the plaque, the held/cursed/again lines, a class interject for each portrait.
- Edits to the draft (this was the roughest reply, most lines were recast):
  - `lockwood`: the household count was recast; "y'all" to "you"; the plaque is now two lines naming the Lockwoods then the Patrinis, and the
    "dent" became brass worn smooth.
  - `lockwood_cursed`: the draft ended "right behind your eyes"; it now says the cold settles there, listening.
  - `lockwood_again`, `druskenvald_again`, `party_again`: "boots", "y'all" and "weight for you now" were cut; each "again" line now stands alone.
  - `party`: the draft's "smelled of wet wool" was ungrammatical; "travelling" became American; the rogue's "I reckon" (Southern) became
    plain.
  - The draft's `look_away` node was not used: the gaze is an automatic roll, not a choice, so a way to dodge it would defeat it.
- Added by us: the `check Charisma DC 10` after each picture, the plaque menu on the Lockwood portrait, `set portrait_seen_*`,
  `set portrait_cursed += 1`.
- The 1d6 psychic damage of a failed gaze cannot be written in a dialogue (no damage statement); it is left to the prop (a trap).
- Dropped-g Narrator lines: 5 of 17.
