Reply with plain text only, no JSON, no code fences, and do not send messages to anyone else.

You are drafting dialogue for a Halloween D&D video game, "The Crooked Moon". Chapter 12 is "The Crooked House": a haunted, warping manor on a hill above the village of Wickermoor Hollow. The heroes (a party of four, who speak through one chosen member; any hero, any class, never named) came up the hill road to a dinner Phillip and Adela Druskenvald promised them. The house twisted itself into a crooked ruin, a tall grinning ghost (the Crooked Man) welcomed them on the porch, a storm shut the front door, and the Druskenvalds are missing. Inside, the ghosts of the old Lockwood household each guard one of six keepsakes ("mementos"): a bloodstone gem, a black key, a porcelain cup, a wooden doll, a blue teddy bear, a silver pin. The six mementos fit six rune circles on the attic landing and open a ward on the way to the weasel hag Vessla Browntooth (the youngest of three hag sisters), who keeps the Druskenvalds bound beside a cauldron full of glowing red ichor, on a floor carpeted in human teeth. A man named Eustace Lockwood murdered his household long ago; his shade is the Crooked Man. Weasels live in the walls everywhere. The house, its ghosts and the hag are all our own telling: never quote or paraphrase any published book; write fresh lines only.

THE DRAFT IS A TEMPLATE WITH SLOTS. Below is a dialogue file skeleton. The structure (node names, jumps, flags, checks) is FIXED; you only write the words. Slots look like:
  @L07 speaker_id [limit] :: what this line must do      (one spoken line or Narrator line)
  * ... @O03 :: what this player option says -> node     (the text the player chooses; first person plural or imperative, under 14 words)
  @I02 class:bard :: what a party member of that kind mutters (one short line, under 22 words)
Reply with one row per slot, nothing else, in this exact format, in slot order:
  L07 | mood | text
  O03 | text
  I02 | text
For L rows: the speaker is already fixed by the skeleton; "mood" is one of neutral, smile, angry, afraid, sad, sly, weary, or empty for the Narrator and for the spirit board (leave the field empty but keep both bars). Put the text after the second bar; never use the bar character inside the text. One row per line, no blank lines, no commentary, no markdown.

RULES FOR EVERY LINE
- All text is in our own words. No placeholders, no stage directions, no {name} or other braces, no modern slang, no words the 1920s would not know.
- NO GAME WORDS anywhere (no HP, damage, roll, check, save, DC, level, class names in narration, XP, spell slot, saving throw, advantage). Describe in the senses.
- Never "suddenly". Never tell the player what to feel. No facts the party has not earned: only what a person standing there could see, hear, smell or be told in the slot's own intent.
- Keep every line to its slot's intent; if the slot says a length, obey it.

THE NARRATOR is the Vagrant, an old train conductor telling the tale afterwards in a folksy, warm, wry Southern drawl (reckon, ain't, mighty, a spell, a piece, folks, "turn out", "like as not"). Second person ("you"), present tense, ONE or TWO sentences (under about 34 words in all); the second sentence is usually the turn or the payoff. Concrete senses (smell, sound, cold, taste) over adjectives. Drop a final g ("hissin'", "creepin'") in about one Narrator line in three, not more. The fiddle is never written or mentioned. Narrator lines are VOICED and FINAL: write them as you want them heard.

OTHER VOICES
- joseph_patrini (the board): the butler's ghost, answering through a spirit board. ALL CAPITAL LETTERS, short, formal, old-fashioned, no contractions, full stops only (no commas, no dashes, no exclamation marks). Usually 1 to 6 words per sentence, at most two short sentences per answer. A music lover, a servant, grieving and dignified.
- phillip_druskenvald: smooth 1920s transatlantic lord, courtly and wry: "my dear friends", "I daresay", "rather", "singularly", "capital", "one", long clauses that end with a joke. Samples of his house voice: "A gentleman always repays a debt in kind, and tonight our debt to you is considerable." / "Come now, darling, some ledgers must be closed in ink before the page can turn."
- adela_druskenvald: bubbly flapper, quick and fond, never cruel: "darlings", "swell", "the bee's knees", "jazzed", "hush-hush", "Philly", "applesauce". Samples: "Oh, never mind your coat, Philly, we're only a touch singed around the edges." / "Honestly, it's a swell card once you get past the bones!"
- vessla_browntooth: a weasel hag, shrill, quick, wet and hissing, with giggles that burst in the MIDDLE of words (write them in the word: "sweet-hee-hee-sweet", "pre-hee-cious", "teeeeth", "sss-sisters"). Mean, delighted, greedy for teeth. Short, fast sentences; no more than 30 words a line.

Write horror that is eerie and a little funny, never gory: flesh not blood, hints not wounds.

FILE: seance.dialogue. Slots: 57 L rows (L01..L57) and 14 O rows (O01..O14). Board answers are ALL CAPS and short; the Narrator lines are the Vagrant. Where a slot says 'a short board sentence' write it yourself in the butler's formal voice (but stay inside the facts in the slot). The questions the player asks are the O rows (first person plural, imperative or plain question, under 14 words).

THE SKELETON (write every slot, in order):

# R12: the séance at the spirit board in the parlor (H3). Speaker joseph_patrini (the butler's spirit, ALL CAPS, answers through the board). Region crooked_house.
# FINAL-WORDED: every line below is voiced as written; do not edit a line once the voice lane starts.
# Started by: the prop h3_spirit_board (`start`). Two or more hands on the planchette; the party chooses when (they may say "not yet" and explore first).
# The question menu grows as the house is explored (visited: floors) and as earlier answers are given, capped at eight questions; each answer is followed by the open
# roll (`roll`): a bite of cold on a failed roll steps up every time. HOOK(damage): the dialogue grammar has no damage statement, so a bite is narration
# plus the counter seance_stings; when the engine gains `hurt`, each bite should hurt every hand on the board by psychic damage 1d4, 1d6, 1d8, 1d10, then 1d12
# (stings 1..5, capped at 5). The roll is a Constitution check against the party's best (DC 6 stands in for the book's "1 on a d10").
# He answers "where is the attic door" with TROPHIES (sets trapdoor_known), "who is the cat" with LIAR, "what is Shuck" with SALLY.
# GOODBYE closes it for good: seance_done. When the three plot clues (the hag, the six mementos, the attic door) were all asked, he asks them to find his son.
# Drafted by Gemini (docs/plans/gemini_r12_seance/), edited.

~ start
if flag.seance_done
-> board_dead
endif
@L01 Narrator :: First look at the round parlor table: the spirit board with its letters, YES, NO, HELLO and GOODBYE, a heart-shaped planchette marked with the letters A and D, dust over everything, the cobwebbed hearth cold. Make it plain the board wants hands on it.
-> hands_menu

~ hands_menu
* @O01 :: Together, lay our fingertips on the planchette and ask whether anyone is there. -> begin
* [Arcana DC 10] @O02 :: Recall how a sitting like this is properly done. -> arcana_ok | arcana_miss
* @O03 :: Not yet. -> END

~ arcana_ok
@L02 Narrator :: What the hero remembers: all hands lightly on the planchette, ask plain and one thing at a time, the answers come letter by letter.
@L03 Narrator :: What else the hero remembers: some of the dead bite back (cold climbing into the hands now and again), and once the spirit says goodbye the board goes dead for good.
-> hands_menu

~ arcana_miss
@L04 Narrator :: The hero reaches for how it is done and finds only half-remembered stories; a wry shrug of a line.
-> hands_menu

~ begin
@L05 Narrator :: Hands settle on the planchette, which trembles; the cold hearth lights itself with a small dry sound; the room leans toward it.
@L06 joseph_patrini :: The first word the planchette spells, a greeting: HELLO.
@L07 Narrator :: The planchette stops on the word, patient as a servant awaiting orders; a cold ache sits in the fingertips.
-> menu

~ menu
if flag.seance_asked_1 and flag.seance_asked_2 and flag.seance_asked_3 and flag.seance_asked_4 and flag.seance_asked_5 and flag.seance_asked_6 and flag.seance_asked_7 and flag.seance_asked_8
-> closing
endif
* [if not flag.seance_asked_1] @O04 :: Ask who he is. -> q1
* [if flag.seance_asked_1 and not flag.seance_asked_2] @O05 :: Ask who did this to him. -> q2
* [if not flag.seance_asked_3] @O06 :: Ask where Phillip and Adela are. -> q3
* [if flag.seance_asked_3 and not flag.seance_asked_4] @O07 :: Ask who is behind all this. -> q4
* [if flag.seance_asked_4 and not flag.seance_asked_5] @O08 :: Ask how we get out of here, what will open the way. -> q5
* [if flag.seance_asked_4 and not flag.seance_asked_6] @O09 :: Ask where the door to the attic is. -> q6
* [if visited:crooked_house_second and not flag.seance_asked_7] @O10 :: Ask who the grey cat is. -> q7
* [if visited:crooked_house_third and not flag.seance_asked_8] @O11 :: Ask what Shuck is, the red dog. -> q8
* @O12 :: That is enough. Let him go. -> confirm_goodbye

~ q1
set seance_asked_1
@L08 Narrator :: The planchette begins to move, dragging across the letters one at a time.
@L09 joseph_patrini :: His name and trade: JOSEPH PATRINI. BUTLER.
@L10 joseph_patrini :: That he served this house. A second short board sentence.
-> roll

~ q2
set seance_asked_2
@L11 Narrator :: The planchette stalls, then jerks, as if it dislikes where it is going.
@L12 joseph_patrini :: EUSTACE LOCKWOOD. MY MASTER.
@L13 joseph_patrini :: That he killed the whole household. One short board sentence.
-> roll

~ q3
set seance_asked_3
@L14 Narrator :: The planchette lifts a hair off the board and comes down above the YES.
@L15 joseph_patrini :: They are ABOVE. ALIVE. And a short grim afterthought: not for long.
-> roll

~ q4
set seance_asked_4
@L16 Narrator :: The planchette drifts in a slow circle before it picks a letter.
@L17 joseph_patrini :: A HAG. IN THE ATTIC.
@L18 joseph_patrini :: What she wants: the couple's souls, for the house. One short board sentence.
-> roll

~ q5
set seance_asked_5
@L19 Narrator :: The planchette swings from corner to corner, quick, like a hand counting.
@L20 joseph_patrini :: SIX KEEPSAKES OPEN THE WAY.
@L21 joseph_patrini :: The six, one after another: GEM. KEY. CUP. DOLL. BEAR. PIN.
@L22 joseph_patrini :: That they lie on every floor of the house. One short board sentence.
-> roll

~ q6
set seance_asked_6
set trapdoor_known
@L23 Narrator :: The planchette creeps, then darts, and for once spells with no hesitation.
@L24 joseph_patrini :: TROPHIES.
@L25 joseph_patrini :: A tiny directive: LOOK UP. (or similar, two or three words)
-> roll

~ q7
set seance_asked_7
@L26 Narrator :: The planchette shivers on the board like something stepping onto a cold floor.
@L27 joseph_patrini :: LIAR.
@L28 joseph_patrini :: A second short board sentence: the cat hungers for stories, do not feed him.
-> roll

~ q8
set seance_asked_8
@L29 Narrator :: The planchette slows and goes gently, almost tenderly, to the first letter.
@L30 joseph_patrini :: SALLY.
@L31 joseph_patrini :: One short board sentence: the little one runs free now, a child of this house.
-> roll

# The open roll after every answer. A failed roll is a bite of cold; every bite is worse than the last.
~ roll
check Constitution DC 6 -> calm | sting

~ calm
@L32 Narrator :: The planchette settles, the cold stays in the floorboards, the board waits for the next question.
-> menu

~ sting
set seance_stings += 1
if flag.seance_stings == 1
@L33 Narrator :: The first bite of cold when the board bites back: the planchette bucks, a thin cold needle runs through every hand on the board.
endif
if flag.seance_stings == 2
@L34 Narrator :: The second bite is colder: it climbs the wrists and leaves numbness.
endif
if flag.seance_stings == 3
@L35 Narrator :: The third bite is deeper: a hard frost in the bones of every hand.
endif
if flag.seance_stings == 4
@L36 Narrator :: The fourth bite wrings the breath from every chest; the hands do not want to let go.
endif
if flag.seance_stings >= 5
@L37 Narrator :: The fifth and every later bite: a black cold grips every hand to the elbow, holds, and lets go slow.
endif
-> menu

~ confirm_goodbye
@L38 Narrator :: Warn plainly that if the spirit is let go now the board never answers again and what is unasked stays unasked.
* @O13 :: Ask something else first. -> menu
* @O14 :: Let him go. -> closing

# His last words. The urgent clue is the first thing the party missed; with nothing missed, he warns of the hag's disguise and asks them to find his son.
~ closing
if not flag.seance_asked_5
-> urgent_mementos
endif
if not flag.seance_asked_4
-> urgent_hag
endif
if not flag.seance_asked_6 and not flag.trapdoor_known
-> urgent_door
endif
-> urgent_face

~ urgent_mementos
@L39 Narrator :: The planchette stirs, urgent, before the party lets go (same intent for the four urgent openers; vary the wording each time).
@L40 joseph_patrini :: SIX KEEPSAKES OPEN THE WAY. GEM. KEY. CUP. DOLL. BEAR. PIN.
@L41 joseph_patrini :: They lie on every floor. A short urgent board sentence.
-> goodbye

~ urgent_hag
@L42 Narrator :: Same intent as L39: urgent, before the party lets go; different words.
@L43 joseph_patrini :: A HAG WAITS IN THE ATTIC.
@L44 joseph_patrini :: A short urgent board sentence: she must not finish.
-> goodbye

~ urgent_door
set trapdoor_known
@L45 Narrator :: Same intent as L39: urgent, before the party lets go; different words.
@L46 joseph_patrini :: THE WAY UP IS HIDDEN. TROPHIES.
@L47 joseph_patrini :: A short urgent board sentence: look to the ceiling.
-> goodbye

~ urgent_face
@L48 Narrator :: Same intent as L39: urgent, before the party lets go; different words.
@L49 joseph_patrini :: SHE WEARS THE LADY'S FACE.
@L50 joseph_patrini :: A short urgent board sentence: look twice.
-> find_my_son

# Only reached when nothing was missed: all three plot clues (the hag, the six keepsakes, the attic door) were gathered.
~ find_my_son
set patrini_asked_find_son
@L51 Narrator :: The planchette trembles, as if the spirit has held something back a very long time.
@L52 joseph_patrini :: ONE THING MORE. MY SON LIVES.
@L53 joseph_patrini :: His name: FRANCIS. A short board sentence: find him.
@L54 joseph_patrini :: TELL HIM HIS NAME. PATRINI.
-> goodbye

~ goodbye
set seance_done
@L55 joseph_patrini :: GOODBYE.
@L56 Narrator :: The planchette slides to the corner and stops dead; the hearth fire hisses out like a doused lamp; the cold leaves the room with it.
-> END

~ board_dead
@L57 Narrator :: The dead board under its dust; nothing answers; some doors only open once.
-> END
