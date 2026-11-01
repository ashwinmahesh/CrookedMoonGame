# R20: the posse at the post office door. Doris holds a forged letter; they are charmed. Talk, run, give up or fight.

~ start
Narrator: <<The Vagrant: the posse fills the lane, torches and cudgels, Doris Squire in front with a letter held up like a warrant>>
doris_squire [angry]: <<Doris, clipped, says the letter names you as the postmaster's killers; hands up, quietly, or she takes you by force; she says very few words>>
-> menu

~ menu
* [Insight DC 18] <<Look closely at Doris's eyes and the faces behind her.>> -> charm | charm_missed
* [if flag.rk_charm_seen] [Persuasion DC 18] <<Tell Doris the letter is a forgery and she is not herself.>> -> talk_down | talk_fail
* [if flag.rk_charm_seen] [Deception DC 18] <<Swear we found the body that way and send the posse after Geneva.>> -> talk_down | talk_fail
* [Intimidation DC 20] <<Warn her what the posse will cost her if it comes closer.>> -> talk_down | talk_fail
* [knows:dispel_magic] <<Cast Dispel Magic on Doris.>> -> spell
* [knows:remove_curse] <<Cast Remove Curse on Doris.>> -> spell
* <<Run: the east alley behind the post office.>> -> flee
* <<Put our hands up and go with them.>> -> surrender
* <<Fight our way out.>> -> fight

~ charm
set rk_charm_seen
Narrator: <<The Vagrant: a lilac glint in every eye, steady and unblinking; the posse is not angry, it is being walked>>
-> menu
~ charm_missed
Narrator: <<The Vagrant: all you see is an angry mob with the sort of faces that came straight from supper>>
-> menu

~ talk_fail
doris_squire [angry]: <<Doris says no, and signals the deputies forward; two words and a step>>
-> menu_after_fail

~ menu_after_fail
* [knows:dispel_magic] <<Cast Dispel Magic on Doris.>> -> spell
* [knows:remove_curse] <<Cast Remove Curse on Doris.>> -> spell
* <<Run: the east alley behind the post office.>> -> flee
* <<Put our hands up and go with them.>> -> surrender
* <<Fight our way out.>> -> fight

~ talk_down
set posse_outcome = "talked"
set rk_posse_done
quest roving_rookery hysteria
doris_squire [weary]: <<Doris wavers, frowns at the letter, and says she gives you an hour, no more; she has seen the pigeons too>>
Narrator: <<The Vagrant: the posse goes slowly back toward the Round, still chanting; the hysteria has not lifted, only paused>>
-> END

~ spell
set posse_outcome = "talked"
set rk_posse_done
set doris_cleared
quest roving_rookery hysteria
Narrator: <<The Vagrant: the magic runs over her like cold water and the lilac glint goes out of her eyes; for an hour Doris Squire is herself>>
doris_squire [neutral]: <<Doris sniffs the letter, mutters that the ink stinks of pigeon, and tells you to go, quickly, before the charm creeps back>>
-> END

~ flee
set posse_outcome = "fled"
set rk_posse_done
quest roving_rookery hysteria
Narrator: <<The Vagrant: you bolt down the east alley, over a fence, and through someone's cabbages; the shouting follows you all the way to the estate road>>
move wickermoor_village:from_estate

~ fight
set posse_outcome = "fought"
Narrator: <<The Vagrant: Doris sets her feet and the deputies come on>>
combat rk_posse

~ surrender
set posse_outcome = "surrendered"
set rk_posse_done
set jail_began = now
quest roving_rookery jailed
doris_squire [neutral]: <<Doris, grimly, says gear off, hands where she can see them; a bed and a bucket until the Witching Hour>>
Narrator: <<The Vagrant: the cell door is only a barred frame, but there is nowhere in Wickermoor to take what they have kept; across the Round the mob is already chanting>>
jail wickermoor_constable_station:cells until flag.jail_free

~ howie
howie_butterman [smile]: <<Howie, friendly and false, says it would all go easier if you come along quietly; he can speak to Doris about a quick trial>>
-> start

~ grunt
Narrator: <<The Vagrant: a deputy in an armband stares through you and mutters your names in rhythm, over and over>>
-> END
