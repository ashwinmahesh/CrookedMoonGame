Reply with plain text only: no JSON, no code fences, no commentary before or after. Do not send messages to anyone else.

You are drafting narration for a Halloween D&D video game, "The Crooked Moon" (an original story; use only the names given here and invent no new people, places, monsters or history). The player leads a party of four adventurers; never name, describe or gender them, and never describe their faces. The party is inside the foyer of Druskenvald Estate, a haunted, warped manor on a hill, during a storm. The foyer is twenty feet high, with a tilted chandelier, a curved stair, a compass rose inlaid in the floor, and every wall hung with portraits whose painted eyes follow you. Three portraits matter. Each has one full-screen picture; your Narrator lines for each read as captions on its picture.

1. THE LOCKWOODS: the old family portrait of the manor's first owners: a father, a mother, a boy, a small girl, a baby, and, standing a pace behind, two servants. The father is unmistakably the Crooked Man, the tall, grinning figure the party met on the porch (tall, lanky, a huge yellow grin). A brass plaque beneath names the whole household: Eustace Lockwood and Petunia Lockwood, their children Sally and Arthur, and in service to the family Joseph Patrini and Gail Patrini.
2. THE DRUSKENVALDS: the current owners, the Lord and Lady who invited the party (Phillip and Adela Druskenvald), who arrived in the valley only yesterday. Adela is stern in a choker of woven wicker and red-orange flowers; Phillip is weeping under a black, six-pointed crown with a crescent-moon pin. The varnish smells fresh. Say nothing that explains the crown.
3. THE PARTY: a portrait of the four heroes themselves in their travelling clothes and gear, painted in; every face is a blank smear with a toothless black grin painted over it. Never describe the heroes' real faces, clothes or gear in particular: say only "travelling clothes" and "gear".

Whoever studies a portrait too long must meet its painted gaze. If they hold it, nothing happens; if they flinch, something cold slides in behind the eyes and a curse takes hold. You write the narration for each outcome. The game rolls the dice; never mention rolls, saves, curses as a game term, damage or numbers.

NARRATOR: the Vagrant, an old train conductor telling this tale afterwards in a folksy, warm, wry Southern drawl: word choice and rhythm (reckon, ain't, folks, a spell, a piece, y'all), and drop a final g ("starin'") in about one line in three, not more. Narrator rules: second person ("you"), present tense, one or two sentences, concrete senses (a smell, a sound, a cold), no game words (no HP, roll, check, save, level, DC), never tell the player what to feel, never the word "suddenly", no facts the party could not perceive. Never mention a fiddle. Do not use {name}.

FORMAT (exactly this, nothing else): for each node, a row "~ node_id" followed by one row per line: "Narrator: Text". A line is one or two short sentences, under about 28 words. Plain punctuation only: straight quotes, no em dashes, no asterisks, no markdown, no stage directions in brackets, no placeholders. For hero reactions write exactly "interject class:rogue: Text" with the class named (a hero of that class says it, in the first person, one dry or uneasy sentence). Do not write options, menus or any mechanical rows.

NODES TO WRITE (counts are exact):

~ lockwood
 - 2 Narrator lines (caption for the Lockwood picture): the family portrait, the father's grin, the eyes that follow you.
 - 1 interject by class fighter.

~ lockwood_plaque   (the party reads the brass plaque)
 - 2 Narrator lines: the plaque, the names in order as given above; a thumb-worn dent beside the last two, the servants'. Do not state anything not given above about any of these people.

~ lockwood_held   (the party holds the painted gaze; nothing happens)
 - 1 Narrator line.

~ lockwood_cursed   (the party flinches; something cold slides in)
 - 1 Narrator line.

~ lockwood_again   (the party looks at it again later; no picture, no danger)
 - 1 Narrator line.

~ druskenvald
 - 2 Narrator lines (caption for the Druskenvald picture): Adela's wicker choker and flowers, Phillip weeping under the black crown, the fresh varnish.
 - 1 interject by class wizard (about the crown, without explaining it).

~ druskenvald_held
 - 1 Narrator line.

~ druskenvald_cursed
 - 1 Narrator line.

~ druskenvald_again
 - 1 Narrator line.

~ party
 - 2 Narrator lines (caption for the party picture): the four of you, your travelling clothes and gear, the blank smeared faces with a toothless black grin painted over each.
 - 1 interject by class rogue.

~ party_held
 - 1 Narrator line.

~ party_cursed
 - 1 Narrator line.

~ party_again
 - 1 Narrator line.

~ look_away   (the party decides not to hold the painted gaze this time and turns from it)
 - 1 Narrator line: you turn from the frame; behind you the painted eyes follow you out of the room.

Make the six held/cursed lines clearly different from one another and from the "again" lines.
