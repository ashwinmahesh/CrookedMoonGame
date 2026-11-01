# Rule deviations

Every place this game departs from the 2024 rules, with the reason. A rule that simply isn't built yet is "not started" in
coverage.md, not a deviation. **The engine's own departures** (grid rulings, high ground, falls, slopes and the rest) are in
`addons/dnd_core/docs/reference/rules/deviations.md` and hold here as well; this file lists only what the Crooked Moon adds or
changes. Write a ruling here the day it is made.

Revisit names what will close a row: an item in the plan's Engine and Systems Work note (E1, G2 ...) with its lane, or "—".
A row that waits on a plan phase fails `make validate` once that phase is built (tools/data/check_rules_docs.py).

| Rule | What the game does | Why | Revisit |
|---|---|---|---|
| Character level 14 and up (2024 PHB) | The campaign is capped at level 13. The ritual gives +2 to an ability score (to a maximum of 24) instead of a level; level 14 comes only from the Horned King's offer or in Moonfall, which plays to 20 | The book's own cap and its Moonfall variant (plan section 4); features at 14 and above are built only with Moonfall | E1 |
| Darkvision under the Creeping Dark | The book's optional Creeping Dark rule, which suppresses heroes' darkvision, is a setting and is off by default | It is the book's optional rule; on by default it would blind every darkvision hero in a land of eternal night (plan fork F7) | E2 |
| The Ghostlight Locomotive's movement (the book's stat block) | It ignores Difficult Terrain (its Spectral Rails trait, `ignore_difficult_terrain`) | Its 4 x 4 body in the wreck's roots, soul-mist and banks covered about 5 squares a turn and never reached a Soul Can, the fight's whole idea (Ashwin, 2026-10-31) | — |
| Circle of the Old Ways: Awaken (Druid 9) | Summon Plant instead | Awaken left the game with the removed PHB spells; a plant that rises to fight beside the druid is the nearest playable 5th-level answer to waking the old growth (Ashwin, 2026-11-01, option B3) | — |
| Circle of the Old Ways: Tree Stride (Druid 9) | Commune with Nature instead | Tree Stride left the game; the old ways still talk with the land itself, at the same level (Ashwin, 2026-11-01, B3) | — |
| Harvest Domain, Sowing: Awaken (Cleric 9) | Summon Plant instead | Awaken left the game; what was sown comes up and answers the cleric (Ashwin, 2026-11-01, B3) | — |
| College of Whistles, Homeward Bound: Teleportation Circle (Bard 9) | Far Step instead; the marks and the trip home to a marked place are gone, and the phantom train carries only the bard | Teleportation Circle left the game and no playable spell sends a party home; Far Step keeps the train's vanishing ride at the same level (Ashwin, 2026-11-01, B3) | — |
| Great Fool patron: Rope Trick (Warlock 3) | Mirror Image instead | Rope Trick left the game; a fool's trick of the same level that works in a fight (Ashwin, 2026-11-01, B3) | — |
| Grim Harbinger: Dream (Ranger 17) | Synaptic Static instead | Dream left the game; the harbinger's dread still breaks minds, now in the moment rather than in sleep (Ashwin, 2026-11-01, B3) | — |
| Philosopher, Citrinitas: Creation (Wizard 10) | Wall of Stone instead; Quintessence no longer stretches a duration | Creation left the game; making stone rise out of nothing keeps the feature's idea of making, not purifying (Ashwin, 2026-11-01, B3) | — |
| Philosopher, Citrinitas: Fabricate (Wizard 10) | Stone Shape instead | Fabricate left the game; reshaping raw matter at the same level (Ashwin, 2026-11-01, B3) | — |
| Warrior of the Pestilent Haze, Vermin Kinship: Animal Messenger (Monk 3) | Beast Sense instead, on a plague-carrying Tiny beast, once per Long Rest with Wisdom | Animal Messenger left the game; seeing through the vermin keeps the kinship at the same level (Ashwin, 2026-11-01, B3) | — |
