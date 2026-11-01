# R20 Narrator lines: the walking dovecote, the four roosts, and the fights' retries. Triggers: enter:<location or area id>, examine:<prop id>, defeat:<fight id>.
# The Vagrant: second person, present tense, one or two sentences, no game words. Every key has a plain variant.

~ enter:rk_dovecote_r1
| <<The Vagrant: stepping inside the walking dovecote, the floor moving gently underfoot, straw, seed, feathers, crates and cooing>>
| <<The Vagrant: the ground floor of a building that is also a bird, a smell of grain and droppings, letters in drifts>>
once

~ enter:rk_dovecote_r2
| <<The Vagrant: climbing into the roost floor, cubbies to the rafters stuffed with stolen letters, the thatch low overhead, a platform at the far end>>
| <<The Vagrant: the roost is warm and close, and every cubby holds a pair of orange eyes watching you>>
once

~ enter:r2_rafters
| <<The Vagrant: the high platform of straw and cloth, four windows open on the night, and the moor moving past like a slow river>>

~ enter:rk_roost_prairie
| <<The Vagrant: the rolling prairie at night, gold-grey grass in the wind, the dark shape of the dovecote in the middle of it>>
| <<The Vagrant: tall grass whispers round your knees, and a big sky keeps its own counsel above>>
once

~ enter:rk_roost_swamp
| <<The Vagrant: the murky swamp, green-black water between dead trees and reeds, the dovecote standing in the shallows on its bird legs>>
| <<The Vagrant: fog sits on still water and the dovecote's reflection stands upside down in it>>
once

~ enter:rk_roost_foothills
| <<The Vagrant: the barren foothills under the Howlers, scree and thin cold air, the dovecote perched on a rise like a nest on a cliff>>
| <<The Vagrant: bare rock, a bitter wind, and the faint cooing that carries a long way on stone>>
once

~ enter:rk_roost_lakeshore
| <<The Vagrant: the stormy north shore of Moonsong Lake, rain on shingle, the dovecote squatting on the stones against a dark treeline>>
| <<The Vagrant: grey water slaps the beach and the rain runs off the dovecote's thatch in ropes>>
once

~ examine:rk_r1_cord
| <<The Vagrant: coils of leather cord, a hag's knotwork, tied and re-tied>>

~ examine:rk_r1_window
| <<The Vagrant: the round window shows the moor sliding by, a dark and patient landscape being walked over>>

~ examine:rk_r2_window_a
| <<The Vagrant: the tall window frames the night, the ground a very long way down>>

~ defeat:rk_golub
| <<The Vagrant: the hag's laughter is the last thing you hear, high and delighted, and the roost goes around again>>

~ defeat:rk_posse
| <<The Vagrant: a boot, a cudgel, and then the lane tilts; you wake to the sound of a key turning, though not in your favour>>

~ defeat:rk_mob_fight
| <<The Vagrant: the torches close in, the chanting fills your ears, and the world goes dark at the edges>>
