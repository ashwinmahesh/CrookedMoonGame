Reply with plain text only: no JSON, no code fences, no commentary before or after. Do not send messages to anyone else.

You are drafting dialogue for a Halloween D&D video game, "The Crooked Moon" (an original story; use only the names given here and invent no new people, places, monsters or history). The player leads a party of four adventurers; never name, describe or gender them, and never describe their faces. The setting is Wickermoor Hollow, a country valley in an autumn that never ends, with a village and a manor on the hill above it.

SCENE: dusk at the gate of Druskenvald Estate, a manor on the hill. The Lord and Lady of the manor (Phillip and Adela Druskenvald, who came to the valley yesterday) invited the party to dinner tonight. At the gate the party meets the two caretakers, Gilly Jenkin and her husband Walter Jenkin, who are just leaving for the village for supplies and for a book their ten-year-old daughter Dani has asked for (Dani is down in the village tonight, being minded; do not say by whom). The manor behind them looks tidy and welcoming, every window lit. Gilly and Walter met the Lord and Lady last evening and have not seen them tonight (the lamps are lit and no one answers a knock). Both are fond of the village and of the mayor, Wendel Somerton, who lent the house to the Druskenvalds; Walter reveres the mayor. A grey estate cat called Wisp also lives about the grounds; Gilly thinks of him as an ordinary cat, but Dani's dog Shuck cannot abide him. Under the cheer, Walter is afraid of the house and never says so.

IMPORTANT: Walter has NO spoken lines. He lost his voice and signs and writes in a worn pocket notebook. Whenever Walter "speaks", write it as a Narrator line that shows his notebook, for example: Narrator: Walter turns his notebook toward you; in a tidy hand it says: Lamp oil, candles, the mayor's regards. Keep what he writes short, polite and cheerful; his fear shows only in how he writes (a pressed-hard pencil, a crossed-out word), never in what the words say.

The scene is a short talk (it is not a quest and nothing in it is a fight). At the end the two walk off down the hill. A moment later the estate cat walks out of the bushes by the gatepost, stares at each of the four heroes in turn with golden eyes, sneers (a cat sneer: lip, whisker, a look), and leaves. The cat NEVER speaks in this scene. Then the whole manor warps in the dusk: roofs and eaves slump at impossible angles, mould climbs the walls, petals fall, and a tall, lanky crooked figure waves from the porch under a storm front. The player sees two full-screen pictures for that: first the tidy manor in early-night light with flowers by the porch and the caretakers' barn behind it; then the same view warped, with the lanky figure waving from the porch. Your Narrator lines for those two pictures read as captions on them.

VOICES:
- Gilly (speaker id gilly_jenkin): warm, quick, protective, rural West Country English. Contractions, "my lover", "my lovelies", "proper", "ent", "'tis", "bless", the odd dropped letter. Keep it readable and never a cartoon; most lines should be plain warm English with a West Country turn of phrase. She chatters, she fusses, she is anxious about Dani.
- Narrator: the Vagrant, an old train conductor telling this tale afterwards in a folksy, warm, wry Southern drawl: word choice and rhythm (reckon, ain't, folks, a spell, a piece, y'all), and drop a final g ("flickerin'") in about one line in three, not more. Narrator rules: second person ("you"), present tense, one or two sentences, concrete senses (a smell, a sound, a cold), no game words (no HP, roll, check, save, level, DC), never tell the player what to feel, never the word "suddenly", no facts the party could not perceive. Never mention a fiddle. Do not use {name}.

FORMAT (exactly this, nothing else): for each node, a row "~ node_id" followed by one row per line: "speaker_id [mood]: Text". Moods allowed: neutral, smile, angry, afraid, sad, sly, weary (the mood is optional; Narrator lines take none: "Narrator: Text"). Plain punctuation only: straight quotes, no em dashes, no asterisks, no markdown, no stage directions in brackets, no placeholders. A line is one or two short sentences, under about 28 words. Do not write options, menus or any mechanical rows; the game's wiring is added afterwards. For the "interject" rows write exactly "interject class:rogue: Text" with the class named (a hero of that class says it).

NODES TO WRITE (counts are exact):

~ start   (the meeting at the gate)
 - 2 Narrator lines: the gate at dusk, a lantern, two figures with a covered basket, the lit manor behind them.
 - 3 lines by gilly_jenkin: a warm quick greeting of the guests, mentioning the Lord and Lady are expecting them, and that she and Walter must not keep them standing in the damp.
 - 1 Narrator line: Walter touches his cap and holds up his notebook with a short greeting written in it.

~ going   (asked where they are headed)
 - 3 lines by gilly_jenkin: down to the village for supplies, and a book Dani has set her heart on; Dani is down there tonight, being minded; she frets a little.
 - 1 Narrator line: Walter's notebook, a short list of what they need from town.

~ couple   (asked whether they have seen the Lord and Lady tonight)
 - 3 lines by gilly_jenkin: met the pair last evening, lovely and grand, but not seen them tonight; the lamps are lit, a knock gets no answer, she supposes they are resting after the journey; she is a touch uneasy but laughs it off.
 - 1 Narrator line: Walter's notebook, a calm, cheerful note that the table is laid and the lamps are lit, and the guests are to make themselves at home.

~ house   (asked what the house is like)
 - 3 lines by gilly_jenkin: she is proud of the house and fond of the village; the mayor was so kind to lend it; it has been aired and polished for weeks; a faint dry remark that it has "its ways" like any old place.
 - 1 Narrator line: Walter's notebook, a respectful line about Mayor Somerton.

~ walter_sees   (the party noticed Walter's nerves: a good look at him)
 - 1 Narrator line: Walter's pencil starts a different sentence, stops after two words, and he turns the page on it; his hand will not finish it.
 - 1 line by gilly_jenkin: she pats his arm and brightens it over, saying he is only tired.

~ walter_misses   (the party studied Walter and saw nothing)
 - 1 Narrator line: a smiling man with a steady pencil, and nothing under the smile that you can read.

~ leaving   (the party says they will go up to the house; the two take their leave)
 - 2 lines by gilly_jenkin: the door is on the latch, go on up, they will see them on the morrow; mind the porch boards.
 - 1 Narrator line: Walter's notebook, a neat goodnight.
 - 2 Narrator lines: the pair go off down the hill road, the lantern bobbing smaller, until the dark closes over it; only then does the gatepost bush shiver, as though something had waited.

~ after   (the cat, then the warping)
 - 4 Narrator lines: a grey cat with golden eyes steps out of the bushes; it looks at each of you in turn, long and unhurried, like a clerk reading a list; its lip curls in a sneer; it walks off into the dark. (Make the stare feel too knowing for a cat. Do not say it is anything but a cat.)
 - 3 interject rows by class (rogue, fighter, wizard): each hero-voice reaction to the cat, one short sentence, in the first person, dry or uneasy.
 - 1 Narrator line (caption for the FIRST picture): the manor in early-night light, tidy and warm, flowers by the porch, the barn behind it.
 - 2 Narrator lines (captions for the SECOND picture, with a first line about the nausea or the ground tilting under you): the manor twists, roofs slump, mould climbs, petals fall, and on the porch a tall crooked figure lifts a hand and waves.

Keep every Narrator line fresh: do not repeat an image from another line.
