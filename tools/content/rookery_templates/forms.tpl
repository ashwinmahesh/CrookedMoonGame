# R20 side quest: Forms for the End of the World. Mayor Somerton will not let the hysteria proceed without three stamps; the last may be forged, at a price.

~ start
Narrator: <<The Vagrant: Mayor Wendel Somerton at a trestle table in the Founder's Round, bowler hat on, cane across the forms, supervising the end of the world>>
wendel_somerton [neutral]: <<Wendel, officious, says matters of public hysteria cannot proceed without Form 14-B, Form 22, and a Writ of Passage, all stamped in triplicate; the stamps are missing; he will give a Writ to whoever finds them>>
* <<Agree to find the stamps.>> -> accept
* <<Ask what the Writ is for.>> -> writ_for
* <<Say we have other business.>> -> END

~ writ_for
wendel_somerton [smile]: <<Wendel says a Writ of Passage entitles the bearer to walk the village unmolested provided the molesters can be shown the correct form>>
-> start

~ accept
set rk_forms_asked
quest forms_for_the_end asked
wendel_somerton [smile]: <<Wendel lists them: the clock-chamber stamp, the schoolhouse seal, and the constable's; he trusts he need not say that forging is illegal>>
-> END

~ progress
wendel_somerton [neutral]: <<Wendel taps the table: clock stamp, schoolhouse seal, constable's stamp; what has the party brought?>>
-> menu

~ menu
* [if not flag.rk_stamp_a] <<The clock-chamber stamp: ask Tamsin Ledger, who audits all stamps.>> -> stamp_a
* [if not flag.rk_stamp_b] <<The schoolhouse seal: ask Pip Oakum, who owns everyone's buttons.>> -> stamp_b
* [if not flag.rk_stamp_c] <<The constable's stamp.>> -> stamp_c
* [if flag.rk_stamp_a and flag.rk_stamp_b and flag.rk_stamp_c] <<Deliver the three stamped forms.>> -> deliver
* <<Come back later.>> -> END

~ stamp_a
Narrator: <<The Vagrant: Tamsin Ledger holds the clock-chamber stamp as if it were a baby, and will not let go without a receipt>>
* [Persuasion DC 13] <<Ask Tamsin to lend the stamp for one signature.>> -> stamp_a_ok | stamp_a_poor
* <<Sign her receipt in triplicate, an hour of paperwork.>> -> stamp_a_receipt
~ stamp_a_poor
Narrator: <<The Vagrant: Tamsin says stamps are not lent; they are requisitioned>>
-> menu
~ stamp_a_receipt
time +60
-> stamp_a_ok
~ stamp_a_ok
set rk_stamp_a
give rk_stamp_clock
Narrator: <<The Vagrant: the stamp is yours for one signature, and TIME OF THE ESSENCE is printed on the forms in violet ink>>
-> menu

~ stamp_b
Narrator: <<The Vagrant: Pip Oakum has the schoolhouse seal in his button tin; the owl on it glares at you>>
* [if gold >= 2] <<Pay Pip two gold for the seal.>> -> stamp_b_paid
* [Persuasion DC 12] <<Tell Pip the village needs the seal for a good cause.>> -> stamp_b_ok | stamp_b_poor
~ stamp_b_poor
Narrator: <<The Vagrant: Pip says the village owes him for the last good cause and he is still waiting>>
-> menu
~ stamp_b_paid
gold -2
-> stamp_b_ok
~ stamp_b_ok
set rk_stamp_b
give rk_stamp_school
Narrator: <<The Vagrant: the seal is warm from his pocket, and you press it hard on the form>>
-> menu

~ stamp_c
Narrator: <<The Vagrant: the constable's stamp is in the locked station, in Doris Squire's desk>>
* [Sleight of Hand DC 15] <<Forge the constable's stamp from a potato and a penknife.>> -> forge_ok | forge_poor
* [if gold >= 20] <<Pay Wendel a twenty-gold filing fee instead.>> -> fee
* [if flag.doris_cleared] <<Ask Doris, who is clear-headed, to stamp it.>> -> stamp_c_ok
* <<Come back to this one.>> -> menu
~ forge_poor
Narrator: <<The Vagrant: the potato crumbles, the ink smears, and a deputy is looking over your shoulder>>
* <<Pay the twenty-gold fee and tear up the forgery.>> -> fee
* [ends:forms_for_the_end] <<Surrender the forgery and go quietly to the cells.>> -> forged
~ forge_ok
Narrator: <<The Vagrant: the stamp is rough but passes at a glance; Wendel will not look closely>>
-> stamp_c_ok
~ fee
gold -20
Narrator: <<The Vagrant: Wendel accepts the fee with the delicacy of a man who has never accepted a bribe in his life>>
-> stamp_c_ok
~ stamp_c_ok
set rk_stamp_c
-> menu

~ forged
set rk_forms_forged
set jail_began = now
quest forms_for_the_end forged
Narrator: <<The Vagrant: a deputy takes the forgery between two fingers; Wendel looks very pained; the cell door shuts>>
jail wickermoor_constable_station:cells until days_since.jailed >= 1

~ deliver
quest forms_for_the_end stamped
wendel_somerton [smile]: <<Wendel studies each form for a very long time, finds nothing wrong, and with enormous reluctance prepares the Writ>>
give rk_writ_of_passage
set rk_writ
set rk_forms_done
quest forms_for_the_end done
Narrator: <<The Vagrant: the Writ is ornate and mostly seals; you suspect no mob in the valley has ever read one>>
-> END

~ after
wendel_somerton [weary]: <<Wendel says that, strictly speaking, the world has not ended, and he would prefer to keep it so>>
-> END
