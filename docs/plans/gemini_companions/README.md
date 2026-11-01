# Companions lane: camp talks, approval talks, Thread beats and banter (phase 1)

Branch `claude/project-thread-3c8g6x`. The systems are on the branch already: `story/fateweaving.gd` (the Threads' beats and
rewards), `data/threads/*.json`, the beat quests `data/quests/{discovery,confrontation}_<thread>.json`, the beat flags in
`data/flags/companions.json`, the approval roster in `data/campaign.json` (`approval`, read by the engine once hook H1 lands).
`make validate` fails until the Discovery and Confrontation talks below exist (no playthrough reaches their quests yet).

Drafting follows CLAUDE.md: Gemini 4 Argon medium through ai-bridge, one send per brief, `brief_*.txt`, `sent_*.txt` and the
raw `reply_*.json` kept in this folder, the edits listed here under "Edits to the drafts". The voice sheet in every brief is the
companion's vault note (`Companions/<Name>.md`: how they talk, pet phrases, likes and dislikes, secret and dark secret, existing
lines), never the book. Reuse `../gemini_r12_incitements/preamble.txt`'s rules for line shape (Narrator: the Vagrant, second
person or third about the companion, present tense, one or two sentences, under ~32 words; companion lines under ~28 words; no
game words; plain punctuation; no invented people, places or history; nothing from the book).

## The six

| Companion | Thread | Discovery after | Confrontation after |
|---|---|---|---|
| rook_coldwake | pilgrimage | Fields of the Crow, `flag.raum_slain` | the Crooked Nightmare, `flag.nm_chapter_done` |
| tobin_hayward | rejuvenation | Skitterdeep, `flag.stonoga_slain` | Hartsblight, `flag.gorthos_slain` |
| silas_vane | liberation | the Drowned Crossroads, `flag.crossroads_done` | Fool's Day, `flag.chuckles_dead` |
| delphine_ravelle | ascendancy | the Crimson Monastery, `flag.renathyr_slain` | Fool's Day, `flag.chuckles_dead` |
| lucan_houndstooth | slaughter | Fields of the Crow, `flag.raum_slain` | Hartsblight, `flag.gorthos_slain` |
| cordelia_skein | evolution | Memory's Rest, `flag.lethica_slain` | the Crooked Nightmare, `flag.nm_chapter_done` |

What each beat found is fixed by its quest's journal line (`data/quests/discovery_<thread>.json` and `confrontation_*`, stage
`done`); the talk tells that, in the companion's own words, and goes no further than it.

## Files and nodes (the logic is ours, not drafted)

### `narrative/camp/<id>_thread.dialogue` (six files): the Thread's beats at camp

CampTalk offers each file's first `talk_` node whose opening `if` holds, once a playthrough, so put them in this order:

1. `talk_incitement` — the companion was benched when their Incitement's car or room played (`pending_<thread>_incitement` set,
   `incitement_<thread>` not). Opening: `if name:<id> and flag.pending_<thread>_incitement and not flag.incitement_<thread>`.
   The companion tells what they saw when they caught up (one short scene, two options). Ends `set incitement_<thread>` and the
   same `inspire name:<id>: ...` the Incitement scene uses. (R10's are liberation, evolution, ascendancy; R12's are pilgrimage,
   rejuvenation, slaughter.)
2. `talk_discovery` — opening `if name:<id> and flag.connection_<thread> and <discovery flag> and not flag.discovery_<thread>`.
   About six to ten lines and one menu of three options (one a quiet way on, none a check). Each option's node: an `approve
   <id> +2` (or +3 for the one most like them, -1 for one that brushes them off), then `set discovery_<thread>`,
   `quest discovery_<thread> done` (Fateweaving pays the Twist of Fate) and `quest confrontation_<thread> waiting`.
3. `talk_confrontation` — opening `if name:<id> and flag.discovery_<thread> and <confrontation flag> and not
   flag.confrontation_<thread>`. Same shape, the climax of their act-three story; approve sizes 4 to 6. Ends
   `set confrontation_<thread>` and `quest confrontation_<thread> done` (Fateweaving pays +2 to the Thread's ability).
   Strained or worse (`approval.<id> <= strained`) holds it back until mended, never for good:

   CampTalk marks a talk had when it starts. So the strained path is its own node `talk_confrontation_wait`, placed BEFORE
   `talk_confrontation`, opening `if name:<id> and flag.discovery_<thread> and <confrontation flag> and not
   flag.confrontation_<thread> and approval.<id> <= strained and not flag.<id>_confrontation_waited`; it ends with `set
   <id>_confrontation_waited` (register it in data/flags/companions.json) and an `approve <id> +6` on the mending option, and
   `talk_confrontation`'s opening adds `and (approval.<id> > strained or flag.<id>_confrontation_waited)`. Nothing is lost.

Climax and Catharsis come with R24 and R25 (act4-finale-merge isn't on main); leave them out of this phase.

### `narrative/camp/<id>.dialogue` (six files): approval and the acts

Order (CampTalk offers the first that holds):

1. `talk_strained` — `if name:<id> and approval.<id> <= strained`. Says what's wrong in their voice; three options: answer well
   (`approve <id> +8: You heard me out at the fire`), answer coldly (`approve <id> -3`), or say nothing (no change).
2. `talk_doubt` — `if name:<id> and approval.<id> == doubtful`. Same shape, +5 / -2.
3. `talk_act1` — `if name:<id> and flag.gl_crashed and not flag.vessla_slain`. After the wreck, the first night in Wickermoor.
4. `talk_act2` — `if name:<id> and flag.act2_done >= 2`. Halfway through Act II.
5. `talk_act3` — `if name:<id> and flag.act2_done >= 5`. Act III opens.
6. `talk_warm` — `if name:<id> and approval.<id> >= warm and level >= 3`. A secret (their small one, never the dark secret).
7. `talk_close` — `if name:<id> and approval.<id> >= close and level >= 5`. What they want.
8. `talk_devoted` — `if name:<id> and approval.<id> >= devoted and level >= 8`. What they'd give up for the party; ends `inspire
   name:<id>: ...` and `inspiration`.

Each act talk: six to ten lines, one menu of three options, each with a small approve (+1 to +3, or -1 to -2) whose reason reads
as the companion's memory ("You asked about the badge and let it go"). The dark secrets are the world lane's (Raum's gate, G7):
hint at most.

### `narrative/banter/party_act1.dialogue` .. `party_act3.dialogue`: party banter while exploring

Banter plays one node at a time on entering an area, once each; any file whose name starts `party` plays anywhere. Each node is
one exchange between two (sometimes three) companions, four to six lines, all `interject name:<id>:` lines, no options. Open
every node with the act's condition and both speakers: `if name:rook_coldwake and name:silas_vane and flag.gl_crashed and not
flag.vessla_slain` ... `endif` (so an exchange that can't be heard comes out empty and is skipped). Write the pairings from the
"With the others" sections of the vault notes; cover all fifteen pairs at least once across the three files, eight to ten
exchanges a file. Act gates: act 1 `flag.gl_crashed and not flag.act2_done`, act 2 `flag.vessla_slain and flag.act2_done < 5`,
act 3 `flag.act2_done >= 5`.

## Checks before the hand-off

- `make validate` green (the beat quests become reachable, every flag registered, approve sizes in range).
- `make test FILES=tests/unit/test_fateweaving.gd,tests/unit/test_companion_talks.gd` (the second: every camp file parses with no
  errors, every `talk_` node opens with an `if` naming `name:<its companion>`, and a party with each companion at Strained is
  offered `talk_strained` first).
- `python3 tools/content/act1_voice_keys.py --region camp --list` and `--region banter --list` list the new lines for the voice
  lane (add those two regions to the script if it can't read them yet).
