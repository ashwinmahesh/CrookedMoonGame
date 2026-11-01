# R20: the hunt. Finding the dovecote's roost (five ways, one needing no roll), reaching it unseen, and the empty roosts.

~ sky
set rk_hunt
quest roving_rookery hunt
Narrator: <<The Vagrant: from the estate road you can see every roof in the village grey with pigeons, and above the moor a handful of them flying one way, away from town>>
-> sky_menu

~ sky_menu
* [Survival DC 15] <<Watch the sky for a pigeon flying to the dovecote and read its route.>> -> sky_found | sky_missed
* [Investigation DC 15] <<Study where the pigeons gather and where they leave.>> -> sky_found | sky_missed
* [if item:rk_letter_theodora] [Animal Handling DC 12] <<Calm a pigeon and hand it the letter for Theodora.>> -> sky_found | sky_squabs
* [if item:rk_letter_theodora and flag.rk_squabs_down] <<Give the letter to the swarm we calmed.>> -> sky_found
* [if flag.rk_roost_known] <<Remember what Albert blurted.>> -> sky_found
* [if attitude.hilda_brom == friendly] <<Ask Hilda Brom to read the huge footprints.>> -> sky_found
* <<Walk the circuit of the four roosts.>> -> sky_circuit
* <<Look away from the sky.>> -> END

~ sky_missed
Narrator: <<The Vagrant: the birds scatter like flung seed, and you cannot tell one line from another>>
-> sky_menu

~ sky_squabs
Narrator: <<The Vagrant: the pigeon on your hand bursts into a grey wave of wings and the roof empties onto you>>
combat rk_squabs

~ sky_found
set rk_roost_known
if flag.dovecote_roost == 0
Narrator: <<The Vagrant: the birds' line runs out over the rolling prairie, past Foxwillow, where the grass is gold and grey>>
elif flag.dovecote_roost == 1
Narrator: <<The Vagrant: the birds' line runs south, toward the murky swamp and the Drowned Crossroads>>
elif flag.dovecote_roost == 2
Narrator: <<The Vagrant: the birds' line runs north, to the barren foothills under the Howlers>>
else
Narrator: <<The Vagrant: the birds' line runs west, to the rainy shore of Moonsong Lake>>
endif
if flag.dovecote_moves >= 2
Narrator: <<The Vagrant: it has been in the same place a long time; Golub has grown cocky, and the place is easy to find>>
endif
-> END

~ sky_circuit
Narrator: <<The Vagrant: four roosts, three nights apart; wherever it is not, the tracks lead on>>
-> END

~ hilda
Narrator: <<The Vagrant: Hilda Brom crouches at the edge of the village, reading the mud like a letter>>
hilda_brom [neutral]: <<Hilda, terse, says the thing that walked off left prints the size of carts, and she can follow them; she is not going to be asked twice>>
* [if attitude.hilda_brom == friendly] <<Ask her to lead us to the roost.>> -> hilda_tell
* [Persuasion DC 14] <<Ask her to help.>> -> hilda_tell | hilda_no
* [if gold >= 50] <<Offer fifty gold for her tracking.>> -> hilda_paid
* <<Leave her to it.>> -> END
~ hilda_tell
set rk_roost_known
hilda_brom [smile]: <<Hilda stands, tells you where the dovecote squats, and says she will follow in a day>>
-> END
~ hilda_no
hilda_brom [neutral]: <<Hilda says she does not work for charm victims or for strangers, and goes back to her prints>>
-> END
~ hilda_paid
gold -50
set rk_roost_known
hilda_brom [neutral]: <<Hilda pockets the coin, points the way, and does not say another word>>
-> END

~ arrive
quest roving_rookery hunt
Narrator: <<The Vagrant: the roost lies ahead, the dovecote squatting on its legs with the wind whistling through its thatch, and a wrinkled little shape on the ridgepole>>
if at:rk_roost_prairie
set rk_seen_prairie
endif
if at:rk_roost_swamp
set rk_seen_swamp
endif
if at:rk_roost_foothills
set rk_seen_foothills
endif
if at:rk_roost_lakeshore
set rk_seen_lakeshore
endif
if flag.albert_dead or flag.dovecote_moves >= 2
Narrator: <<The Vagrant: nothing watches from the thatch; the dovecote sits as if it has stopped caring>>
-> END
endif
* [Stealth DC 13] <<Creep in low through the grass, out of Albert's sight.>> -> arrive_ok | arrive_seen
* [Perception DC 15] <<Watch the thatch for the pigeon with the man's face.>> -> arrive_ok | arrive_seen
* <<Charge the dovecote openly.>> -> arrive_seen

~ arrive_ok
Narrator: <<The Vagrant: Albert shuffles on the ridgepole and falls asleep; you get under the legs unseen>>
-> END

~ arrive_seen
cutscene rk_rookery_horizon
Narrator: <<The Vagrant: a shriek from the ridgepole, a clap of wings, and the dovecote pulls up its legs>>
cutscene rk_rookery_horizon_2
Narrator: <<The Vagrant: it strides off over the moor, leaving a muddy three-toed footprint the size of a cart behind>>
cutscene end
set dovecote_moves += 1
if flag.dovecote_roost == 3
set dovecote_roost = 0
else
set dovecote_roost += 1
endif
-> END

~ dovecote_here
Narrator: <<The Vagrant: the dovecote stands on legs of scaly grey, thatch dripping, with the soft insistent cooing of a thousand birds coming through the shutters>>
* [Survival DC 15] <<Read how long it has been settled.>> -> timer_known | timer_missed
* <<Go in.>> -> enter
* <<Not yet.>> -> END
~ timer_known
Narrator: <<The Vagrant: the grass under the legs is only just flattened; it has not been here long, and it will not stay>>
-> dovecote_here
~ timer_missed
Narrator: <<The Vagrant: you cannot tell how long it has sat here>>
-> dovecote_here
~ enter
quest roving_rookery dovecote
move rk_dovecote_r1

~ tracks
Narrator: <<The Vagrant: three-toed prints the size of carts, filling slowly with water, leading away>>
if flag.dovecote_roost == 0
Narrator: <<The Vagrant: the prints turn toward the rolling prairie>>
elif flag.dovecote_roost == 1
Narrator: <<The Vagrant: the prints turn toward the murky swamp>>
elif flag.dovecote_roost == 2
Narrator: <<The Vagrant: the prints turn toward the barren foothills>>
else
Narrator: <<The Vagrant: the prints turn toward the stormy lakeshore>>
endif
-> END
