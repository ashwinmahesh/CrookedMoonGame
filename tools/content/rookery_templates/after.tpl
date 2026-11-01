# R20: the village after Golub: the new postmaster, the constable, the Druskenvalds' repairs.

~ geneva_postmaster
Narrator: <<The Vagrant: Geneva Fairchild is back behind the post office counter, a little thinner, her lilac eyes tired but clear>>
geneva_fairchild [sad]: <<Geneva, earnest and quiet, says she remembers shouting at you and cannot say why; she is the postmaster now and means to do it by the book>>
* <<Tell her it was not her fault.>> -> geneva_forgive
* <<Ask what she remembers of the postmaster.>> -> geneva_remember
* <<Wish her well.>> -> END
~ geneva_forgive
set rk_geneva_back
geneva_fairchild [smile]: <<Geneva smiles shakily and says she will read every letter exactly once, and never twice>>
-> END
~ geneva_remember
geneva_fairchild [afraid]: <<Geneva says Theodora taught her to read lilac eyes as luck, not a curse, and that is the nicest thing anyone ever said to her>>
-> geneva_postmaster

~ wynn
Narrator: <<The Vagrant: a broad young inn hand sorts letters at the post office counter with enormous, slow care>>
wynn_carter [smile]: <<Wynn, earnest, says somebody had to take the keys, and nobody else would; he has read the rules twice and means to read them again>>
* <<Ask how he came to the job.>> -> wynn_how
* <<Wish him luck.>> -> END
~ wynn_how
wynn_carter [weary]: <<Wynn says Alda Farnum put him forward because he can read and keep quiet; he did not know that was a warning>>
-> wynn

~ doris_after
set rk_doris_after
Narrator: <<The Vagrant: Doris Squire stands in the Round, cap straight, looking at the wreckage and at her own hands>>
doris_squire [weary]: <<Doris says she remembers all of it and would sooner not; she is sorry; she does not say it twice>>
if flag.jail_key_left
doris_squire [sad]: <<Doris adds that somebody read a few lines of hers, and it was kind, and she has not decided how she feels about that>>
endif
-> END

~ phillip_repairs
Narrator: <<The Vagrant: Phillip Druskenvald, in a dapper coat, is handing out purses to a line of people who cannot meet his eye>>
phillip_druskenvald [smile]: <<Phillip, theatrical, says the Druskenvalds will rebuild what the madness broke, down to the last shutter; it is the least a landowner can do>>
set rk_repairs_paid
-> END

~ adela_worry
Narrator: <<The Vagrant: Adela Druskenvald stands with her hands tucked in her sleeves, looking at a roof where pigeons have settled>>
adela_druskenvald [afraid]: <<Adela says in her bright, slangy way that she had a dream about a laughing sun, and that she did not like the look of it at all>>
-> END
