# R20 side quest: The Quiet Door. Marianna Grey is hiding Mrs. Oakum from the mob; the party escorts her to the estate in three legs.

~ start
Narrator: <<The Vagrant: Marianna Grey at the corner of the stable yard, close to the wall, pale; she beckons without a word>>
marianna_grey [afraid]: <<Marianna, shy and halting, whispers that she has Mrs. Oakum hidden in the loft above the stalls; the mob has her name; she needs her out of the village and does not know who else to ask>>
* <<Say we will take her to the estate.>> -> accept
* <<Ask why the mob wants Mrs. Oakum.>> -> why
* <<Say we cannot, not now.>> -> refuse

~ why
marianna_grey [sad]: <<Marianna says Mrs. Oakum is a good woman who walks out at night, and the mob will not need more than that>>
-> start
~ refuse
marianna_grey [sad]: <<Marianna nods, very small, and says she understands>>
-> END
~ accept
set rk_quiet_asked
quest quiet_door asked
marianna_grey [smile]: <<Marianna thanks you hoarsely and says she is in the loft, go in by the side door>>
-> END

~ progress
if flag.rk_oakum_gone
marianna_grey [weary]: <<Marianna says only that the stable is quiet now, and thank you>>
-> END
endif
Narrator: <<The Vagrant: Marianna's eyes flick toward the stable door and back>>
marianna_grey [afraid]: <<Marianna whispers that Mrs. Oakum is still in the loft; please hurry>>
-> END

~ oakum
Narrator: <<The Vagrant: Mrs. Oakum sits among the hay bales, a big woman folded small, a pitchfork across her knees that she has no intention of using>>
mrs_oakum [afraid]: <<Mrs. Oakum, hill-country twang, says she doesn't want to hurt a soul, but if the mob finds her in the dark she might, and she'd never forgive herself>>
* <<Lead her out now.>> -> leg1
* <<Wait here a little longer.>> -> END

~ leg1
Narrator: <<The Vagrant: the first leg is the lane behind the stalls, forty yards of shadow before the Round; torches move beyond the fence>>
* [Stealth DC 15] <<Creep along the wall in the shadow.>> -> leg2 | spotted
* [Deception DC 14] <<Cover her with a sack and call her a pig for the butcher.>> -> leg2 | spotted
* <<Take Marianna's mare and cart the long way round by the river, two hours.>> -> leg2_long

~ leg2_long
time +120
Narrator: <<The Vagrant: the mare is slow and calm; the river is wet; nobody looks twice at a woman and a cart of hay>>
-> leg2

~ leg2
Narrator: <<The Vagrant: the second leg is the edge of the Founder's Round, where the mob is thickest and the Oak is lit from below>>
* [Stealth DC 15] <<Slip along the shadow of the buildings.>> -> leg3 | spotted
* [Performance DC 14] <<Pose as drunks singing the mob's chant.>> -> leg3 | spotted
* <<Wait for the mob to disperse, an hour.>> -> leg3_wait

~ leg3_wait
time +60
Narrator: <<The Vagrant: the torches bob away down another lane, and for a moment the Round is empty>>
-> leg3

~ leg3
Narrator: <<The Vagrant: the third leg is the moor road and the long climb to the estate, with the gates of the crooked house at the top>>
* [Survival DC 12] <<Take the back path through the heather.>> -> arrive | spotted
* <<Walk the road openly.>> -> arrive

~ spotted
Narrator: <<The Vagrant: a torch swings round, a hundred eyes find you, and the mob chants its name for Mrs. Oakum>>
mrs_oakum [afraid]: <<Mrs. Oakum whispers that they should leave her; she'll hold them and you run>>
* <<Fight the mob off.>> -> fight_for_her
* [ends:quiet_door] <<Hand her over; we cannot win this.>> -> give_up

~ fight_for_her
set rk_mob_down = now
combat rk_mob_fight

~ give_up
set rk_oakum_gone
set rk_oakum_taken
quest quiet_door taken
Narrator: <<The Vagrant: they take her gently, almost kindly, and she does not look back; the cell door shuts on her and the whole lane goes quiet>>
-> END

~ arrive
set rk_oakum_gone
quest quiet_door delivered
Narrator: <<The Vagrant: the crooked gates of the estate swallow you; Mrs. Oakum lets out a breath she has held since supper>>
mrs_oakum [smile]: <<Mrs. Oakum says thank you, a little shyly, and that it's an odd place but a warm one>>
move druskenvald_estate:from_village

~ prisoner
Narrator: <<The Vagrant: Mrs. Oakum sits in the end cell with her hands folded, patient as a cow>>
mrs_oakum [weary]: <<Mrs. Oakum says not to worry, she's had worse nights, and the constable brought her a blanket>>
-> END
