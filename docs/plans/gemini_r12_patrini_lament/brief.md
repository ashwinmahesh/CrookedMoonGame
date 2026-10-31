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

FILE: patrini_lament.dialogue. All Narrator (the Vagrant), plus two party interjects (I rows). Slots L01..L13, O01..O04, I01..I02.

THE SKELETON (write every slot, in order):

# R12: the harpsichord in the music room (H5) and Patrini's lament. No speaker: Patrini speaks only through the board and by playing, so this is all Narrator. Region crooked_house.
# FINAL-WORDED: every line below is voiced as written; do not edit a line once the voice lane starts.
# Started by: the prop h5_harpsichord (`harpsichord`). The dance floor's weasels charm the whole first floor into dancing; the harpsichord is the way to stop the music.
# Two ways: any hero may sit and play (Performance DC 15; Patrini's spirit steadies even unpractised hands), or, once the weasels are down, Religion or Arcana (DC 12) calls the dead
# butler to play himself. A failed Performance is spent (never offered again), so the calling is the second way and may be tried again; a miss costs ten minutes of the night.
# Either way he plays a lament and a black key pops out of the instrument: memento_black_key, flag memento_key. The tune is a lullaby in disguise: a hero who heard it
# hums it to Arthur later (arthur.dialogue reads memento_key for advantage on the lullaby), so the Narrator hints at that.
# Drafted by Gemini (docs/plans/gemini_r12_patrini_lament/), edited.

~ harpsichord
if flag.memento_key
-> played_out
endif
@L01 Narrator :: First look at the harpsichord with its lid gaping like a coffin; yellowed keys; smell of beeswax and old felt; the room hushed as if listening.
-> menu

~ menu
* [Performance DC 15] @O01 :: Sit at the harpsichord and play, trusting the old butler to steady your hands. -> play_ok | play_miss
* [Religion DC 12] @O02 :: Speak to the dead man kindly, as a servant is spoken to, and ask him to play. -> call_ok | call_miss
* [Arcana DC 12] @O03 :: Reach for the lingering music in the room and draw him up. -> call_ok | call_miss
* @O04 :: Leave it be. -> END

~ play_ok
@L02 Narrator :: A hero sits to play; cold hands settle lightly over theirs, steadying them.
@L03 Narrator :: The wrong notes fall away; the instrument finds its own grave, slow voice; it feels like a kindness.
-> lament

~ play_miss
time +10
@L04 Narrator :: The playing goes wrong: clatter, a string snapping inside, a chill like a polite refusal.
@L05 Narrator :: The instrument wants no more of that; a good ten minutes of the night pass in the quiet after.
-> menu

~ call_ok
@L06 Narrator :: The call is answered: the air turns warm and close, beeswax and old wool, and the stool slides out by itself.
@L07 Narrator :: Notes begin to fall with no hand on the keys; the party stands like guests at the back of a church.
-> lament

~ call_miss
time +10
@L08 Narrator :: The call goes unanswered; only the house ticking and settling overhead.
@L09 Narrator :: About ten minutes slip by in the listening; the keys stay cold.
-> menu

# The lament itself, then the key.
~ lament
@L10 Narrator :: The music is a lament, slow, patient, rocking in threes, the loneliest tune they ever stood still for.
@I01 class:bard :: the bard recognises a lullaby hidden in the lament and says they could carry the tune.
@I02 class:cleric :: the cleric hears a prayer for the household, one that was never answered.
@L11 Narrator :: Last note fades; something clicks inside the case and a black key pops out onto the keys and rolls to a hand.
give memento_black_key
set memento_key
if quest.the_crooked_house == trapped
quest the_crooked_house mementos
endif
@L12 Narrator :: The tune stays in the head, round and rocking, the kind you could hum a little one to sleep with (a hint for later, said lightly, no names).
-> END

~ played_out
@L13 Narrator :: The harpsichord sits quiet, lid open on an empty velvet hollow; whoever played has said what he came to say.
-> END
