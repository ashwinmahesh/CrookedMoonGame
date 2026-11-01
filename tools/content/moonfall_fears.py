#!/usr/bin/env python3
"""R26 Moonfall: the eight Old Fear conversation files, generated from one pattern (moonfall_common.FEARS) plus per-Fear briefs.
Logic here; the spoken lines are drafted by Gemini from the briefs (moonfall_gemini.py)."""
from moonfall_common import FEARS, fq, fl, fear_flag
from moonfall_dsl import File, S, N, L, O, SK, cut2

# Per-Fear briefs (our own words; the digest is the source). Keys: see fear_file().
FT = {
"headsman": dict(
    hook_who="a Foxwillow farmer, Osric Plow, weathered, scared, gives it straight: neighbours behead neighbours now, since the moon shrieked",
    hook=("afraid", "He says since the moon shrieked his neighbours have taken to beheading each other over nothing, and the field behind his barn swallows people whole."),
    again=("weary", "He says the corn is strangling people at the edges now, and asks if you have found how to stop it."),
    trouble=("afraid", "The ground opens under anyone the mob calls guilty, and the corn wraps itself around ankles; folk look at one another and see an enemy."),
    where=("sad", "He says the trouble comes from the old covered bridge east of town, where the founders once beheaded the wrong man, a horseman."),
    a_intro=("neutral", "He offers that the town records and the old people might say how the horseman died, if somebody reads them properly."),
    a_label=["Read the town's old records", "Question the oldest farmers about the founding"], a_plain="Walk the farms asking, however long it takes",
    a_ok=("smile", "The records show it plainly: the headless horseman died before the covered bridge, and the mob has been gathering in the corn ever since."),
    a_slow="You spend the best part of a night door to door, and in the end an old woman tells you the horseman died before the covered bridge.",
    clue_who="Captain Harl Reeve, who leads the mob that beheads, weary and sweating, half hating himself",
    clue=("weary", "He says he does not know why he leads them; the anger comes down on him at nightfall and he cannot put it down."),
    clue_talk=("sad", "He says the mob meets in the corn at dusk and a headless rider is always at its back, whatever they swear to afterwards."),
    b_intro=("sly", "He says the mob admits anyone who can look angry enough, and he might let you stand with them tonight."),
    b_label=["Slip in among the mob unseen", "Pass as one of the angry mob"], b_plain="Wait out the night at the edge and follow the mob in",
    b_ok=("sly", "The mob takes you for its own and you ride along to the bridge without a word asked."),
    b_slow="It costs you hours of cold waiting at the edge of the corn, but the mob does finally walk, and you follow it to the bridge.",
    weak_intro=("sly", "He whispers that the skull of the headsman's first victim lies in a hole under the mob's meeting place; whoever holds it, the rider fears."),
    w_label=["Search the riverbank mud for the skull", "Haul stones off the old sinkhole to reach it"], w_plain="Dig by hand through the long night",
    w_ok=("smile", "You find the old skull wrapped in rotten sacking, small and yellow, and the mud seems reluctant to give it up."),
    w_slow="You dig through the long night with your hands and a borrowed spade, and the skull comes up grinning at dawn.",
    arrive="A farm at the edge of the corn, gates hanging open, and the earth near the fence pocked with holes the size of wagons.",
    affl_ok="You feel the ground sag in time and step across; the hole closes behind you with a sigh.",
    affl_hit="The earth drops from under a hero's feet and the hole closes on their legs before it lets go, bruised.",
    region="You cross a field where the sinkholes open without warning, and the corn leans to catch at your ankles.",
    lair="The covered bridge looms, its dark mouth open, and the sound of hooves rises where no horse stands.",
    reveal=("The Headsman bursts from the bridge's dark, a headless rider on a skeletal mount with a flaming axe raised.", "His burning skull is thrown ahead of him, screaming, and the whole bridge lights with it."),
    fall=("The rider's flame gutters and his axe drops, and the corn lets go of its grip on the ground.", "Overhead the moon turns its face slowly toward the west, toward a dark lake."),
    after="Far off the water of Moonsong Lake is already stirring, and the moon's grin has found it.",
),
"worm": dict(
    hook_who="Pell Netwright, a fisher from a lakeside village, grey, drained, sleepless",
    hook=("afraid", "He says the nets come up full of white worms, and the water makes a man forget his own children's names."),
    again=("weary", "He says another family lost their memory in the shallows this morning, and asks for news."),
    trouble=("afraid", "Drink from the lake and you forget everything for hours; swim and the worms get in under your skin; and the lake cultists say they hear it singing."),
    where=("sad", "He says it was something pulled through from another place by a woman called Matron Lethica, and it fell into the deep lake."),
    a_intro=("neutral", "He says the first people of the lake left black obelisks on the shore; they might tell what lies in the water, if someone could read them."),
    a_label=["Decipher the black obelisks", "Study the lake's first people's carvings"], a_plain="Copy every carving and puzzle at them for hours",
    a_ok=("smile", "The carvings are a warning, plain once you see it, and a map of the rift where the thing came through."),
    a_slow="You spend a long afternoon copying the obelisks onto your sleeves, and by evening the pattern at last makes sense.",
    clue_who="Brother Silt, a lake cultist who worships the Worm, softly mad and polite, eager to recruit",
    clue=("smile", "He greets you like old friends and asks if you have heard the Worm singing under the lake, and would you like to join the choir."),
    clue_talk=("sly", "He says the Worm eats minds and the faithful are those it has already tasted; the choir meets on the long jetty each midnight."),
    b_intro=("sly", "He says the Order is always glad of new voices; you would only have to pretend to love the Worm convincingly."),
    b_label=["Pretend to join the Worm's order", "Talk the cultists into taking you to the rift"], b_plain="Sit through the whole sermon and follow them out",
    b_ok=("smile", "Brother Silt weeps with joy, and the choir leads you down the jetty to the rift."),
    b_slow="It is an unpleasantly long sermon, but the choir does at last walk you down the jetty to the rift.",
    weak_intro=("sly", "He whispers that the Worm fears one star pattern, the ones the lake's first people painted; show it that sequence and it will choke on whoever knows it."),
    w_label=["Work out the constellations from the obelisks", "Chart the stars by the lake's reflection"], w_plain="Trace the whole sky on the shore, star by star",
    w_ok=("smile", "You mark the seven stars in order on a scrap of oilcloth, and the lake seems to flinch from it."),
    w_slow="It takes the whole night, lying on the shore with a lamp, but the chart is finished by dawn.",
    arrive="A lakeside village of grey huts, nets draped on every post, and white worms gleaming in the shallows.",
    affl_ok="You keep your mind on the names of those you love and the water's whisper slides off.",
    affl_hit="A hero breathes the lake's mist and loses a quarter hour entirely; they come back with a headache and no memory of why.",
    region="You walk the shore, and the lake mist drifts into your mouth with a taste of cold pennies.",
    lair="Down the long jetty a tear in the air hangs open over black water, and a white shape coils beyond it.",
    reveal=("The White Worm rises, vast and pale, from the rift in the lake bed, its mouth a ring of soft teeth.", "It sings, and every worm in the water turns toward you at once."),
    fall=("The Worm shudders, coils tight, and falls back through the rift, which closes on it like a wound.", "The moon swings its gaze over the water toward a dark forest to the north."),
    after="In Hartsblight, the trees are already bending their heads toward something tall.",
),
"tall_man": dict(
    hook_who="Bram Fallow, a logger from a settlement on the edge of the healed Hartsblight, grim and sleepless",
    hook=("afraid", "He says folk keep wandering into the trees at night in their sleepclothes, and the ones found come back screaming and cannot say why."),
    again=("weary", "He says two more went in last night, and asks if you have any answer."),
    trouble=("afraid", "Each hour in the woods the dread gets worse, shadows stand up and walk, and voices call from where nobody is."),
    where=("sad", "He says the forest was healed, green again, and then the moon shrieked and something tall came out of the old fey ruins in the heart of it."),
    a_intro=("neutral", "He says there is an old crone in the camp who tells tales of the Greenwood's court; her story might name it."),
    a_label=["Hear the crone's tale and test it against the lore", "Ask for the old court's story in careful words"], a_plain="Sit by her fire all night and let her talk it out",
    a_ok=("smile", "The crone's tale is true enough to check: a graceful lord of the Greenwood, rotted by neglect into the Tall Man, walking his old palace's halls."),
    a_slow="You sit through a rambling night of old women's stories, and somewhere near dawn she names the palace and the thing in it.",
    clue_who="Mother Hesper, an old crone with milky eyes and a clay pipe, cackling, who tells tales for pennies",
    clue=("sly", "She cackles that she has been telling this tale for sixty years and nobody listened until the moon fell on it."),
    clue_talk=("sly", "She says the Tall Man was an archfey with a court of dancers, and he waits in the ruined palace, hungry for fear."),
    b_intro=("sly", "She says he comes to fear the way a moth comes to a candle; you could bait him and he would follow it to his palace."),
    b_label=["Stalk the woods and lure him with fear", "Make yourselves loud with dread and be hunted"], b_plain="Walk the woods all night frightened on purpose",
    b_ok=("sly", "He comes, tall and long-limbed, and you lead him back toward his own palace walls, step by step."),
    b_slow="You blunder through the dark half the night before something tall finally follows your fear toward the palace.",
    weak_intro=("sly", "She tells you the steps of the dance of his lost court; dance them in his sight and the old magic of the Greenwood hurts him."),
    w_label=["Learn the steps of the lost court dance", "Study the old dance from her fingers' counting"], w_plain="Practise the steps clumsily until dawn",
    w_ok=("smile", "She taps the measure on her knee and you have it, six turns and a bow, a dance for a vanished court."),
    w_slow="You stumble through the steps until the sun that is not there would have risen, and by then you have them.",
    arrive="A logging camp at the edge of a forest that has grown green and healed, the Wellspring bubbling clear, and every tree leaning slightly the same way.",
    affl_ok="You keep to the lantern light and the whispers of the dark slide past.",
    affl_hit="A heavy dread falls on a hero in the trees, their hands tremble, and for a long hour they can do nothing right.",
    region="You walk the healed forest, and each tree you pass seems to have turned a little to watch you.",
    lair="The ruined palace of the Greenwood court rises ahead, its pillars grey, its great hall open to the dark.",
    reveal=("The Tall Man unfolds from between the pillars, impossibly tall and thin, his head bowed under the roof he once was lord of.", "His long hand reaches, and the shadows around you stand up to follow it."),
    fall=("The Tall Man folds, his long limbs collapsing like a dropped puppet, and the shadows go back to being shadows.", "The moon turns slowly northward, toward the Howlers and their snow."),
    after="High on the Howlers a rock slides, and something very large turns over in the dark.",
),
"titan": dict(
    hook_who="Jory Delve, a Dawn's Gate miner who has lost his family, hollowed out, stubborn",
    hook=("sad", "He says his wife and boy went up to the pass for firewood and did not come down, and the mountain has been roaring for days."),
    again=("weary", "He says the rocks fell on another hamlet last night and asks if you can help."),
    trouble=("angry", "Rocks come down a mile at a time, fire will not burn near the peaks, and the roars rise until strong men run mad with them."),
    where=("sad", "He says the mountain itself woke, a thing made of the wild and forgotten by whoever made it, and it walks the high passes."),
    a_intro=("neutral", "He says the old rune stones on the slopes may tell of its maker; somebody who reads runes might learn how to hurt it."),
    a_label=["Read the old rune stones on the slope", "Compare the runes against the mountain's lore"], a_plain="Copy every rune on the slope by hand",
    a_ok=("smile", "The stones tell of a maker and a binding, and somewhere among them a name that is half erased."),
    a_slow="You spend hours on the freezing slope copying runes with numb fingers, and the story of the Titan comes together out of them.",
    clue_who="Grizzle Hawkes, a grizzled hunter in patched furs, terse, who has been tracking the Titan",
    clue=("neutral", "He tells you to keep your voice down, and that he has been trailing the thing for three days and it is bigger than the book of stories says."),
    clue_talk=("neutral", "He says it follows the high ridges and goes to the summit plateau to roar, and anyone who hears it too long goes berserk."),
    b_intro=("neutral", "He says he can show you its trail, if you can keep up and keep quiet."),
    b_label=["Track the Titan along the ridges", "Follow the animals fleeing its path"], b_plain="Climb the ridge slowly and follow the cracked earth",
    b_ok=("smile", "The trail is clear once you see it, boulders thrown aside, and it leads to the summit plateau."),
    b_slow="You lose hours on the false trails, but the cracked earth leads you to the summit at last.",
    weak_intro=("neutral", "He says the maker's name is carved as a glyph on a big stone down the slope; carve it large enough and the Titan sickens by it."),
    w_label=["Transcribe the maker's glyph from the stones", "Work out the glyph's meaning and carve it true"], w_plain="Carve the glyph out clumsily, over and over, until it holds",
    w_ok=("smile", "You carve the glyph deep into a great flat stone, and the air around it goes cold and strange."),
    w_slow="Your first dozen carvings are worthless, but through the night a good one emerges, big and square and true.",
    arrive="A cluster of mining huts on a snowy ridge, the shafts boarded up, and cracks running through the frozen ground.",
    affl_ok="You hear the rumble in time and press against the rock face as the stones fall past.",
    affl_hit="A rockfall catches a hero on the slope and leaves them bruised and shaken.",
    region="You climb the slope, and the whole mountain rumbles, dropping stones the size of cartwheels.",
    lair="The summit plateau opens above, ringed with broken stones, and the ground trembles with slow footfalls.",
    reveal=("The Wild Titan rises over the summit, a giant of rock and root and ice, its fists the size of cottages.", "It roars, and the whole mountain answers."),
    fall=("The Titan staggers, its great arms hanging, and slowly sits down on the summit like a mountain settling.", "Below, the moon turns its face south and east, toward the place the dead are buried."),
    after="At Maidenmist the graves are already opening, one after another, like mouths.",
),
"barrow": dict(
    hook_who="Solomon Roderick, Wickermoor's stonemason, cold and plain, who has found graves open that he laid himself",
    hook=("weary", "He says every grave he ever cut a stone for has opened, and the dead are not climbing out, they are being fetched."),
    again=("weary", "He says there are fewer living in the village each day, and asks if you have found the door to the king."),
    trouble=("angry", "Wounds will not heal near the barrow, the living weaken by the hour, half the village has taken to praying to the dead, and a plague turns the fallen into wights."),
    where=("sad", "He says a king with no name has woken under the old royal barrow, with an army of wights, and the mourners are his."),
    a_intro=("neutral", "He says the old graves hold the way down; open the right ones and the king's own stair will show."),
    a_label=["Exhume the oldest graves for the way in", "Read the grave markers for the king's stair"], a_plain="Dig every grave on the hill until the stair is found",
    a_ok=("smile", "Under the third old grave a stair of black stone leads down, the rock worn smooth by an army's tread."),
    a_slow="You dig through the long night, grave after grave, and finally the spade rings on a stair.",
    clue_who="Aldous, a half-free ghost in the barrow, courteous and tragic, who served the king in life",
    clue=("sad", "He greets you with a courtly bow that is half a drift, and says he has been trying to leave for a very long time."),
    clue_talk=("sad", "He says the king had no name that history kept, only a title, and that his name is carved in lost runes on a blade in the deep chamber."),
    b_intro=("sad", "He says if you can persuade him he is free to go, he will show you the way into the king's hall."),
    b_label=["Persuade the ghost he is free to go", "Say the last rites over his bones"], b_plain="Sit with him through the night and listen",
    b_ok=("smile", "He weeps without tears, thanks you, and points down the stair to the king's hall."),
    b_slow="It takes a long night of listening, but at the end he lets go enough to point the way.",
    weak_intro=("sad", "He tells you the king's lost runes: a weapon that bears them is the king's bane, and the king fears whoever carries it."),
    w_label=["Copy the king's runes onto a blade", "Etch the lost name along a sword's fuller"], w_plain="Etch the runes by hand, slowly, a stroke at a time",
    w_ok=("smile", "The runes bite into the blade's steel and glow faintly green, and the ghost shudders and nods."),
    w_slow="It takes hours of careful scratching, but the runes are finally right, and they hold.",
    arrive="Maidenmist's graves stand open to the sky, earth heaped beside each, and a stonemason's cart abandoned at the gate.",
    affl_ok="You keep moving through the cold, and the creeping weariness slides off.",
    affl_hit="The air by the barrow saps a hero's strength, and they have to sit down for a time.",
    region="You walk between open graves, and each one breathes out a thin cold air.",
    lair="Below the stair, the royal catacombs open into a vast hall, and at its end a throne of skulls waits.",
    reveal=("The Barrow King rises from his throne of skulls, armoured in black, a crown of bone on his brow, his sword already drawn.", "Around him the dead stand up, rank on rank."),
    fall=("The King's crown falls and rolls, ringing, and his armour goes to dust; the wights around him sink back into the earth.", "Above, the moon turns its gaze toward the southern marshes."),
    after="In the Drowned Crossroads the swamplights are already dancing, brighter than they should.",
),
"leviathan": dict(
    hook_who="Nadine Marsh, a Murkwater Bend resident in a patched waterproof, resigned, unflappable",
    hook=("weary", "She says everything in the bayou has been going wrong this week: the boats sink, the dice fall badly, and something huge turns in the water at night."),
    again=("weary", "She says another punt sank on a calm morning, and asks what you have learned."),
    trouble=("weary", "Everything goes wrong by a little, always, swamplights lead folk astray, and the party-goers dance until they drop."),
    where=("sad", "She says an alligator was hexed into a colossus of bad luck to fight Snake Eye Jack, and it ate its makers, and it is in the bayou's deep pool."),
    a_intro=("neutral", "She says a giant serpent sacred to Jack's followers nests upstream; the Leviathan hates it, and might follow you if you used it."),
    a_label=["Bait the Leviathan with the sacred serpent", "Read the serpent's nesting place to lead the Leviathan"], a_plain="Drag bait through the swamp and see what follows",
    a_ok=("smile", "The great serpent drifts through the water, and the Leviathan turns slowly, drawn after it toward its pool."),
    a_slow="It takes a long wet afternoon of luring and bad luck, but the Leviathan finally turns toward the pool.",
    clue_who="Cassius Dunn, a follower of Snake Eye Jack with a lucky hat, jovial and a little drunk",
    clue=("smile", "He tips his hat and says it is a fine day for tempting fate, and would you like a drink to your health."),
    clue_talk=("smile", "He says the followers bless idols of Jack for luck, and that a blessed idol rebounds a curse, which would be very bad news for a Leviathan."),
    b_intro=("sly", "He says he knows where the beast was made, and might tell you for a fair bargain or a fair threat."),
    b_label=["Intimidate him into telling where it was made", "Charm him into telling where it was made"], b_plain="Let him talk and listen to every wandering tale",
    b_ok=("sly", "He tells you the whole sorry story, the hexing and the sinking, and where the pool is."),
    b_slow="It takes a long drunken afternoon of rambling, but in the end he tells where the pool is.",
    weak_intro=("smile", "He says you need an idol of Snake Eye Jack blessed by a true follower; and he happens to be one."),
    w_label=["Persuade him to bless an idol for you", "Show proper reverence so he blesses it freely"], w_plain="Pay your respects at the shrine and ask politely, over hours",
    w_ok=("smile", "He lays a small idol in your hands and murmurs a blessing, and for a moment the whole swamp seems to wink."),
    w_slow="It takes hours of dutiful respect at the shrine, but he finally blesses the idol.",
    arrive="Murkwater Bend, stilt shacks and swamplights, boats sunk at their moorings, and a stink of old luck gone sour.",
    affl_ok="You follow your own lantern and the swamplights lose their pull.",
    affl_hit="The swamplights lure a hero off the boardwalk, and they come back damp and muddled.",
    region="You walk the boardwalk, and every third plank gives way, and the swamplights wink knowingly.",
    lair="The boardwalk ends at a cursed pool, black and still, with an island of mud and bones in its middle.",
    reveal=("The Jinxed Leviathan breaks the surface of the pool, a colossal alligator with a crown of old hexes, grinning.", "Its mouth opens, and the air fills with sour luck."),
    fall=("The Leviathan sinks beneath the pool, finally unlucky, and the swamplights wink out one by one.", "The moon turns its gaze south and west, toward a forest of spiders."),
    after="In the Webwoods something is stitching, and children have stopped playing.",
),
"dusk": dict(
    hook_who="Ysolde Thrush, a teenage girl from a homestead on the edge of the Webwoods, sharp and brave, whose siblings have vanished",
    hook=("angry", "She says her brothers and sisters were taken from their beds, and the grown folk walk about like sacks and will not say why."),
    again=("sad", "She says another cot was empty this morning, and asks if you have found them."),
    trouble=("afraid", "Webs choke the woods, wails come at every hour, and the grown ones are empty as dolls, stitched at the seams."),
    where=("sad", "She says a seamstress went mad and killed her children while possessed, and now she weeps in white, taking the rest."),
    a_intro=("neutral", "She says the children's rhymes hold what happened, if someone puts the verses together."),
    a_label=["Piece together the children's rhymes", "Match the verses to what the old folk remember"], a_plain="Gather every rhyme the children ever sang, however long it takes",
    a_ok=("smile", "The rhymes fit together into a story, and the last verse names the hut where the seamstress still sits."),
    a_slow="It takes all night to gather the rhymes, but laid together they point to the hut in the woods.",
    clue_who="Granny Pennywhistle, an old nurse who raised half the homestead, quick-witted, hands always stitching",
    clue=("smile", "She says she has been waiting for someone sensible, and sets her mending aside to look you over."),
    clue_talk=("sad", "She says the seamstress's own children were small and loved their toys, and that their toys are what the weeping thing cannot bear to see."),
    b_intro=("neutral", "She says the spiders of the Webwoods go straight to the hut as to a hearth; follow them and you will not go wrong."),
    b_label=["Follow the spiders through the Webwoods", "Read the webs for the way to the hut"], b_plain="Follow the webs the long way round",
    b_ok=("smile", "The spiders lead you unerringly, a river of small legs, to the hut in the clearing."),
    b_slow="You lose hours to wrong turns in the webs, but the spiders do at last bring you to the clearing.",
    weak_intro=("sad", "She presses a small bundle on you: the children's toys, saved from the fire. Show them to the Mother and she will not be able to fight."),
    w_label=["Read the toys for the children's memories", "Gather the toys and the children's spirits gently"], w_plain="Hold each toy and wait, slowly, for it to speak",
    w_ok=("sad", "The toys hold the shape of small hands, and when you turn them over each one seems to hum a lullaby."),
    w_slow="You sit with the toys through a long hour, quietly, until each is ready to be shown.",
    arrive="A homestead at the edge of a spider forest, cots empty, shutters hung with white thread, a doll on every windowsill.",
    affl_ok="You cut a path through the webs with a blade and the poison never touches you.",
    affl_hit="Webs catch a hero and the spiders' poison burns in their veins before they cut free.",
    region="You walk the Webwoods, and strands of web drape across the path like ribbons.",
    lair="The seamstress's hut stands in the clearing, small from outside, its door ajar and a sound of shears inside.",
    reveal=("The Dusk Mother rises from her loom, a weeping shade in white, huge shears in her hands, a doll hanging from each finger.", "She wails, and the whole hut seems to listen."),
    fall=("The Dusk Mother's shears fall, her shape dissolves into dust and white thread, and from the hut small voices laugh, once.", "The moon turns its face slowly north and east, toward the burning hill."),
    after="Beyond the moors Rowan's Rise cracks open, and a red light shines.",
),
"behemoth": dict(
    hook_who="Brother Ashfall, a doomsday cultist at the Rise's camp, red-eyed, joyful, eager",
    hook=("smile", "He says the hill has opened at last, as it was always going to, and would you like a good seat for the end."),
    again=("smile", "He says it will be soon, and wonders if you have changed your minds about joining the prayer."),
    trouble=("afraid", "Meteors fall every hour, the cultists burst like firecrackers, and the fire marks those it touches until they change."),
    where=("sad", "He says a fiend born of every culture's fear of the end was called up by the spirit of a girl named Rowan, who wanted the world to burn."),
    a_intro=("sly", "He says Rowan's spirit is the key; learn the truth of her wickedness and shame her, and the thing weakens."),
    a_label=["Learn the truth of Rowan's wickedness", "Press her story until she admits it"], a_plain="Gather every tale of Rowan, however long it takes",
    a_ok=("neutral", "You piece it together: she was proud, cruel, a girl who wanted the apocalypse, and only love for her sister ever moved her."),
    a_slow="It takes hours of old folk and older letters, but the truth of Rowan comes together at last.",
    clue_who="Rowan's spirit, a pale girl in an old-fashioned dress, bitter and proud, who called the Behemoth up",
    clue=("angry", "She tells you you are late, and that the end is already here and she was merely the first to ask for it."),
    clue_talk=("sad", "She says she was wicked and wanted the world over, and the only thing she ever loved was her sister."),
    b_intro=("sad", "She asks, almost against her will, if her sister ever had children."),
    b_label=["Find Rowan's sister's descendant in the camp", "Trace the family line from the barrow's portrait"], b_plain="Search the camp for anyone with her sister's eyes",
    b_ok=("smile", "A woman in the camp has her sister's eyes, and she steps forward, blinking, and says, quietly, that she remembers the name."),
    b_slow="It takes hours of asking in the camp, but at last you find the one who is her sister's blood.",
    weak_intro=("sad", "She whispers that if she were to go willingly into the fire, the Behemoth that wears her wickedness would be hurt in its turn."),
    w_label=["Persuade Rowan to go willingly into the lava", "Show her the sister's love and let her choose"], w_plain="Sit with her through the long hour until she is ready",
    w_ok=("sad", "Rowan looks at the descendant, whispers her sister's name, and walks calmly toward the fire."),
    w_slow="You stay by her through a long hour of silence, and at the end she rises, ready.",
    erupt=("Rowan's Rise bursts open like a boil, red light pouring from the hill, and the moor around it going to ash.", "Winged fiends rise from rivers of lava over the dark moors, and the sky above them is the colour of an old bruise."),
    arrive="Rowan's Rise has burst open, a volcano over a moor of ash, and the doomsday camp is hung with red cloth.",
    affl_ok="You throw yourself behind a rock as the meteor falls, and it burns past.",
    affl_hit="A burning boulder falls near a hero and the flame bites their arm before they roll clear.",
    region="You cross the ash moor, and burning rocks drop out of the red sky.",
    lair="The crater's lip lies ahead, hot and glowing, and something vast stirs in the lava below.",
    reveal=("The Brimstone Behemoth climbs out of the crater, a mountain of horn and flame, wings of smoke spread across the sky.", "It speaks no word, and the whole moor lights with its breath."),
    fall=("The Behemoth gutters, sinks into the lava, and the sky above the crater begins, slowly, to clear.", "Far above, the moon has stopped turning away. It hangs low now, looking at you, and it is smiling."),
    after="The last of the eight is gone, and the moon waits for you alone.",
),
}


def fear_file(f):
    t = FT[f["key"]]
    k = f["key"]
    H, C = f["hook_npc"], f["clue_npc"]
    Fq = fq(f)
    asked, found, clue_a, clue_b, clue_met, weak = fl(f, "asked"), fl(f, "found"), fl(f, "clue_a"), fl(f, "clue_b"), fl(f, "clue_met"), f["weak_flag"]
    arrived, resisted, aftermath = fl(f, "arrived"), fl(f, "resisted"), fl(f, "aftermath")
    ab, dc, dice, dtype, desc = f["afflict"]
    dmg = f"damage {dice} {dtype} party"
    fl_ = File(f["file"], f"Drafted by Gemini (R26 {f['short']}), edited. {f['name']}: hook, clues, weakness, the lair fight and the aftermath.")
    ra, rb, rw = f["route_a"], f["route_b"], f["weak_skills"]

    # arrival and the land's affliction
    pre = cut2("mf_rowans_erupts", N(t["erupt"][0]), N(t["erupt"][1])) if "erupt" in t else []
    fl_.node("arrive", L(f"set {arrived}"), pre, N(t["arrive"]), L(f"check {ab} DC {dc} -> arrive_ok | arrive_hit"))
    fl_.node("arrive_ok", N(t["affl_ok"]), L(f"set {resisted}"), L("-> END"))
    fl_.node("arrive_hit", N(t["affl_hit"]), L(dmg), L("-> END"))
    fl_.node("region", N(t["region"]), L("time +60"), L(f"check {ab} DC {dc} -> arrive_ok | arrive_hit"))

    # the hook-giver
    fl_.node("hook", S(H, *t["hook"]), L(f"set {asked}"), L(f"quest {Fq} asked"), L("-> menu"))
    fl_.node("hook_again", S(H, *t["again"]), L("-> menu"))
    fl_.node("menu",
             O("Ask what has been happening", "trouble"), O("Ask where it comes from", "where"),
             O("Ask how to find it", "route_a", cond=f"not flag.{found}"),
             O("Say we will deal with it", "END"))
    fl_.node("trouble", S(H, *t["trouble"]), L("-> menu"))
    fl_.node("where", S(H, *t["where"]), L("-> menu"))
    fl_.node("route_a", S(H, *t["a_intro"]),
             SK(ra[0][0], ra[0][1], t["a_label"][0], "a_ok", "a_slow"), SK(ra[1][0], ra[1][1], t["a_label"][1], "a_ok", "a_slow"),
             O(t["a_plain"], "a_slow"), O("Another time", "menu"))
    fl_.node("a_ok", S(H, *t["a_ok"]), L("time +60"), L(f"set {found}"), L(f"set {clue_a}"), L(f"quest {Fq} trail"), L("-> menu"))
    fl_.node("a_slow", N(t["a_slow"]), L("time +300"), L(f"set {found}"), L(f"quest {Fq} trail"), L("-> menu"))

    # the clue-giver
    fl_.node("clue", S(C, *t["clue"]), L(f"set {clue_met}"), L("-> clue_menu"))
    fl_.node("clue_again", S(C, "neutral", "A short greeting back, in character, that welcomes the heroes to ask again."), L("-> clue_menu"))
    fl_.node("clue_menu",
             O("Ask about it", "clue_talk"), O("Ask how to find it", "route_b", cond=f"not flag.{found}"),
             O("Ask what could hurt it", "weak", cond=f"flag.{found} and not flag.{weak}"),
             O("Take our leave", "END"))
    fl_.node("clue_talk", S(C, *t["clue_talk"]), L("-> clue_menu"))
    fl_.node("route_b", S(C, *t["b_intro"]),
             SK(rb[0][0], rb[0][1], t["b_label"][0], "b_ok", "b_slow"), SK(rb[1][0], rb[1][1], t["b_label"][1], "b_ok", "b_slow"),
             O(t["b_plain"], "b_slow"), O("Another time", "clue_menu"))
    fl_.node("b_ok", S(C, *t["b_ok"]), L("time +60"), L(f"set {found}"), L(f"set {clue_b}"), L(f"quest {Fq} trail"), L("-> clue_menu"))
    fl_.node("b_slow", N(t["b_slow"]), L("time +300"), L(f"set {found}"), L(f"quest {Fq} trail"), L("-> clue_menu"))
    fl_.node("weak", S(C, *t["weak_intro"]),
             SK(rw[0][0], rw[0][1], t["w_label"][0], "weak_ok", "weak_slow"), SK(rw[1][0], rw[1][1], t["w_label"][1], "weak_ok", "weak_slow"),
             O(t["w_plain"], "weak_slow"), O("Another time", "clue_menu"))
    fl_.node("weak_ok", S(C, *t["w_ok"]), L("time +60"), L(f"give {f['weak_item']}"), L(f"set {weak}"), L(f"quest {Fq} ready"), L("-> clue_menu"))
    fl_.node("weak_slow", N(t["w_slow"]), L("time +300"), L(f"give {f['weak_item']}"), L(f"set {weak}"), L(f"quest {Fq} ready"), L("-> clue_menu"))

    # the lair
    fl_.node("lair", N(t["lair"]), O("Go in and face it", "fight"), O("Not yet", "END"))
    reveal = cut2(f["reveal_cut"], N(t["reveal"][0]), N(t["reveal"][1]))
    fl_.node("fight", reveal,
             L(f"if flag.{weak}"), L(f"combat mf_{k}_weak"), L(f"elif level >= {f['level']}"), L(f"combat mf_{k}_full"), L("else"), L(f"combat mf_{k}_light"), L("endif"))

    # the aftermath
    close = [N(t["after"])]
    tail = [L(f"set {aftermath}"), L("set old_fears_slain += 1"), L("set moonfall_credit += 1"), L("set moonfall_nights_left += 1"),
            L(f"give {f['reward']}"), L(f"quest {Fq} slain")]
    if f["n"] < 8:
        tail.append(L("xp milestone"))
        fl_.node("aftermath", cut2(f["fall_cut"], N(t["fall"][0]), N(t["fall"][1])), tail, close, L("-> END"))
    else:
        tail += [L("quest moonfall one_last_choice")]
        fl_.node("aftermath", cut2(f["fall_cut"], N(t["fall"][0]), N(t["fall"][1])), tail, close, L("move mf_last_hill:from_rise"))
    return fl_
