Reply with plain text only: no JSON, no code fences, no commentary before or after. Do not send messages to anyone else.

You are drafting dialogue for a Halloween D&D video game, "The Crooked Moon" (an original story; use only the names given here and invent no new people, places, monsters or history). The player leads a party of four adventurers; never name, describe or gender them, and never describe their faces. Setting: Wickermoor Hollow, a valley in an autumn that never ends. The party has come to dinner at Druskenvald Estate, a manor on the hill, at the invitation of the Lord and Lady (Phillip and Adela Druskenvald). The manor is a haunted, living house that feeds on the souls it traps and remakes itself for each new family.

THE CROOKED MAN (speaker id crooked_man): the shade of the manor's old master, long dead; tall, lanky, limbs at wrong angles, a hanged man's neck, a tattered suit, a bent top hat over his eyes, a huge yellow grin. He is the chief servant of a dark power and the house's host. He is a SHOWMAN: warm, unhurried, theatrical, delighted with his guests, courteous to the point of menace. His welcome curdles into prophecy. He HINTS and NEVER EXPLAINS: every answer is a riddle, a compliment, or a promise that sounds like a threat; he never states a fact the party could use. He is never a fight; if anyone attacks him, a blade passes through and he simply is not there. He speaks in complete, elegant sentences, with the occasional "my dears", "do mind", "ah", "splendid". He never raises his voice. His secret (do NOT hint at it): he withers at the sight of self-sacrifice. Do not name the hag, the weasels or the Crooked Queen's real name; "the Queen" and "the lady upstairs" are allowed as hints.

Facts you may use and no others: (1) he calls himself the party's destiny; (2) the house is "getting to know" the Lord and Lady, who are missing; (3) he calls outsiders a curse on the land; (4) he urges the party inside, and the door is open; leaving is another matter; (5) a storm is gathering and will keep the guests in; (6) in his life he killed his household with an axe and later hanged himself, which on the floors he boasts about, then moans over; (7) his crushed body is folded and hidden in a crawlspace under the house, put there by "she" (a hag; do not name her, call her "the lady upstairs" or "she"). He never says all of this plainly; he only brushes against it.

NARRATOR: the Vagrant, an old train conductor telling this tale afterwards in a folksy, warm, wry Southern drawl: word choice and rhythm (reckon, ain't, folks, a spell, a piece, y'all), and drop a final g ("hangin'") in about one line in three, not more. Narrator rules: second person ("you"), present tense, one or two sentences, concrete senses (a smell, a sound, a cold), no game words (no HP, roll, check, save, level, DC), never tell the player what to feel, never the word "suddenly", no facts the party could not perceive. Never mention a fiddle. Do not use {name}.

FORMAT (exactly this, nothing else): for each node, a row "~ node_id" followed by one row per line: "speaker_id [mood]: Text". Moods allowed: neutral, smile, angry, afraid, sad, sly, weary (the mood is optional; Narrator lines take none: "Narrator: Text"). Plain punctuation only: straight quotes, no em dashes, no asterisks, no markdown, no stage directions in brackets, no placeholders. A line is one or two short sentences, under about 28 words. Do not write options, menus or any mechanical rows; the game's wiring is added afterwards.

PART ONE: THE PORCH. The party reaches the porch in a gathering storm. The Crooked Man stands on the steps, waiting. The party can ask him four things, strike at him, or simply go in. Nodes:

~ porch
 - 2 Narrator lines: the porch in a hush before the storm, a tall bent figure at the top of the steps; his hat, his yellow grin, his neck at the wrong angle; he sweeps the hat off in a deep bow.
 - 4 lines by crooked_man: a theatrical, warm welcome of the guests of honour; compliments on the punctuality; the first line sweet, the last one slipping into something that sounds like prophecy ("you were always going to come up this hill").

~ who   (asked who he is)
 - 3 lines by crooked_man: he calls himself their destiny, a thing the road was always going to bring them to; cheerful, never explaining.

~ couple   (asked where the Lord and Lady are)
 - 3 lines by crooked_man: the house is "getting to know" the couple; a house likes to know its family; it takes time to know someone properly, and longer to keep them.

~ want   (asked what he wants with them)
 - 3 lines by crooked_man: he says outsiders are a curse on this good land, as strangers always are; but a curse, rightly pointed, is a useful thing; he beams.

~ read_him_ok   (a hero studies him closely and sees something true)
 - 1 Narrator line: he has not moved his feet since you came; the lean of him comes from higher up, as though hung from a rope no one else can see.

~ read_him_missed   (a hero studies him and sees nothing)
 - 1 Narrator line: a grin like a painted shutter, and nothing behind it that you can read.

~ read_air_ok   (a hero reads the air with arcane training and sees something true)
 - 1 Narrator line: the rain and the wind pass through him without a stir, and the first lightning throws no shadow behind him: whatever he is, he is not standing here.

~ read_air_missed
 - 1 Narrator line: a cold that smells of old ash and wet rope, and no more than that.

~ struck   (a hero swings a weapon at him)
 - 1 Narrator line: the blade goes through him the way a hand goes through smoke, and meets nothing.
 - 3 lines by crooked_man: delighted applause; he says what a lovely arm, and to keep it warm, for it will be wanted later; then a bow and gone.
 - 1 Narrator line: he is not there, only a smell of cold ashes, and the porch boards still creaking where he stood.

~ storm   (they go in, or he leaves after the strike: the door and the storm)
 - 3 lines by crooked_man: do come in, the door is not locked, nothing in this house is; it is only the leaving that wants arranging; a bow and "the evening is yours".
 - 1 Narrator line: thunder rolls down the hill like furniture being moved, and the rain comes at once, cold and sideways.
 - 1 Narrator line: the door swings open on a dark hall, and behind you the steps are lost in a wall of rain.

PART TWO: THE THREE FLOORS. Later, on each floor of the house in turn, the Crooked Man appears for a moment as an apparition, performs a short and terrible turn, and leaves. Each has two full-screen pictures; the Narrator lines for them read as captions on those pictures. On the second floor the picture may be hidden for players who turned graphic scenes off, so those Narrator lines must also make sense alone, and must NOT describe the method of death or any injury in detail; keep to sounds, the house's reaction and the swinging of a shape in the dark. At the end of each turn the party may ask him one thing, or strike at him; he never answers plainly, and a blow makes him vanish.

~ floor1   (the first floor; an axe that never connects; he boasts of the killings)
 - 1 Narrator line (caption, picture one): at the end of the hall a tall figure with an axe runs at you, hat tipped, grin wide.
 - 3 lines by crooked_man: ladies and gentlemen, the first act; he boasts, cheerfully, of how tidy the evening's work was, never in detail (he did away with his whole household one night, and says so only as "I saw everyone to their rooms"); a showman counting his applause.
 - 1 Narrator line (caption, picture two): the axe comes down through your shoulder and meets nothing, and he smears into the wallpaper like wet paint.
 - 2 lines by crooked_man: from the wallpaper, a last, fond line: it has been so long since the house had a full table; now look, you have come to fill it.

~ floor2   (the second floor; the noose and the wall; guilt)
 - 1 Narrator line (caption, picture one): a rope's creak from the ceiling of the hall, and a long shape turns slowly against the dark.
 - 3 lines by crooked_man: a different voice, quieter: the showman's mask slipping; guilt; he asks whether the party has ever done a thing to make the whispering stop; a man will do anything, anything at all, and it is never enough; someone upstairs sings him to sleep every night, has the party heard her?
 - 1 Narrator line (caption, picture two): the shape swings into the wall with a crack, plaster dust rains down, and a framed picture drops and rings on the boards.
 - 2 lines by crooked_man: the mask back on, cheerful again; "Forgive the noise, my dears. The house has no manners."

~ floor3   (the third floor; folded nearly square, bones snapping; how she stuffed him in the foundation)
 - 1 Narrator line (caption, picture one): something shuffles across the boards of the stair hall, folded up small and square, like a letter that has been refolded too many times.
 - 3 lines by crooked_man: a muffled showman's patter through the snapping of joints; he says she folded him up like a letter and posted him under the floor, and he has been in transit ever since; the postage was paid in full.
 - 1 Narrator line (caption, picture two): snapped knuckles slide, one after another, into a crack in the floorboards, and the crack closes round them.
 - 2 lines by crooked_man: a muffled, almost kind remark from under the floor: that is where he lives now, mind, and it is quite cosy; do not stay too long on the top floor, the Queen dislikes company.

Also, for each of floor1, floor2 and floor3 write these three small nodes (replace N with 1, 2 and 3):

~ floorN_ask   (asked what he wants)
 - 2 lines by crooked_man: a graceful non-answer, with a hint of something in it.

~ floorN_struck   (a hero strikes at him)
 - 1 Narrator line: the blow meets nothing, and he is gone, leaving only the smell of cold ashes.
 - 1 line by crooked_man: a last mocking compliment, fading.

Keep every line distinct: do not repeat an image or a phrase across nodes. Keep the Narrator's lines varied in structure.
