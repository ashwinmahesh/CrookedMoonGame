# R20 side quest: A Jury of Pigeons. Tamsin Ledger will not let a mob try anyone without a docket, a quorum and sworn witnesses.

~ start
Narrator: <<The Vagrant: Tamsin Ledger on a crate at the edge of the Round, clipboard on her knee, auditing a mob as if it were a ledger>>
tamsin_ledger [neutral]: <<Tamsin, deadpan, says the mob is out of order: no docket, no quorum, no sworn witnesses; she is minuting it, and she needs a jury, and the party is it>>
* <<Agree to be her jury.>> -> accept
* <<Ask what the charge is.>> -> charge
* <<Say we have no time.>> -> END

~ charge
tamsin_ledger [neutral]: <<Tamsin says the charge, as far as she can tell, is being a pigeon, and she has yet to establish whether that is a crime>>
-> start

~ accept
set rk_jury_asked
quest jury_of_pigeons asked
tamsin_ledger [smile]: <<Tamsin ticks a box, says she needs three things: a docket, a quorum and an oath from the witnesses, and she would like them before the Witching Hour>>
-> END

~ progress
tamsin_ledger [neutral]: <<Tamsin reads her list: docket, quorum, oath; she will tell you what remains>>
-> menu

~ menu
* [if not flag.rk_jury_docket] <<The docket: ask Mayor Somerton for one.>> -> docket
* [if not flag.rk_jury_quorum] <<The quorum: seat enough people to sit.>> -> quorum
* [if not flag.rk_jury_oath] <<The oath: swear in the pigeons.>> -> oath
* [if flag.rk_jury_docket and flag.rk_jury_quorum and flag.rk_jury_oath] <<Call the hearing to order.>> -> hearing
* [ends:jury_of_pigeons] <<Abandon the hearing; it is hopeless.>> -> quit
* <<Come back to it later.>> -> END

~ docket
* [Persuasion DC 13] <<Ask Mayor Somerton politely for a docket form.>> -> docket_ok | docket_poor
* <<Copy a docket out by hand from his desk, an hour.>> -> docket_copy
~ docket_poor
Narrator: <<The Vagrant: the mayor says forms are issued on Thursdays only>>
-> menu
~ docket_copy
time +60
-> docket_ok
~ docket_ok
set rk_jury_docket
give rk_docket
Narrator: <<The Vagrant: you hold the docket, ruled and blank, and Tamsin's eyes follow it like a hawk>>
-> menu

~ quorum
* [Intimidation DC 12] <<Order the mob to sit down in rows.>> -> quorum_ok | quorum_poor
* <<Note that the village goat counts as a juror.>> -> quorum_goat
~ quorum_poor
Narrator: <<The Vagrant: the mob stares through you; apparently nobody has yet been dismissed>>
-> menu
~ quorum_goat
Narrator: <<The Vagrant: Tamsin looks at the goat, looks at her list, and rules it admissible>>
-> quorum_ok
~ quorum_ok
set rk_jury_quorum
Narrator: <<The Vagrant: somehow there are twelve of them, more or less, sitting in rows on the cobbles>>
-> menu

~ oath
* [Animal Handling DC 12] <<Coax a pigeon onto your arm and have it take the oath.>> -> oath_ok | oath_poor
* [Performance DC 12] <<Swear the pigeons in with a very solemn flourish.>> -> oath_ok | oath_poor
* <<Request a solemn affirmation instead of an oath.>> -> oath_affirm
~ oath_poor
Narrator: <<The Vagrant: the pigeon fixes you with one orange eye and leaves a deposit on the docket>>
-> menu
~ oath_affirm
Narrator: <<The Vagrant: Tamsin lowers her pen and says that, under section nine, an affirmation is equally binding on a bird>>
-> oath_ok
~ oath_ok
set rk_jury_oath
Narrator: <<The Vagrant: the pigeons coo something that Tamsin minutes as agreement>>
-> menu

~ hearing
quest jury_of_pigeons sitting
tamsin_ledger [neutral]: <<Tamsin calls the court to order, reads the charges against a pigeon, and asks whether the accused has anything to say>>
Narrator: <<The Vagrant: the pigeon says something long and complicated, and the mob listens, rapt, as if it were scripture>>
tamsin_ledger [smile]: <<Tamsin rules that proceedings cannot continue until the minutes are read, and she begins to read them, slowly, from page one>>
set rk_mob_calm = now
set rk_jury_done
quest jury_of_pigeons done
Narrator: <<The Vagrant: by the third page the torches are guttering, by the tenth the mob is asleep in rows, and the whole Round lies quiet for the first time in days>>
-> END

~ quit
set rk_jury_abandoned
quest jury_of_pigeons abandoned
tamsin_ledger [sad]: <<Tamsin says in a very small voice that she understands, and begins to pack her docket away>>
-> END

~ after
if flag.rk_jury_done
tamsin_ledger [smile]: <<Tamsin says the minutes were adopted unanimously, though no one was awake to move it>>
-> END
endif
tamsin_ledger [weary]: <<Tamsin says she is still auditing, but nobody is listening>>
-> END
