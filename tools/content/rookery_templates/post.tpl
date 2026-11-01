# R20: the crime scene in the post office, the master stroke, and the envelopes.

~ false_geneva
quest roving_rookery crime_scene
Narrator: <<The Vagrant: the post office, lamp unlit, letters everywhere; Theodora Mayville's skin lies on the floor behind the counter, and Geneva hangs back by the door>>
geneva_fairchild [afraid]: <<Geneva, small and shaky, asks the party to look at poor Theodora; she cannot bring herself to go near>>
* <<Ask Geneva what she saw.>> -> geneva_story
* <<Look at the body.>> -> body_look
* <<Look hard at Geneva.>> -> accuse
* <<Back away from the body.>> -> stroke

~ geneva_story
geneva_fairchild [sad]: <<Geneva says she came in at dawn, found Theodora like this, and fetched you straight away; she touched nothing, she swears it>>
Narrator: <<The Vagrant: the story is smooth as a polished stone, and there is no dust on the floor where she says she stood>>
-> false_geneva

~ body_look
Narrator: <<The Vagrant: there is a woman on the floor, and she has the wrong shape, like a coat dropped from a hook>>
* [Medicine DC 15] <<Check the body for wounds, bone, and blood.>> -> body_skin | body_missed
* [Investigation DC 15] <<Search the floor round her for tracks, feathers or ink.>> -> body_skin | body_missed
* <<Step back from it.>> -> false_geneva

~ body_skin
set rk_skin_known
Narrator: <<The Vagrant: no bones, no organs, no blood; this is an empty skin with the eyes taken out, laid out for someone to find>>
geneva_fairchild [afraid]: <<Geneva whispers that she cannot look; she will wait by the door; her voice is a little too steady>>
-> false_geneva

~ body_missed
Narrator: <<The Vagrant: it is a corpse and it is horrible, and you cannot say more than that>>
-> false_geneva

~ accuse
Narrator: <<The Vagrant: you turn your attention to the girl by the door>>
geneva_fairchild [afraid]: <<Geneva says she does not understand why you are looking at her like that>>
-> stroke

~ stroke
cutscene rk_master_stroke
geneva_fairchild [angry]: <<Geneva shrieks that the party has murdered the postmaster, then smirks; her voice is suddenly a hag's, vain and delighted>>
cutscene rk_master_stroke_2
Narrator: <<The Vagrant: she folds in on herself in a burst of grey feathers; an empty skin settles on the boards where she stood>>
cutscene rk_master_stroke_3
Narrator: <<The Vagrant: through the north window the dovecote stands up on pigeon legs, sprouts wings from its thatch, and lurches away over the roofs>>
cutscene end
set golub_exposed
set hysteria_began = now
set rk_posse_out
quest roving_rookery posse
Narrator: <<The Vagrant: a dozen angry voices, coming from the Founder's Round, and a stamp of boots down the lane>>
move wickermoor_village:from_post_office

~ skin_theodora
Narrator: <<The Vagrant: Theodora Mayville's empty skin, slack as a shed coat, eye sockets hollow; a smell of old straw and bird>>
* [Medicine DC 15] <<Study the skin for wounds, bones, and the way it was shed.>> -> skin_known | skin_unknown
* <<Leave it be.>> -> END
~ skin_known
set rk_skin_known
Narrator: <<The Vagrant: it was worn like a coat for years and taken off like one; whoever wore it had claws>>
-> END
~ skin_unknown
Narrator: <<The Vagrant: it is a body and not a body, and you cannot say how>>
-> END

~ skin_geneva
Narrator: <<The Vagrant: a second skin, small and fine-boned, lilac eyes gone from it; Geneva Fairchild would have been twenty>>
-> END

~ letters
Narrator: <<The Vagrant: a tray of blank envelopes and a pot of ink; a pigeon on the rail tilts its head at you>>
* <<Address an envelope to Theodora Mayville.>> -> letters_take
* <<Leave the envelopes.>> -> END
~ letters_take
give rk_letter_theodora
set rk_letter_ready
Narrator: <<The Vagrant: you write her name in a neat hand and seal it; any bird that carries it will know where the postmaster lives>>
-> END
