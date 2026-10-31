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

FILE: sockets.dialogue. All Narrator (the Vagrant). Slots L01..L19, O01..O08. The 'count in plain words' lines must say the number in words (one, two...), no digits.

THE SKELETON (write every slot, in order):

# R12: the six rune circles on the secret landing (H16) and the ward on the way to the hag. No speaker: all Narrator. Region crooked_house.
# FINAL-WORDED: every line below is voiced as written; do not edit a line once the voice lane starts.
# Started by: the prop h16_sockets (`place`). Six options, one per memento, each with ONE bracket: [if item:memento_X and not flag.memento_X_placed]; placing takes the item, sets its own placed flag
# and counts mementos_placed (the door h16_ward reads mementos_placed >= 6). The sixth opens the ward and moves the main quest on. Nothing depends on which one goes last.
# After vessla_slain the runes let the six go (release): each placed memento is handed back once (mementos_released), the bear and the doll stay useful against the lurker and the bag.
# Flags not in the contract list (register them): memento_gem_placed, memento_key_placed, memento_cup_placed, memento_doll_placed, memento_bear_placed, memento_pin_placed, mementos_released.
# Drafted by Gemini (docs/plans/gemini_r12_sockets/), edited.

~ place
if flag.vessla_slain and not flag.mementos_released
-> release
endif
if flag.vessla_slain
-> quiet
endif
if flag.mementos_placed >= 6
-> ward_open
endif
@L01 Narrator :: The rune-cut wall, floor and ceiling pulse blood-red; six empty circles wait in a ring in the runes.
-> place_menu

~ place_menu
* [if item:memento_bloodstone and not flag.memento_gem_placed] @O01 :: Set the bloodstone in a circle. -> place_gem
* [if item:memento_black_key and not flag.memento_key_placed] @O02 :: Set the black key in a circle. -> place_key
* [if item:memento_porcelain_cup and not flag.memento_cup_placed] @O03 :: Set the porcelain cup in a circle. -> place_cup
* [if item:memento_wooden_doll and not flag.memento_doll_placed] @O04 :: Set the wooden doll in a circle. -> place_doll
* [if item:memento_blue_bear and not flag.memento_bear_placed] @O05 :: Set the blue bear in a circle. -> place_bear
* [if item:memento_silver_pin and not flag.memento_pin_placed] @O06 :: Set the silver pin in a circle. -> place_pin
* @O07 :: Look the circles over. -> look
* @O08 :: Step back. -> END

~ look
@L02 Narrator :: What the circles ask for: six small things that mattered to the household, one to a circle; the rune-light seems to count what the party carries.
-> place_menu

~ place_gem
take memento_bloodstone
set memento_gem_placed
set mementos_placed += 1
@L03 Narrator :: The bloodstone is set in its circle; a small wet click; the runes around it drink its red.
-> placed

~ place_key
take memento_black_key
set memento_key_placed
set mementos_placed += 1
@L04 Narrator :: The black key is set in its circle; the runes turn once about it like a lock taking a key.
-> placed

~ place_cup
take memento_porcelain_cup
set memento_cup_placed
set mementos_placed += 1
@L05 Narrator :: The porcelain cup is set in its circle; a chime like a spoon on a saucer; thread of steam from the empty cup.
-> placed

~ place_doll
take memento_wooden_doll
set memento_doll_placed
set mementos_placed += 1
@L06 Narrator :: The little wooden doll is set in its circle, face up; the runes round it go soft as a lamp turned low.
-> placed

~ place_bear
take memento_blue_bear
set memento_bear_placed
set mementos_placed += 1
@L07 Narrator :: The blue bear is set in its circle; faint bedtime warmth rises from the stitching.
-> placed

~ place_pin
take memento_silver_pin
set memento_pin_placed
set mementos_placed += 1
@L08 Narrator :: The silver pin is set in its circle; it gleams like a new needle and the runes round it stand taut as threads.
-> placed

# How many circles are lit: the Narrator says it in words; the sixth opens the ward.
~ placed
if flag.mementos_placed >= 6
-> ward_opens
endif
if flag.mementos_placed == 1
@L09 Narrator :: Count in plain words: one circle burns, five dark.
endif
if flag.mementos_placed == 2
@L10 Narrator :: Count in plain words: two burn, four dark.
endif
if flag.mementos_placed == 3
@L11 Narrator :: Count in plain words: three burn, three dark; the red light in the walls has begun to breathe.
endif
if flag.mementos_placed == 4
@L12 Narrator :: Count in plain words: four burn, two dark; the landing hums like a held note.
endif
if flag.mementos_placed == 5
@L13 Narrator :: Count in plain words: five burn, the sixth gapes alone like a missing tooth.
endif
-> place_menu

~ ward_opens
quest the_crooked_house vessla
@L14 Narrator :: The sixth circle flares, every rune goes white, then the light shudders out and the small glowing door at the end of the landing stands open.
@L15 Narrator :: The ward is down; from beyond comes a smell of hot copper and a faint wet giggling.
-> END

~ ward_open
@L16 Narrator :: (The party returns after the ward opened) all six burn quietly, the door stands open, the wet giggling still drifting out.
-> END

# After the hag is dead: the runes let the keepsakes go, once.
~ release
set mementos_released
@L17 Narrator :: After the hag is dead: the runes gutter out like candles in a draught and the circles let go with a soft sound of cloth and china.
if flag.memento_gem_placed
give memento_bloodstone
endif
if flag.memento_key_placed
give memento_black_key
endif
if flag.memento_cup_placed
give memento_porcelain_cup
endif
if flag.memento_doll_placed
give memento_wooden_doll
endif
if flag.memento_bear_placed
give memento_blue_bear
endif
if flag.memento_pin_placed
give memento_silver_pin
endif
@L18 Narrator :: The six keepsakes lie warm in the hands again; somebody who loved them ought to have them back, and you mean to carry them until you find who.
-> END

~ quiet
@L19 Narrator :: Afterwards the runes are only dark plaster and scratches, the landing a cramped place under a roof.
-> END
