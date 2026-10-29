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
