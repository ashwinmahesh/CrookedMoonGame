# R20 hook: Geneva's plea (route A), Geneva's accusation (route B), and the accusation of the postmaster across her counter (route B, earlier).

~ plea
Narrator: <<A pale young woman with lilac eyes runs up the north lane, skirts in her fists; the Vagrant, one or two sentences>>
geneva_fairchild [afraid]: <<Geneva, breathless: Theodora is dead on the post office floor, and she is terrified the constable will blame the first strangers she sees. Asks them to look at the body now.>>
* <<Ask what happened.>> -> plea_what
* <<Say we will come at once.>> -> plea_go
* <<Say not yet.>> -> plea_wait

~ plea_what
geneva_fairchild [afraid]: <<Geneva stammers that she found Theodora face down among the letters; nothing was taken, nothing broken, and there is not a mark on her. She will not say more in the street.>>
-> plea
~ plea_wait
geneva_fairchild [sad]: <<Geneva says please do not wait long, she cannot stay alone with it.>>
-> END

~ plea_go
set rk_started
quest roving_rookery plea
geneva_fairchild [afraid]: <<Geneva, relieved, says to follow her quickly and keep your heads down.>>
Narrator: <<The two of you hurry down the lane; the post office door stands open, and inside the lamp has not been lit; one sentence>>
move wickermoor_post_office

~ geneva_accuses
Narrator: <<The Vagrant: a posse's torches at the end of the lane, and Geneva stepping out in front of them with the whole village behind her>>
geneva_fairchild [angry]: <<Geneva, her eyes glinting lilac and her voice not her own, accuses the party of plotting to murder Mayor Somerton and of spilling Theodora's secrets; the mob has her letter.>>
set hysteria_began = now
set rk_posse_out
quest roving_rookery posse
* [Insight DC 16] <<Her eyes have a lilac glint, as if someone were standing behind them.>> -> geneva_charmed | geneva_missed
* <<Insist we never touched the mayor.>> -> geneva_end
* <<Say nothing and look for a way out.>> -> geneva_end

~ geneva_charmed
set rk_charm_seen
Narrator: <<The Vagrant: the glint is in her eyes and in every eye behind her, steady as a lantern; this is not anger, it is a hand on a puppet's strings>>
-> geneva_end
~ geneva_missed
Narrator: <<The Vagrant: all you can read is a very frightened young woman and a lot of angry neighbours>>
-> geneva_end
~ geneva_end
cutscene rk_village_turns
geneva_fairchild [angry]: <<Geneva, flatly: the constable will hear it; do not run>>
cutscene rk_village_turns_2
Narrator: <<The Vagrant: pigeons in rows along every roof ridge, all their heads turning to look at you>>
cutscene end
-> END

~ accuse_theodora
Narrator: <<The Vagrant: the postmaster at her counter, gloved left hand flat on a ledger, the pigeon on her shoulder watching you>>
theodora_mayville [neutral]: <<Theodora asks pleasantly whether you are here to post something; brisk and kind, with the faintest edge>>
* [Investigation DC 15] <<Lay out the mismatched seals, the changed letters, the glove she never takes off.>> -> exposed | exposed
* [Intimidation DC 16] <<Tell her we know what she is and she has one chance to say it.>> -> exposed | exposed
* <<Name her plainly as the hag who has been reading the valley's mail.>> -> exposed
* <<Post a letter, and keep our suspicions.>> -> accuse_wait

~ accuse_wait
theodora_mayville [neutral]: <<Theodora stamps the letter and says to come again, in a voice like a closing door>>
-> END

~ exposed
theodora_mayville [angry]: <<Theodora drops the kindness; she cackles and says the valley will be sorry, and that they were always her pawns>>
Narrator: <<The Vagrant: the woman sags like a coat off a peg, a smell of feathers fills the room, and out the north window something round is standing up on huge pigeon legs>>
cutscene rk_master_stroke_2
Narrator: <<The Vagrant: the dovecote, out the north window, rises on huge pigeon legs; the postmaster's skin lies empty on the boards>>
cutscene rk_master_stroke_3
Narrator: <<The Vagrant: it hops once, twice, and walks off over the roofs toward the moors; the valley will keep this mischief for later>>
cutscene end
set golub_exposed
set golub_exposed_early
set geneva_alive
quest roving_rookery exposed
-> END
