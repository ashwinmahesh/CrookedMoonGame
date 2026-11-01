# R20 side quest: Doris Writes Poetry. Ambrose Quill finds a nameless poem better than his own; the party finds the rest in Doris's desk and, when the charm lifts, brings him to her.

~ start
Narrator: <<The Vagrant: Ambrose Quill on an upturned crate, reciting to a mob that has stopped to listen, every bit as grand and hopeless as ever>>
ambrose_quill [smile]: <<Quill, flourishing a sheet, says he found a nameless poem pinned to the notice board that is better than anything he has written, and he is furious, and he must find the poet>>
* <<Ask to see the poem.>> -> read
* <<Offer to find the poet.>> -> accept
* <<Say we are busy.>> -> END

~ read
ambrose_quill [sad]: <<Quill reads four lines about the moor in the rain, in a plain square voice, and goes quiet>>
Narrator: <<The Vagrant: it is a good poem, plain as a stone and twice as heavy>>
-> start

~ accept
set quill_asked
quest doris_poetry asked
ambrose_quill [smile]: <<Quill declares the quest a noble one and says the hand is square and the paper is the constable's; he is not accusing anyone>>
-> END

~ progress
if flag.golub_dead and flag.quill_poem_found and not flag.rk_poetry_met
ambrose_quill [smile]: <<Quill says the charm is over, and the poet may be told; he has prepared a modest critique>>
* <<Take Quill to the constable's station.>> -> go_station
* <<Not yet.>> -> END
endif
if flag.quill_poem_found
ambrose_quill [weary]: <<Quill asks that nothing be done until the mob stops chanting, as he does not fancy reading verse to a posse>>
-> END
endif
ambrose_quill [sly]: <<Quill asks if there is any word of the poet, and says the constable's desk is a place a rhymer might look>>
-> END

~ go_station
Narrator: <<The Vagrant: the two of you walk to the constable's station, Quill rehearsing under his breath>>
move wickermoor_constable_station

~ drawer
Narrator: <<The Vagrant: the desk drawer sticks, then gives with a soft squeak; inside, a stack of neat square sheets tied with a bootlace>>
* [Sleight of Hand DC 10] <<Work the drawer open quietly.>> -> found | found
* <<Force it with a knife.>> -> found
* <<Leave it.>> -> END

~ found
set quill_poem_found
give rk_doris_poems
if flag.quill_asked
quest doris_poetry poem_found
endif
Narrator: <<The Vagrant: twenty poems about the moor, a lost sister and the Patient Lady, in a hand you recognise from every warning ticket in the village; they are good>>
* <<Keep them safe, to bring to Ambrose Quill.>> -> keep
* [ends:doris_poetry] <<Burn them: nobody should read her heart without leave.>> -> burn

~ keep
Narrator: <<The Vagrant: you tie the bootlace again and tuck the stack into your coat>>
-> END

~ burn
quest doris_poetry burned
take rk_doris_poems
Narrator: <<The Vagrant: the stove takes them hungrily; for a moment each page glows with its own words before the words go out>>
-> END

~ doris_station
appear ambrose_quill
Narrator: <<The Vagrant: Doris Squire at her desk, cap straight; Ambrose Quill stands in the doorway holding the stack of poems like a baby>>
ambrose_quill [smile]: <<Quill, solemn for once, says he has read all twenty and the third is the best thing he has heard in a decade; he would be honoured to publish it under her name>>
doris_squire [afraid]: <<Doris stares at the poems, then at Quill, and says four words: it is not very good>>
ambrose_quill [sly]: <<Quill says that is exactly the sort of thing a poet says when it is very good indeed>>
set rk_poetry_met
quest doris_poetry met
doris_squire [smile]: <<Doris says to leave the stack on the desk, and not to tell anyone, and perhaps to come back on Thursday>>
-> END
