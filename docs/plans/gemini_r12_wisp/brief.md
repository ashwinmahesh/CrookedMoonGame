Reply with plain text only: no JSON, no code fences, no commentary before or after. Do not send messages to anyone else.

You are drafting dialogue for a Halloween D&D video game, "The Crooked Moon" (an original story; use only the names and facts given here and invent no new people, places, monsters or history). The player leads a party of four adventurers; never name, describe, gender or give a face to them. The setting is the Druskenvald estate, a manor on a hill above the village of Wickermoor Hollow, in an autumn that never ends. Tonight the manor has warped into a crooked, haunted house and a storm has shut the party inside.

SCENE: the library on the third floor: shelves, a reading desk, a liquor cart. On the desk sits a grey estate cat with golden eyes beside a stack of three empty books. The cat is Wisp (speaker id: wisp), really a malicious fey creature in a cat's shape, a minion of the hag behind the haunting. He speaks with a stolen voice: the warm, handsome, friendly voice of a mute man named Walter (Walter Jenkin, the estate caretaker, whose voice Wisp took). Wisp is all charm and lies. He wants the party to tell him tales, three of them, one for each empty book: each book he fills with the story, in words and pictures. What he does not say: a story told into his book leaves a thread of the teller in the page, which he can pull later to turn them against their friends. In return for the three tales he offers a boon (a rest that mends and refreshes them). He cannot resist a riddle (his secret): a clever riddle holds him fascinated and makes him blurt the truth. If threatened he drops the cat shape, shows a long wrong-jointed grey true form, and flees through the window; if the party attacks him, a fight starts.

VOICES:
- Wisp: silken, warm, flattering, self-satisfied; a charming host who never answers a question straight; uses "my dear friends", "do sit", "how delightful"; lies fluently and smiles while he lies; his charm cools to contempt only when exposed. No cat noises. He never admits he is not a cat until threatened. Never mention a hag or any name for her; if he must, he says "my lady" and nothing more. Never state his plan flatly except in riddle_ok.
- Narrator: the Vagrant, an old train conductor telling this tale afterwards in a folksy, warm, wry Southern drawl: word choice and rhythm (reckon, ain't, folks, a spell, a piece, y'all), and drop a final g ("flickerin'") in about one Narrator line in three, not more. Narrator rules: second person ("you"), present tense, one or two sentences, under about 30 words, concrete senses (a smell, a sound, a cold) over adjectives, no game words (no HP, roll, check, save, level, DC, fight, turn, Hit Dice), never tell the player what to feel, never the word "suddenly", no facts the party could not perceive. Never mention a fiddle. Do not use {name}. The Narrator can notice small wrongness (a man's warm voice from a cat's muzzle, a jaw that does not match the words) but never says what Wisp is.

FORMAT (exactly this, nothing else): for each node, a row "~ node_id" followed by one row per line: "speaker_id [mood]: Text". Moods allowed: neutral, smile, angry, afraid, sad, sly, weary (the mood is optional; Narrator lines take none: "Narrator: Text"). Plain punctuation only: straight quotes, no em dashes, no asterisks, no markdown, no stage directions in brackets, no placeholders. A character line is one or two short sentences, under about 28 words. Do not write options, menus or any mechanical rows; the game's wiring is added afterwards. For "interject" rows write exactly "interject class:rogue: Text" with the class named (a hero of that class says it, in the first person, one short dry or uneasy sentence).

NODES TO WRITE (counts are exact):

~ start   (the first sight of him)
 - 2 Narrator lines: the library at the top of the house (dust, old paper, a cold hearth) and the grey cat sitting upright on the desk beside three empty books, golden eyes following you; the voice that speaks is a warm man's voice, and it comes from a cat.
 - 3 lines by wisp [smile]: a delighted welcome; he has so longed for company; he is the keeper of the estate's library, and what a pleasure to find readers at last.
 - 1 interject row by class:rogue, 1 by class:cleric.

~ return   (they come back to him)
 - 2 lines by wisp [smile]: how delightful, his friends are back; the books wait, and so does he.

~ who   (asked who he is)
 - 3 lines by wisp [smile]: just the estate's cat, the keeper of its stories, a poor old library cat with a love of tales; nothing to be afraid of.

~ voice   (asked why he sounds like a man)
 - 3 lines by wisp [sly]: he is a gift of the house; the house is generous with voices; a lovely gift to give to a cat.
 - 1 Narrator line: the muzzle moves a half beat after the words, the way a puppet's does.

~ ask_tale   (asked what he wants)
 - 3 lines by wisp [smile]: three tales, for the three books on the desk; each teller says their story in their own words and he writes it down in words and pictures; in return he will give them a rest like no rest they have had.

~ insight_ok   (a hero reads him and sees the malice)
 - 2 Narrator lines: behind the golden eyes there is no warmth, only appetite; the smile is a thing he wears on top of a bigger smile underneath.

~ insight_miss   (a hero cannot read him)
 - 1 Narrator line: a handsome voice and a cat's yawn and nothing you can put a finger on.

~ riddle_ok   (a hero poses a riddle he cannot resist; he is held fascinated and blurts the truth)
 - 2 Narrator lines: the golden eyes go wide and fixed, his tail stops dead, and he turns the riddle over and over the way a dog worries a bone.
 - 4 lines by wisp [angry]: muttering at the riddle, he cannot leave it alone; in his distraction he blurts that the voice is borrowed from the caretaker who has no further use of it; that a story told into the page leaves a thread of the teller in it; that threads are handy for whoever holds the books.
 - 1 line by wisp [sly]: he recovers and smiles again; clever friends, but cleverness changes nothing; the books are still open.

~ riddle_miss   (the riddle does not hold him)
 - 1 Narrator line: he lets the riddle go by with one idle flick of an ear.
 - 2 lines by wisp [sly]: he laughs warmly and says it was almost clever; he is far too old a cat for that kind of game.

~ tales_first   (before the first tale)
 - 2 lines by wisp [smile]: he opens the first book; which of his friends will be first to tell?

~ tales_second   (before the second tale)
 - 2 lines by wisp [smile]: one book is full; he purrs without a purr; he is ready for the second.

~ tales_third   (before the third tale)
 - 2 lines by wisp [smile]: two books are full and one to go; he trembles to hear the last.

~ perf_1_ok   (a hero tells a hushed ghost story, well)
 - 1 Narrator line: you lower your voice and the lamps seem to lean in; the pages turn on their own and ink writes itself across them in words and little pictures.
 - 1 line by wisp [smile]: delighted flattery of the telling.
~ perf_1_miss   (told badly)
 - 1 Narrator line: your ghost story limps; the pages stay blank and a candle gutters out unhelped.
 - 1 line by wisp [smile]: polite, thinly disguised disappointment.

~ perf_2_ok   (a hero acts out a comic tale about a clever fox, well)
 - 1 Narrator line: you play every part and the books quiver with laughter; ink runs down the page in loops and fox-shaped pictures.
 - 1 line by wisp [smile]: delighted flattery.
~ perf_2_miss   (flat)
 - 1 Narrator line: your fox trips over its own tail and the joke dies on the desk.
 - 1 line by wisp [smile]: polite, thinly disguised disappointment.

~ perf_3_ok   (a hero sings a ballad, well)
 - 1 Narrator line: the ballad goes out true and slow, and the book drinks it, every verse becoming a line of ink and a small drawing of a road.
 - 1 line by wisp [smile]: delighted flattery.
~ perf_3_miss   (flat)
 - 1 Narrator line: a verse goes sour and the third line falls out of your head entirely.
 - 1 line by wisp [smile]: polite, thinly disguised disappointment.

~ hist_1_ok   (a hero tells the true old tale of a siege won by a trick, well)
 - 1 Narrator line: the old siege comes out in order, wall by wall, and the book fills with maps and arrows and tiny banners.
 - 1 line by wisp [smile]: delighted flattery.
~ hist_1_miss   (muddled)
 - 1 Narrator line: you get the dates tangled and the siege falls over itself; the page stays white.
 - 1 line by wisp [smile]: polite, thinly disguised disappointment.

~ hist_2_ok   (a hero tells the tale of a lost crown, well)
 - 1 Narrator line: the lost crown travels from hand to hand across the page, a gleam of gold ink following it from king to thief to river.
 - 1 line by wisp [smile]: delighted flattery.
~ hist_2_miss   (muddled)
 - 1 Narrator line: you lose the crown somewhere in the middle and have to go back for it, and the book yawns.
 - 1 line by wisp [smile]: polite, thinly disguised disappointment.

~ hist_3_ok   (a hero tells how a town got its name, well)
 - 1 Narrator line: you tell how a town came by its name, and little roofs and a well rise on the page as the words settle.
 - 1 line by wisp [smile]: delighted flattery.
~ hist_3_miss   (muddled)
 - 1 Narrator line: you reach for the name of the town and come up with a different town entirely, and the page stays empty.
 - 1 line by wisp [smile]: polite, thinly disguised disappointment.

~ tale_first_done   (after the first book fills)
 - 1 Narrator line: the first book shuts itself with a soft clap and settles on the pile as if it had always been there.

~ tale_second_done   (after the second book fills)
 - 1 Narrator line: the second book closes with a sigh of paper, and the pile on the desk is one book from finished.

~ finale   (the third book fills; he thanks them and winks out; this is the end of the scene)
 - 3 lines by wisp [smile]: warm, exaggerated thanks; the library has not been so well fed in an age; he must go now, his friends are kindness itself.
 - 2 Narrator lines: the cat blinks once, slowly, and the whole shape of him goes out like a blown candle, leaving a warm hollow on the desk and a smell of cold smoke.
 - 2 Narrator lines: then the rest he promised comes over you in a slow wave: weariness lifting, aches easing, breath coming deep, as if you had slept a night in a good bed.
 - 1 Narrator line: and under that comfort sits one small unease, like a splinter you can't find, because that thanks was a shade too sweet.

~ threat   (a hero threatens him; he drops the cat shape and flees through the window; this is the end of the scene)
 - 2 Narrator lines: the cat's outline stretches and loosens, grey fur running like smoke into something long and wrong-jointed with too many bends, and the golden eyes burn.
 - 2 lines by wisp [angry]: in the same warm man's voice, now cold and spiteful, he says they have made a mistake and he never forgets a face.
 - 1 Narrator line: the long grey shape goes through the window glass without breaking it, and the cold night eats the sound of him.

~ attack   (a hero draws a weapon on him; combat follows)
 - 1 Narrator line: the cat's back arches and the smile slides off the man's voice.
 - 1 line by wisp [angry]: a spitting, warm-voiced "You will regret that."

~ refuse   (the party refuses him outright)
 - 2 lines by wisp [sly]: he is wounded, quite wounded, but the books will keep; his door is always open to friends who change their minds.

~ gone   (the desk after he has fled or gone)
 - 1 Narrator line: the desk is bare but for a scatter of grey hairs and a ring in the dust where a cat sat.

Keep every Narrator line fresh: do not repeat an image from another line.
