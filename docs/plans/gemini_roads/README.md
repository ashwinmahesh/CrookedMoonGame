# Road meetings, road fight narration and the Crooked Man's appearances (fun pass, lane D)

Gemini (gemini-4-argon-medium) through ai-bridge, project `ai-bridge` (the `crooked-moon` project refuses sends, as for the
earlier lanes). One send per brief, no resends; the bridge takes at most 16,000 characters, so each brief went in two halves.
`preamble.txt` is prepended to each; `sent_*.txt` is what went out and `reply_*.json` the raw reply, untouched. The
`*_structure.dialogue` files are the fixed structure with `[[n]]` markers; `fill.py` fills them from the replies.

- `sent_act1a/b` → `narrative/roads/act1.dialogue` (the wreck road's and the hill road's meetings) and the Act I fight lines.
- `sent_act2a/b` → `narrative/roads/act2.dialogue` (the meetings of the Act II roads and the cemetery road) and the later fight
  lines.
- `sent_cma/b` → `narrative/roads/crooked_man.dialogue` (his three road appearances and two fireside visits).
- `fight_texts.json`: the fight lines as edited, keyed `table:entry`; `tools/content/road_tables.py` writes them into the tables.

Edits to the drafts:
- Every meeting node starts with a guard on its own flag (`if flag.X -> END`), as the Strahd road events did.
- act1: magpie fight line recast ("caws once like it don't care for the number"); `hill_road:weasels_led` is ours (no draft
  asked for it).
- act2: the miner's thank-you was stage direction in his own mouth ("He drains the whole flask"), recast as his words; the
  patient's goodbye was narration under his name, now a Narrator line; the pilgrim's first line cut from 37 words to 27;
  `bayou_road:husks` gained the mud things that come with them. `set road_pilgrim_turned` and `set road_miner_looked` were
  dropped (nothing reads them).
- crooked_man: as drafted.

New lines for the voice queue (none voiced yet): act1.dialogue 47 spoken lines, act2.dialogue 49, crooked_man.dialogue 51, and the
33 + 11 fight lines in the tables (Narrator). Speakers new to the cast use shared village voices: road_passenger and
road_patient voice_newcomer, road_bonfire_keeper, road_refugee, road_dice_ghost and road_miner voice_backwoods, road_pilgrim
and road_mourner voice_hollow; joan_murdoch and crooked_man have their own.
