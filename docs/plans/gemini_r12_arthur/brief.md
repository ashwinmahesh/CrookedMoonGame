Reply with plain text only: no JSON, no code fences, no commentary before or after. Do not send messages to anyone else.

You are drafting dialogue for a Halloween D&D video game, "The Crooked Moon" (an original story; use only the names and facts given here and invent no new people, places, monsters or history). The player leads a party of four adventurers; never name, describe, gender or give a face to them. The setting is the Druskenvald estate, a manor on a hill above the village of Wickermoor Hollow, in an autumn that never ends. Tonight the manor has warped into a crooked, haunted house and a storm has shut the party inside. Long ago the head of the house, Eustace Lockwood, murdered his household; their ghosts remain, and each one still guards a keepsake the party needs.

SCENE: the nursery at the top of the house: a mahogany crib, a rocking horse, a shelf of stuffed toys, a cold lamp. Over the crib floats a blue, glowing, see-through baby, Arthur Lockwood (speaker id: arthur_lockwood), a ghost infant, wailing without end. The wail runs through every floor of the house like a draught. What he wants is his blue teddy bear. The party takes the bear from the crib (the stuffed toys on the shelf come alive to stop them, that is handled elsewhere); then it is theirs to hold. The party can calm Arthur with soft words, or by singing him a lullaby, or by sitting with him and the bear; calmed, he falls asleep in their arms and fades, and the bear stays with the party as a keepsake. Arthur cannot speak: his lines are only wails and baby sounds (a few words of babble, "ba", "mama"-like sounds are fine); the Narrator carries the story. One hero among the party once heard a lament played on a harpsichord downstairs; the tune comes back to them, a gift if they sing it.

VOICES:
- Arthur: wails, hiccups, gurgles, one or two syllables at a time ("Waaah... ba... ba!"). Never real sentences. Keep each of his lines to a few sounds.
- Narrator: the Vagrant, an old train conductor telling this tale afterwards in a folksy, warm, wry Southern drawl: word choice and rhythm (reckon, ain't, folks, a spell, a piece, y'all), and drop a final g ("flickerin'") in about one Narrator line in three, not more. Narrator rules: second person ("you"), present tense, one or two sentences, under about 30 words, concrete senses (a smell, a sound, a cold) over adjectives, no game words (no HP, roll, check, save, level, DC, fight), never tell the player what to feel, never the word "suddenly", no facts the party could not perceive. Never mention a fiddle. Do not use {name}. Tender with the infant: no horror at his expense. Do not say where the bear is in the room in nodes where it is not stated (the bear may be in your hands or not).

FORMAT (exactly this, nothing else): for each node, a row "~ node_id" followed by one row per line: "speaker_id [mood]: Text". Moods allowed: neutral, smile, angry, afraid, sad, sly, weary (the mood is optional; Narrator lines take none: "Narrator: Text"). Plain punctuation only: straight quotes, no em dashes, no asterisks, no markdown, no stage directions in brackets, no placeholders. A Narrator line is one or two short sentences. Do not write options, menus or any mechanical rows; the game's wiring is added afterwards. For "interject" rows write exactly "interject class:cleric: Text" with the class named (a hero of that class says it, in the first person, one short tender or uneasy sentence).

NODES TO WRITE (counts are exact):

~ wail   (the party stands before him and has no bear in hand)
 - 3 Narrator lines: the wail as something you feel in your teeth and the floorboards; the small blue ghost over the crib, tears running upward; his tiny hands closing on air as if reaching for something.
 - 2 lines by arthur_lockwood [sad]: wails and a broken "ba... ba!" (no real words).
 - 1 interject row by class:cleric, 1 by class:fighter.

~ hush_empty   (a hero tries talking to him and it does nothing)
 - 1 Narrator line: your words go in one ear and out of the wail; a baby wants what a baby wants.

~ calm   (the party holds the bear and stands before him)
 - 2 Narrator lines: the bear in your hands is old, one button eye hanging by a thread; the wail climbs a note and then stops to look at it.
 - 1 line by arthur_lockwood [sad]: a hiccup and a small "ba?" reaching out.

~ calm_ok   (soft steady words reach him)
 - 2 Narrator lines: you pitch your voice low and even as a banked stove; the wail unravels into long shaky breaths.
 - 1 line by arthur_lockwood [smile]: a gurgle and a sleepy "ba".

~ calm_miss   (the words do not take; the wail grows)
 - 1 Narrator line: the wail swells and the house shivers around you, windows humming in their frames.
 - 1 line by arthur_lockwood [afraid]: a thin rising "waaah!"

~ lullaby_ok   (a sung lullaby reaches him)
 - 2 Narrator lines: the song goes out thin and plain, and the cold lamp seems to lean in to hear it; the blue light in the baby settles from a boil to a simmer.
 - 1 line by arthur_lockwood [smile]: a soft coo.

~ lullaby_ok_lament   (a hero who heard the harpsichord lament below sings it as a lullaby; shown after lullaby_ok)
 - 1 Narrator line: halfway through, the tune you carried up from the music room finds its own way into the song, and the baby's eyes follow it down.

~ lullaby_miss   (the song falls flat)
 - 1 Narrator line: your voice cracks on the third bar and the wail comes back louder, rattling the shelf of stuffed toys.
 - 1 line by arthur_lockwood [afraid]: an offended "waaah!"

~ patient   (a hero simply sits with him and the bear and waits it out; time passes)
 - 3 Narrator lines: you sit on the floor with the bear in your lap and say nothing clever; an hour goes by in small shushing sounds; the wail runs down, one breath at a time, like a clock nobody winds.
 - 1 line by arthur_lockwood [weary]: a long shuddering sigh and a tiny "ba".

~ asleep_1   (caption over a picture of a hero's arms, no face, cradling the glowing infant; he is asleep)
 - 2 Narrator lines: he settles into your arms as light as lamp-glow, one hand wrapped round a button eye; for the first time in a long age the house is quiet.

~ asleep_2   (caption over a picture of empty arms and blue motes drifting up past the empty cradle)
 - 2 Narrator lines: he thins until you are holding only warmth, then the warmth lifts away in small blue sparks; and the bear is in your hands again, a good deal heavier than it looks.
 - 1 line by arthur_lockwood [smile]: one faint, fading "ba".

~ done   (the room after he is gone)
 - 1 Narrator line: the crib is only a crib, the nursery as still as a held breath, and a faint smell of milk and lamp oil hangs in it.

Keep every Narrator line fresh: do not repeat an image from another line.
