# R20: the village under the charm: villagers who shun the party, the mob, Albert in town, and the comic people.

~ shun
Narrator: <<The Vagrant: a neighbour you know sees you, crosses the street, and a bolt scrapes shut behind them>>
* [Insight DC 18] <<Look at their eyes.>> -> shun_charm | shun_missed
* <<Let them go.>> -> END
~ shun_charm
set rk_charm_seen
Narrator: <<The Vagrant: a lilac glint, the same in every eye; they are not bad people, only walked>>
-> END
~ shun_missed
Narrator: <<The Vagrant: a closed face, and nothing more than that>>
-> END

~ mob_a
Narrator: <<The Vagrant: a knot of neighbours with torches comes round the corner, all in step, chanting a name that is not quite yours>>
-> mob
~ mob_b
Narrator: <<The Vagrant: neighbours with cudgels fill the lane from wall to wall, walking as one>>
-> mob
~ mob_c
Narrator: <<The Vagrant: farmers with pitchforks, chanting, and not one of them blinking>>
-> mob
~ mob_round
Narrator: <<The Vagrant: the crowd round the Oak of Many Faces turns together and sees you>>
-> mob

~ mob
* [Insight DC 18] <<Study the mob: are they under an enchantment?>> -> mob_charm | mob_missed
* [Stealth DC 15] <<Slip into a doorway and let them pass.>> -> mob_slip | mob_caught
* [knows:dispel_magic] <<Free one villager with Dispel Magic.>> -> mob_freed
* [if item:rk_writ_of_passage] <<Show the Writ of Passage.>> -> mob_writ
* [if item:rk_button_ledger] <<Show Pip's receipt.>> -> mob_receipt
* <<Fight them off, without killing anyone.>> -> mob_fight
* <<Back away slowly.>> -> mob_back

~ mob_charm
set rk_charm_seen
Narrator: <<The Vagrant: lilac under every brow, and they come on without a flicker; you can strike but you cannot talk them down>>
-> mob
~ mob_missed
Narrator: <<The Vagrant: they are plainly in no mood to be asked anything>>
-> mob
~ mob_slip
set rk_mob_down = now
Narrator: <<The Vagrant: you press into a dark doorway and the mob goes by an arm's length away, mouthing your names>>
-> END
~ mob_caught
Narrator: <<The Vagrant: a torch swings round and a hundred eyes find you>>
-> mob_fight
~ mob_freed
set rk_mob_down = now
Narrator: <<The Vagrant: the magic washes over one man, who blinks, drops his cudgel, and whispers that the Oak is not where the trial will be>>
-> END
~ mob_writ
set rk_mob_down = now
Narrator: <<The Vagrant: the foremost villager reads the form, finds a missing initial, and the whole mob queues up to ask Wendel about it>>
-> END
~ mob_receipt
set rk_mob_down = now
Narrator: <<The Vagrant: a very small boy steps out of nowhere, nods to the mob, and it parts like water>>
-> END
~ mob_fight
set rk_mob_down = now
Narrator: <<The Vagrant: a cudgel swings and the lane erupts>>
combat rk_mob_fight
~ mob_back
Narrator: <<The Vagrant: you retreat a step at a time; the mob follows a step behind, uncertain>>
-> END

~ albert_town
Narrator: <<The Vagrant: on a lamp-post a fat pigeon with a wrinkled bald human head and ears watches you with great interest>>
peeping_albert [sly]: <<Albert, wet and wheedling, says mother knows everything you do and is so very pleased with how it is going>>
* <<Attack the pigeon.>> -> albert_fight
* [Intimidation DC 14] <<Tell him exactly what we will do to a spy.>> -> albert_talks | albert_flees
* [Performance DC 12] <<Bark like a hound.>> -> albert_talks | albert_flees
* [Animal Handling DC 14] <<Talk him down off the post.>> -> albert_talks | albert_flees
* <<Let him go.>> -> albert_flees
~ albert_fight
Narrator: <<The Vagrant: the pigeon takes off with a shriek>>
combat rk_albert_town
~ albert_talks
set rk_albert_fled
set rk_roost_known
peeping_albert [afraid]: <<Albert, quavering, blurts the dovecote is three nights out and mother will be cross; then flaps off>>
-> END
~ albert_flees
set rk_albert_fled
Narrator: <<The Vagrant: he bolts for the roofs and the pigeons close round him; something in the sky will know where you are by now>>
-> END

~ gaunt
Narrator: <<The Vagrant: Sergeant Gaunt crouches behind a hay cart at the back of a mob, one hand on a sword he has never drawn>>
sgt_gaunt [smile]: <<Gaunt, loud and unconvincing, says he is leading the mob from the rear, as any good commander would, and he has never lost a battle he was present at the end of>>
* <<Ask where the mob goes next.>> -> gaunt_route
* [Intimidation DC 12] <<Tell him to stop this nonsense.>> -> gaunt_scared | gaunt_route
* <<Leave him to it.>> -> END
~ gaunt_route
sgt_gaunt [weary]: <<Gaunt, in a whisper, says the lanes are patrolled in loops; the Round at night, the south lane at the turn of the hour; he would rather not be asked how he knows>>
-> END
~ gaunt_scared
set rk_mob_calm = now
sgt_gaunt [afraid]: <<Gaunt blanches and gives the order to go home, in a voice that cracks; the mob, to everyone's surprise, goes>>
-> END

~ pip
Narrator: <<The Vagrant: Pip Oakum sits on a barrel with a handful of buttons and a very businesslike expression>>
pip_oakum [sly]: <<Pip says he knows everybody's name and everyone owes him a button; for three gold pieces he will write you a receipt good for one safe passage>>
* [if gold >= 3] <<Pay Pip three gold for a receipt.>> -> pip_pay
* <<Ask what a button is worth these days.>> -> pip_buttons
* <<Say maybe later.>> -> END
~ pip_pay
gold -3
give rk_button_ledger
pip_oakum [smile]: <<Pip hands over a receipt, proudly, and says to show it to anyone who tries to hang you>>
-> END
~ pip_buttons
pip_oakum [sly]: <<Pip says a button is worth exactly what the person who needs it most will pay, which is why the mayor owes him eleven>>
-> pip

~ goat
Narrator: <<The Vagrant: in the middle of a village gone mad, the goat chews a thistle and regards the chaos with perfect calm>>
* <<Pet the goat.>> -> goat_pet
* <<Leave it to its thistle.>> -> END
~ goat_pet
advantage stealth 1h: the goat's calm
Narrator: <<The Vagrant: it permits this; a little of its composure seems to rub off on you>>
-> END

~ jeremiah_body
Narrator: <<The Vagrant: Jeremiah Stover lies where the mob left him, accused of hiding strangers; his hat is on his chest>>
-> END
~ jeremiah_escort
jeremiah_stover [afraid]: <<Jeremiah, hunched behind a cart, says the mob has his name on a list; he will go to the estate if somebody shows him the way>>
* <<Tell him to go up the hill tonight, we will cover him.>> -> jeremiah_go
* <<Say we will come back for him.>> -> END
~ jeremiah_go
set rk_jeremiah_hidden
jeremiah_stover [weary]: <<Jeremiah thanks you gruffly and says the tubers can rot; he sets off up the hill>>
-> END
~ jeremiah_hiding
jeremiah_stover [weary]: <<Jeremiah, crouched at the foot of the estate road, says he is waiting for dark>>
-> END
