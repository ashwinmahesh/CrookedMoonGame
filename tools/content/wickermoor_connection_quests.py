#!/usr/bin/env python3
"""ONE-SHOT (world-quests1): the thirteen Connections as quests. Each is a journal thread: for the five whose thread begins on the train (an
incitement), a stage that WAITS (QuestLog `waits`) until Wickermoor is reached; then the scene in Wickermoor sets the stage "met" and the
quest ends well. The other eight appear when their scene is played. Patches the scenes and the incitements idempotently. Run from the repo root."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
# thread: (quest name, giver npc, waiting text, met journal, the scene's file)
THREADS = {
    "evolution": ("The Tailor's Measure", "thomasin_ardor", "Thomasin Ardor in Wickermoor will pick this up once the Crooked House is behind us.", "Thomasin took Cordelia's measure, and neither of them said what the fitting was really for.", "connections"),
    "ascendancy": ("The Innkeeper's Question", "alda_farnum", "Alda Farnum at the Green Queen will ask her question once the Crooked House is behind us.", "Alda asked Delphine her question over the taproom's bar, and Delphine answered it with a joke.", "connections"),
    "slaughter": ("The Huntress's Tracks", "hilda_brom", "", "Hilda Brom read Lucan's tracks in the Round, and some of what she read was not about wolves.", "connections"),
    "pilgrimage": ("What the Undertaker Knows", "mori_shade", "", "Mori Shade knew Rook's name before Rook gave it.", "connections"),
    "liberation": ("The Baker's Page", "holly_aster", "Holly Aster's bakery in Wickermoor will have a page for Silas once the Crooked House is behind us.", "Holly Aster kept a page back for Silas, and baked a loaf around it.", "connections"),
    "rejuvenation": ("Sister Rain's Seed", "sister_rain", "", "Sister Rain put a seed in Tobin's hand and asked for nothing for it.", "connections"),
    "apocalypse": ("The Apothecary's Forgetting", "morgan", "Morgan the apothecary in Wickermoor will take up this thread once the Crooked House is behind us.", "Morgan knows the shape of what we forgot.", "connections_custom"),
    "deliverance": ("A Ticket at the Trading Post", "baltus_tolliver", "Baltus Tolliver at the Trading Post will take up this thread once the Crooked House is behind us.", "Baltus Tolliver had seen a ticket like ours before.", "connections_custom"),
    "duality": ("The Schoolmaster's Mirror", "finneas_trout", "", "Finneas Trout looked at us as if we were two people in one coat.", "connections_custom"),
    "immortality": ("The Smith's Hunger", "jean_myriel", "", "Jean Myriel talked about iron, and about what lasts, and about us.", "connections_custom"),
    "kindred": ("The Mason's Kin", "solomon_roderick", "", "Solomon Roderick found a name on a stone that was ours.", "connections_custom"),
    "malediction": ("The Bookseller's Curse", "eleanor_heyling", "", "Eleanor Heyling recognised the hand of our curse in an old book.", "connections_custom"),
    "rapture": ("The Preacher's Rapture", "weston_murdoch", "", "Weston Murdoch sang a hymn to us that we half remembered.", "connections_custom"),
}
INCITED = ("evolution", "ascendancy", "liberation", "apocalypse", "deliverance")


def main():
    for t, (name, giver, wait, met, f) in THREADS.items():
        stages = []
        if t in INCITED:
            stages.append({"id": "waiting", "journal": f"{name}: something on the train left a thread loose, and it picks up in Wickermoor.",
                           "hint": "Finish the Crooked House, then talk to them in Wickermoor.", "waits": {"until": "flag.vessla_slain", "text": wait}})
        stages.append({"id": "met", "journal": met, "ends": "success"})
        (ROOT / f"data/quests/connection_{t}.json").write_text(json.dumps({
            "id": f"connection_{t}", "name": name, "kind": "side", "region": "companions" if t in ("evolution", "ascendancy", "slaughter", "pilgrimage", "liberation", "rejuvenation") else "wickermoor",
            "giver": giver, "summary": "A thread from a companion's past, picked up by someone in Wickermoor.", "stages": stages}, indent=2, ensure_ascii=False) + "\n")
        # the scene closes the thread
        p = ROOT / f"narrative/wickermoor/{f}.dialogue"
        s = p.read_text()
        line = f"quest connection_{t} met\n"
        if line not in s:
            s = s.replace(f"set connection_{t}\n", f"set connection_{t}\n{line}", 1)
            p.write_text(s)
    # the train starts the waiting stage where it sets the incitement
    p = ROOT / "narrative/ghostlight_express/incitements.dialogue"
    lines = p.read_text().split("\n")
    out = []
    for ln in lines:
        out.append(ln)
        if ln.startswith("set incitement_") and ln.split("_", 1)[1] in INCITED:
            t = ln.split("_", 1)[1]
            out.append(f"quest connection_{t} waiting")
    p.write_text("\n".join(out))


if __name__ == "__main__":
    main()
