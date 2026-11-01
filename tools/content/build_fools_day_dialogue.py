#!/usr/bin/env python3
"""ONE-SHOT (R21). Writes the fifteen reveler conversations, one file per costume (narrative/fools_day/reveler_<costume>.dialogue), and the release-slip
nodes of the Prize Counter (the Prize Counter's narrative/fools_day/prize.dialogue (appended)). The logic is a fixed template; the spoken lines come from
tools/content/fools_day_lines.json (drafted by Gemini through the ai-bridge, edited).
    python3 tools/content/build_fools_day_dialogue.py"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from fools_day_cast import REVELERS, COSTUMES

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "narrative/fools_day"
LINES = json.loads((ROOT / "tools/content/fools_day_lines.json").read_text())
MOOD = {"intro": "smile", "slip": "neutral", "church_ok": "smile", "church_fail": "smile", "calm": "weary", "beaten": "weary", "sheltered": "weary", "fight_warn": "angry",
        "tune_intro": "smile", "tune_ok": "smile", "tune_fail": "smile", "letter_charmed": "smile", "letter_free": "sad"}
BELLS = ("doris_squire", "weston_murdoch")


def say(nid, key, mood=None):
    t = " ".join(str(LINES[nid][key]).split())
    return f"{nid} [{mood or MOOD[key]}]: {t}"


def freed(nid, how):
    return [f'set reveler_{nid} = "{how}"', f"set reveler_{nid}_freed", "set revelers_freed += 1"]


def person(nid):
    name = REVELERS[nid][0]
    L = [f"~ {nid}_start", say(nid, "intro"), f"-> {nid}_menu", "",
         f"~ {nid}_menu",
         f"* [if flag.release_slips >= 1] Show them a release slip -> {nid}_slip",
         f"* [Persuasion DC 15] Invite them to a better party, at a quiet church -> {nid}_church | {nid}_church_fail",
         f"* [Deception DC 15] Say Chuckles wants them at the church for the next number -> {nid}_church | {nid}_church_fail",
         f"* [knows:calm_emotions] Cast Calm Emotions on them -> {nid}_calm",
         f"* [knows:greater_restoration] Cast Greater Restoration on them -> {nid}_calm"]
    if nid in BELLS:
        L += [f"* [if not flag.bell_tune_known and not flag.bell_tune_lost] Ask about the tune they keep humming -> {nid}_tune",
              f"* [if flag.bell_tune_known] Hum the finished tune with them -> {nid}_calm"]
    if nid == "old_rusty":
        L += ["* [if item:bess_second_letter] Read him Bess's letter -> old_rusty_letter"]
    L += [f"* Knock them out of the costume, bruised but not hurt for good -> {nid}_fight",
          "* Leave them dancing for now -> END", ""]
    L += [f"~ {nid}_slip", say(nid, "slip"), "set release_slips -= 1"] + freed(nid, "tickets") + ["-> END", ""]
    L += [f"~ {nid}_church", say(nid, "church_ok"), f"lead {nid} to fd_silent_church", "if check.last"] + freed(nid, "church") + ["set church_guests += 1", "endif", "-> END", ""]
    L += [f"~ {nid}_church_fail", say(nid, "church_fail"), "set fd_chuckles_amused", f"-> {nid}_menu", ""]
    L += [f"~ {nid}_calm", say(nid, "calm")] + freed(nid, "uncharmed") + ["-> END", ""]
    L += [f"~ {nid}_fight", say(nid, "fight_warn"), "Narrator: The dancers nearby keep on dancing. Nobody here is going to remember a punch.", f"combat reveler_{nid}", ""]
    L += [f"~ {nid}_beaten", say(nid, "beaten")] + freed(nid, "beaten") + ["-> END", ""]
    if nid == "old_rusty":
        L += [f"~ {nid}_sheltered", say(nid, "sheltered"), "* [if item:bess_second_letter] Give him Bess's letter -> old_rusty_letter_free", "* Let him sit -> END", ""]
        L += ["~ old_rusty_letter", say(nid, "letter_charmed"), "take bess_second_letter", 'set stork_letter_outcome = "charmed"', "quest the_storks_letter done", f"-> {nid}_menu", ""]
        L += ["~ old_rusty_letter_free", say(nid, "letter_free"), "take bess_second_letter", 'set stork_letter_outcome = "lucid"', "quest the_storks_letter done", "-> END", ""]
    else:
        L += [f"~ {nid}_sheltered", say(nid, "sheltered"), "-> END", ""]
    if nid in BELLS:
        L += [f"~ {nid}_tune", say(nid, "tune_intro"), "if not flag.free_bell_asked", "quest free_the_bell asked", "set free_bell_asked", "endif", f"-> {nid}_tune_menu", "",
              f"~ {nid}_tune_menu",
              f"* [Performance DC 15] Finish the tune -> {nid}_tune_ok | {nid}_tune_fail",
              f"* [if item:jericho_banjo] Play the tune out on Jericho's banjo -> {nid}_tune_banjo",
              f"* [Religion DC 13] Recall a Brightsinger hymn that ends it -> {nid}_tune_ok | {nid}_tune_fail",
              f"* [ends:free_the_bell] Give up on the tune -> {nid}_tune_silenced",
              f"* Back to the others -> {nid}_menu", "",
              f"~ {nid}_tune_ok", say(nid, "tune_ok"), "quest free_the_bell done", "set bell_tune_known", f"-> {nid}_menu", "",
              f"~ {nid}_tune_banjo", "Narrator: A banjo is not a bell, but it knows how a song wants to end. The last bar lands and the little bells all ring together.", say(nid, "tune_ok"),
              "set bell_tune_banjo", "quest free_the_bell done", "set bell_tune_known", f"-> {nid}_menu", "",
              f"~ {nid}_tune_fail", say(nid, "tune_fail"), f"-> {nid}_tune_menu", "",
              f"~ {nid}_tune_silenced", "Narrator: The humming goes on without an ending, a little thinner each time round.", "quest free_the_bell silenced", "set bell_tune_lost", f"-> {nid}_menu", ""]
    return L


def slips():
    taunts = ["Hee-hee, the very first one is only one ticket!", "Two tickets for the second, hip-hip, such a bargain!", "Three! The third is three. I did not make that up.",
              "Four, four, four, a friend for four.", "Five tickets, and what a lovely friend.", "Six! Look how much you love them.",
              "Seven, seven, shiny seven.", "Eight tickets and you are still not cross with me? Rude.", "Nine, and I am starting to enjoy this.",
              "Ten! Ten! Do you hate me yet?", "Eleven, my favourite number after twelve.", "Twelve. The last one. Look how much it costs."]
    L = ["~ slip", "chuckles [sly]: A release slip, for one friend, hee-hee. The price goes up every time. That is the whole joke."]
    for n in range(12):
        L.append(f"{'if' if n == 0 else 'elif'} flag.revelers_bought == {n}")
        L.append(f"-> slip_{n + 1}")
    L += ["else", "chuckles [weary]: Nothing left to sell, silly. You have all the friends there are.", "-> counter", "endif", ""]
    for n in range(1, 13):
        L += [f"~ slip_{n}", f"chuckles [sly]: {taunts[n - 1]}",
              f"* [if flag.fool_tickets >= {n}] Pay {n} ticket{'s' if n > 1 else ''} for a slip -> buy_{n}", "* Not now -> counter", "",
              f"~ buy_{n}", f"set fool_tickets -= {n}", "set revelers_bought += 1", "set release_slips += 1",
              "chuckles [smile]: Hip-hip! Take it to your friend and wave it under their nose. They love that.", "-> counter", ""]
    return L


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for costume in COSTUMES:
        L = [f"# R21 reveler conversations for the {costume} costume: logic from tools/content/build_fools_day_dialogue.py, lines drafted by Gemini (R21 revelers), edited.", ""]
        for nid, (name, c, cell, sw) in REVELERS.items():
            if c == costume:
                L += person(nid)
        (OUT / f"reveler_{costume}.dialogue").write_text("\n".join(L) + "\n")
    prize = OUT / "prize.dialogue"
    MARK = "# --- release slips (tools/content/build_fools_day_dialogue.py) ---"
    text = prize.read_text() if prize.exists() else ""
    text = text.split(MARK)[0].rstrip() + "\n\n" + MARK + "\n" + "\n".join(slips()) + "\n"
    prize.write_text(text)
    print("ok")
