#!/usr/bin/env python3
"""R26 Moonfall: every conversation (narrative/moonfall/*.dialogue). The eight Old Fear files come from moonfall_fears.py; the Vagrant, the moon,
and the four side quests are here. Logic by hand; lines drafted by Gemini from the briefs (moonfall_gemini.py).
    python3 tools/content/moonfall_dialogue.py            writes narrative/moonfall/*.dialogue using moonfall_texts.json if it exists
    python3 tools/content/moonfall_dialogue.py briefs     prints the number of lines to draft"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from moonfall_dsl import File, S, N, L, O, SK, cut2
from moonfall_common import FEARS, START_NIGHTS
from moonfall_fears import fear_file

ROOT = Path(__file__).resolve().parents[2]
V, K, G, T, Q, M, RO = "the_vagrant", "mf_kehlenn", "sgt_gaunt", "tamsin_ledger", "ambrose_quill", "marianna_grey", "mf_rowan_spirit"


def vagrant():
    f = File("vagrant", "Drafted by Gemini (R26 vagrant), edited. The Vagrant's offer in Wickermoor, his talk at the Round, the rewind and the ride out.")
    f.node("offer",
           cut2("mf_moon_shrieks", N("Night over Wickermoor, and the sky above the clocktower splits: the moon's mouth opens wide."),
                N("The whole village is in the street looking up, some already on their knees, and the shriek comes down over them like cold water.")),
           L("quest moonfall shriek"),
           S(K, "angry", "The moon speaks in Kehlenn's voice: thirteen nights, then it falls, and she will take the whole Hollow with her."),
           S(V, "weary", "He steps out of the fog with his fiddle under his arm and says he is sorry, he had hoped the epilogue was the last of it."),
           S(V, "neutral", "He explains eight old powers tied to the Hollow have woken to pull the moon down, each promised a realm remade in its image."),
           O("Ask what we can do", "plan"), O("Ask about the thirteen nights", "nights"),
           O("We will take up the hunt", "accept"), O("Not yet, we need a night", "later"))
    f.node("plan", S(V, "neutral", "Kill them, in order, each worse than the last, and every one you kill pauses the moon for a day and lifts you a little higher."),
           S(V, "sly", "And when the last is gone, Her Ladyship will make an offer, and that part nobody can help you with."), L("-> offer"))
    f.node("nights", S(V, "weary", "Thirteen to start, a day more for each of the eight you kill, and the moon waits for nobody, not even for you."),
           S(V, "neutral", "The clock runs on whatever you do, travel included, so do not dawdle over the small things."), L("-> offer"))
    f.node("later", S(V, "weary", "He nods, and says the moon will not wait but he will, a little, in the Round, with the train."), L("-> END"))
    f.node("accept",
           S(V, "smile", "He pulls his hat brim down and says that is the spirit, and he will keep the train warm at the Round."),
           N("Something loosens in your bones: the limit that held you has lifted, and there is room to grow past what you thought you were."),
           L("set moonfall_started"), L("set moonfall_begun"), L("set moonfall_clock = now"), L("set moonfall_credit = 0"),
           L(f"set moonfall_nights_left = {START_NIGHTS}"), L("quest moonfall hunt"),
           S(V, "neutral", "He says the first of them is in the farmland to the east, where the neighbours have taken to beheading each other."), L("move mf_round:from_village"))
    f.node("hub_start", S(V, "smile", "He tips his hat and says the train is warm and the tea is not bad, and what can he do for his passengers."), L("-> hub_menu"))
    f.node("hub_menu",
           O("Ask about the moon", "moon_talk"),
           O("Ask about turning time back", "rewind_ask", cond="not flag.moonfall_rewound"),
           O("Ask about the train out", "ride_ask", cond="flag.moonfall_started and not flag.moonfall_fled"),
           O("Ask about the things we lost", "moonfall/keeps:start", cond="not flag.mf_keeps_asked"),
           O("Take our leave", "END"))
    f.node("moon_talk", S(V, "weary", "He looks up at it for a long moment and says it is bigger every night, and it is not just his eyes."),
           S(V, "neutral", "He reminds you that the Ledger by the fire keeps the count, and that it is not a kind count."), L("-> hub_menu"))
    f.node("rewind_ask", S(V, "sly", "He says he has a tune that turns the clock back three nights, once, but it takes a crowd's worth of lives behind it."),
           L("if flag.vigil_deaths <= 11"), L("-> rewind"), L("elif item:jericho_banjo"), L("-> rewind_banjo"), L("else"), L("-> rewind_no"), L("endif"))
    f.node("rewind", S(V, "smile", "He says you saved enough on the moors to pay for it, and tucks the fiddle under his chin."), L("-> rewind_play"))
    f.node("rewind_no", S(V, "sad", "He says there were too many lost on the moors; the tune needs more voices than you left him."),
           S(V, "sly", "But a banjo from the cornfield, played true, might make up the difference, if you had one."), L("-> hub_menu"))
    f.node("rewind_banjo", S(V, "smile", "He sees Jericho's banjo on a hero's back and says that will do, that will do very nicely, and he will take the fiddle."), L("-> rewind_play"))
    f.node("rewind_play", N("The fiddle begins slow, then the banjo falls in behind it, and for the length of one tune the stars slide backward in their places."),
           L("set moonfall_credit += 3"), L("set moonfall_nights_left += 3"), L("set moonfall_rewound"),
           S(V, "smile", "Three nights, and not a minute more. Do not ask me to do it twice."), L("-> hub_menu"))
    f.node("ride_ask", L("quest mf_ride_out offered"),
           S(V, "weary", "He says there is a ride out on the final night, one train, for those who would rather not be here when the moon lands."),
           S(V, "sad", "It leaves the Hollow to its fate, and he will not think the less of you, but he will not pretend it is not a choice."),
           O("Take the ride out now", "ride_confirm"), O("We stay and fight", "ride_no", ends="mf_ride_out"), O("Ask about it later", "hub_menu"))
    f.node("ride_confirm", S(V, "neutral", "He asks you plainly if you are sure, because the Hollow stays behind."),
           O("Yes, take us out", "ride_yes"), O("No, not yet", "hub_menu"))
    f.node("ride_yes", L("quest mf_ride_out taken"), L("set moonfall_fled"), L("quest moonfall fled"),
           cut2("mf_train_out", N("The Ghostlight Express pulls out of the fog, its windows lit, and the Vagrant takes his hat off to the village once."),
                N("Behind the train the moon sags lower over the roofs, and the last lamp in the Round goes out.")),
           S(V, "sad", "He puts the train into the dark, and none of you speak until the Hollow is a smudge behind you."), L("end_game"))
    f.node("ride_no", S(V, "smile", "He grins, and says he rather thought so, and that the seat is yours if you change your minds."),
           L("quest mf_ride_out declined"), L("-> END"))
    return f


def moon():
    f = File("moon", "Drafted by Gemini (R26 moon), edited. The Night Ledger, Kehlenn's last offer, and the impact.")
    f.node("ledger", N("The Night Ledger is a long board of chalk tallies by the Round's fire, and a clock that has stopped agreeing with the church."),
           L("if flag.moonfall_nights_left >= 10"), N("There is a comfortable gap between the last tally and the bottom of the board."),
           L("elif flag.moonfall_nights_left >= 6"), N("The tallies crowd toward the bottom of the board now, and someone has stopped tidying them."),
           L("elif flag.moonfall_nights_left >= 3"), N("Three or four lines of chalk are left, and the lower ones have been gone over twice."),
           L("else"), N("There is hardly a hand's width of board left, and someone has chalked a small face beside it."), L("endif"),
           O("Study the sky", "sky"), O("Leave it", "END"))
    f.node("sky", N("The moon fills more of the sky than a moon should, its crooked grin big enough to read the teeth."),
           L("if flag.old_fears_slain >= 4"), N("It looks less sure of itself than it did, the way a bully does when you have hit him once."), L("endif"),
           L("-> END"))
    f.node("last_offer",
           cut2("mf_one_last_choice", N("The moon hangs a few hundred feet above the hill, its face filling the sky, roofs and trees tearing loose toward it in the gale."),
                N("In the crescent the crone's face moves, and its lips shape words you can hear in your teeth.")),
           S(K, "sly", "Kehlenn speaks softly: all eight are dead and you are still standing, and she is almost impressed."),
           S(K, "neutral", "She offers one thing: let the moon fall, and remake Druskenvald in your own image, with every other soul in it gone."),
           L("-> last_menu"))
    f.node("last_menu",
           O("Hear her out", "offer_speak"), O("Ask the Vagrant what he thinks", "vagrant_say"),
           O("Refuse her", "refuse_confirm"), O("Accept her offer", "accept_confirm"))
    f.node("offer_speak", S(K, "neutral", "She says it is a clean offer: a realm that is only you, no old powers, no crooked anything, nobody left to be hurt."),
           S(K, "sad", "She says she is too proud to beg, so she will say it once, and let the wind carry the rest."), L("-> last_menu"))
    f.node("vagrant_say", S(V, "weary", "He studies the moon with his head to one side and says it is not his place to tell the living how to live."),
           S(V, "neutral", "But he has carried a great many dead, and not one of them wished for company that wasn't alive."), L("-> last_menu"))
    f.node("refuse_confirm", N("The gale pulls at your coats, and the moon hangs on your answer."),
           O("Refuse her, and let the moon go back", "refused"), O("Think again", "last_menu"))
    f.node("accept_confirm", N("The wind drops for a moment, as if the world were listening."),
           O("Accept: the moon falls on everyone else", "accepted"), O("Think again", "last_menu"))
    f.node("refused", L("set moonfall_offer = \"refused\""), L("quest moonfall refused"),
           S(K, "angry", "Kehlenn gives a long, cracked cry, and says then you are all fools, and the moon is hers no longer."),
           cut2("mf_offer_refused", N("The moon rises: slowly at first, then faster, lifting off the Hollow like a lid, its face softening and fading as it goes."),
                N("Above you the stars come back, one at a time, clean and small, and the crescent hangs in the sky with no face at all.")),
           L("end_game"))
    f.node("accepted", L("set moonfall_offer = \"accepted\""), L("quest moonfall accepted"),
           S(K, "smile", "Kehlenn laughs, a low rich sound, and says then let it be done, and let it be yours."),
           cut2("mf_offer_accepted", N("The moon comes down on Druskenvald like a hand closing, and the whole land goes white and silent."),
                N("When you open your eyes you are floating in a green sea of light, the four of you alone, and everything is waiting to be named.")),
           L("end_game"))
    f.node("impact", L("quest moonfall lost"),
           cut2("mf_moon_impact", N("The moon fills the sky, and there is no room for anything else, and the night goes white from edge to edge."),
                N("There is a long, long silence where the Hollow was, and then there is nothing to hear it.")),
           L("end_game"))
    return f


def last_night():
    f = File("last_night", "Drafted by Gemini (R26 last_night), edited. Last Night in Wickermoor: three goodbyes at the Round.")
    f.node("gaunt_start", S(G, "neutral", "Sergeant Gaunt reports that he has executed a tactical retreat, toward the fight, and would like the party's blessing."),
           S(G, "sly", "He adds that the village would like one last evening together, with the three he can name, if the party can spare it."),
           O("We will sit with the village a while", "gaunt_accept"), O("Maybe later", "END"),
           O("There is no time for this", "gaunt_decline", ends="mf_last_night", cond="not flag.mf_last_night_asked"))
    f.node("gaunt_accept", L("set mf_last_night_asked"), L("quest mf_last_night asked"), L("-> gaunt_vignette"))
    f.node("gaunt_decline", S(G, "weary", "He salutes, a little stiffly, and says he understands, that duty comes first, and that he will be in the front rank."),
           L("quest mf_last_night skipped"), L("-> END"))
    f.node("gaunt_vignette", N("Sergeant Gaunt has drawn up a camp stool for each of you and set out his medals on a blanket as if for inspection."),
           S(G, "smile", "He explains his plan: advance in good order toward the retreat, and cover the rear by facing it."),
           O("Salute and say goodbye", "gaunt_done"))
    f.node("gaunt_done", S(G, "smile", "He says there is no finer company to be overrun in."), L("set mf_gaunt_said"), L("set mf_goodbyes += 1"), L("-> tally"))
    f.node("gaunt_after", S(G, "neutral", "He reports the rearguard is holding, and that there is no rear."), L("-> END"))
    f.node("tamsin_start", S(T, "neutral", "Tamsin Ledger is auditing the moon, and has found its distance unverified and its book of account missing."),
           O("Sit with her a while", "tamsin_vignette"), O("Later", "END"))
    f.node("tamsin_vignette", S(T, "weary", "She says she has filed the moon's fall in triplicate, and that if the moon is going to land on a village it ought to have the courtesy to submit a form."),
           O("Stamp her form and say goodbye", "tamsin_done"))
    f.node("tamsin_done", S(T, "smile", "She stamps it herself, carefully, and says it has been a privilege to be audited by you."),
           L("set mf_tamsin_said"), L("set mf_goodbyes += 1"), L("-> tally"))
    f.node("marianna_start", S(M, "weary", "Marianna Grey is brushing a horse that does not need it, and speaks haltingly: the animals know the moon is wrong."),
           O("Stay with her and the horses a while", "marianna_vignette"), O("Later", "END"))
    f.node("marianna_vignette", S(M, "sad", "She says she does not mind going, only that she has not finished the grey mare's mane, and might you help."),
           O("Help with the mane and say goodbye", "marianna_done"))
    f.node("marianna_done", S(M, "smile", "She says the mare is the calmest thing in the Hollow, and thanks you for the company."),
           L("set mf_marianna_said"), L("set mf_goodbyes += 1"), L("-> tally"))
    f.node("tally", L("if flag.mf_goodbyes >= 3"), L("quest mf_last_night done"),
           N("The three of you sit for a while without speaking, and it is the best hour of the whole sorry business."),
           L("else"), N("Somewhere in the Round, another stool is waiting."), L("endif"), L("-> END"))
    return f


def keeps():
    f = File("keeps", "Drafted by Gemini (R26 keeps), edited. What the Moon Keeps: four keepsakes, one for each Act.")
    f.node("start", S(V, "sly", "The Vagrant says the moon keeps what the dead lose, and four small things of yours are in its pockets, one from each part of your journey."),
           L("set mf_keeps_asked"), L("quest mf_what_moon_keeps asked"), L("-> menu"))
    f.node("menu", O("Ask where they might be", "where"), O("Show him what we have found", "hand_over", cond="item:mf_keepsake_1 or item:mf_keepsake_2 or item:mf_keepsake_3 or item:mf_keepsake_4"),
           O("Tell him to leave them to the moon", "left", ends="mf_what_moon_keeps"), O("Take our leave", "END"))
    f.node("where", S(V, "neutral", "The first fell at his own platform, the second in the farmland, the third in the Maidenmist dark, the fourth on the burning hill."), L("-> menu"))
    f.node("hand_over",
           L("if item:mf_keepsake_1"), L("take mf_keepsake_1"), L("set mf_keepsakes += 1"), L("endif"),
           L("if item:mf_keepsake_2"), L("take mf_keepsake_2"), L("set mf_keepsakes += 1"), L("endif"),
           L("if item:mf_keepsake_3"), L("take mf_keepsake_3"), L("set mf_keepsakes += 1"), L("endif"),
           L("if item:mf_keepsake_4"), L("take mf_keepsake_4"), L("set mf_keepsakes += 1"), L("endif"),
           L("if flag.mf_keepsakes >= 4"), L("-> all_found"), L("else"), L("-> some_found"), L("endif"))
    f.node("some_found", S(V, "neutral", "He turns the keepsakes over in his green hands and says that is some of it, and the rest is still out there somewhere."), L("-> menu"))
    f.node("all_found", S(V, "smile", "He lays the four small things in a row and says that is everything, and asks what you would like done with them."),
           O("Let him carry them on the train", "returned"), O("Keep them close ourselves", "kept"))
    f.node("returned", S(V, "smile", "He says he will keep them safe in the baggage car, and that you will have them back when it is over."),
           L("quest mf_what_moon_keeps returned"), L("bless party 2h"), L("-> END"))
    f.node("kept", S(V, "smile", "He says that is fair, that things want to be near their people, and tucks the empty cloth away."),
           L("quest mf_what_moon_keeps kept"), L("inspiration party"), L("-> END"))
    f.node("left", S(V, "weary", "He says the moon can have them, then, and that it will probably look after them better than most."),
           L("quest mf_what_moon_keeps left"), L("-> END"))
    return f


def verse():
    f = File("verse", "Drafted by Gemini (R26 verse), edited. The Last Verse: Ambrose Quill's finest line.")
    f.node("start", S(Q, "neutral", "Ambrose Quill declares he is composing the finest verse of his career and cannot find the last line."),
           L("set mf_verse_asked"), L("quest mf_last_verse asked"), L("-> menu"))
    f.node("menu", O("Offer a stirring line", "line_stirring"), O("Offer a wry line", "line_wry"), O("Offer an honest line", "line_honest"),
           O("Play a chord on Jericho's banjo", "banjo", cond="item:jericho_banjo"),
           O("Tell him to stop", "silence", ends="mf_last_verse"), O("Leave him to it", "END"))
    f.node("line_stirring", S(Q, "smile", "He writes your line down and declares it a battle hymn, which, he admits, has been his weakness all along."), L("set mf_verse_style = \"stirring\""), L("-> deliver"))
    f.node("line_wry", S(Q, "sly", "He writes your line down and says that is exactly the kind of thing a village says when it has no more dignity left to lose."), L("set mf_verse_style = \"wry\""), L("-> deliver"))
    f.node("line_honest", S(Q, "sad", "He writes your line down and is silent a moment, and says that is true, and that is why it hurts."), L("set mf_verse_style = \"honest\""), L("-> deliver"))
    f.node("banjo", N("You pluck one chord on Jericho's banjo and the whole Round holds still to hear it."),
           S(Q, "smile", "Quill says that is the missing music, and that the verse will be sung and not spoken."), L("set mf_verse_banjo"), L("-> menu"))
    f.node("deliver", N("Quill climbs onto the dais of the Round and clears his throat, and the village gathers in the dark below him."),
           S(Q, "neutral", "He recites the whole verse, in one steady breath, and the last line is the one you gave him."),
           L("if flag.mf_verse_banjo"), N("Behind him the banjo carries the tune, and for the length of it the Round forgets the moon."), L("endif"),
           L("quest mf_last_verse delivered"), L("-> END"))
    f.node("silence", S(Q, "sad", "He folds the page and puts it away, and says perhaps the village has heard enough verse for one lifetime."),
           L("quest mf_last_verse silenced"), L("-> END"))
    f.node("progress", S(Q, "neutral", "He asks if you have found the last line yet."), L("-> menu"))
    f.node("after", S(Q, "smile", "He nods to you across the Round, and goes on murmuring his verse to the dark."), L("-> END"))
    return f


def behemoth_extra(f):
    """The descendant of Rowan's sister (Marianna Grey): a short talk that gives Advantage on persuading Rowan."""
    f.node("descendant", S(M, "afraid", "Marianna Grey says a name her family never spoke, and does not know why she has it on her tongue."),
           O("Tell her about Rowan", "descendant_told"), O("Ask her what she remembers", "descendant_memory"), O("Leave her be", "END"))
    f.node("descendant_memory", S(M, "sad", "She says her grandmother used to stop sewing at dusk and look at the hill, and never said why."), L("-> descendant"))
    f.node("descendant_told", S(M, "sad", "She listens to the whole sad story with her hand on her mouth, and says she will go to her, if Rowan will have her."),
           L("set mf_behemoth_descendant"), L("advantage persuasion 2h: Rowan's sister's blood stands beside you"), L("-> END"))


def hook_stubs():
    """The Vagrant-offered hunt starts the Headsman's quest quietly; the other Fears' quests start from their own hook-givers."""
    return None


def all_files():
    out = [vagrant(), moon(), last_night(), keeps(), verse()]
    for fear in FEARS:
        ff = fear_file(fear)
        if fear["key"] == "behemoth":
            behemoth_extra(ff)
        out.append(ff)
    return out


def main():
    files = all_files()
    texts = {}
    tp = ROOT / "tools/content/moonfall_texts.json"
    if tp.exists():
        texts = json.loads(tp.read_text())
    if len(sys.argv) > 1 and sys.argv[1] == "briefs":
        n = sum(len(x.lines) for x in files)
        print(n, "lines in", len(files), "files")
        return
    out = ROOT / "narrative/moonfall"
    out.mkdir(parents=True, exist_ok=True)
    for x in files:
        (out / f"{x.name}.dialogue").write_text(x.render(texts))
    print("wrote", len(files), "files;", sum(len(x.lines) for x in files), "lines;", len(texts), "drafted")


if __name__ == "__main__":
    main()
