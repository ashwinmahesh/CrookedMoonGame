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

## Drafting record

How it was sent. Project `ai-bridge`, model `gemini-4-argon-medium` (Gemini 4 Argon, medium; the bridge reports no model id, so `reported_model` is empty
and the effort is left unset), one send per brief, none failed, none resent: 6 thread briefs, 6 approval-and-acts briefs, 6 secrets briefs and 3 banter briefs.
`send_brief.py` is the client (the same as `~/.crooked-moon/bridge.py`, plus context files). The bridge takes at most 16000 characters in a message body, so each
companion's voice sheet and character file travel as two attached documents (the bridge's context files, 32000 characters each; copies here as
`context_<id>-voice-and-beats.txt` and `context_<id>-camp-talks.txt`; banter's two cast sheets are `context_banter-cast-1.txt` and `-2.txt`). The voice sheet
is the companion's vault note (`Companions/<Name>.md`) with the voice block from the earlier briefs (Silas's updated to Relicborn), never the book. Banter gets
secret-free fact lists instead of whole notes, because the notes state the dark secrets and banter must not.

| Brief | What it asked | Files |
|---|---|---|
| `thread_<id>` | the Incitement echo, the Discovery, the held-back and the played Confrontation | `brief_`, `sent_`, `reply_*.json`, `send_*.log`, `edits_` |
| `acts_<id>` | strained, doubt, act 1, act 2, act 3 | same |
| `secrets_<id>` | warm, close, devoted | same |
| `banter_act1` .. `act3` | nine exchanges each, five of the act's own pairs and four extras (all fifteen pairs covered) | same |

What the briefs fixed (ours) and Gemini wrote (the words): each talk's opening count, its three options' roles, and the facts allowed; Gemini wrote the Narrator and
companion rows, the party's option text and the REASON rows. The Discovery and the Confrontation tell only what the quest's journal line says
(`data/quests/discovery_*.json`, `confrontation_*.json`); the briefs said the vault note describes an older plan for the same beats and the journal line wins.

## What the converter adds (`tools/content/companion_talks.py`)

- `<id>_thread.dialogue`: `talk_incitement` (opening `pending_<thread>_incitement` and not `incitement_<thread>`; sets what the scene sets, `incitement_<thread>`,
  the quest `connection_<thread> waiting` for the three train Incitements, `<name>_inc_choice`, and the same `inspire` as the scene), `talk_discovery`
  (`connection_<thread>` and the chapter flag; `set discovery_<thread>`, `quest discovery_<thread> done`, `quest confrontation_<thread> waiting`),
  `talk_confrontation_wait` (Strained, once: sets `<id>_confrontation_waited`, registered in `data/flags/companions.json`) before `talk_confrontation`
  (which also opens once the word has been had; `set confrontation_<thread>`, `quest confrontation_<thread> done`). Approval sizes: Discovery +2 / +3 / -1,
  Confrontation +4 / +6 / -2, the mending word +6 / -2 / none.
- `<id>.dialogue`: `talk_strained`, `talk_doubt`, `talk_act1`, `talk_act2`, `talk_act3`, `talk_warm`, `talk_close`, `talk_devoted` with the conditions the brief above fixes.
  Sizes: strained +8 / -3 / none, doubt +5 / -2 / none, the acts and Warm +2 / +3 / -1, Close +3 / +2 / -1, Devoted +3 / +3 / +2 with `inspire` and `inspiration`.
- `party_act1.dialogue` .. `party_act3.dialogue`: one node per exchange, opened by the act's gate and every speaker's `name:` so an exchange nobody present can speak comes out empty.
- The `approve` lines do nothing yet: the engine's `Approval.COMPANIONS` is still Curse of Strahd's six, so `Approval.witnesses` finds none of ours until hook H1 reads
  `data/campaign.json`'s `approval`. The tests set `StoryState.approval` directly. The vault notes' three older camp talks per companion (the ledger, the knocker, the
  Deep Thaw and their kin, in the notes' "Camp talks" sections) are not in these files: the README's list did not ask for them.

For the voice lane: `python3 tools/content/act1_voice_keys.py --region camp --list` and `--region banter --list` (the script reads both regions now and lists every line
with no job when the jobs file isn't there).

## Edits to the drafts

Every row below is a find-and-replace applied to Gemini's raw reply (`edits_<brief>.json`, applied by `tools/content/companion_talks.py` before the
reply is read), so `reply_*.json` stays exactly what the bridge returned. Besides these, the converter changes only mechanics: straight quotes,
a speaker's row becomes `interject name:<id>:` or `Narrator:`, a line over about 28 words (34 for the Narrator) is split at a sentence end, a REASON or
INSPIRE loses its closing full stop, a companion's vocative pet words (friend, darling) are cut to the first in anything a single play of a talk says
(and in banter to one an exchange for each speaker, none in two consecutive lines: the cloud thread's note on group 1, 2026-11-01; pet phrases that came twice
were fixed by hand below), and the logic (conditions, flags, quests, approval sizes) is ours. The Thread files were then trimmed the same way
by the cloud thread in 9cd7911, so they are no longer exactly what the converter makes from these replies.

**thread_cordelia_skein** (2 edits)
- "her lower hands spreads-out, dryin'" -> "her lower hands spread out, dryin'": Typo.
- "before thehumours cool." -> "before the humours cool.": Typo.

**thread_delphine_ravelle** (1 edits)
- "the ink is stayin' locked in my lining tonight." -> "the ink is staying locked in my lining tonight.": Dropped g's belong to the Narrator only.

**thread_lucan_houndstooth** (2 edits)
- "and the hound begged for a crumb of cheddar on the bear's plinth before I called him off." -> "and the hound begged for a crumb of cheddar before I called him off.": No bear mount in the canon (the Trophy Room scene has a Pomeranian and a crow).
- "It is not the first time I have stood over a kill that was not mine and let the dark dress me larger than I am." -> "It is not the first time I have stood over a kill and felt the dark offer to dress me larger than I am.": The dark secret (claiming a kill) is Raum's gate's to tell: a hint only.

**thread_rook_coldwake** (15 edits)
- "Mori Shade knew my name before I gave it at her parlour door, and she knew what an honest ledger requires." -> "Mori Shade knew my name before I gave it at her door, and she knew what an honest ledger requires.": Her shop is a funeral home, not a parlour.
- "Rook turns back toward the dark beyond the wagons, standing quiet at parade rest." -> "Rook turns back toward the dark beyond the firelight, standing quiet at parade rest.": No wagons in the canon.
- "OPTION 3: Say nothing and give him room by the fire." -> "OPTION 3: Say nothing. Stay by the fire.": Option text is the party's words or action, not a stage direction about him.
- "I'll keep my post and my halberd in line, never fret." -> "I'll keep my post and my shield in line, never fret.": No halberd in the canon (a joke in the note only).
- "his hands settlin' square on the rim of his shield" -> "his hands settling square on the rim of his shield": Fewer dropped g's (one Narrator row in four).
- "sets it neatly beside his halberd." -> "sets it neatly beside his shield.": No halberd in the canon.
- "the noise sounded dead ringer for a glacial trench caving in." -> "it sounded for all the world like a trench caving in.": Plainer.
- "Thought for a long count it was the man I left under the ice up in Syndramas, come to audit the badge on my coat." -> "Thought for a long count it was something I left behind a long way north, come to audit the badge on my coat.": The dark secret (the man left under the ice) is Raum's gate's to tell: a hint only.
- "Wasn't his voice at all, when I stood my ground and listened past the draught in the flues." -> "Wasn't anybody else's at all, when I stood my ground and listened past the draught in the flues.": Follows the previous edit.
- "It was my own voice from the ditch, calling for a shovel I never went back to fetch while another man held the timber." -> "It was my own voice from a ditch up north, calling for a shovel.": Cut the deed (the dark secret).
- "OPTION 1: Tell me about the man who held the timber." -> "OPTION 1: Tell me what you heard in there.": The option presupposed the dark secret.
- "He was a stonemason's lad with a clean chisel hand, and he kept his post to the end. There are two pages left to fill before his whole file is squared." -> "A voice from a ditch a long way north, and a debt I won't name tonight. Two pages left to fill before the file is squared.": The man behind the dark secret is not named or described.
- "REASON: You asked to hear about the man I left under the ice." -> "REASON: You asked what I heard in there.": Follows the option edit.
- "the brass knocker on his shield restin' quiet against his knee." -> "the brass knocker on his shield resting quiet against his knee.": Fewer dropped g's.
- "where a red ink blot shows through the lining." -> "where the calfskin has gone soft with damp.": The red-ink chit in the lining is the dark secret's proof, which Raum's gate shows.

**thread_silas_vane** (3 edits)
- "friend, when I let the mark fall where it did not belong." -> "friend.": The dark secret (the marked card and his brother) is Raum's gate's to tell.
- "same way I did the night my tab began." -> "same as I always have.": Same: no hint of the night the tab began.
- "bad bargains and tall hats" -> "bad bargains": 'Tall hats' is nothing in the canon.

**thread_tobin_hayward** (9 edits)
- "SAY: Aye, the binding is tight enough to see the bough through till morning." -> "SAY: Right, the binding is tight enough to see the bough through till morning.": Tobin's drawl is West Country, not Northern: 'Aye' became 'Right' (as in the R12 Incitement).
- "A season where the blight moved faster than the pruning hook, and a man made a foul ledger of his neighbours' trees." -> "A season where the blight moved faster than the pruning hook, and a man made choices he doesn't care to count.": The neighbours are the dark secret's: Raum's gate tells it.
- "Tobin stands by the baggage cart with his arms crossed" -> "Tobin stands at the edge of the firelight with his arms crossed": No cart in the canon.
- "In my mortal seasons, when a black canker took the rows, I chose the torch over the pruning knife, and I woke in this valley made of dry straw." -> "In my mortal seasons, when a black canker took the rows, something burned that I'll not describe, and I woke in this valley made of dry straw.": The dark secret (the fire he set) stays unsaid; the journal's 'fire he never talks about' is the most the talk says.
- "terrified my own hands would turn a curable blight into an ash-heap twice." -> "terrified a curable blight would turn into an ash-heap twice.": Same: no hint of whose hand.
- "Do you reckon one clean row pays a speck toward an acre a man ruined with his own hand?" -> "Do you reckon one clean row pays a speck toward an acre lost?": Same.
- "NARRATOR: The Vagrant sets his tin cup down without a sound while Tobin steadies his breathing and lets his hand drop from his chest." -> "NARRATOR: Tobin steadies his breathing and lets his hand drop from his chest.": The Narrator never appears in his own tale.
- "SAY: Aye, a surgeon does not un-scar the bark" -> "SAY: Right, a surgeon does not un-scar the bark": As above.
- "OPTION 2: If the root can be cut, we bring a sharp blade and clear the row." -> "OPTION 2: If the root can be cut, we'll bring a blade.": Option text kept under 12 words.

**acts_cordelia_skein** (4 edits)
- "SAY: When presented with rare anomalies, you reach for a heavy blunt instrument or offer me that dreadful, moist-eyed pity." -> "SAY: When presented with rare anomalies, I fear we reach too quickly for a blunt instrument, or for pity, before we have understood.": The talk may not claim deeds the party did.
- "SAY: We are wasting priceless specimens on superstition and panic, and I did not leave the dark of Nerukhet to watch ignorance triumph." -> "SAY: A good deal of priceless data is being lost to superstition and panic, and I did not leave the dark of Nerukhet to watch ignorance triumph.": Same.
- "with a clean, sharp click of her claw." -> "with a clean, sharp click of her fingernail.": No claws in the canon.
- "having three stubborn anomalies at my shoulder" -> "having stubborn anomalies at my shoulder": The party's size is not hers to count.

**acts_delphine_ravelle** (2 edits)
- "SAY: You lecture the broken, you flinch when the spotlight gets hot, and you walk past every decent riddle with your boots loud on the boards." -> "SAY: Somewhere along the road this company stopped listening for the cues that matter to me, and took to walking the boards with its boots loud.": The talk may not claim deeds the party did.
- "though I did lose two perfectly good brass pins in the ditch." -> "though I did lose two perfectly good brass pins in the wreck.": How the Express crashed is not told (no ditch).

**acts_lucan_houndstooth** (8 edits)
- "SAY: We trample the brush with clattering haste, we bully tethered beasts that cannot flee, and we yield the field when a true predator shows its teeth." -> "SAY: I fear we trample the brush with clattering haste and have forgotten what the hunt is for.": The talk may not claim deeds the party did.
- "and the next the engine is ploughing the turf of Wickermoor Hollow like a startled boar." -> "and the next the whole train is lying in the turf of Wickermoor Hollow like a startled boar.": How the Express crashed is not told.
- "REASON: You told me to put the ledger away and rest." -> "REASON: You told me to put the journal away and rest.": His book is the field journal.
- "When the Ghostlight Express first spilled us into the ditch," -> "When the Ghostlight Express first spilled us into the Hollow,": No ditch.
- "than our usual approach, if you please." -> "than our usual approach.": Pet phrase 'if you please': once a talk.
- "you shall have my rifle and my manners" -> "you shall have my bow and my manners": Lucan carries a bow, not a rifle (the cloud thread's review of group 1).
- "against his rifle sling." -> "against the stave of his bow.": Lucan carries a bow, not a rifle (the cloud thread's review of group 1).
- "Lucan rests his rifle across his knees with his tricorn off" -> "Lucan rests his bow across his knees with his tricorn off": Lucan carries a bow, not a rifle (the cloud thread's review of group 1).

**acts_rook_coldwake** (9 edits)
- "Rook sits out past the wagon wheel where the frost creeps in" -> "Rook sits out past the edge of the firelight where the frost creeps in": No wagon in the canon.
- "When a watchman sees shrines cracked and graves treated like open pantries, he starts wondering what sort of parish he signed on to guard." -> "When a watchman starts to wonder whether the dead are owed less than they were, he wonders what sort of parish he signed on to guard.": The talk may not claim a deed the party did not necessarily do.
- "SAY: Keep your hands out of the barrows, hold the line when the night presses in, and leave the headstones plumb." -> "SAY: Keep your hands off what is buried, hold the line when the night presses in, and leave the headstones plumb.": Same: no barrows (no deed claimed).
- "Sloppy work is how trenches cave in, friend, whether you are digging in northern ice or valley mud." -> "Sloppy work is how trenches cave in, whether you are digging in northern ice or valley mud.": 'Friend' is Silas's word.
- "That locomotive came down off the viaduct with no regard for grade, ballast, or municipal right-of-way." -> "That locomotive came down with no regard for grade, ballast, or municipal right-of-way.": No viaduct in the canon (how the Express crashed is not told).
- "SAY: Don't need the sleep myself, friend, but I will rest the joints and keep an ear on the perimeter." -> "SAY: Don't need the sleep myself, but I will rest the joints and keep an ear on the perimeter.": 'Friend' is Silas's word.
- "They will hold a halberd shaft through this deployment, though." -> "They will hold a shield strap through this deployment, though.": No halberd in the canon.
- "SAY: No falsified tallies, no leaving a mate behind in the ditch while you run for the warm dugout." -> "SAY: No fudged tallies, and nobody left to stand a watch alone.": That line told the dark secret (a mate left in the ditch, a false report): Raum's gate tells it.
- "SAY: Put that down in block capitals, friend, because I intend to hold you to the contract." -> "SAY: Put that down in block capitals, because I intend to hold you to the contract.": 'Friend' is Silas's word.

**acts_silas_vane** (5 edits)
- "SAY: Lately the way things have gone, we're bowing to tall hats, buying every crooked contract at face value, and turning poor sods over to the bailiffs." -> "SAY: Lately the way things have gone, I can't tell who's dealing and who's being dealt, and I don't like the feeling that we're working for the house.": The talk may not claim deeds the party did ('tall hats' is nothing in the canon).
- "SAY: Start by reading the fine print before you shake a hand, and stop doing the watchman's dirty work for free." -> "SAY: Start by reading the fine print before you shake a hand, and stop working for the house for free.": Same.
- "Catching forty winks under that moon is a tall order, friend, but I'll rest my eyes and keep one ear on the brush." -> "Dozing off under that moon is a tall order for a fellow who doesn't sleep, friend, but I'll rest my bones and keep one ear on the brush.": Relicborn do not sleep.
- "Turns out having three solid backs around the fire beats" -> "Turns out having solid backs around the fire beats": The party's size is not his to count.
- "so I'll banking the grate and let the bones warm through." -> "so I'll be banking the grate and letting the bones warm through.": Grammar.

**acts_tobin_hayward** (9 edits)
- "SAY: Throwing live sparks near dry brush, writing off sick ground that could still be mended, leaving hurt creatures to rot in the ditch." -> "SAY: Sparks carried carelessly, sick ground written off when it could still be mended, hurt things left behind. That is the ledger I fear we are keeping.": The talk may not claim deeds the party did.
- "SAY: Aye, well, keep your boots out of the embers before you turn in." -> "SAY: Right, well, keep your boots out of the embers before you turn in.": Tobin's drawl is West Country: 'Aye' became 'Right' (as in the R12 Incitement).
- "my eyes are still rattling from the rails." -> "my eyes are still rattling from the crash.": How the Express crashed is not told.
- "and the next the whole carriage pitches into the ditch like an overturned hay-wain." -> "and the next the whole carriage goes over like an overturned hay-wain.": No ditch: how the Express crashed is not told.
- "since the boiler burst," -> "since the crash,": Same.
- "after flying through a baggage door." -> "after flying through a carriage door.": Same.
- "SAY: Aye, well, when you are dropped in a strange orchard" -> "SAY: Right, well, when you are dropped in a strange orchard": As above.
- "SAY: Aye, even a field surgeon knows when to shut the ledger and save his breath." -> "SAY: Right, even a field surgeon knows when to shut the ledger and save his breath.": As above.
- "Goodnight, friend, I will see you when the lanterns go up." -> "Goodnight, then, I will see you when the lanterns go up.": 'Friend' is Silas's word.

**secrets_delphine_ravelle** (2 edits)
- "maybe the tailor in Funtopia did not know everything after all." -> "maybe the toymaker in Funtopia did not know everything after all.": Master Orsino is a toymaker, not a tailor.
- "With you darlings reading over my shoulder," -> "With you reading over my shoulder,": Pet words: one a talk.

**secrets_lucan_houndstooth** (8 edits)
- "Let meknow if your own cloaks" -> "Let me know if your own cloaks": Typo.
- "Traveling in your company" -> "Travelling in your company": Lucan's English is British.
- "and good friends at my shoulder," -> "and good company at my shoulder,": Pet words: one a talk.
- "Lucan rests his rifle across his knees, his yellow eyes" -> "Lucan rests his bow across his knees, his yellow eyes": Lucan carries a bow, not a rifle (the cloud thread's review of group 1).
- "why I hold the rifle," -> "why I hold the bow,": Lucan carries a bow, not a rifle (the cloud thread's review of group 1).
- "against the polished wood of the stock." -> "against the polished wood of his bow.": Lucan carries a bow, not a rifle (the cloud thread's review of group 1).
- "and my rifle is yours until the last lantern goes out." -> "and my bow is yours until the last lantern goes out.": Lucan carries a bow, not a rifle (the cloud thread's review of group 1).
- "INSPIRE: Pledged his rifle to the company." -> "INSPIRE: Pledged his bow to the company.": Lucan carries a bow, not a rifle (the cloud thread's review of group 1).

**secrets_rook_coldwake** (11 edits)
- "Brushin' ash from the binding." -> "brushing ash from the binding.": Typo (a capital B mid-sentence).
- "Rook sets his soggy calfskin ledger and the small oilskin seed packet side by side on his knee," -> "Rook sets his soggy calfskin ledger on his knee,": The cornflower seeds were never for his own plot: they are the Catharsis's, so no talk uses them.
- "The ledger with the rubbings, the packet of blue cornflower seeds, and the hope of a quiet plot when the work's done." -> "The ledger with the rubbings, the chalk, and the hope of a quiet plot when the work's done.": Same: no seeds.
- "the ledger can burn and the seeds can scatter in the ditch." -> "the ledger can burn and the plot can wait.": Same: no seeds.
- "I left a post once when the roof came down, and I won't leave another. Settle down now, the watch is set." -> "I know what a watch is worth when it holds, and I won't fail this one. Settle down now, the watch is set.": 'Left a post once' hinted the dark secret too plainly.
- "He tucks the oilskin packet back inside his lining and pats his chest twice," -> "He tucks the ledger back inside his lining and pats his chest twice,": No seeds.
- "INSPIRE: Swore to hold the line for us." -> "INSPIRE: Swore to hold the line for the party.": Reason text: no 'us'.
- "INSPIRE: Put our lives ahead of his rest." -> "INSPIRE: Put the party ahead of his own rest.": Same.
- "He reaches into his coat, pats the oilskin packet of blue cornflower seeds through the wool, and rests his hand there." -> "He reaches into his coat, pats the damp calfskin of his ledger through the wool, and rests his hand there.": No seeds.
- "And a handful of blue cornflower seeds pressed in come the spring, so the bees know the lease is paid." -> "And the grass left to come up wild in the spring, so the bees know the lease is paid.": No seeds.
- "OPTION 2: Keep your seeds and your ledger safe." -> "OPTION 2: Keep your ledger safe, Rook.": No seeds.

**secrets_silas_vane** (2 edits)
- "You try sleeping in an empty loft when the fog rolls off the river" -> "You try sitting up in an empty loft when the fog rolls off the river": Relicborn do not sleep.
- "INSPIRE: offered the bone deck for us" -> "INSPIRE: offered the bone deck for the party": Reason text: no 'us'.

**secrets_tobin_hayward** (2 edits)
- "NARRATOR: The Vagrant watches the embers settle while Tobin turns a dry twig over in his fingers." -> "NARRATOR: The embers settle while Tobin turns a dry twig over in his fingers.": The Narrator never appears in his own tale.
- "NARRATOR: Tobin dustin' his palms together makes a soft papery whisper in the quiet." -> "NARRATOR: Tobin dusts his palms together with a soft papery whisper in the quiet.": Grammar.
