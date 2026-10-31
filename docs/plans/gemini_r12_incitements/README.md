# R12 Incitements (lane r12-dialogue-d)

File written: `narrative/crooked_house/incitements.dialogue` (40 nodes: 3 companion Incitements, 5 custom-hero stubs).

- Project: `crooked-moon` refused the send (HTTP 400, see the Narrator README), so briefs went to project `ai-bridge`; model gemini-4-argon-medium; one send per brief, no resends.
- `brief_e1_rook`, `brief_e2_tobin`, `brief_e3_lucan` (one scene each, with `preamble.txt`), `brief_f_stubs` (the five custom-hero scenes, with `stub_header.txt`); `sent_*.txt` is what went out;
  `reply_*.json` is the raw reply. The scene facts, the three options (under 12 words, one a quiet way on) and the signature lines are Lane F's (Companions/Rook Coldwake.md, Tobin Hayward.md, Lucan Houndstooth.md).
  The signature line is the first interject of each start node, verbatim, as the briefs asked.

## Logic (mine, not drafted)

- `<thread>_enter` is the call node: `if flag.incitement_<thread>` ends; with the companion in the party the scene plays; without them it sets `pending_<thread>_incitement`
  (guarded by `if not flag.pending_...` so the flag has a reader) and plays nothing. Unlike R10's cars it does NOT end on `pending`, so the home scene still plays in full when the
  companion is later in the party (Lane F: the room stays armed). Lane F's camp echo has to set `incitement_<thread>` too, which stops the home scene.
- The five stubs are the custom hero's own `Player:` lines, first person, no Narrator lines; each plays from the prop's `call` when the hero has the background
  (`reflected_wanderer`, `crimson_aspirant`, `druskenvald_dweller`, `scholar_of_the_forbidden`, `cultist`) and the flag is not set; everyone else gets `narrate examine:<prop>`, so the
  prop is never silent: h5_mirror, h17_cauldron (Immortality has no prop of its own in the contract), h12_scratchings, h14_tome, h4_bust.
- The companion variants for the custom hero's own matching backgrounds (rest_warden, wicker_weaver, night_stalker) were not asked for and are not written.

## Edits to the drafts

Rook
- start: "mouthin'" kept as drafted; the second interject kept. opt1: "thefirst" -> "the first"; interject "I have logged ... we will see" -> "I've logged ... we'll see". opt2: "stoppin'" kept. opt3: "pulls his frost-bitten fingers from the shelf" -> "steps back from the shelf" (he had not reached for it).
Tobin
- start N1: the vision is not in the Narrator line (only the signature interject says it); "He jerks his hand back fast" -> "He jerks it back as if the sap had scalded him". N2: "scorchin' ... sendin' his lapel mice squeakin' into his pockets" -> the mice squeak and dive; interject 2 ("Split's clean through the cambium, four inches wide ... It needs a sharp blade") -> "Cracked clean through the heartwood, and weeping. The rot in this is old, and it runs a long way from here." (no invented measurement, and it feeds the splint).
- opt1 interject: contractions restored ("doesn't"). opt2 interject: "Good soil, bad seed" is a once-an-act moral-judgement phrase, so it was cut; now "I've known a bad fire in my time, and it doesn't bear dwelling on" (Lane F: admits the fire without telling it). opt3: "Aye" -> "Right" (Tobin's drawl is country, not Northern).
Lucan
- start N1: "marble-eyed" -> "glass-eyed". N2: "He points at a high stuffed crow" had no clear subject -> "It points its nose at a stuffed black crow high on a shelf"; "the fur mount" -> "the mount". Interject 2 kept ("H-hush now, Barnaby ...").
- opt1 interject: "no respectable marsh bird" -> "no respectable bird". opt2 N: "his stolen coat collar" -> "his long collar" (Lucan's secret is never stated, and "stolen" said it); "gloved thumb" kept.
Stubs (the drafts were first person and good; edits are for facts and length)
- Duality: "behind the faded rose wallpaper" cut from line 2; "the teal wall" -> "the wall"; INSPIRE rows lose their capital and full stop ("spoke to the grinning double" ...).
- Immortality: "cross the attic" -> "cross"; "the old alchemist here almost finished the work" -> "the work here was almost finished once" (no invented alchemist); "round attic window" -> "round window".
- Kindred: "a cramped hand I know by heart" -> "a hand I almost know" (the draft assumed whose hand); "bruised purple paper" -> "the wallpaper" (purple is the upholstery); "my relative left" -> "left in this wall"; the cover-up line's "familiar handwriting" -> "that scratched hand"; "the pale floor-marks" -> "the floor-marks" in Immortality.
- Malediction: "torn wings" -> "wings"; "sepia pages" kept; "Even the mildew green stain" -> "the mildew stain".
- Rapture: "One prophet already vanished into the dirt of this hollow" -> "came to this hollow before me" and "what ate the first flock" -> "what became of the first flock" (no invented fate); "Behind the faded rose wall" -> "Behind the wall".
- Lines over about 35 words (the stub openers) were left long on purpose (they play once, as the hero's own thought); all are under the 60-word lint limit.
