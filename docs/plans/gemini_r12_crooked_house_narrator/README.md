# R12 Narrator lines for the Crooked House (lane r12-dialogue-d)

File written: `narrative/narrator/crooked_house.dialogue` (102 keys, 129 variants: 121 plain, 5 class/name extras, 3 flag-tagged extras).

- Project: the `crooked-moon` bridge project refused the send (HTTP 400), so every brief went to project `ai-bridge` (as lane a1-polish did).
  Model gemini-4-argon-medium, one send per brief, no resends. `preamble.txt` is prepended to each `brief_*.txt`; `sent_*.txt` is what went out;
  `reply_*.json` is the raw reply, untouched.
- `brief_a_enter` (25 enter keys), `brief_b1_examine` (20 examine keys), `brief_b2_examine` (18), `brief_c_finds` (finds, tooth misses, traps, oven),
  `brief_d_defeat` (14 retry keys). The facts in each brief come from the R12 package, the chapter 12 digest and the Narrator voice bible.
- `reply_c_finds.json` came back garbled (the model wrote a half answer, then commentary, then the whole answer again as a second JSON object).
  `reply_c_finds.extracted.txt` is the final, complete JSON object's text, cut out unchanged; that is what the edits below start from.

## Edits to the drafts (everything else went in as drafted)

Dropped g: the drafts dropped it in about 40 percent of the lines in some batches and almost none in others; the file now has 36 of 129 variants
(28 percent): "tickin'", "scratchin'" and the like were kept, and about 20 more were added (-ing words in the defeat, examine and enter lines).
- enter:druskenvald_estate: the "turned" extra now reads `[flag.crooked_house_turned and not flag.vessla_slain]` so the post-boss line wins after the boss; "buildin'" restored.
- enter:crooked_house_first: "scraping" -> "scrapin'". enter:crooked_house_third: "thin ... thin" -> "the air runs cold"; "wailin'".
- enter:h3_parlor: "cobweb grey" -> "a skin of grey cobweb" (it read as a colour name). enter:h7_kitchen: "pounds and screams" -> "pounds, muffled, like a scream through a wall".
- enter:h14_library: the draft's stray capital ("desk Stack") fixed and the cat set on the stack. enter:h15_trophy_room: "dozens of" -> "a crowd of" (no invented number), a stray capital fixed.
- enter:h17_cauldron_room: "sit two bound figures, one slumped low and one cloaked" -> "wait two figures, one slumped in his bonds and one cloaked" (does not say the cloaked one is bound).
- examine:h2_chandelier: "cobweb grey" -> "grey cobweb". examine:h12_bed: "a heavy, restless heave" -> "restless and heavy".
- examine:h14_tome: "waiting for a hand that never came back" cut to "blank and waiting" (it told a history nobody has earned).
- examine:h17_phillip: "Heat comes off his skin in shallow, ragged breaths" -> breath and fever as two plain facts. examine:h17_adela: "not a breath" -> "not a word" (no claim she does not breathe).
- examine:h17_cauldron: "eatin' pits into the floorboards" -> "eating pits into the floor" (the floor is teeth).
- search/check lines: "bicuspid", "incisor", "molar", "canine" -> plain "tooth" in most (the clinical words broke the register); "carved animals" -> "loose toys";
  "Scar" capital fixed; "chalk-white tooth wedged in a floor crack" kept. trap:h7_oven_trap:found: the glyph "pushin' the greasy smoke aside" -> "the greasy smoke bends away".
- defeat:*: the drafts were wordy and some lines made little sense ("my tongue slipped in the dust", "the sepia dark", "weasels scratchin' behind the faded rose and teal paper
  heard a different turn"). Each key was rewritten in the draft's own images (stone bird, tune, table, clock, red water, toys, cat, roar), shorter, with where the party
  comes back worked in (front door for the first floor, the top of the stair for the second and third floors, the top of the ladder for the attic). The Vagrant's "Hold on,
  friends" and "Wait now" openings are the draft's. Nothing says retry, restart or game.
- Dropped g added to the defeat lines ("tellin'", "standin'").

## Assumptions the wiring worker has to match (ids the package leaves open)

- Area ids: `h1_porch`, `h2_foyer`, `h3_parlor`, `h4_gallery`, `h5_music_room`, `h5_floor` (contract), `h6_dining_room`, `h7_kitchen`, `h8_conservatory`, `h9_sitting_room`,
  `h10_childrens_room`, `h11_bathroom`, `h12_master_bedroom`, `balcony_edge` (contract), `h13_nursery`, `h14_library`, `h15_trophy_room`, `h16_landing`, `h17_cauldron_room`,
  `h17_cauldron_area` (contract: the area that starts `ch_vessla`; the readiness note says `h17_cauldron`). If the maps worker names them otherwise, rename the key: a voice clip is keyed by the line's text, not the key.
- Hidden-find props: `h6_table_loot`, `h10_closet`, `h10_bed_left`, `h10_bed_right`, `h10_chest`, `h10_armoire`, `h10_window` (perception), `the_bag` (investigation), `h15_trapdoor` (perception).
  `search:` is the one line that plays at the find; `check:<skill>:<prop>:failure` plays when the search finds nothing and the prop's `checks` entry hands over a `human_tooth`
  (Crooked Teeth is per prop, readiness item 11), so every miss line ends with a tooth in the hand.
- Traps: `h1_porch_edge` (the No Escape bounce), `balcony_edge` (assumed trap id), `h7_oven_trap`. Container `h7_oven_contents` opens with `open:`.
- Fights: `defeat:crooked_house` is the fallback; `defeat:ch_*` for the 13 house fights. The retry puts the party at the floor's entry spawn (`data/fight_retries.json` on r12-systems),
  so the lines say front door / top of the stair / top of the ladder; if the spawns change, the lines need a look before voicing.

## Contract gaps (not in this file)

- No prop id for Immortality at H17 (the incitements file calls `immortality_enter` and falls back to `examine:h17_cauldron`; a flask prop id is wanted), none for Vessla's ruse search,
  none for the yellow duck figurine's container, none for the H10 mismatch scrape, none for the estate's props (gate, pond, barns, tree).
- The porch exit's `locked_text` (the storm) is data in the maps worker's file; no Narrator key covers it. Suggested wording for them:
  "Thunder walks the roof, and the rain beyond the rail falls like a shut door." and for the balcony: "The wind takes the doors out of your hand and shuts them again."
- No `rest:*` lines for the house (Short Rests are allowed there; the long rest refusal is data text).
