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

FILE: vessla.dialogue. Slots: L rows L01..L32, O rows O01..O18. The disguise lines are spoken as 'adela_druskenvald' but are Vessla pretending badly: breathy, fond, a hiss or a giggle slipping out mid-word. Vessla's own lines hiss and giggle mid-word. Mood for each NPC line is yours to choose from the list.

THE SKELETON (write every slot, in order):

# R12: Vessla Browntooth in the cauldron room (H17). Speakers vessla_browntooth (the weasel hag; shrill, quick, wet hissing, giggles mid-word), adela_druskenvald (also what Vessla's DISGUISE is shown as and sounds
# like in the ruse), phillip_druskenvald (bound, feverish). Region crooked_house.
# FINAL-WORDED: every line below is voiced as written; do not edit a line once the voice lane starts.
# Scene: floor carpeted in human teeth, a great cauldron of glowing red ichor, Phillip bound beside it, mumbling; a cloaked figure (the real Adela) swaying blind and still beyond the cauldron; and a woman in
# Adela's green dress crumpled on the floor as if fainted: that is Vessla in disguise, waiting to bite whoever bends over her. A Search within ten feet and Investigation or Insight (DC 15) sees through it;
# failing it is not a gate, it only gives her the first blow. She never targets the Druskenvalds: they are the sacrifice.
# Nodes: pre_fight (the room, then a menu), ruse (tending the "fainted" woman), tooth_gift (a hero who knows her secret offers one of their own teeth; she must take it, is charmed for a day, and the party
# may talk, cut the couple loose, or strike first), death (after the fight: her last word; then the house unbends, druskenvalds_after). Every way out of the scene is `combat ch_vessla` (the fight has three versions,
# keyed on vessla_ruse_seen and vessla_tooth_gift) except the walk back to the room's menu. vessla_slain is set by the fight itself, never here.
# Flags not in the contract list (register them): vessla_looked (one close look at the woman on the floor per party), vessla_lore_tried, vessla_secret_known.
# Drafted by Gemini (docs/plans/gemini_r12_vessla/), edited.

~ pre_fight
@L01 Narrator :: The attic's last door opens on the cauldron room: the floor crunching like gravel with human teeth, the ichor glowing red and hissing in the great pot, and the smell of hot copper.
@L02 Narrator :: Phillip sits bound against the pot's iron foot, mumbling; a cloaked figure sways blind and still beyond it; and a woman in a green dress lies in a heap on the floor, one white hand flung out.
-> room_menu

~ room_menu
* [if not flag.vessla_looked] [Investigation DC 15] @O01 :: Study the woman on the floor before going near. -> seen | missed_look
* [if not flag.vessla_looked] [Insight DC 15] @O02 :: Watch her breathing and her hands for something false. -> seen | missed_look
* [if not flag.vessla_lore_tried] [Arcana DC 13] @O03 :: Search memory for the old lore of weasel hags. -> lore_ok | lore_miss
* [if flag.vessla_secret_known] @O04 :: Work a tooth loose, hold it out to the woman on the floor, freely given. -> tooth_gift
* @O05 :: Kneel by the fallen woman to help her. -> ruse
* @O06 :: Go to Phillip. -> phillip_bound

~ phillip_bound
@L03 phillip_druskenvald :: Bound and feverish, he does not know them: he mumbles of a long table, a dinner that will not end, and Adela, Adela, her name over and over.
@L04 phillip_druskenvald :: A second bewildered mumble: someone should take her away before the train comes back.
@L05 Narrator :: His cords are tight and his lips are cracked, and he never once looks at the woman on the floor.
-> room_menu

~ missed_look
set vessla_looked
@L06 Narrator :: You look the fainted woman over from a safe distance and find only a woman in a green dress in a bad way. A wry line: whatever is wrong in this room, she doesn't look like it.
-> room_menu

# The lore: a tooth given freely binds a weasel hag.
~ lore_ok
set vessla_lore_tried
set vessla_secret_known
@L07 Narrator :: The hero remembers an old wives' tale about weasel hags and their love of teeth, and a worse thing underneath: they cannot refuse one freely given.
-> room_menu

~ lore_miss
set vessla_lore_tried
@L08 Narrator :: The hero chases a tale about hags and weasels and gets as far as a nursery rhyme and no further.
-> room_menu

# Seeing through the ruse: she drops it.
~ seen
set vessla_ruse_seen
@L09 Narrator :: The woman's breathing is a shade too even and her hand too neatly flung; something wrong clicks together like a lock.
@L10 vessla_browntooth :: She drops the act: delighted, shrill, giggling mid-word that they are clever, clever, and it will make the teeth taste sweeter.
@L11 vessla_browntooth :: Her shriek as she rises: she promises their souls to the house.
-> to_fight

# Tending the woman on the floor: Vessla in Adela's voice (a poor, breathy imitation of the flapper).
~ ruse
@L12 adela_druskenvald :: Faint and breathy, in Adela's flapper way but a little off: oh darling, thank goodness, my head. Make one giggle slip mid-word, like a hiccup.
@L13 adela_druskenvald :: She begs them to see to Philly and to the thing in the pot; she cannot stand.
-> ruse_menu

~ ruse_menu
* [if not flag.vessla_looked] [Insight DC 15] @O07 :: Study how she holds herself close up: something is off. -> seen | ruse_unseen
* @O08 :: Ask what happened to her. -> ruse_story
* @O09 :: Help her to her feet. -> ruse_help
* @O10 :: Step back from her. -> room_menu

~ ruse_unseen
set vessla_looked
@L14 Narrator :: She is just a frightened woman, you tell yourself, a hand on yours, damp and eager. Nothing more.
-> ruse_menu

~ ruse_story
@L15 adela_druskenvald :: A wandering, weeping tale: a dinner, a long table, a voice that talked too sweetly; she has lost her shoes. One word is mangled by a hiss.
@L16 adela_druskenvald :: A slip she doesn't notice: a remark about how sore and hungry her gums are, said with an odd wet hiss.
-> ruse_menu

~ ruse_help
@L17 Narrator :: You take her hand and it is far too strong and far too warm; then the pretty face is simply gone, and a long yellow muzzle is full of crooked teeth.
@L18 vessla_browntooth :: Gleeful and shrill, giggling mid-word: she wanted them to come closer, to be good and bend down. She promises their souls to the house.
-> to_fight

# A tooth given freely: she cannot refuse. (Reached from room_menu; vessla_secret_known is set.)
~ tooth_gift
set vessla_tooth_gift
@L19 Narrator :: A hero works a tooth loose with a wince, and holds it out on an open palm, freely given.
@L20 vessla_browntooth :: The false woman snaps upright, the pretty face sliding off: she cannot, cannot help it, her giggle breaking into a gasp. A tooth, a real tooth, offered, her clawed hand already reaching.
@L21 Narrator :: She plucks it from your palm, shuddering, and her red eyes go wide and soft as a sleepwalker's.
@L22 vessla_browntooth :: Dreamy, slurring, still shrill, with a giggle mid-word: she says the party is her friends now, such dear, dear friends.
-> tooth_both

# What the party does with a charmed hag: talk, cut the couple loose, or strike. (Four versions; talk and cut each happen once.)
~ tooth_both
* @O11 :: Talk with her while she is soft. -> tooth_talk_a
* @O12 :: Cut Phillip loose from the pot. -> cut_loose_a
* @O13 :: Strike her while she is dazed. -> strike_tooth

~ tooth_talk_only
* @O14 :: Cut Phillip loose from the pot. -> cut_loose_b
* @O15 :: Strike her while she is dazed. -> strike_tooth

~ tooth_cut_only
* @O16 :: Talk with her while she is soft. -> tooth_talk_b
* @O17 :: Strike her while she is dazed. -> strike_tooth

~ tooth_done_only
* @O18 :: Strike her while she is dazed. -> strike_tooth

~ tooth_talk_a
@L23 vessla_browntooth :: Chattering, fond, giggling: how hard she works, the dull ritual of readying souls, her sisters leaving her all the tedious tasks.
@L24 vessla_browntooth :: A cheerful, fatal slip: her sisters said the Druskenvalds would make her a queen, and she is only a little afraid they were teasing.
@L25 Narrator :: She hums happily to the pot, and the ichor hums back, and you cannot decide which of them is more pleased.
-> tooth_talk_only

~ tooth_talk_b
@L26 vessla_browntooth :: Chattering, fond, giggling: how hard she works, the dull ritual of readying souls, her sisters leaving her all the tedious tasks.
@L27 vessla_browntooth :: A cheerful, fatal slip: her sisters said the Druskenvalds would make her a queen, and she is only a little afraid they were teasing.
@L28 Narrator :: She hums happily to the pot, and the ichor hums back, and you cannot decide which of them is more pleased.
-> tooth_done_only

~ cut_loose_a
@L29 Narrator :: You cut Phillip's cords and drag him clear of the pot; the cloaked figure never stirs. The hag watches, smiling, quite unbothered.
-> tooth_talk_only

~ cut_loose_b
@L30 Narrator :: You cut Phillip's cords and drag him clear of the pot; the cloaked figure never stirs. The hag watches, smiling, quite unbothered.
-> tooth_done_only

~ strike_tooth
@L31 Narrator :: The hag blinks up at you like a child woken from a nap, charmed to the roots; whatever you do next, you do first.
-> to_fight

# Every way into the fight: the opening shriek has played; the fight's own version is chosen by the flags above.
~ to_fight
combat ch_vessla

# After the fight (called by the wiring once the weasel hag is down): her last word, then the house unbends (the collapse into teeth is the first picture of ch_house_unbends). vessla_slain is the fight's flag.
~ death
@L32 vessla_browntooth :: Dying and incredulous, she understands at last that her sisters set her here as the offering. Her voice is small and wet and broken; she whispers: Sisters.
-> crooked_house/druskenvalds_after:unbends
