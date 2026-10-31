Reply with plain text only: no JSON, no code fences, no commentary before or after. Do not send messages to anyone else.

You are drafting dialogue for a Halloween D&D video game, "The Crooked Moon" (an original story; use only the names and facts given here and invent no new people, places, monsters or history). The player leads a party of four adventurers; never name, describe, gender or give a face to them. The setting is the Druskenvald estate, a manor on a hill above the village of Wickermoor Hollow, in an autumn that never ends. Tonight the manor has warped into a crooked, haunted house and a storm has shut the party inside. Long ago the head of the house, Eustace Lockwood, murdered his household; their ghosts remain, and each one still guards a keepsake the party needs.

SCENE: the glass conservatory on the ground floor. Dead vines cover the panes, but one bergamot tree stands somehow alive and green. A pale woman in a black mourning gown sits facing the tree. Her name is Petunia Lockwood (speaker id: petunia_lockwood), a ghost, the dead wife of Eustace. A faded green ribbon is tied snug at her throat. She holds a porcelain teacup of dark tea gone cold long ago, and will not set it down. The cup is the keepsake the party wants. She married Eustace for his money and she knows it, and the one thing in that house she truly chose was her two children, Sally (a small girl) and Arthur (a baby). Sally's wooden doll and Arthur's blue teddy bear are elsewhere in the house; if the party shows her both she will give up the cup in peace.

VOICES:
- Petunia: genteel city vowels, distracted, polite, a little vague, a lady who has lost the thread of the years. Refined diction ("I do beg your pardon", "how very kind", "do forgive me"), full sentences that sometimes trail off mid-thought ("Now, where was I"). No phonetic dialect spelling. She mistakes the party for callers for tea. She is never cruel until threatened, and then she goes icy, not shrill. Never mention her ribbon, her head or how she died.
- Narrator: the Vagrant, an old train conductor telling this tale afterwards in a folksy, warm, wry Southern drawl: word choice and rhythm (reckon, ain't, folks, a spell, a piece, y'all), and drop a final g ("flickerin'") in about one Narrator line in three, not more. Narrator rules: second person ("you"), present tense, one or two sentences, under about 30 words, concrete senses (a smell, a sound, a cold) over adjectives, no game words (no HP, roll, check, save, level, DC, fight), never tell the player what to feel, never the word "suddenly", no facts the party could not perceive. Never mention a fiddle. Do not use {name}. Respect the dead: wry about the room, never about the dead woman.

FORMAT (exactly this, nothing else): for each node, a row "~ node_id" followed by one row per line: "speaker_id [mood]: Text". Moods allowed: neutral, smile, angry, afraid, sad, sly, weary (the mood is optional; Narrator lines take none: "Narrator: Text"). Plain punctuation only: straight quotes, no em dashes, no asterisks, no markdown, no stage directions in brackets, no placeholders. A character line is one or two short sentences, under about 28 words. Do not write options, menus or any mechanical rows; the game's wiring is added afterwards. For "interject" rows write exactly "interject class:cleric: Text" with the class named (a hero of that class says it, in the first person, one short dry or uneasy sentence).

NODES TO WRITE (counts are exact):

~ start   (the party's first sight of her)
 - 2 Narrator lines: the conservatory (dead vines on the glass, the one living bergamot tree, its smell) and the woman in black facing it, cup in both hands.
 - 2 lines by petunia_lockwood: a distracted polite welcome to what she takes for callers; she lost track of who was expected.
 - 1 interject row by class:cleric, 1 by class:bard.

~ return   (they come back to her)
 - 2 lines by petunia_lockwood: "oh, it is you again" in a vague polite way; hopes they were not offended before.

~ who   (asked who she is)
 - 3 lines by petunia_lockwood: Mrs Petunia Lockwood, the lady of the house; dinner is always just about to be served; she cannot quite say how long she has waited.

~ cup_talk   (asked about the cup)
 - 3 lines by petunia_lockwood: the tea is cold but she will not put it down; her mother painted the little roses round its rim; it is the last thing that is wholly hers.

~ house_talk   (asked about the house and what happened)
 - 3 lines by petunia_lockwood: a dinner and then a great deal of noise upstairs; she stirred her tea and the day ended up beginning again; she gets lost mid-sentence and returns to the tea.

~ children   (asked about her children)
 - 3 lines by petunia_lockwood: Sally, who is afraid of monsters under the bed and keeps a doll; baby Arthur, who will not sleep without his blue bear; she always means to go up to them and then her tea is cold and she begins again.

~ insight_ok   (a hero reads the woman behind the manners)
 - 1 Narrator line: her grip tightens at the word husband and the smile stays put like a painted one.
 - 1 line by petunia_lockwood [sly]: a girl in her position was advised to marry well and she did as advised; the children were the only thing in all of it she chose herself.

~ insight_miss   (a hero finds nothing)
 - 1 Narrator line: nothing under her manners that you can read, only weather.

~ appeal_ok   (a hero's gentle words about her little ones reach her)
 - 1 Narrator line: the cup trembles in her hands and the tea ripples.
 - 2 lines by petunia_lockwood [sad]: she hears them speak of her small ones; she had forgotten how much she wanted to hear someone say their names.

~ appeal_miss   (the words do not reach her)
 - 1 Narrator line: she pulls the cup in against her chest and the conversation slides off her like rain off a pane.
 - 2 lines by petunia_lockwood: she thanks them kindly but she thinks she will keep the cup a little longer; perhaps if there were something of the children's to show her, something real.

~ show_both   (the party sets Sally's doll and Arthur's bear in her lap)
 - 1 Narrator line: you set the chipped doll and the blue bear in her lap and she goes very still.
 - 3 lines by petunia_lockwood [sad]: she knows Sally's doll and Arthur's bear at once; her hands are shaking; she cannot remember when she last let go of anything.

~ peace   (she lets go; this is the end of the scene)
 - 3 lines by petunia_lockwood [smile]: she gives up the cup and says it was only ever tea; she tells them of the quiet life she wanted (a small garden, a husband who read aloud, a fire) and thanks them for being so patient with a tiresome hostess.
 - 2 Narrator lines: she fades like breath off a window, the cup warm in your hand at last, and on the chair where she sat a faded green ribbon lies in a small coil.

~ threat   (a hero warns her they will take the cup by force)
 - 1 Narrator line: the glass room turns cold enough that the tea in her cup skins with frost.
 - 2 lines by petunia_lockwood [angry]: icy, not shrill; she will not be shouted at in her own house, and the polite caller is gone.

~ grab   (a hero reaches for the cup)
 - 1 Narrator line: your fingers are an inch from the porcelain when the whole room goes dark at the edges.
 - 1 line by petunia_lockwood [angry]: a cold, outraged "How dare you."

~ cup_held   (the cup prop examined while she still holds it)
 - 1 Narrator line: the cup rests in her hands, and she holds it the way a person holds a candle in a draught.

~ cup_after_fight   (the quiet after the wight is destroyed; these are caption lines over two soft pictures, so keep them gentle and not graphic: never describe the body)
 - 1 Narrator line: the green ribbon slips its knot and falls, and the room goes quiet.
 - 1 Narrator line: the cup rolls from her fingers across the tiles and stops against your boot, whole.

~ ribbon_take   (a hero picks up the green ribbon lying where she sat)
 - 2 Narrator lines: the faded silk is soft and still faintly warm; you wind it round your fingers and it smells of bergamot.

~ cup_empty   (examining the empty chair after she is gone)
 - 1 Narrator line: the chair holds the shape of someone and nothing else; the bergamot tree breathes out its sweet smell anyway.

Keep every Narrator line fresh: do not repeat an image from another line.
