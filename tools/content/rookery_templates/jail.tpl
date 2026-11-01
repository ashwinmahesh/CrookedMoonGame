# R20: the jail beat. A timed escape with six ways out and no execution: the Witching Hour march ends in a slipped rope.

~ cell
Narrator: <<The Vagrant: the constable's cells, gear locked away, and through the wall the sound of the mob chanting your names>>
doris_squire [neutral]: <<Doris, at the bars, keeps it short: the trial is at the Witching Hour at the Oak; she does not say more>>
-> cell_menu

~ cell_menu
* <<Ask about the trial.>> -> trial
* [if flag.quill_poem_found] <<Mention that we have read her poems.>> -> poems
* [Insight DC 18] <<Study Doris: is she herself?>> -> noticed | notice_missed
* [if flag.rk_charm_seen] [Persuasion DC 18] <<Appeal to the Patient Lady's gentler side in her.>> -> persuaded | persuade_failed
* [knows:dispel_magic] <<Cast Dispel Magic on Doris through the bars.>> -> out_spell
* [knows:remove_curse] <<Cast Remove Curse on Doris through the bars.>> -> out_spell
* <<Let her be; look for another way out.>> -> END

~ trial
doris_squire [neutral]: <<Doris says the mayor reads the letter at the Witching Hour in the Round, the crowd chants, and then the Oak; she does not look away when she says it>>
Narrator: <<The Vagrant: she says it like a thing she has been told rather than a thing she believes>>
-> cell_menu

~ poems
doris_squire [afraid]: <<Doris goes still and says very quietly that nobody was meant to read those>>
Narrator: <<The Vagrant: something in her face loosens, the way a knot does when the right end is pulled>>
set jail_key_left
doris_squire [weary]: <<Doris says she must think, and walks away from the bars, leaving her key ring on its peg>>
-> END

~ noticed
set rk_charm_seen
Narrator: <<The Vagrant: the glint is under her eyes like a coin at the bottom of a well; she is hurting inside the charm>>
-> cell_menu
~ notice_missed
Narrator: <<The Vagrant: her face is stone and you cannot read a thing in it>>
-> cell_menu

~ persuaded
set jail_key_left
doris_squire [sad]: <<Doris says the Patient Lady would not like this; she walks away to think and leaves her key ring on its peg, in reach of a long arm>>
-> END
~ persuade_failed
doris_squire [angry]: <<Doris says no, and turns her back>>
-> END

~ out_spell
set jail_escape = "spell"
set jail_free
jail release
quest roving_rookery hysteria
Narrator: <<The Vagrant: the lilac glint goes out of her eyes; she sniffs the forged letter, mutters about pigeon ink, and unlocks the door herself>>
doris_squire [weary]: <<Doris tells you to go, quickly, before it comes back; she will be very bad at forgetting this>>
-> END

~ bars
Narrator: <<The Vagrant: iron bars set in oak, with a lock the size of a fist>>
* [if item:rk_improvised_picks] [Sleight of Hand DC 18] <<Pick the lock with the improvised picks.>> -> out_picks | pick_failed
* [Athletics DC 20] <<Bend the bars apart with brute strength.>> -> out_bars | bar_failed
* <<Leave the bars.>> -> END
~ pick_failed
Narrator: <<The Vagrant: a nail snaps in the lock; there is a second nail, and another hour>>
-> END
~ bar_failed
Narrator: <<The Vagrant: the bars shudder and hold, and somewhere a deputy shouts and then goes away again>>
-> END
~ out_picks
set jail_escape = "picks"
set jail_free
jail release
quest roving_rookery hysteria
Narrator: <<The Vagrant: the lock gives with a soft click; the picks go in your boot>>
-> END
~ out_bars
set jail_escape = "bars"
set jail_free
jail release
quest roving_rookery hysteria
Narrator: <<The Vagrant: iron screams, an oak post splinters, and the cell door swings open crooked>>
-> END

~ keys
Narrator: <<The Vagrant: the key ring hangs on its peg across the office, a long arm's length beyond the bars>>
* [if flag.jail_key_left] <<Take the key ring from its peg.>> -> out_keys
* [knows:mage_hand] <<Fetch the keys with Mage Hand.>> -> out_keys
* [Sleight of Hand DC 14] <<Hook the ring with a belt and drag it over.>> -> out_keys | keys_failed
* <<Leave it.>> -> END
~ keys_failed
Narrator: <<The Vagrant: the ring slides, jingles, and stops two inches short>>
-> END
~ out_keys
set jail_escape = "keys"
set jail_free
jail release
quest roving_rookery hysteria
Narrator: <<The Vagrant: the ring comes sliding across the boards into your hand, and the cell opens like any other door>>
-> END

~ window
Narrator: <<The Vagrant: a small window under the eaves, and on the sill a bird that is not a pigeon>>
* [if attitude.weston_murdoch == friendly] <<Call to the songbirds Weston sent.>> -> out_songbird
* <<Leave the window.>> -> END
~ out_songbird
set jail_escape = "help"
set jail_free
jail release
quest roving_rookery hysteria
Narrator: <<The Vagrant: a sparrow lets a heavy iron key fall through the bars, then twenty more of them sing the deputies away>>
-> END

~ wall
Narrator: <<The Vagrant: the back wall of the cell, and from the other side a scratching and a soft whine>>
* [if minutes_since.jail_began >= 120] <<Whisper through the boards.>> -> wall_dani
* <<Leave the wall.>> -> END
~ wall_dani
dani_jenkin [smile]: <<Dani, whispering through a hole under the sill: Shuck dug it, hurry, nobody is looking>>
set jail_escape = "help"
set jail_free
jail release
quest roving_rookery hysteria
Narrator: <<The Vagrant: a wolfhound-sized hole, and a child with her finger to her lips; you crawl out into the dark>>
-> END

~ march
Narrator: <<The Vagrant: the Witching Hour has come; the door opens, the constable walks you out into the torches, and the Oak of Many Faces is lit from below>>
doris_squire [neutral]: <<Doris says nothing at all, and puts a hand on your shoulder>>
Narrator: <<The Vagrant: the crowd surges; the mayor reads the letter; the rope in the deputy's hands jerks and slips, and someone is shouting that the Oak is alive>>
set jail_escape = "march"
set jail_free
jail release
quest roving_rookery hysteria
Narrator: <<The Vagrant: in the crush you slip the rope, shoulder through a torch-lit knot of neighbours, and run for the estate road with a hundred pigeons exploding off the roofs>>
move wickermoor_village:from_estate
