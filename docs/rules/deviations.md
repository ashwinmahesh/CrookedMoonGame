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
| Life Drain of the Corrupted Passengers (the Ghostlight Express; the Specter's block) | Their Life Drain deals its Necrotic damage only; it no longer lowers the target's Hit Point maximum (`corrupted_passenger`, which is otherwise the Specter) | Ashwin's call (2026-11-02) | — |
| Searching again (2024: a check can't be retried without a change) | A hero who missed a hidden find may search for it again after the party's next Short or Long Rest (`search_again_after_rest`) | A find all four heroes missed was lost for the rest of the run (the marble jar the Sweetheart's bottle needs, Act 1 QA 2026-11-01); a rest is the change | — |
| Fabled Heirlooms' spells (the book's heirlooms) | Spells an heirloom casts use its bearer's best spell save DC and attack bonus; only the heirlooms' own properties use 16 + the bonus | The engine's item spells read the wielder's numbers; at the levels these heirlooms are found the two are within a point or two | E13 |
| Honor of the Vanguard (Shield of Marius Renathyr) | A free power usable in round 1 (once a fight), not an automatic step as Initiative is rolled | The player controls every hero; a free action in the first round asks the same choice | — |
| Double Down (Cutlass of Briggsy Kratch) | The extra attack is granted when the bearer first attacks the wagered creature in a turn, and can go at anyone | The Attack action has no per-target attack count | E13 |
| Sea Legs (Cutlass of Briggsy Kratch) | Ignoring Difficult Terrain starts once the Disengage is taken and lasts the turn | The engine marks a Disengage on the turn, not on the move | — |
| Cycle's Balance (Staff of Farryn) | The burst hits the bearer's foes within 20 ft of the creature that failed the save | The book names the area, not who it hurts; friends are spared so the healer's staff doesn't hurt its party | — |
| Rotting Touch (Idol of the Beast of Blight) | The Unarmed Strike keeps its usual ability (no choice of Wisdom) | Unarmed Strikes have no per-item ability choice in the engine yet | E13 |
| Sense Grief, Fool's Motley, Vermincall (Veil, Marotte, Cauldron) | Once a dusk each | The book gives no number of uses; once a dusk matches the rest of the heirlooms | — |
| Jinxshot (Blunderbuss of the Grinning Sinner) | Half damage on a successful save | The book's line names only the save and the damage; half on a success is the usual rule for a Cone | — |
| Railings and parapets (floors and layers, rail_ft) | A line over a railing to someone on another floor gives at most Half Cover, like a low wall; a railing doesn't stop a shove over it | The 2024 rules leave railings to the DM; a creature shoved at the rail topples over it, so balconies and bridges stay dangerous | — |
| Flying and climbing between floors | A flyer or climber goes up through an opening onto the boards beside it, or down over an edge, for the height moved; a ghost (Incorporeal Movement) goes through the boards at double | The grid has no free 3D squares in the air; the move takes the rise or drop as the distance, which matches the 2024 grid distance rule | — |
| Areas across floors | A square on another floor is in an area when its middle is (a creature's middle over its floor) and the origin has a line of effect to it; a cone or line can be aimed down | On one floor the engine's exact square coverage stays; across floors the shape is three-dimensional | — |
