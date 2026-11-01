# 0001: The story systems (ritual track, visits, Sin, the sacrifice, endings, comfort)

**Context.** Plan sections 5.5, 5.7 and 13 (G1, G4, G5, G9) call for the Crooked Queen's slow victory, the Crooked Man's
visits, Sin, the sacrifice ritual, ten endings and comfort settings. None were built (Plan Gaps, 2026-11-01).

**Decision.** Each is a pure library in `story/` reading its own data, and the campaign module answers the engine with it:

- **Ritual track** (`story/ritual_track.gd`, `data/ritual/track.json`): twelve seals, one per death the prophecy wants, each
  a condition on the flag its chapter sets. The seals broken are the engine's `attention`; five stages (sliver, grinning,
  wide, leering, full; the scowl once Kehlenn is bound) are its presence tiers: the night roads' extra chance, Adela's
  vision (`{tarokka.ritual.vision}`), the Crooked Man's chance, and the moon's grin and light for the look lane
  (`RitualTrack.grin`, `RitualTrack.light`).
- **Visits** (`story/crooked_moon_visits.gd`, `data/ritual/visits.json`): the Crooked Man on roads, at the village's edge
  and in dreams; Gorthos and the Horned King as second and third voices. Apparitions never fight: each is a Narrator line
  (`narrative/narrator/crooked_moon_visits.dialogue`) or a conversation. A road visit is told on arriving.
- **Sin** (`story/sin.gd`, `data/ritual/sin.json`): a hidden tally of bargains, the sinner's deals, the Horned King's offers
  and death bargains, slain innocents and betrayed Connections (int flags the story adds to). Its tier sets the
  temptations' press, Kehlenn's Ritual Points and epilogue lines (`tarokka.sin.tier`, `tarokka.sin.at_least.<tier>`).
- **Sacrifice** (`story/sacrifice_ritual.gd`, `data/ritual/sacrifice.json`): offerings at the goat skull, the d20 in the
  open, Kehlenn's points capped by difficulty, six refusals, Heroic Inspiration, the Last Act, lingering spirits, the
  ritual's +2. Our numbers (DC 11, bonuses 2 to 5, 13 base points) come from a simulation tuned to the plan's 41% / 53%.
- **Endings** (`data/endings/`, `narrative/endings/`): the six story endings and four Moonfall endings, read from the
  ritual's flags, the barrow's parley (`parley_answer`: `kneel_queen`, `kneel_goat`) and the Born King's fight.
- **Comfort** (`story/comfort.gd`, `data/comfort/comfort.json`): five topics, softened unless the playthrough option
  `show_<topic>` is on; scenes test `option:show_<topic>`; each region's content note.

**The finale chapters' flags** (R23 to R26, act4-finale-merge) are read under their own names: Adela's seal is
`wicker_man_burned` or `wicker_man_triumphant`; Phillip's is the Born King's fight or the barrow's kneeling (`kehlenn_sided`,
`ct_kneeled`, `horned_king_destroyed`); Sin counts `horned_bargains`; the ritual sets `kehlenn_bound`, `crooked_cause`,
`last_act_count`, `party_size`, `ritual_fails` and `ritual_points`; Moonfall's endings read `moonfall_offer`, `moonfall_fled`,
`moonfall_begun`, `moonfall_nights_left` and `old_fears_slain`. Until that branch lands, `data/flags/act4_bridge.json`
registers them; delete it when it does. Sin's `innocents_slain`, `connections_betrayed` and `sin_other` are ours.

**Engine hooks asked for** (through the hooks lane): the pause menu's Content rows from `CampaignModule.comfort_options()`,
the loading card's note from `content_note(region, st)`, a dialogue statement that calls the module (for the ritual's
offerings and Sin), the build's `given_up` features and Thread honoured by `refresh()`, and play that goes on after an
ending for Moonfall.

**Decided** by the story-systems lane, 2026-11-01, from the plan's defaults (13.3, 13.6, 13.9 to 13.12).
