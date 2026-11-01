# R20: inside the dovecote: Golub before the fight, her stashed secrets, and home to roost.

~ golub
Narrator: <<The Vagrant: at the north end of the roost a platform of straw and cloth, four windows behind it, and on the platform a pigeon hag admiring her own feathers>>
golub_graygullet [sly]: <<Golub, haughty and cooing at once, says the party took such trouble to find her and she hopes it was worth the mud; she sneers that they were useful pawns>>
-> menu

~ menu
* [Insight DC 15] <<Look at how she preens.>> -> vain | vain_missed
* <<Say we will end her here.>> -> attack
* <<Say nothing and ready our weapons.>> -> attack
* <<Back away down the ladder.>> -> END

~ vain
set rk_golub_vain
Narrator: <<The Vagrant: she cannot keep her wings still; every sentence she says angles for admiration, and a kind word lands on her like a blow>>
-> menu
~ vain_missed
Narrator: <<The Vagrant: she is overwhelming and you cannot say why>>
-> menu

~ attack
set rk_golub_started
golub_graygullet [angry]: <<Golub shrieks that nobody comes into her roost and leaves it, and the dovecote lurches>>
Narrator: <<The Vagrant: the whole building heaves up on its legs, the floor tilts, and pigeons burst from every cubby>>
combat rk_golub

~ cubbies
Narrator: <<The Vagrant: cubby after cubby stuffed with letters, diaries and notes, each tagged in a hag's neat hand with a name and what they would pay to hide>>
* <<Read them all.>> -> read
* <<Leave them.>> -> END
~ read
set golub_secrets_read
set cult_proof_randall
set cult_proof_alda
set cult_proof_baltus
set cult_proof_gaston
set cult_proof_howie
Narrator: <<The Vagrant: it takes an hour; by the end you know who in Wickermoor serves which faith and which of your neighbours kneels to the antlered hare>>
-> END

~ home_to_roost
cutscene rk_home_to_roost
Narrator: <<The Vagrant: the dovecote's legs fold under it and the wings pull back into the thatch as it thumps down for good>>
cutscene rk_home_to_roost_2
Narrator: <<The Vagrant: in the straw lies a small dead pigeon-man, one human ear turned up toward the rafters>>
cutscene rk_home_to_roost_3
Narrator: <<The Vagrant: that morning in the village the townsfolk stand blinking in the street, and someone hangs the first strand of festival bunting>>
cutscene end
set golub_dead
quest roving_rookery done
xp milestone
if quest.quiet_door == asked
quest quiet_door moot
endif
if quest.jury_of_pigeons == asked
quest jury_of_pigeons moot
endif
if quest.forms_for_the_end == asked
quest forms_for_the_end moot
endif
if quest.forms_for_the_end == stamped
quest forms_for_the_end moot
endif
if quest.powder_keg_ledger == asked
quest powder_keg_ledger moot
endif
Narrator: <<The Vagrant: the charm lifts like a held breath; the pigeons go back to being only pigeons, and a very long night is almost over>>
-> END
