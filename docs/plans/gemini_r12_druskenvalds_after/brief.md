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

FILE: druskenvalds_after.dialogue. Slots L01..L21, O01..O05. Phillip and Adela speak in the voices above; Narrator lines under pictures are captions the Vagrant speaks over a full-screen picture (one or two sentences each). Phillip never mentions the powers he lost as game terms: only that something in the valley has gone quiet in him, a gift out of reach.

THE SKELETON (write every slot, in order):

# R12: the Druskenvalds after the hag. Speakers phillip_druskenvald (smooth 1920s transatlantic lord), adela_druskenvald (bubbly flapper). Region crooked_house.
# FINAL-WORDED: every line below is voiced as written; do not edit a line once the voice lane starts.
# Reached from vessla:death (the hag dies whispering, then the cutscene). The three pictures of ch_house_unbends are captioned by the Narrator lines under them: (1) the hag collapsing into a heap of teeth,
# (2) the house seen from outside, angles straightening, rot receding, the round attic window going dark, (3) Phillip and Adela blinking awake on the attic floor. The couple wake remembering only a dinner and
# nightmares. Phillip pays 75 gp to each hero (one `gold +300`, for a party of four heroes), once. The scratchings in the attic name the other two hags (Stonoga Blackstinger and Golub Graygullet).
# Phillip stays on at the house, hoping his curse will lift (his powers have not come back here). `unbends` is reached once (from the hag's death); `chat` serves later visits (the restored manor).
# Flags not in the contract list (register them): phillip_reward_used. vessla_slain is the fight's flag; druskenvald_manor_restored is set here.
# Drafted by Gemini (docs/plans/gemini_r12_druskenvalds_after/), edited.

~ unbends
cutscene ch_house_unbends
@L01 Narrator :: Caption for the first picture: the hag collapsing into a heap of teeth.
cutscene ch_house_unbends_2
@L02 Narrator :: Caption for the second picture: the house seen from outside, angles straightening, rot receding, petals and shingles settling, the round attic window going dark; the storm ending.
cutscene ch_house_unbends_3
@L03 Narrator :: Caption for the third picture: Phillip and Adela blinking awake on the attic floor, the ropes gone slack.
cutscene end
set druskenvald_manor_restored
-> wake

~ wake
@L04 adela_druskenvald :: Waking, bewildered and bright: where is she, what a dreadful draught, and who are these darlings. She half remembers a dinner.
@L05 phillip_druskenvald :: Waking, dazed but courtly: he remembers a dinner, a long table, the soup going cold, and then nothing he cares to describe.
@L06 adela_druskenvald :: Nightmares, darling: teeth in the carpet, a floor that kept turning over, somebody laughing in the plumbing. She is trying to make a joke of it and nearly manages.
-> thanks

~ thanks
@L07 phillip_druskenvald :: He understands they were saved by these friends; formal, moved, a little rueful that he cannot repay it properly; he insists on paying what he promised, seventy-five gold pieces to each of them.
# 75 gp x 4 heroes (R11 audit item 4): one place, once.
if not flag.phillip_reward_used
set phillip_reward_used
quest the_crooked_house done
gold +300
@L08 Narrator :: A purse of heavy coin changes hands, warm from his coat, and the house around you gives a long contented creak like an old man settling back in his chair.
endif
-> menu

~ menu
* @O01 :: Ask what they remember. -> remember
* @O02 :: Mention the scratchings on the attic wall. -> scratchings
* @O03 :: Ask whether they will stay in the house. -> stay
* @O04 :: Ask about the Ghostlight Express. -> train
* @O05 :: That is all for now. -> leave

~ remember
@L09 adela_druskenvald :: What she remembers of the dinner: the candlelight, a lovely stranger who pressed one more glass on them; and the talking, always the talking.
@L10 phillip_druskenvald :: What he remembers: the sensation of the house learning his gait, as one learns a tune; and a growing dread that he had brought her here against her better judgment.
-> menu

~ scratchings
set coven_names_known
@L11 Narrator :: Scratched into the stone by the cauldron, in a hand that dug rather than wrote, two names: Stonoga Blackstinger and Golub Graygullet.
@L12 phillip_druskenvald :: He reads the two names with distaste: the dead hag's sisters, surely; the sort of names one keeps for something that bites.
@L13 adela_druskenvald :: Names with a cold shiver and a joke: they'll be after the party now, won't they, darlings, such a terrible lot for the hag to have for family.
-> menu

~ stay
@L14 phillip_druskenvald :: He means to stay on a while in the house, which seems to have changed its mind about him; and he hopes whatever curse took his gifts away from him in this valley will lift now the hag is gone.
@L15 adela_druskenvald :: She stands by him, loyal and bright, but is anxious to be gone before that horrid train comes back round for them.
-> menu

~ train
@L16 adela_druskenvald :: A shiver, a joke: she'll not go on that train again, darlings, not for all the tea in China, and Philly had better mind it too.
@L17 phillip_druskenvald :: Dry and wry: the Express will come when it comes, and he fully intends to be somewhere else, preferably with a fire.
-> menu

~ leave
@L18 phillip_druskenvald :: A courtly farewell: his door is open to them, and they must call on the manor whenever they like.
@L19 adela_druskenvald :: A bright farewell: she'll have the cook put something on, and no teeth in it this time, promise.
-> END

# Later visits: the manor restored, a gentler place that is still a little odd.
~ chat
@L20 phillip_druskenvald :: A warm greeting, settled, in the restored manor, the house now rather gentler than before though still a little odd.
@L21 adela_druskenvald :: A bright greeting: the wallpaper has stopped whispering; she calls it a tremendous improvement.
-> menu
