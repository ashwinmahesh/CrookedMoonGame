Reply with plain text only: no JSON, no code fences, no commentary before or after. Do not send messages to anyone else.

You are drafting dialogue for a Halloween D&D video game, "The Crooked Moon" (an original story; use only the names and facts given here and invent no new people, places, monsters or history). The player leads a party of four adventurers; never name, describe, gender or give a face to them. The setting is the Druskenvald estate, a manor on a hill above the village of Wickermoor Hollow, in an autumn that never ends. Tonight the manor has warped into a crooked, haunted house and a storm has shut the party inside. Long ago the head of the house, Eustace Lockwood, murdered his household; their ghosts remain, and each one still guards a keepsake the party needs.

SCENE: the round gallery on the ground floor, a room of paintings, busts and trophies. The shade of Keziah Endicott (speaker id: keziah_endicott) haunts it: she was a painter, a taxidermist and a breeder of albino peafowl, and the mother of Petunia Lockwood (the lady of the house, who was married to Eustace). Her paintings are dream-paintings; inside them, if you look closely, tiny pink-eyed weasels hide in the painted skies and corners (they belong to the vermin coven behind the haunting; Keziah merely tolerates them). In the middle of the gallery a marble peacock statue guards a bloodstone set in its tail. When the party tries to pry the stone free the statue wakes and attacks (that fight is handled elsewhere). During that fight Keziah's twisted shade appears every round, delighted by the carnage, and now and then reaches out and pulls a hero into one of her paintings for a moment, dropping them out again afterwards. When the peacock finally crumbles she vanishes.

VOICES:
- Keziah: dry, amused, old money, a languid grande dame. Imperious endearments ("darling", "dear", "my pets"), a painter's and a taxidermist's eye for everything (composition, light, pose, stuffing), faintly cruel and fond at once; a twisted cackle now and then, written out sparingly as "Heh heh heh" or "Ah ha ha" (no more than three times in all). No phonetic dialect spelling. Never states a fact the party has not earned. Never mention how she died.
- Narrator: the Vagrant, an old train conductor telling this tale afterwards in a folksy, warm, wry Southern drawl: word choice and rhythm (reckon, ain't, folks, a spell, a piece, y'all), and drop a final g ("flickerin'") in about one Narrator line in three, not more. Narrator rules: second person ("you"), present tense, one or two sentences, under about 30 words, concrete senses (a smell, a sound, a cold) over adjectives, no game words (no HP, roll, check, save, level, DC, fight, turn), never tell the player what to feel, never the word "suddenly", no facts the party could not perceive. Never mention a fiddle. Do not use {name}.

FORMAT (exactly this, nothing else): for each node, a row "~ node_id" followed by one row per line: "speaker_id [mood]: Text". Moods allowed: neutral, smile, angry, afraid, sad, sly, weary (the mood is optional; Narrator lines take none: "Narrator: Text"). Plain punctuation only: straight quotes, no em dashes, no asterisks, no markdown, no stage directions in brackets, no placeholders. A character line is one or two short sentences, under about 26 words. Do not write options, menus or any mechanical rows; the game's wiring is added afterwards. For "interject" rows write exactly "interject class:wizard: Text" with the class named (a hero of that class says it, in the first person, one short dry or uneasy sentence).

NODES TO WRITE (counts are exact):

~ paintings   (a hero examines the dream-paintings on the gallery walls)
 - 2 Narrator lines: the canvases are dream-skies and impossible shores, the paint still looking wet; the longer you look, the more the colours seem to move.
 - 1 line by keziah_endicott [sly]: a dry voice out of the empty air, remarking that the dears have an eye; a painter knows when she is being studied.
 - 1 interject row by class:wizard, 1 by class:ranger.

~ paintings_look_ok   (a hero looks closely at the paintings and sees the weasels)
 - 1 Narrator line: tucked into a painted cloud, then another, then a dozen, are small pink eyes in small narrow faces, watching you back.
 - 2 lines by keziah_endicott [sly]: they crawl in at night, one can never keep the vermin out of one's skies; she tolerates them as one tolerates lodgers, and she does not care to say who sent them.

~ paintings_look_miss   (a hero finds only paint)
 - 1 Narrator line: you see skies, shores and clouds, beautifully done, and nothing in them but paint.

~ peacock_round   (five separate lines said by Keziah, ONE PER ROUND of the peacock fight, in order; each stands alone, with no reference to the other lines; she appears in the air each round as a pale grinning shade)
 - 5 lines by keziah_endicott: (1) a delighted greeting: mind the tail, she spent a whole season on those feathers; (2) she critiques the heroes' stance like a painter posing a portrait; (3) a twisted cackle and a remark about how marble keeps so much better than flesh; (4) amused, almost affectionate: you are so very lively, it is a pity to waste such colour on a stone bird; (5) imperious and impatient: hold still, a portrait wants patience and she has all the time there is.

~ peacock_pull   (she pulls one hero into a painting)
 - 1 line by keziah_endicott [sly]: a delighted order that this one will do nicely in the frame.
 - 1 Narrator line: a cold hand closes on you from nowhere and the room tilts, colours smearing, until you are inside a painted sky with oil paint in your nose.

~ peacock_return   (she drops the hero back out)
 - 1 line by keziah_endicott: a bored apology that the composition did not quite work; out you pop.
 - 1 Narrator line: the sky peels away like wet paper and drops you on the gallery floor, the taste of linseed in your mouth.

~ peacock_fall   (the peacock crumbles; she vanishes)
 - 3 lines by keziah_endicott: a last drawling compliment (a fine bit of work, for such crude hands); she says her peacock was always the best-behaved of her pets; and a fading, amused farewell that the paintings will keep, they always do.
 - 2 Narrator lines: the marble bird goes to dust and gravel, a shower of grey pebbles ringing across the floor; the pale shade in the air thins out like smoke from a snuffed candle, grinning to the last.

Keep every Narrator line fresh: do not repeat an image from another line.
