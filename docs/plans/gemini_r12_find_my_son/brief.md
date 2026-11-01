Reply with plain text only: no JSON, no code fences, no commentary before or after. Do not send messages to anyone else.

You are drafting dialogue for a Halloween D&D video game, "The Crooked Moon" (an original story; use only the names given here and invent no new people, places, monsters or history). The player leads a party of four adventurers; never name, describe or gender them, and never describe their faces. Setting: Wickermoor Village, in a valley in an autumn that never ends.

SCENE: in the village square (the Founder's Round) the party speaks to Old Rusty, the village groundskeeper who sweeps the Round with a birch broom. He is wild-bearded and wild-haired (red-grey), filthy, with darting eyes, an old white scar splitting his scalp beneath the hair, and he speaks only in broken phrases, nursery rhymes and riddles. He has no idea who he is. His lines in the village so far, to match in voice and not to repeat: "Step on a crack, break the moon's back. Wipe your boots before you tread the Round, strangers." / "Leaves fall down, faces look down. What do you want with an old broom?" / "Sweep the stone, keep the bone." / "Crooked beam, crooked stair, nobody left to sit in the chair. Don't go up the hill, don't knock on the door." / "Wind in the gorse, nothing worse. Mind where you put your heels, I just swept there."

The party carries a dead man's last request. In a haunted house on the hill, the spirit of the butler Joseph Patrini, who loved music, asked them to find his son, who lives. The party suspects Old Rusty may be that son, and has come to say the name to him. Old Rusty IS Francis Patrini, Joseph's son, the one survivor of a massacre at the house long ago; he does not know it, and the game never says it outright here. When he hears the name Patrini, something moves in him: he does not know why, he will not understand, but a door half opens. He should not recover his memory or explain anything; he only half-remembers, in fragments (a tune played up and down stairs, a hand on his hair, a woman's voice calling him in), and goes back to his sweeping a little changed, standing straighter. A later chapter will give him a blessing; do not mention it.

NARRATOR: the Vagrant, an old train conductor telling this tale afterwards in a folksy, warm, wry Southern drawl: word choice and rhythm (reckon, ain't, folks, a spell, a piece, y'all), and drop a final g ("sweepin'") in about one line in three, not more. Narrator rules: second person ("you"), present tense, one or two sentences, concrete senses (a smell, a sound, a cold), no game words (no HP, roll, check, save, level, DC), never tell the player what to feel, never the word "suddenly", no facts the party could not perceive. Never mention a fiddle. Do not use {name}.

FORMAT (exactly this, nothing else): for each node, a row "~ node_id" followed by one row per line: "speaker_id [mood]: Text". The speaker id for Old Rusty is old_rusty. Moods allowed: neutral, smile, angry, afraid, sad, sly, weary (the mood is optional; Narrator lines take none: "Narrator: Text"). Plain punctuation only: straight quotes, no em dashes, no asterisks, no markdown, no stage directions in brackets, no placeholders. A line is one or two short sentences, under about 28 words. Do not write options, menus or any mechanical rows; the game's wiring is added afterwards.

NODES TO WRITE (counts are exact):

~ start   (the party approaches him carrying the request)
 - 2 Narrator lines: the broom's slow scrape on the cobbles, the smell of damp leaves and woodsmoke; he does not look up until you are almost on his boots.
 - 2 lines by old_rusty: his usual greeting, in a rhyme, new words; a nonsense warning about the cracks in the stones.

~ before   (asked where he was before the Round)
 - 3 lines by old_rusty: a riddling answer that tells nothing: he was in the wind, he was in the broom, before the broom was the stairs; he will not say more; he sweeps.

~ scar_ok   (a hero studies the scar and sees something true)
 - 1 Narrator line: the scar is old and white and neatly healed; a long time ago someone stitched it with a steady hand and cared that it should heal.

~ scar_missed
 - 1 Narrator line: a wild thatch of hair and an old white seam under it, and nothing else you can make of him.

~ told_rusty   (the party says the name Patrini to him, slowly)
 - 2 Narrator lines: the broom stops mid-stroke; for the first time his eyes stay on yours and do not dart.
 - 5 lines by old_rusty: he repeats the name over and over like a tune; fragments: someone played, someone always played, up and down the stairs, the little tune; a hand on his hair; a woman's voice calling him in out of the rain; he does not understand why his face is wet. Never say he is Francis or a son.
 - 2 Narrator lines: he goes back to his sweeping, but he stands straighter and hums as he sweeps, and the tune is almost a tune.

~ again   (the party speaks to him again after being told)
 - 2 lines by old_rusty: a gentler rhyme, with the hummed tune in it; he thanks them in his own way ("a name is a good broom").

Keep every line distinct. Old Rusty's rhymes must be original; do not quote existing nursery rhymes.
