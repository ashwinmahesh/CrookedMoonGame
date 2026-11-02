#!/usr/bin/env python3
"""ONE-SHOT: the data files this wrote have since been edited by hand and by other lanes (set pieces, cans, recounts); running it again would overwrite those edits.
Writes the Ghostlight Express (R10) data files: ten locations, the quests, items and people.
The maps and prop lists come from the package design doc (the vault's Packages/R10); run from the repo root:
    python3 tools/content/build_ghostlight.py
The output is plain JSON under data/ and is what the game reads; edit either this script or the JSON, but not both."""
import json, os, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
DOC = Path.home() / "Documents/Obsidian Vault/Crooked Moon/Packages/R10 - The Ghostlight Express.md"
REGION = "ghostlight_express"


def write(rel, obj):
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


# ---- maps, read from the design doc's code blocks ----------------------------------------------------------------
def doc_blocks():
    """{location id: {"rows": [...], "elevation": [...]}} from the design doc."""
    lines = DOC.read_text().split("\n")
    out, loc, kind, i = {}, None, None, 0
    while i < len(lines):
        ln = lines[i]
        if ln.startswith("### "):
            import re
            m = re.search(r"\(`(ghostlight_[a-z0-9_]+)`\)", ln)
            loc = m.group(1) if m else None
        if loc and ln.startswith("`map.rows`"):
            kind = "rows"
        elif loc and ln.startswith("`map.elevation`"):
            kind = "elevation"
        if kind and ln.startswith("```") and not ln.strip() == "```":
            pass
        if kind and ln.strip() == "```":
            j = i + 1
            block = []
            while lines[j].strip() != "```":
                block.append(lines[j]); j += 1
            if kind == "rows" or kind == "elevation":
                import re
                rows = []
                for b in block:
                    m = re.match(r"^\s*(\d+) (.*)$", b)
                    if m:
                        rows.append(m.group(2))
                    elif re.match(r"^[#.=~_0-9a-z ]+$", b) and b.strip() and not re.match(r"^\s*[0-9]+\s*$", b.strip()) and ("#" in b or kind == "elevation"):
                        rows.append(b)
                if rows:
                    out.setdefault(loc, {})[kind] = rows
                kind = None
            i = j
        i += 1
    return out


BLOCKS = doc_blocks()


def prop(pid, cell, label=None, kind="examine", model=None, **kw):
    d = {"id": pid, "cell": list(cell), "kind": kind}
    if label:
        d["label"] = label
    if model:
        d["model"] = model
    d.update(kw)
    return d


def area(aid, name, a, b, **kw):
    d = {"id": aid, "name": name, "cells": [list(a), list(b)]}
    d.update(kw)
    return d


def npc(npc_id, cell, dialogue=None, **kw):
    d = {"npc": npc_id, "cell": list(cell)}
    if dialogue:
        d["dialogue"] = dialogue
    d.update(kw)
    return d


GL = "ghostlight_express/"


def grille(n, cell=(10, 3)):
    """The Vagrant's grille: examine it to call him; the first time the party comes near after the fight he speaks by himself (phantom_after)."""
    return prop(f"grille_g{n}", cell, "A brass grille in the ceiling", model="window", dialogue=GL + "vagrant_intercom:grille",
                when="not flag.gl_crashed", call=GL + "vagrant_intercom:phantom_after", approach=12,
                call_when="flag.gl_phantom_done and not flag.gl_vagrant_briefed")


def router_lamp(n, cell=(10, 2)):
    """A brass lamp that carries the Vagrant's check-ins: he speaks as the party comes into a car once the briefing has played."""
    return prop(f"g{n}_lamps", cell, "The brass lamps", model="lamp", call=GL + "vagrant_intercom:router", approach=12,
                call_when="flag.gl_vagrant_briefed and not flag.gl_crashed")


CARS = ["ghostlight_g1_passenger", "ghostlight_g2_sleeper", "ghostlight_g3_lounge", "ghostlight_g4_dining",
        "ghostlight_g5_mail", "ghostlight_g6_baggage", "ghostlight_g7_circus", "ghostlight_g8_tender"]
# The Switcheroo (E23) is not built yet: the cars are chained in the book's order until it is, and the exits are plain doors.
SIX_DONE = " and ".join(f"(flag.haint_{h}_done or flag.haint_{h}_destroyed)" for h in
                         ["sweetheart", "songstress", "daydreamer", "mariner", "jailbird", "harlequin"])


def car(lid, n, name, summary, text, areas, props, npcs, encounters=None, containers=None, lights=None, extra=None, door_row=3, tender=False, carve=()):
    rows = [list(r) for r in BLOCKS[lid]["rows"]]
    for (cx, cy) in carve:      # a stack of luggage left a pocket the party can't leave: open one square, as the story walk found
        rows[cy][cx] = "."
    rows = ["".join(r) for r in rows]
    idx = CARS.index(lid)
    exits = []
    if idx > 0:
        exits.append({"id": "rear_door", "cell": [0, 4 if tender else door_row], "to": "module_switcheroo_previous", "spawn": "from_front",
                      "label": "Back to the " + ("last car" if idx > 1 else "Passenger Car")})
    if idx < 7:
        ex = {"id": "front_door", "cell": [19, door_row], "to": "module_switcheroo_next", "spawn": "from_rear", "label": "On to the next car"}
        if idx == 6:
            ex["label"] = "The Tender's door"
            ex["when"] = SIX_DONE
            ex["locked_text"] = "It won't budge while a haint rides the train."
        exits.append(ex)
    spawns = {"default": [1 if idx == 5 else 2, door_row] if not tender else [1, 4], "from_rear": [1, door_row] if not tender else [1, 4]}
    if idx > 0 and not tender:
        spawns["from_front"] = [18, door_row]
    if idx == 0:
        spawns = {"default": [2, 3], "from_boarding": [2, 3], "from_front": [17, 3], "phantom_fight": [12, 3]}
    loc = {
        "id": lid, "name": name, "region": REGION, "summary": summary, "text": text,
        "map": {"rows": rows, "theme": "manor", "light": "bright", "outdoors": False},
        "areas": areas, "spawns": spawns, "exits": exits, "props": props, "npcs": npcs,
        "rest": "no", "rest_text": "The rocking of the train will not let anyone sleep. A short breath, then.",
    }
    if encounters:
        loc["encounters"] = encounters
    if containers:
        loc["containers"] = containers
    if lights:
        loc["lights"] = lights
    if extra:
        loc.update(extra)
    write(f"data/locations/{lid}.json", loc)


def lamps(cells):
    return [{"cell": list(c), "kind": "lamp", "bright_ft": 20, "dim_ft": 40, "color": "candle"} for c in cells]


def build_locations():
    # ----- boarding -------------------------------------------------------------------------------------------------
    b = BLOCKS["ghostlight_boarding"]
    boarding = {
        "id": "ghostlight_boarding", "name": "Barrow Hill", "region": REGION,
        "summary": "A burying hill at the end of a lane, a ring of standing stones on its crown, and a shelf on its east side where a black train waits on rails of mist.",
        "text": "A low hill wears a ring of standing stones, and its west slope is all leaning headstones under an old yew hung with paper lanterns. Past the stones the ground levels into a shelf where a black engine sits on rails made of mist, its one lamp blue-white in the fog.",
        "map": {"rows": b["rows"], "elevation": b["elevation"], "theme": "forest", "light": "dim", "outdoors": True},
        "areas": [
            area("bd_lychgate", "The lychgate", (9, 15), (18, 19)),
            area("bd_burying_ground", "The burying ground", (3, 7), (9, 16)),
            area("bd_stones", "The standing stones", (9, 5), (17, 12)),
            area("bd_shelf", "The shelf", (17, 4), (24, 12)),
            area("bd_hollow", "The hollow", (23, 9), (27, 16)),
        ],
        "spawns": {"default": [13, 16]},
        "exits": [{"id": "board_train", "cell": [21, 10], "to": "ghostlight_g1_passenger", "spawn": "from_boarding", "label": "Board the train",
                   "when": "flag.gl_boarded", "locked_text": "The Vagrant has not shown you aboard yet."}],
        "props": [
            prop("bd_lychgate", (13, 18), "The lychgate", model="gate"),
            prop("bd_gate_turnips", (12, 19), "Carved turnip lanterns", kind="decor"),
            prop("bd_yew_lanterns", (4, 8), "An old yew hung with paper lanterns"),
            prop("bd_headstones", (5, 9), "Leaning headstones", model="grave"),
            prop("bd_iron_markers", (3, 13), "Iron grave-markers", model="grave"),
            prop("bd_stone_ring", (13, 9), "The ring of standing stones", model="rocks"),
            prop("bd_fallen_stone", (10, 6), "The fallen stone", model="rocks"),
            prop("bd_tumbled_wall", (9, 3), "A tumbled drystone wall", model="rocks"),
            prop("bd_scarecrow", (4, 12), "A scarecrow among the graves", model="scarecrow"),
            prop("bd_mist_rails", (23, 12), "The rails of mist", kind="decor"),
            prop("bd_engine", (20, 4), "The black engine", span=[2, 2]),
            prop("bd_passenger_car", (19, 9), "The passenger car", span=[2, 2]),
        ],
        "npcs": [npc("the_vagrant", (22, 11), GL + "vagrant_boarding:boarding", when="not flag.gl_boarded", facing="west", approach=10)],
        "rest": "no", "rest_text": "The fiddle is already tuning. This is no place to lie down.",
    }
    write("data/locations/ghostlight_boarding.json", boarding)

    # ----- G1 --------------------------------------------------------------------------------------------------------
    car("ghostlight_g1_passenger", 1, "The Passenger Car", "The rear car of the Ghostlight Express: red leather seats, brass lamps, pale passengers who never answer.",
        "Two rows of paired red leather seats run the length of the car with a wide lit aisle between them. Pale passengers flicker in and out of the seats, and green smoke streams past every window.",
        [area("g1_rear", "The rear end", (1, 1), (5, 5)), area("g1_aisle", "The aisle", (6, 1), (13, 5)), area("g1_front", "The front end", (14, 1), (18, 5))],
        [prop("g1_seats", (6, 1), "Paired seats", model="chairs"), prop("g1_booths", (1, 1), "The end booths", model="chairs"),
         prop("g1_windows", (8, 1), "The windows", model="window", call=GL + "car_banter:start", approach=3,
              call_when="flag.gl_aboard_welcomed and not flag.gl_phantom_done"), router_lamp(1),
         prop("g1_boarding_door", (0, 2), "The boarding door", model="door"), prop("g1_rear_door", (0, 4), "The rear door", model="door"),
         grille(1),
         prop("g1_passengers", (7, 3), "The pale passengers", kind="search", search_dc=15, skill="perception", model="chairs"),
         prop("g1_marble_jar", (12, 5), "A jar of glass marbles", kind="search", search_dc=13, item="marble_jar"),
         prop("g1_curse_mist", (17, 3), "Black-veined mist", when="flag.gl_phantom_done", call=GL + "incitements:deliverance_enter", approach=12,
              call_when="flag.gl_phantom_done and not flag.incitement_deliverance", checks=[
             {"id": "g1_curse_mist", "skill": "perception", "dc": 13, "label": "Study the mist",
              "success": {"text": "Black veins thread through the mist at the front door, and the mist is cold."}, "failure": {}}]),
         ],
        [npc("the_vagrant", (2, 3), GL + "vagrant_boarding:aboard", when="flag.gl_boarded and not flag.gl_aboard_welcomed", approach=6, facing="east"),
         npc("phantom_trainhopper", (16, 3), GL + "vagrant_intercom:phantom_strikes", when="not flag.gl_phantom_done and flag.gl_aboard_welcomed", approach=3, facing="west")],
        encounters=[
            {"id": "gl_phantom_strikes", "trigger": "dialogue", "flag": "gl_phantom_done", "quest": {"id": "ghostlight_express", "stage": "phantom_struck"},
             "when": "level >= 3", "monsters": [
                 {"monster": "shadow", "cell": [16, 3], "name": "The Phantom Trainhopper", "facing": "west", "steps_down": {"npc": "phantom_trainhopper"}},
                 {"monster": "corrupted_passenger", "cell": [17, 2], "name": "Corrupted Passenger", "facing": "west"},
                 {"monster": "corrupted_passenger", "cell": [17, 4], "name": "Corrupted Passenger", "facing": "west"},
                 {"monster": "corrupted_passenger", "cell": [18, 3], "name": "Corrupted Passenger", "facing": "west"}]},
            {"id": "gl_phantom_strikes", "trigger": "dialogue", "flag": "gl_phantom_done", "quest": {"id": "ghostlight_express", "stage": "phantom_struck"},
             "when": "level == 2", "monsters": [
                 {"monster": "shadow", "cell": [16, 3], "name": "The Phantom Trainhopper", "facing": "west", "steps_down": {"npc": "phantom_trainhopper"}},
                 {"monster": "corrupted_passenger", "cell": [17, 2], "name": "Corrupted Passenger", "facing": "west"},
                 {"monster": "corrupted_passenger", "cell": [17, 4], "name": "Corrupted Passenger", "facing": "west"}]},
            {"id": "gl_phantom_strikes", "trigger": "dialogue", "flag": "gl_phantom_done", "quest": {"id": "ghostlight_express", "stage": "phantom_struck"},
             "monsters": [
                 {"monster": "shadow", "cell": [16, 3], "name": "The Phantom Trainhopper", "facing": "west", "steps_down": {"npc": "phantom_trainhopper"}},
                 {"monster": "corrupted_passenger", "cell": [17, 4], "name": "Corrupted Passenger", "facing": "west"}]}],
        lights=lamps([(4, 3), (10, 3), (16, 3)]))

    # ----- G2 --------------------------------------------------------------------------------------------------------
    car("ghostlight_g2_sleeper", 2, "The Sleeper Car", "A corridor and three first-class cabins behind sliding doors, velvet curtains drawn over the windows.",
        "A narrow corridor runs along the south side with three sliding cabin doors on the other. Mahogany, velvet and brass, and every curtain drawn against the Shroud.",
        [area("g2_corridor", "The corridor", (1, 4), (18, 5)), area("g2_cabin_1", "Cabin one", (1, 1), (6, 2)),
         area("g2_cabin_2", "Cabin two", (8, 1), (12, 2)), area("g2_cabin_3", "Cabin three", (14, 1), (18, 2))],
        [prop("g2_beds", (2, 1), "The made beds", model="case"), prop("g2_curtains", (4, 1), "Velvet window curtains", model="window"),
         prop("g2_phonograph", (12, 2), "The brass phonograph", model="case", dialogue=GL + "incitements:phonograph"),
         prop("g2_weeping_door", (16, 3), "The weeping cabin door", model="door"),
         grille(2), router_lamp(2)],
        [npc("haint_sweetheart", (17, 2), GL + "haint_sweetheart:start", approach=4, facing="south", when="not flag.haint_sweetheart_done and not flag.haint_sweetheart_destroyed")],
        containers=[{"id": "g2_clothes_chest", "cell": [6, 2], "label": "A clothes chest", "items": [{"id": "fine_clothes", "qty": 6}], "model": "case"}],
        encounters=[haint_fight("sweetheart", (17, 2), "The Sweetheart")], lights=lamps([(5, 4), (15, 4)]), door_row=4)

    # ----- G3 --------------------------------------------------------------------------------------------------------
    car("ghostlight_g3_lounge", 3, "The Lounge Car", "Ebony and gold, burgundy velvet, a long black bar, and a smoking singer at the window.",
        "Understated luxury: ebony walls inlaid with gold lines, burgundy velvet chairs in quiet corners, frosted sconces and a long black bar with a mirrored back.",
        [area("g3_bar", "The bar", (5, 1), (14, 2)), area("g3_seating", "The seating", (1, 1), (18, 5)), area("g3_window_seat", "The window seat", (11, 4), (13, 5))],
        [prop("g3_bar_counter", (9, 2), "The bar", model="bar"),
         prop("g3_seascape", (4, 1), "The landscape paintings", kind="search", search_dc=13, item="seascape_painting", model="case"),
         prop("g3_paintings", (15, 1), "Landscape paintings", model="case"),
         prop("g3_chairs", (17, 1), "Burgundy velvet chairs", model="chairs"), prop("g3_sconces", (10, 3), "Frosted sconces", model="lamp", call=GL + "vagrant_intercom:router", approach=12, call_when="flag.gl_vagrant_briefed and not flag.gl_crashed"),
         prop("g3_whiskey_bottle", (7, 1), "An empty whiskey bottle", kind="search", search_dc=13, item="empty_whiskey_bottle"),
         prop("g3_haint_hooch", (12, 1), "A jug marked XxX", kind="search", search_dc=18, item="haint_hooch"),
         grille(3)],
        [npc("phillip_druskenvald", (10, 3), GL + "druskenvalds_lounge:meet", when="not flag.gl_crashed", facing="east", approach=3),
         npc("adela_druskenvald", (11, 3), GL + "druskenvalds_lounge:meet", when="not flag.gl_crashed", facing="east"),
         npc("haint_songstress", (12, 5), GL + "haint_songstress:start", facing="south", when="not flag.haint_songstress_done and not flag.haint_songstress_destroyed")],
        encounters=[haint_fight("songstress", (12, 5), "The Songstress")], lights=lamps([(4, 3), (10, 3), (16, 3)]))

    # ----- G4 --------------------------------------------------------------------------------------------------------
    booths = [prop(f"g4_booth_{s}{i}", c, "A booth", model="table_round", dialogue=GL + "dining_car:sit", say="examine:g4_booth")
              for (s, i, c) in [("n", 1, (3, 2)), ("n", 2, (6, 2)), ("n", 3, (12, 2)), ("s", 1, (3, 4)), ("s", 2, (6, 4)), ("s", 3, (12, 4))]]
    car("ghostlight_g4_dining", 4, "The Dining Car", "Six four-seat booths down each side, white cloths, brass-rimmed menus, and a big empty half-booth at the front.",
        "Booths under white cloths line both walls beneath orange paper bunting. At the front end an eight-seat half-booth is laid with a spotless cloth and nobody has ever sat at it.",
        [area("g4_booths", "The booths", (1, 1), (15, 5)), area("g4_big_booth", "The big booth", (16, 1), (18, 5))],
        booths + [prop("g4_menu_cards", (2, 2), "Brass-rimmed menu cards", model="papers"), prop("g4_big_booth", (17, 3), "The empty half-booth", model="table_round", dialogue=GL + "dining_car:big_booth"),
                  prop("g4_silverware", (8, 2), "Polished silverware", model="lamp", call=GL + "vagrant_intercom:router", approach=12, call_when="flag.gl_vagrant_briefed and not flag.gl_crashed"), grille(4)],
        [npc("haint_daydreamer", (9, 2), GL + "haint_daydreamer:start", approach=3, when="not flag.haint_daydreamer_done and not flag.haint_daydreamer_destroyed")],
        encounters=[haint_fight("daydreamer", (9, 2), "The Daydreamer")], lights=lamps([(4, 3), (10, 3), (16, 3)]))

    # ----- G5 --------------------------------------------------------------------------------------------------------
    car("ghostlight_g5_mail", 5, "The Mail Car", "Pigeonholes of letters from the dead to the living and back, a sorting bench, canvas mailbags, and an old sailor hauling them about.",
        "Two long walls of pigeonholes: letters from the dead on the north wall, letters from the living on the south. An old sailor hauls canvas mailbags from one pile to another.",
        [area("g5_living_shelf", "The living-to-dead shelves", (2, 5), (17, 5)), area("g5_dead_shelf", "The dead-to-living shelves", (2, 1), (17, 1)), area("g5_bench", "The sorting bench", (7, 2), (12, 4))],
        [prop("g5_letters_living", (6, 5), "Letters from the living to the dead", kind="book", model="letters", codex="g5_living_1"),
         prop("g5_letters_dead", (6, 1), "Letters from the dead to the living", kind="book", model="letters", codex="g5_dead_1"),
         prop("g5_pink_envelope", (14, 1), "A bright pink envelope", kind="search", search_dc=13, skill="investigation", item="jakob_braun_letter", codex="g5_jakob_letter"),
         prop("g5_mailbags", (4, 2), "Canvas mailbags", model="rags"), prop("g5_sorting_bench", (9, 3), "The sorting bench", model="table_round"),
         prop("g5_gambler_letter", (16, 4), "A letter on the bench", model="letter", call=GL + "incitements:liberation_enter", approach=12,
              call_when="not flag.incitement_liberation and not flag.pending_liberation_incitement"),
         grille(5), router_lamp(5)],
        [npc("haint_mariner", (11, 4), GL + "haint_mariner:start", path=[[6, 2], [14, 4]], pause=3, when="not flag.haint_mariner_done and not flag.haint_mariner_destroyed")],
        encounters=[haint_fight("mariner", (11, 4), "The Mariner")], lights=lamps([(4, 3), (10, 3), (16, 3)]))

    # ----- G6 --------------------------------------------------------------------------------------------------------
    car("ghostlight_g6_baggage", 6, "The Baggage Car", "Heaps of dusty luggage, the Druskenvalds' new trunks, and a snoring tiger of green flame behind a stack at the front.",
        "Luggage is piled to the ceiling in rough stacks with narrow ways between them. Near the rear door the Druskenvalds' new leather trunks glimmer; somewhere at the front something large is snoring.",
        [area("g6_front_stack", "The front stacks", (9, 1), (12, 5)), area("g6_rear_stack", "The rear stacks", (1, 1), (8, 5)), area("g6_den", "The tiger's den", (13, 2), (18, 5))],
        [prop("g6_druskenvald_trunks", (2, 3), "The Druskenvalds' trunks", model="case", dialogue=GL + "phillip_luggage:trunks"),
         prop("g6_steamer_trunk", (3, 4), "A steamer trunk", model="case", dialogue=GL + "phillip_luggage:adela_trunk"),
         prop("g6_abandoned_luggage", (4, 2), "Abandoned luggage", kind="search", search_dc=15, item="goggles_of_night", model="case"),
         prop("g6_medical_bag", (7, 3), "A discarded medical bag", model="case", call=GL + "incitements:evolution_enter", approach=12,
              call_when="not flag.incitement_evolution and not flag.pending_evolution_incitement"),
         prop("g6_tiger", (16, 3), "The sleeping tiger", kind="decor"),
         prop("g6_iron_ring", (17, 3), "The iron ring on its tail", checks=[
             {"id": "g6_iron_ring", "skill": "sleight_of_hand", "dc": 15, "label": "Slip the ring off its tail", "once": True,
              "success": {"items": [{"id": "wildpyre_iron_ring"}]}, "failure": {"damage": "2d6", "damage_type": "fire", "flag": "wildpyre_woken"}}]),
         grille(6), router_lamp(6)],
        [npc("haint_jailbird", (6, 3), GL + "haint_jailbird:start", facing="west", when="not flag.haint_jailbird_done and not flag.haint_jailbird_destroyed"),
         npc("wildpyre", (16, 3), asleep=True, facing="west", when="not flag.wildpyre_destroyed")],
        encounters=[haint_fight("jailbird", (6, 3), "The Jailbird"),
                    {"id": "gl_wildpyre", "trigger": "flag:wildpyre_woken", "flag": "wildpyre_destroyed", "monsters": [
                        {"monster": "wildpyre", "cell": [16, 3], "name": "The wildpyre", "facing": "west"}]}],
        lights=lamps([(4, 3), (10, 3), (16, 3)]), carve=[(2, 3)])

    # ----- G7 --------------------------------------------------------------------------------------------------------
    car("ghostlight_g7_circus", 7, "The Circus Car", "A travelling show's car: rusted cages, striped crates, banners of clowns, and a jester hanging from a trapeze.",
        "Rusted animal cages line the north wall, one with its door bent open and its straw scorched. Red-and-white crates, banners of laughing clowns and, overhead, a trapeze swinging with a jester hanging from it by her knees.",
        [area("g7_cages", "The cages", (1, 1), (9, 2)), area("g7_stage", "The stage end", (10, 1), (18, 5))],
        [prop("g7_cages", (4, 1), "The rusted cages", model="cage"), prop("g7_open_cage", (9, 1), "An open cage", model="cage"),
         prop("g7_key_ring", (1, 2), "A ring of keys on a hook", kind="decor", item="ghostlight_key_ring"),
         prop("g7_crates", (5, 3), "Red-and-white crates", model="case"), prop("g7_banners", (12, 1), "Carnival banners", model="papers"),
         prop("g7_poster", (13, 1), "A poster for the Festival of Fools", model="notice_board", call=GL + "incitements:ascendancy_enter", approach=12,
              call_when="not flag.incitement_ascendancy and not flag.pending_ascendancy_incitement"),
         prop("g7_marionette_chest", (14, 5), "A marionette chest", kind="search", search_dc=13, skill="investigation", item="toad_faced_stone", model="case"),
         prop("g7_trapeze", (11, 3), "The trapeze", model="rope"),
         grille(7), router_lamp(7)],
        [npc("haint_harlequin", (11, 3), GL + "haint_harlequin:start", approach=5, when="not flag.haint_harlequin_done and not flag.haint_harlequin_destroyed")],
        encounters=[haint_fight("harlequin", (11, 3), "The Harlequin")], lights=lamps([(4, 3), (10, 3), (16, 3)]))

    # ----- G8 --------------------------------------------------------------------------------------------------------
    car("ghostlight_g8_tender", 8, "The Tender", "An ironclad fuel car: a black tank full of drifting soul coal, pipes along the walls, and a furnace in the front wall.",
        "A cast-iron tank with a round glass porthole fills the middle of the car, full of soul coal drifting like banked embers. Pipes run over the walls to a furnace in the front wall. There is no way forward.",
        [area("g8_vestibule", "The vestibule", (1, 1), (2, 5)), area("g8_tender", "The tender", (3, 1), (10, 5))],
        [prop("g8_tank", (5, 4), "The fuel tank", model="case", call=GL + "tender:crash", approach=12, call_when="flag.gl_stoker_done and not flag.gl_crashed"), prop("g8_porthole", (7, 4), "The porthole", kind="decor"),
         prop("g8_pipes", (2, 2), "Pipes over the walls and ceiling", kind="decor"), prop("g8_firebox", (10, 3), "The firebox", model="hearth", call=GL + "tender:opened", approach=12, call_when="flag.haints_all_gone and not flag.gl_tender_opened"),
         prop("tender_door", (1, 4), "The Tender's door", kind="decor"),
         ],
        [],
        encounters=[
            {"id": "gl_stoker", "trigger": "dialogue", "flag": "gl_stoker_done", "quest": {"id": "ghostlight_express", "stage": "crashed"},
             "when": "level >= 3", "monsters": [{"monster": "soulfire_stoker", "cell": [9, 3], "name": "The Soulfire Stoker", "hp": 30, "facing": "west"},
                                                 {"monster": "shadow", "cell": [8, 5], "name": "The Phantom, re-formed", "facing": "west"}],
             "round_events": [stoker_fuel_event()]},
            {"id": "gl_stoker", "trigger": "dialogue", "flag": "gl_stoker_done", "quest": {"id": "ghostlight_express", "stage": "crashed"},
             "monsters": [{"monster": "soulfire_stoker", "cell": [9, 3], "name": "The Soulfire Stoker", "hp": 30, "facing": "west"}],
             "round_events": [stoker_fuel_event()]}],
        lights=[{"cell": [10, 3], "kind": "fire", "bright_ft": 20, "dim_ft": 40, "color": "bile"}], tender=True)

    # ----- the wreck -------------------------------------------------------------------------------------------------
    w = BLOCKS["ghostlight_wreckage"]
    rows = [list(r) for r in w["rows"]]
    for y in range(9, 13):          # the engine's bank: open roots under the locomotive, the block it makes is the figure itself
        for x in range(36, 40):
            rows[y][x] = "."
    w["rows"] = ["".join(r) for r in rows]
    wreck = {
        "id": "ghostlight_wreckage", "name": "The Ghostlight Wreckage", "region": REGION,
        "summary": "An ancient oak wood in a bowl of land, a crash groove gouged through it, and a locomotive pinned on its side by black roots under a crescent moon with a crone's face.",
        "text": "A groove forty yards across has been ploughed through the oaks, and the carriages lie scattered like dropped cards. On a rise in the east the engine lies on its side, black roots holding it, and above the broken canopy hangs a moon with a face.",
        "map": {"rows": w["rows"], "elevation": w["elevation"], "theme": "forest", "light": "dim", "outdoors": True},
        "areas": [area("wr_clearing", "The clearing", (5, 4), (34, 24)), area("wr_engine_bank", "The engine's bank", (33, 6), (42, 16)),
                  area("wr_oaks", "The oaks", (4, 3), (40, 25)), area("wr_tree_line", "The tree line", (3, 12), (5, 15))],
        "spawns": {"default": [6, 22], "from_crash": [6, 22]},
        "exits": [{"id": "to_wickermoor", "cell": [22, 27], "to": "travel", "label": "Walk to Wickermoor Village", "when": "flag.gl_last_stop",
                   "locked_text": "Not yet. The engine is still pinned in the roots."}],
        "props": [
            prop("wr_roots", (35, 9), "The roots", kind="decor"), prop("wr_grooves", (22, 13), "The crash grooves", kind="decor"),
            prop("wr_wrecked_cars", (11, 5), "The scattered cars", model="cart"), prop("wr_oak_car", (19, 8), "A car in the oak", model="cart", span=[4, 2], stand_ft=10),
            prop("wr_boulders", (13, 13), "Mossy boulders", model="rocks"), prop("wr_moon", (22, 15), "The Crooked Moon", kind="decor", model="rocks", call=GL + "vagrant_farewell:emerge", approach=12, call_when="flag.gl_locomotive_done and not flag.gl_last_stop"),
            prop("wr_soul_can_1", (7, 7), "A glint in the roots", kind="search", search_dc=10, item="soul_can", when="not flag.gl_cans_by_druskenvalds"),
            prop("wr_soul_can_2", (26, 7), "A glint by the groove", kind="search", search_dc=10, item="soul_can", when="not flag.gl_cans_by_druskenvalds"),
            prop("wr_soul_can_3", (23, 19), "A glint under a boulder", kind="search", search_dc=10, item="soul_can", when="not flag.gl_cans_by_druskenvalds"),
            prop("wr_whistle", (14, 18), "Something small in the mud", kind="search", search_dc=10, item="whistle_of_the_vagrant", when="flag.tarot_hero_1 == the_fool or flag.tarot_hero_2 == the_fool or flag.tarot_hero_3 == the_fool or flag.tarot_hero_4 == the_fool"),
            prop("wr_pool", (15, 17), "A pool of soul-mist", kind="decor"),
            prop("wr_rim_w", (6, 14), "Dark trees at the rim", model="rocks", call=GL + "vagrant_wreck:walk_away", approach=2, call_when="flag.gl_wreck_met and not flag.gl_locomotive_done"),
            prop("wr_rim_n", (24, 4), "Dark trees at the rim", model="rocks", call=GL + "vagrant_wreck:walk_away", approach=2, call_when="flag.gl_wreck_met and not flag.gl_locomotive_done"),
            prop("wr_rim_s", (22, 25), "Dark trees at the rim", model="rocks", call=GL + "vagrant_wreck:walk_away", approach=2, call_when="flag.gl_wreck_met and not flag.gl_locomotive_done"),
        ],
        "containers": [{"id": "wr_trunks", "cell": [5, 21], "label": "The Druskenvalds' surviving trunks", "items": [], "model": "case"}],
        "npcs": [npc("the_vagrant", (34, 12), GL + "vagrant_wreck:arrival", approach=8, steps_aside=True, when="not flag.gl_locomotive_done"),
                 npc("phillip_druskenvald", (7, 21), GL + "druskenvalds_wreck:crash_check", approach=6, steps_aside=True, when="not flag.gl_locomotive_done"),
                 npc("adela_druskenvald", (8, 21), GL + "druskenvalds_wreck:crash_check", steps_aside=True, when="not flag.gl_locomotive_done"),
                 npc("ghostlight_locomotive", (36, 9), lying=True, facing="west", when="not flag.gl_locomotive_done")],
        "traps": [{"id": "wr_crash_landing", "cells": [[6, 22]], "detect_dc": 0, "disarm_dc": 0, "save": {"ability": "dex", "dc": 13},
                   "damage": "1d6", "damage_type": "bludgeoning", "label": "The crash's landing", "text": "The ground comes up hard."}],
        "encounters": [locomotive_fight("gl_locomotive", "dialogue"), locomotive_fight("gl_locomotive_edge", "dialogue", edge=True)],
        "rest": "no", "rest_text": "The Vagrant wants the cans before anyone sleeps. A short breath, then.",
    }
    write("data/locations/ghostlight_wreckage.json", wreck)


def haint_fight(h, cell, name):
    return {"id": f"gl_haint_{h}", "trigger": "dialogue", "flag": f"haint_{h}_destroyed", "quest": {"id": f"haint_{h}", "stage": "destroyed"},
            "monsters": [{"monster": "wayward_haint", "cell": list(cell), "name": name, "facing": "south"}]}


def stoker_fuel_event():
    return {"id": "corrupted_fuel", "name": "Corrupted Fuel", "summary": "Black soul coal breathes out a poisonous heat over the tender's floor.",
            "kind": "save", "affects": "party", "save": {"ability": "con", "dc": 5}, "dc_from": {"flag": "haints_destroyed", "base": 5, "step": 2},
            "exhaustion": 1, "at": 20, "every": 1, "area": {"cells": [[3, 1], [10, 5]]}}


def locomotive_fight(eid, trigger, edge=False):
    start = [[32, 12], [32, 13], [33, 11], [33, 14]] if not edge else [[7, 14], [7, 15], [6, 13], [6, 16]]
    return {"id": eid, "trigger": trigger, "flag": "gl_locomotive_done", "quest": {"id": "ghostlight_express", "stage": "last_stop"},
            "lair": True,
            "monsters": [{"monster": "ghostlight_locomotive", "cell": [36, 9] if not edge else [10, 14], "name": "The Ghostlight Locomotive", "boss": True,
                          **({"steps_down": {"npc": "ghostlight_locomotive"}} if not edge else {})}]}


# ---- people, quests, items ---------------------------------------------------------------------------------------
PEOPLE = [
    ("the_vagrant", "The Vagrant", "Conductor of the Ghostlight Express", "An amiable mottled-green frogman in ragged vagabond clothes and a wide hat set with three railroad spikes, who carries a fiddle and ferries the dead.", "friendly", "villager"),
    ("phillip_druskenvald", "Phillip Druskenvald", "Lord of Druskenvald", "A tall, thin lord with slicked black hair, a pencil moustache and a striped suit, who carries a black cane with a silver goat-skull head.", "friendly", "villager"),
    ("adela_druskenvald", "Adela Druskenvald", "Lady of Druskenvald", "A short, curly-haired lady in a sparkling flapper dress with a planchette necklace, a clairvoyant who reads the Fated Tarot.", "friendly", "villager"),
    ("phantom_trainhopper", "The Phantom Trainhopper", "A stowaway shade", "A shade with a wrongly tilted head and branch-like tendrils, sitting among the pale passengers as if it were one more.", "hostile", "villager"),
    ("haint_sweetheart", "The Sweetheart", "A Wayward Haint", "A young woman in a bonnet and ribbons, holding a locket with a mustached man's portrait and the initials J.B.", "indifferent", "villager"),
    ("haint_songstress", "The Songstress", "A Wayward Haint", "A hollow, smoking singer at the window of the Lounge Car, humming the same eight bars.", "indifferent", "villager"),
    ("haint_daydreamer", "The Daydreamer", "A Wayward Haint", "A boy in overalls who eats without stopping, as if to bury something.", "indifferent", "villager"),
    ("haint_mariner", "The Mariner", "A Wayward Haint", "An old sailor with a clay pipe and a seagull ghost on his cap, hauling mailbags as if loading cargo.", "indifferent", "villager"),
    ("haint_jailbird", "The Jailbird", "A Wayward Haint", "A starving man in striped prison clothes with a ball and chain, who lists foods in a dream.", "indifferent", "villager"),
    ("haint_harlequin", "The Harlequin", "A Wayward Haint", "A jester in a belled cap who hangs from a trapeze by her knees, performing painful pratfalls.", "indifferent", "villager"),
    ("ghostlight_locomotive", "The Ghostlight Locomotive", "A pinned engine", "A black locomotive on its side in the roots, a lamp like an eye, smoke full of faces.", "hostile", "villager"),
    ("wildpyre", "The wildpyre", "A tiger of ghostly flame", "A tiger of ghostly green flame asleep behind the luggage, a hot iron ring on its tail.", "hostile", "villager"),
]


def build_people():
    for pid, name, title, summary, att, sprite in PEOPLE:
        d = {"id": pid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": sprite, "region": REGION}
        if pid in ("phillip_druskenvald", "adela_druskenvald"):
            d["guest"] = True
            d["guest_fights"] = False
        if pid == "phantom_trainhopper":
            d["monster"] = "shadow"
        if pid == "ghostlight_locomotive":
            d["monster"] = "ghostlight_locomotive"
        if pid == "wildpyre":
            d["monster"] = "wildpyre"
        write(f"data/npcs/{pid}.json", d)


def stage(sid, journal, hint=None, objectives=None, ends=None):
    d = {"id": sid, "journal": journal}
    if objectives:
        d["objectives"] = objectives
    if hint:
        d["hint"] = hint
    if ends:
        d["ends"] = ends
    return d


def build_quests():
    main = {"id": "ghostlight_express", "name": "The Ghostlight Express", "kind": "main", "region": REGION, "giver": "the_vagrant",
            "summary": "A black train on rails of mist, six haints, and a crash under a moon with a face.",
            "stages": [
                stage("boarding", "A fiddle in the fog led us to a burying hill, a black train on rails of mist, and a frogman in a ragged hat who says we have tickets. It seems we do.",
                      "Talk to the Vagrant beside the train; find the tickets in your pockets, or let him point them out.", ["Get on the train"]),
                stage("aboard", "We are aboard the Ghostlight Express, in the rear car. The Vagrant talks to us through a brass grille in the ceiling: keep the doors shut, be polite to the pale passengers, and keep the Lord and Lady company.",
                      "Walk down the aisle to the front of the car.", ["Explore the Passenger Car"]),
                stage("phantom_struck", "A shade let the Shroud in, and one of the pale passengers went wrong with it. We drove them off. The Vagrant says six haints aboard are the easiest for the Shroud to sour, and that we should free them or put them down; then we are to look in the Tender, which unseals when they are gone.",
                      "Walk the train. Each haint stays in its own car. Any grille in the ceiling will bring the Vagrant, with hints.", ["Free or put down the six Wayward Haints"]),
                stage("haints", "Six haints ride this train, each stuck on something unfinished. We can finish it for them, talk them round, bottle them or put them down.",
                      "Ask the Vagrant through a grille about any haint you have met.", ["Resolve the six haints"]),
                stage("tender_open", "The last haint is gone and the Tender's door has opened. The Vagrant asks us to look inside, and to be careful.",
                      "The Tender is the last car of the train; its door is on the far end of the last car.", ["Look inside the Tender"]),
                stage("crashed", "The curse had reached the fuel. We killed what burst out of the firebox, and the train tore out of the Shroud and crashed in a dark wood, under a moon with a face. The Vagrant, the Lord and the Lady are alive.",
                      "The Vagrant is by the wrecked engine, east of where you landed.", ["Find the Vagrant"]),
                stage("soul_cans", "The engine is pinned by black roots and has no fuel. The Vagrant has three of its six Soul Cans; three were thrown into the woods in the crash. They glow, so they cannot stay lost. A haint we bottled counts for one.",
                      "Look low, among roots, in the grooves' mist and under boulders. The Vagrant's fiddle will make them glow.", ["Find the Soul Cans"]),
                stage("locomotive", "The Vagrant fed the cans to the firebox. The engine broke its roots and grew a face. It is hunting us, and eating the cans we scattered.",
                      "Smash the Soul Cans before the engine eats them; the clearing has cover and high ground.", ["Defeat the Ghostlight Locomotive"]),
                stage("last_stop", "The locomotive fell, and the train mended itself and left without us, the frogman waving his hat. The Lord and Lady, grateful, ask us to walk them to Wickermoor Village.", ends="success"),
            ]}
    write("data/quests/ghostlight_express.json", main)
    H = {
        "sweetheart": ("The Sweetheart", "A weeping woman in the Sleeper Car, afraid to cross over without her beloved. She holds a locket with a mustached man and the initials J.B.",
                       "We gave her Jakob Braun's letter: he has been waiting on the far side. She went to him.", "We stayed with her until she was not afraid. She went on, alone and unafraid.",
                       "We corked her in a jar. She is quiet, and she is still ours to answer for.", "She turned on us in the cabin; the cold took the room.", "We put her down. The cabin keeps the silence.",
                       "The Sleeper Car's third cabin."),
        "songstress": ("The Songstress", "A smoking singer at the window of the Lounge Car, humming the same eight bars. She wants one last song for someone who truly listens.",
                       "We carried her the phonograph from the Sleeper Car. She sang her last verse, and the Lord and Lady danced.", "We listened until she sang it.", "We corked her in a jar, mid-hum.",
                       "She stopped humming and turned.", "We put her down. The window is only a window now.", "The window seat of the Lounge Car."),
        "daydreamer": ("The Daydreamer", "A boy in overalls in the Dining Car, eating to bury something. He stole a painted toad-stone and lost it somewhere on the train.",
                       "We brought him the toad-faced stone from the marionette chest. He went to tell the truth.", "We talked him round. He went to tell the truth.", "We corked him in a jar; the plates are empty.",
                       "He stopped eating, and turned.", "We put him down, gently as we could. The car is quiet.", "A booth in the Dining Car."),
        "mariner": ("The Mariner", "An old sailor in the Mail Car, hauling mailbags, who died far from the sea and wants one last look.",
                    "We brought him the seascape painting from the Lounge Car. He looked a long time, and sighed, and was gone.", "We talked him down from the last mailbag. He sighed and was gone.",
                    "We corked him in a jar, pipe and all.", "He dropped the bag and turned.", "We put him down. The bags lie still.", "Between the mailbag stacks in the Mail Car."),
        "jailbird": ("The Jailbird", "A starving man in striped clothes in the Baggage Car, who wants the steak and eggs he was denied before his execution.",
                     "We carried him a plate of steak and eggs from the Dining Car. He ate it like a man at peace.", "We believed him until he let go.", "We corked him in a jar, still hungry.",
                     "He rose, chain and all.", "We put him down. The chain lies slack.", "On a trunk in the Baggage Car."),
        "harlequin": ("The Harlequin", "A jester on a trapeze in the Circus Car, who wants to be certain that the tiger she let out of its cage cannot hurt anyone again. The tiger is asleep in the Baggage Car.",
                      "We brought her the iron ring off the tiger's tail. She took a real bow.", "We told her enough of the truth that she let it go.", "We corked her in a jar, bells and all.",
                      "She stopped tumbling and turned.", "We put her down. The trapeze keeps swinging.", "The trapeze in the Circus Car."),
    }
    for hid, (nm, met, token, helped, bottled, hostile, destroyed, where) in H.items():
        q = {"id": f"haint_{hid}", "name": nm, "kind": "side", "region": REGION, "giver": f"haint_{hid}", "summary": f"One of the six Wayward Haints of the Ghostlight Express.",
             "stages": [stage("met", met, f"{where} Talk to them, or ask the Vagrant through a grille.", [f"Finish {nm}'s unfinished business"]),
                        stage("token", token, ends="success"), stage("helped", helped, ends="success"), stage("bottled", bottled, ends="success"),
                        stage("hostile", hostile, "Fight it, or leave the car; it will not follow."), stage("destroyed", destroyed, ends="success")]}
        write(f"data/quests/haint_{hid}.json", q)


def item(iid, name, category, text, weight=0, cost=0, extra=None):
    d = {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": category, "weight_lb": weight, "cost_gp": cost, "summary": text}
    if extra:
        d.update(extra)
    return d


def build_items():
    items = [
        item("marble_jar", "A jar of 12 marbles", "gear", "An upright empty jar once the marbles are poured out: a trap for a haint.", 1, 0),
        item("empty_whiskey_bottle", "An empty whiskey bottle", "gear", "Stood upright in a haint's way, it can cork the haint.", 1, 0),
        item("steak_and_eggs", "Steak and eggs", "quest", "A plate still hissing, the yolks trembling. It stays hot.", 1, 0),
        item("jug_of_water", "A jug of water", "consumable", "Plain water. To the wildpyre it burns like holy water.", 4, 0),
        item("ghost_phonograph", "The phonograph", "quest", "A brass-and-wood phonograph with a horn like a flower.", 20, 0),
        item("seascape_painting", "The seascape", "quest", "A rocky coast at sunset; the waves move when you are not looking straight at it.", 5, 0),
        item("toad_faced_stone", "The toad-faced stone", "quest", "A painted stone toad's face, a marionette's head.", 1, 0),
        item("wildpyre_iron_ring", "The iron ring", "quest", "Uncomfortably hot, with the tiger's embers sealed inside.", 1, 0),
        item("jakob_braun_letter", "Jakob Braun's letter", "quest", "A pink envelope with J.B. on its flap.", 0, 0),
        item("ghostlight_key_ring", "A ring of cage keys", "gear", "It opens the cages, which are all empty.", 1, 0),
        item("soul_can", "Soul Can", "quest", "A small brass canister of captured soul-light that glows teal. It is fuel.", 1, 0),
        item("haint_hooch", "Haint Hooch", "potion", "A foul blue-green jug marked XxX: drink it to become insubstantial for a minute.", 1, 0,
             {"magic": {"rarity": "rare", "attunement": False}}),
        item("adelas_jewellery", "A piece of Adela's jewellery", "treasure", "A bright trinket worth 25 gold.", 0, 25),
        item("whistle_of_the_vagrant", "Whistle of the Vagrant", "wondrous", "A small fabled whistle the Vagrant left in the mud.", 0, 0,
             {"magic": {"rarity": "rare", "attunement": True}}),
    ]
    for h, nm in [("sweetheart", "the Sweetheart"), ("songstress", "the Songstress"), ("daydreamer", "the Daydreamer"), ("mariner", "the Mariner"),
                  ("jailbird", "the Jailbird"), ("harlequin", "the Harlequin")]:
        items.append(item(f"bottled_haint_{h}", f"A jar holding {nm}", "quest", f"A corked jar with {nm} inside, quiet. It counts for one Soul Can.", 1, 0))
    for it in items:
        write(f"data/items/{it['id']}.json", it)


def build_cutscenes():
    """One cutscene per picture (docs/ui/cutscenes.md): the picture is art/cutscenes/<id>.jpg, made from the prompt in
    tools/content/ghostlight_cutscenes.json by the image service."""
    pics = json.loads((ROOT / "tools/content/ghostlight_cutscenes.json").read_text())["pictures"]
    for cid, desc in pics.items():
        title = cid.replace("gl_", "").replace("_", " ").capitalize()
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": title, "summary": desc[0].upper() + desc[1:] + ".", "images": [{"image": cid, "when": ""}]})


if __name__ == "__main__":
    build_cutscenes()
    build_locations()
    build_people()
    build_quests()
    build_items()
    print("ok")
