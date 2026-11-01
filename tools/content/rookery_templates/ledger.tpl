# R20 side quest: The Powder Keg Ledger. Weston Murdoch's list of who the hysteria will take; the party crosses names off before the seventh dawn.

~ start
Narrator: <<The Vagrant: Weston Murdoch at the church door, a ledger open in his hands and the light gone from his face>>
weston_murdoch [sad]: <<Weston, warm even now, says the madness will break out in the village on the seventh dawn, a neighbour dead and a house burned, twice as much every week after; he has the first names>>
* <<Ask who is on the list.>> -> names
* <<Offer to help cross them off.>> -> accept
* <<Say we are searching for the cause.>> -> END

~ names
weston_murdoch [weary]: <<Weston says Jeremiah Stover, who the mob thinks hides strangers, and the schoolhouse, which has the driest roof in the village>>
-> start

~ accept
set rk_ledger_asked
quest powder_keg_ledger asked
weston_murdoch [smile]: <<Weston presses the ledger into your hand and says to hide Jeremiah and wet the schoolhouse roof, and God keep us>>
-> END

~ progress
if days_since.hysteria_began >= 7
if flag.rk_jeremiah_hidden or flag.rk_school_saved
quest powder_keg_ledger done
weston_murdoch [weary]: <<Weston closes the ledger and says one name is crossed out, and that is one more than it would have been>>
-> END
else
quest powder_keg_ledger burned
weston_murdoch [sad]: <<Weston says the seventh dawn came and nothing was crossed out; he does not blame you, and cannot look at you>>
-> END
endif
endif
Narrator: <<The Vagrant: Weston turns the ledger toward you; two names, two days of the seventh>>
-> menu

~ menu
* [if not flag.rk_school_saved] <<Wet the schoolhouse roof: organise a bucket line.>> -> school
* [if not flag.rk_jeremiah_hidden] <<Ask Weston where Jeremiah is hiding.>> -> jeremiah
* [if flag.rk_jeremiah_hidden and flag.rk_school_saved] <<Both are done.>> -> both
* <<Not yet.>> -> END

~ school
* [Athletics DC 12] <<Haul water yourselves, up the schoolhouse roof.>> -> school_ok | school_poor
* [if gold >= 20] <<Pay Beatrice Wells twenty gold for her rain barrels.>> -> school_paid
~ school_poor
Narrator: <<The Vagrant: the bucket line collapses in a clatter and a spill; the roof is no wetter>>
-> menu
~ school_paid
gold -20
-> school_ok
~ school_ok
set rk_school_saved
Narrator: <<The Vagrant: the schoolhouse roof streams and steams, the slates black and heavy with water; if a spark lands it will find nothing to hold>>
-> menu

~ jeremiah
weston_murdoch [neutral]: <<Weston says Jeremiah is crouched behind the carts in the Round; ask him to come up the hill after dark>>
-> menu

~ both
quest powder_keg_ledger done
weston_murdoch [smile]: <<Weston crosses off both names with a trembling pen, and weeps a little>>
-> END
