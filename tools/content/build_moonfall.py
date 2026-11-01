#!/usr/bin/env python3
"""ONE-SHOT (R26, Moonfall). Writes the eleven Moonfall maps (mf_*), their people, the nine quests and four side quests, flags, items and the eight
heirlooms, fight variants scaled by level, the travel places and roads, the nights clock (schedule), the cutscene lists, the Vagrant's hook in
Wickermoor and the campaign's region names. The conversations are narrative/moonfall/*.dialogue (moonfall_dialogue.py; lines drafted by Gemini).
Other lanes edit these files afterwards: DO NOT re-run it over them.
    python3 tools/content/build_moonfall.py"""
import json, random, re, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import moonfall_maps as MM
from moonfall_common import FEARS, REGION, NS, START_NIGHTS, fq, fl, fear_flag, BY_KEY

ROOT = Path(__file__).resolve().parents[2]
OPEN = ".~_1234"


def write(rel, obj):
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def read(rel):
    return json.loads((ROOT / rel).read_text())


def prop(pid, cell, label=None, kind="examine", model=None, **kw):
    d = {"id": pid, "cell": list(cell), "kind": kind}
    if label:
        d["label"] = label
    if model:
        d["model"] = model
    d.update(kw)
    return d


def npc(nid, cell, dialogue=None, **kw):
    d = {"npc": nid, "cell": list(cell)}
    if dialogue:
        d["dialogue"] = NS + dialogue
    d.update(kw)
    return d


def monster(mid, cell, name=None, **kw):
    d = {"monster": mid, "cell": list(cell)}
    if name:
        d["name"] = name
    d.update(kw)
    return d


def area(aid, name, a, b, **kw):
    d = {"id": aid, "name": name, "cells": [list(a), list(b)]}
    d.update(kw)
    return d


# ---- helpers for placement -------------------------------------------------------------------------------------------------------------
def free_near(rows, cell, taken, rmin=1, rmax=6, rng=None):
    cx, cy = cell
    cands = []
    for y in range(max(1, cy - rmax), min(len(rows) - 1, cy + rmax + 1)):
        for x in range(max(1, cx - rmax), min(len(rows[0]) - 1, cx + rmax + 1)):
            d = max(abs(x - cx), abs(y - cy))
            if rmin <= d <= rmax and rows[y][x] in OPEN and (x, y) not in taken:
                cands.append((d, x, y))
    cands.sort()
    if rng:
        rng.shuffle(cands)
        cands.sort(key=lambda c: c[0] + rng.random() * 1.5)
    return [(x, y) for (_, x, y) in cands]


def pick(rows, cell, n, taken, rmin=2, rmax=7, rng=None, spread=2):
    out = []
    for (x, y) in free_near(rows, cell, taken, rmin, rmax, rng):
        if all(max(abs(x - a), abs(y - b)) >= spread for (a, b) in out):
            out.append((x, y))
            taken.add((x, y))
            if len(out) == n:
                break
    return out


def one(rows, cell, taken, rmin=1, rmax=4):
    c = free_near(rows, cell, taken, rmin, rmax)
    assert c, ("no free cell near", cell)
    taken.add(c[0])
    return c[0]


def scatter_props(rows, rng, taken, models, n, area_rect, prefix, label_for):
    x0, y0, x1, y1 = area_rect
    out = []
    tries = 0
    while len(out) < n and tries < n * 60:
        tries += 1
        x, y = rng.randint(x0, x1), rng.randint(y0, y1)
        if rows[y][x] == "." and (x, y) not in taken:
            m = rng.choice(models)
            taken.add((x, y))
            out.append(prop(f"{prefix}_{len(out)}", (x, y), label_for(m), kind="decor", model=m))
    return out


# ---- per-region props, texts and models ----------------------------------------------------------------------------------------------
PS = {
    "headsman": dict(scatter=["fence", "hay_bale", "scarecrow", "dead_tree_a", "crow", "cart_broken", "rocks", "woodpile"], lair="gate_pillar", lair_label="The covered bridge's dark mouth",
                     hazard="puddle", hazard_label="A field of sinkholes and strangling corn", board="A list of the accused, in several hands, and the sentences beside each.",
                     rect=(3, 3, 22, 26), lair_rect=(31, 5, 43, 23), hook_label="Osric Plow, a Foxwillow farmer", gate="The covered bridge", mood="A bridge of old timber, roofed against the weather and the sky."),
    "worm": dict(scatter=["reeds", "rowboat", "barrel", "rocks", "puddle", "crate_stack", "rope_coils", "dead_tree_b"], lair="glass_ring", lair_label="A tear in the air above the black water",
                 hazard="puddle", hazard_label="The lake's mist and its white worms", board="A wall of names, each crossed out in a different colour of chalk.",
                 rect=(3, 3, 16, 26), lair_rect=(32, 9, 41, 20), gate="The long jetty", mood="A jetty of grey planks over water too still for water."),
    "tall_man": dict(scatter=["pine_a", "pine_b", "pine_c", "dead_tree_a", "woodpile", "stump", "leaves", "vines"], lair="statue_headless", lair_label="The ruined court's throne",
                     hazard="vines", hazard_label="The wood's wandering dread", board="A tally of the lost, nailed to a stump, each name in a different, shaky hand.",
                     rect=(3, 3, 21, 28), lair_rect=(24, 9, 43, 23), gate="The palace gate", mood="A palace gate hung with creepers, its pillars grey as old teeth."),
    "titan": dict(scatter=["boulder", "boulder_a", "boulder_b", "rocks", "cairn", "standing_stones", "dead_tree_b", "stake_bundle"], lair="standing_stones", lair_label="The summit's broken ring of stones",
                  hazard="rocks", hazard_label="The slope of falling rock", board="A board of missing miners and the shafts they went down, chalked and rechalked.",
                  rect=(3, 3, 13, 28), lair_rect=(34, 8, 43, 23), gate="The switchback path", mood="A path of cut stone that climbs and climbs."),
    "barrow": dict(scatter=["gravestone", "grave_mound", "grave_open", "dead_tree_a", "bones", "bone_scatter", "cobwebs", "coffin"], lair="altar", lair_label="A throne of skulls",
                   hazard="grave_open", hazard_label="The open graves and their creeping chill", board="A board of burials, each name struck through and rewritten.",
                   rect=(3, 3, 42, 15), lair_rect=(13, 22, 39, 28), gate="The royal stair", mood="A stair of black stone, worn hollow by an army's tread."),
    "leviathan": dict(scatter=["reeds", "dead_tree_b", "puddle", "rowboat", "barrel", "lantern_post", "rope_coils", "crate"], lair="standing_stones", lair_label="The cursed pool's island of bones",
                      hazard="puddle", hazard_label="The swamplights and the sinking boards", board="A board of wagers and debts, every one marked lost.",
                      rect=(3, 3, 14, 26), lair_rect=(30, 7, 42, 22), gate="The boardwalk", mood="A boardwalk of green planks over black water."),
    "dusk": dict(scatter=["dead_tree_a", "dead_tree_b", "cobwebs", "pine_b", "doll", "rocks", "leaves", "vines"], lair="doll", lair_label="The Mother's loom",
                 hazard="cobwebs", hazard_label="The webs of the Webwoods", board="A line of empty cots drawn in chalk, and a name by each.",
                 rect=(3, 3, 40, 26), lair_rect=(2, 2, 32, 24), gate="The hut's door", mood="A small door in a small hut, ajar."),
    "behemoth": dict(scatter=["rocks", "boulder", "scorch", "ash_heap", "soot_patch", "brazier", "dead_tree_b", "bone_scatter"], lair="altar", lair_label="The crater's lip",
                     hazard="scorch", hazard_label="The falling meteors", board="A board of red cloth, with prayers pinned to it and burnt at the corners.",
                     rect=(3, 3, 28, 28), lair_rect=(30, 8, 43, 23), gate="The ash road", mood="A road of ash that climbs toward a red light."),
}
KEEPSAKE_BY_FEAR = {"headsman": 2, "barrow": 3, "behemoth": 4}   # act number of the keepsake lying in that region (act 1 lies in the Round)

# ---- the people -------------------------------------------------------------------------------------------------------------------------
PEOPLE = [   # id, name, title, summary, attitude, tags
    ("mf_osric_farmer", "Osric Plow", "A Foxwillow farmer", "A weathered farmer whose neighbours have taken to beheading one another over nothing. Wants his fields and his neighbours back. Lies about nothing, but will not say which neighbour he lost.", "friendly", ["voice_hollow"]),
    ("mf_mob_captain", "Captain Harl Reeve", "Leader of the lynch mob", "A sweating, half-ashamed man who leads the mob that beheads the accused. Wants the anger to stop. Secretly he can't put it down at nightfall.", "indifferent", ["voice_hollow"]),
    ("mf_pell_fisher", "Pell Netwright", "A lakeside fisher", "A grey, sleepless fisher whose nets come up full of worms. Wants his village to remember its own names. Does not know the lake can hear him.", "friendly", ["voice_backwoods"]),
    ("mf_lake_cultist", "Brother Silt", "A cultist of the Worm", "A soft, polite lake cultist who loves the Worm and wants to recruit. Wants a bigger choir. Secretly he is afraid of the day the song stops.", "indifferent", ["voice_backwoods"]),
    ("mf_bram_logger", "Bram Fallow", "A logger", "A grim, sleepless logger on the edge of the healed Hartsblight. Wants the wanderers found. Secretly he has stopped sleeping because he hears his own name in the trees.", "friendly", ["voice_backwoods"]),
    ("mf_hesper_crone", "Mother Hesper", "An old crone", "A milky-eyed crone with a clay pipe who tells tales for pennies. Wants someone to listen. Knows more about the Greenwood's court than she lets on.", "friendly", ["voice_backwoods"]),
    ("mf_jory_miner", "Jory Delve", "A Dawn's Gate miner", "A hollowed-out miner whose wife and son went up the pass and did not come down. Wants them back. Will not admit he thinks they are dead.", "friendly", ["voice_backwoods"]),
    ("mf_grizzle_hunter", "Grizzle Hawkes", "A grizzled hunter", "A terse hunter in patched furs who has tracked the Titan for three days. Wants it dead. Does not like company.", "indifferent", ["voice_backwoods"]),
    ("mf_aldous_ghost", "Aldous", "A half-free ghost", "A courtly ghost who served the Barrow King in life. Wants to be allowed to leave. Knows his master's lost name and is ashamed he never said it.", "friendly", ["voice_druskenvald"]),
    ("mf_nadine_bayou", "Nadine Marsh", "A Murkwater Bend resident", "A resigned, unflappable bayou resident in a patched waterproof. Wants a calm morning. Expects the worst and is rarely disappointed.", "friendly", ["voice_backwoods"]),
    ("mf_jack_follower", "Cassius Dunn", "A follower of Snake Eye Jack", "A jovial, slightly drunk follower of Snake Eye Jack with a lucky hat. Wants everyone to enjoy their luck. Secretly his luck ran out years ago.", "friendly", ["voice_backwoods"]),
    ("mf_ysolde_teen", "Ysolde Thrush", "A homestead girl", "A sharp, brave teenage girl whose siblings vanished from their beds. Wants them back. Hides how afraid she is behind a scowl.", "friendly", ["voice_hollow"]),
    ("mf_pennywhistle_nurse", "Granny Pennywhistle", "An old nurse", "An old nurse who raised half the homestead, hands always stitching. Wants the children found. Saved the seamstress's children's toys from the fire.", "friendly", ["voice_hollow"]),
    ("mf_ash_cultist", "Brother Ashfall", "A doomsday cultist", "A red-eyed, joyful doomsday cultist who has waited for the end all his life. Wants a good seat for it. Is secretly a little disappointed it hurts.", "indifferent", ["voice_backwoods"]),
    ("mf_rowan_spirit", "Rowan", "A spirit in an old dress", "The spirit of a proud, bitter girl who called the Behemoth up and wanted the world to burn. Wants her sister. Does not say so.", "hostile", ["voice_druskenvald"]),
    ("mf_kehlenn", "Kehlenn, in the moon", "The Crooked Queen's voice", "The voice from the Crooked Moon: proud, sly, and too proud to beg. Offers to remake Druskenvald in the heroes' image.", "hostile", ["voice_druskenvald"]),
]

ITEMS = [   # id, name, category, summary
    ("mf_headsman_skull", "The first victim's skull", "quest", "A small yellow skull wrapped in rotten sacking. The Galloping Headsman fears whoever holds it."),
    ("mf_star_chart", "A chart of seven stars", "quest", "Seven stars in order on a scrap of oilcloth, the sequence the lake's first people painted. The White Worm chokes on it."),
    ("mf_court_notes", "The steps of a lost court's dance", "quest", "Six turns and a bow, written out in an old woman's fingers' counting. Danced in the Tall Man's sight, the Greenwood hurts him."),
    ("mf_glyph_stone", "A great square stone, carved with a maker's name", "quest", "A flat stone carved with a glyph the size of a door. The Wild Titan sickens when it stands near it."),
    ("mf_inscribed_blade", "A blade with a king's lost name", "quest", "A blade etched with the Barrow King's lost runes. The king fears whoever carries it."),
    ("mf_blessed_idol", "An idol of Snake Eye Jack, blessed", "quest", "A small idol, blessed by a true follower. A curse thrown at its bearer rebounds."),
    ("mf_children_toys", "A bundle of children's toys", "quest", "Small toys saved from a fire, each humming a lullaby. The Dusk Mother cannot bear to see them."),
    ("mf_rowan_locket", "A locket of two sisters' hair", "quest", "A locket with two curls tied together. Rowan will walk into the fire for it."),
    ("mf_keepsake_1", "A punched ticket", "quest", "A ticket for the Ghostlight Express, punched once, which the party lost on the first night. The moon kept it."),
    ("mf_keepsake_2", "A corn-husk doll", "quest", "A small doll of husk and thread from the Fields of the Crow, lost in the corn. The moon kept it."),
    ("mf_keepsake_3", "A cracked lantern glass", "quest", "A cracked lantern glass from the Maidenmist dark, lost among the graves. The moon kept it."),
    ("mf_keepsake_4", "A charred button", "quest", "A scorched button from the moors, lost on the night of the Wicker Man. The moon kept it."),
]

HEIRLOOMS = [   # fear key -> (summary, modifiers, weapon block or None, icon, category)
    ("headsman", "A headsman's axe, +1 (+2 at level 7, +3 at 13): it remembers every neck it took. (Its Flaming Skull and relentless-stroke powers wait on the engine.)",
     [{"stat": "attack", "value": "tier", "when": {"item": "@self"}}, {"stat": "damage", "value": "tier", "when": {"item": "@self"}}],
     {"kind": "martial_melee", "damage": "1d12", "damage_type": "slashing", "properties": ["heavy", "two_handed"], "mastery": "cleave"}, "greataxe", "weapon", "armaments"),
    ("worm", "A cold white eye that sees what the mind forgets: resistance to psychic damage and +2 to Intelligence saves. (Devour Mind waits on the engine.)",
     [{"stat": "resistance", "value": "psychic"}, {"stat": "save", "ability": "int", "value": 2}], None, "orb", "wondrous", "implements"),
    ("tall_man", "A long hook on a longer pole, +1 (+2 at level 7, +3 at 13): it reaches a little further than a hook ought. (Its disguise and teleport powers wait on the engine.)",
     [{"stat": "attack", "value": "tier", "when": {"item": "@self"}}, {"stat": "damage", "value": "tier", "when": {"item": "@self"}}],
     {"kind": "martial_melee", "damage": "1d10", "damage_type": "slashing", "properties": ["heavy", "reach", "two_handed"], "mastery": "graze"}, "glaive", "weapon", "armaments"),
    ("titan", "A rune-carved stone the size of a fist that never warms: +1 Hit Point per level and resistance to cold. (Its stomp and thrown-boulder powers wait on the engine.)",
     [{"stat": "hp_max", "value": "level"}, {"stat": "resistance", "value": "cold"}], None, "gem", "wondrous", "implements"),
    ("barrow", "A crown of bone and black iron: +1 AC and resistance to necrotic damage. (Its Soul Blades and summoned wights wait on the engine.)",
     [{"stat": "ac", "value": 1}, {"stat": "resistance", "value": "necrotic"}], None, "crown", "wondrous", "implements"),
    ("leviathan", "A yellow tooth the length of a forearm, bad luck turned inside out: +1 to all saving throws and +2 to Initiative. (Its swallow and necrotic breath wait on the engine.)",
     [{"stat": "save", "ability": "all", "value": 1}, {"stat": "initiative", "value": 2}], None, "tooth", "wondrous", "implements"),
    ("dusk", "A small silver bell that tolls without being struck: +1 to spell save DCs and Advantage on saves against being frightened. (Its soul dolls and stunning toll wait on the engine.)",
     [{"stat": "spell_dc", "value": 1}, {"stat": "advantage", "on": "save_vs:frightened"}], None, "bell", "wondrous", "implements"),
    ("behemoth", "A hide of red scale that smells of struck matches: +2 AC and resistance to fire. (Its Cataclysm and burning boulders wait on the engine.)",
     [{"stat": "ac", "value": 2}, {"stat": "resistance", "value": "fire"}], None, "armor", "wondrous", "armaments"),
]


def build_people():
    for (nid, name, title, summary, att, tags) in PEOPLE:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": "villager", "region": REGION, "tags": tags})


def build_items():
    for (iid, name, cat, summary) in ITEMS:
        write(f"data/items/{iid}.json", {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": cat, "weight_lb": 1, "cost_gp": 0, "summary": summary})
    for f, (key, summary, mods, weapon, icon, cat, theme) in zip(FEARS, HEIRLOOMS):
        assert f["key"] == key
        d = {"id": f["reward"], "name": f["reward_name"], "source": {"book": "CrookedMoon", "note": f"Fabled Heirloom from Moonfall ({f['name']}); the book's numbers, our words."},
             "category": cat, "weight_lb": 3, "cost_gp": 0, "magic": {"rarity": "legendary", "attunement": True}, "theme": theme, "icon": icon, "modifiers": mods, "summary": summary}
        if weapon:
            d["weapon"] = weapon
        write(f"data/magic_items/{f['reward']}.json", d)


# ---- maps -------------------------------------------------------------------------------------------------------------------------------
def location(lid, name, summary, text, mp, rest="risky", rest_text=None, narration=True):
    d = mp["m"]
    rows = d.rows()
    return {"id": lid, "name": name, "region": REGION, "summary": summary, "text": text,
            "map": {"rows": rows, "theme": mp["theme"], "light": mp["light"], "outdoors": mp["outdoors"]},
            "areas": [area(a, n, c0, c1) for (a, n, c0, c1) in mp["areas"]], "spawns": {k: list(v) for k, v in mp["spawns"].items()},
            "exits": [], "props": [], "npcs": [], "encounters": [], "rest": rest,
            "rest_text": rest_text or "The moon is too large to sleep under. A short breath, then, and on."}


def impact_prop(cell):
    return prop("mf_impact_" + "x".join(str(c) for c in cell), cell, "The moon, filling the sky", kind="decor", call=NS + "moon:impact", approach=12,
                call_when="flag.moonfall_started and flag.moonfall_nights_left <= 0 and not flag.moonfall_fled")


def gate_when(f):
    prev = FEARS[f["n"] - 2] if f["n"] > 1 else None
    return "flag.moonfall_started" + (f" and flag.{fear_flag(prev)}" if prev else "")


def lair_encounters(f, rows, lair_cell, rng):
    k = f["key"]
    taken = {tuple(lair_cell)}
    boss_hp = f["hp"]
    out = []
    for variant, mins, hpf, extra in (("full", f["minions"], 1.0, ""), ("light", f["light_minions"], 0.85, ""), ("weak", f["light_minions"], 0.65, "")):
        t = set(taken)
        ms = [monster(f["monster"], lair_cell, f["name"], boss=True, facing="west", **({"hp": int(boss_hp * hpf)} if hpf != 1.0 else {}))]
        cells = pick(rows, tuple(lair_cell), sum(c for _, c in mins), t, rmin=4, rmax=9, rng=random.Random(f["n"] * 31 + len(variant)), spread=2)
        i = 0
        for (mid, count) in mins:
            for _ in range(count):
                if i < len(cells):
                    ms.append(monster(mid, cells[i], facing="west"))
                    i += 1
        out.append({"id": f"mf_{k}_{variant}", "trigger": "dialogue", "flag": fear_flag(f), "lair": True, "monsters": ms,
                    "text": {"full": f"{f['name']} comes for you with its own court around it.", "light": f"{f['name']} comes for you, thinner of company than it would like.",
                             "weak": f"{f['name']} comes for you, already hurt by what you carry."}[variant]})
    return out


def patrol_encounter(f, rows, area_id, rect, rng):
    t = set()
    x0, y0, x1, y1 = rect
    ms = []
    cells = []
    tries = 0
    while len(cells) < sum(c for _, c in f["patrol"]) and tries < 400:
        tries += 1
        x, y = rng.randint(x0, x1), rng.randint(y0, y1)
        if rows[y][x] in OPEN and (x, y) not in t and all(max(abs(x - a), abs(y - b)) >= 2 for (a, b) in cells):
            cells.append((x, y))
            t.add((x, y))
    i = 0
    for (mid, c) in f["patrol"]:
        for _ in range(c):
            ms.append(monster(mid, cells[i], facing="west"))
            i += 1
    return {"id": f"mf_{f['key']}_patrol", "trigger": f"enter_area:{area_id}", "when": f"not flag.mf_{f['key']}_patrol_done and flag.{fl(f, 'arrived')}",
            "flag": f"mf_{f['key']}_patrol_done", "monsters": ms, "text": f"{f['patrol_name'].capitalize()} come out of the dark.".replace("Come", "come")}


def build_fear_maps():
    for f in FEARS:
        k = f["key"]
        ps = PS[k]
        lair_map = f["map"]
        out_map = "mf_webwoods" if k == "dusk" else lair_map
        outposts = [out_map] if out_map == lair_map else [out_map, lair_map]
        for lid in outposts:
            mp = MM.MAPS[lid]()
            K = mp["K"]
            rows = mp["m"].rows()
            rng = random.Random(f["n"] * 977 + (1 if lid != out_map else 0))
            is_out = lid == out_map
            is_lair = lid == lair_map
            name = {"mf_covered_bridge": "The Covered Bridge", "mf_moonsong_rift": "Moonsong Lake", "mf_tall_man_palace": "The Healed Wood and the Fey Palace",
                    "mf_howlers_peaks": "The Howlers", "mf_barrow_catacombs": "The Opened Barrow", "mf_jinxed_bayou": "The Jinxed Bayou", "mf_webwoods": "The Webwoods",
                    "mf_dusk_mother_hut": "The Dusk Mother's Hut", "mf_rowans_volcano": "Rowan's Rise, Burning"}[lid]
            summary = {"mf_covered_bridge": "Foxwillow's farmland under the falling moon: a farm, a strangling cornfield, and the covered bridge where the Headsman waits.",
                       "mf_moonsong_rift": "A fishing village on the shore of Moonsong Lake, a long jetty, and an air pocket on the lake bed around a tear into another place.",
                       "mf_tall_man_palace": "The healed Hartsblight Forest leaning toward a ruined fey palace, with a logging camp at its edge.",
                       "mf_howlers_peaks": "A mining hamlet, the rune-stone slopes and the summit plateau of the Howlers, where the Wild Titan roars.",
                       "mf_barrow_catacombs": "Maidenmist's opened graves, a stair of black stone, and the royal catacombs below with a throne of skulls.",
                       "mf_jinxed_bayou": "A stilt village at Murkwater Bend, a boardwalk over black water and the cursed pool where the Leviathan sleeps.",
                       "mf_webwoods": "A farm homestead at the edge of the Webwoods, and the spiders' trail to a hut in the clearing.",
                       "mf_dusk_mother_hut": "A seamstress's hut that is far bigger inside than out, hung with dolls, with a stage of them at its centre.",
                       "mf_rowans_volcano": "Rowan's Rise burst open into a volcano over a moor of ash: a doomsday camp, an ash road and the crater's lip."}[lid]
            text = {"mf_covered_bridge": "Foxwillow's fields lie under a moon too large for the sky. A farmstead sits at the edge of the corn, and beyond the corn a roofed bridge crosses a black river, its mouth open like a grin.",
                    "mf_moonsong_rift": "Moonsong Lake lies flat and silvered under the great moon. A fishing village crowds the shore, nets on every post, and a long jetty runs out over water too still to be honest.",
                    "mf_tall_man_palace": "Hartsblight has healed, and its trees lean all one way. A logging camp huddles at the edge, and far in the green a ruined palace of grey pillars waits.",
                    "mf_howlers_peaks": "The Howlers rise white under the moon, and the miners' huts cling to their lowest ridge. Above, a path of cut stone climbs between standing runes.",
                    "mf_barrow_catacombs": "The graves of Maidenmist stand open to the sky, earth heaped beside each. A stair of black stone drops into the hill, worn smooth by an army's tread.",
                    "mf_jinxed_bayou": "Murkwater Bend sinks into the bayou, shacks on stilts, boats half-sunk. A green boardwalk runs out toward a black pool with an island of mud and bones in it.",
                    "mf_webwoods": "A farm homestead at the edge of a spider forest, every shutter hung with white thread. A trail of webs runs off through the trees toward a clearing.",
                    "mf_dusk_mother_hut": "Inside, the hut is a hall, and the hall is hung with dolls, hundreds of them, in rows, looking down. At its centre a loom stands on a stage, and someone weeps.",
                    "mf_rowans_volcano": "Rowan's Rise has burst. Red light pours from a crater over a moor of ash, and burning stones fall like slow rain. A camp of the faithful waits in the lee."}[lid]
            loc = location(lid, name, summary, text, mp, rest="risky" if lid != "mf_dusk_mother_hut" else "no",
                           rest_text="The moon is too large to sleep under. A short breath, then, and on.")
            taken = {tuple(v) for v in K.values()} | {tuple(v) for v in mp["spawns"].values()}
            P, N_, E = loc["props"], loc["npcs"], loc["exits"]
            ex = K["exit"]
            if is_out:
                E.append({"id": "to_road", "cell": list(ex), "to": "travel", "spawn": "default", "label": "Back to the road"})
                if k == "dusk":
                    E.append({"id": "to_hut", "cell": list(K["hut_door"]), "to": "mf_dusk_mother_hut", "spawn": "from_woods", "label": "Into the small door of the hut",
                              "when": f"flag.{fl(f, 'found')}", "locked_text": "You do not know where the Mother is, yet. The webs go everywhere."})
            else:
                E.append({"id": "to_woods", "cell": list(K["exit"]), "to": "mf_webwoods", "spawn": "default", "label": "Out into the Webwoods"})
            # the arrival, the weather and the notice board
            if is_out:
                P.append(prop(f"{k}_arrive", mp["spawns"]["default"], "The land, on arrival", kind="decor", call=f"{NS}{f['file']}:arrive", approach=12, call_when=f"not flag.{fl(f, 'arrived')}"))
                P.append(prop(f"{k}_region", K["affliction"], ps["hazard_label"], kind="examine", model=ps["hazard"], dialogue=f"{NS}{f['file']}:region", when=f"not flag.{fl(f, 'resisted')}"))
                P.append(prop(f"{k}_board", K["board"], "Notice board", kind="examine", model="notice_board", text=ps["board"]))
                gate = gate_when(f)
                hk = K[{"headsman": "farmer", "worm": "fisher", "tall_man": "logger", "titan": "miner", "barrow": "forge", "leviathan": "resident", "dusk": "girl", "behemoth": "cultist"}[k]]
                ck = K[{"headsman": "mob", "worm": "cultist", "tall_man": "crone", "titan": "hunter", "barrow": "ghost_room", "leviathan": "follower", "dusk": "nurse", "behemoth": "rowan"}[k]]
                N_.append(npc(f["hook_npc"], hk, f"{f['file']}:hook", when=f"{gate} and not flag.{fear_flag(f)} and not flag.{fl(f, 'asked')}", approach=8, facing="east"))
                N_.append(npc(f["hook_npc"], hk, f"{f['file']}:hook_again", when=f"{gate} and not flag.{fear_flag(f)} and flag.{fl(f, 'asked')}", facing="east"))
                N_.append(npc(f["clue_npc"], ck, f"{f['file']}:clue", when=f"{gate} and not flag.{fear_flag(f)} and not flag.{fl(f, 'clue_met')}", facing="east"))
                N_.append(npc(f["clue_npc"], ck, f"{f['file']}:clue_again", when=f"{gate} and not flag.{fear_flag(f)} and flag.{fl(f, 'clue_met')}", facing="east"))
                if k == "behemoth":
                    N_.append(npc("marianna_grey", K["descendant"], f"{f['file']}:descendant", when=f"{gate} and not flag.{fear_flag(f)} and flag.{fl(f, 'asked')} and not flag.mf_behemoth_descendant", facing="east"))
                if k in KEEPSAKE_BY_FEAR:
                    P.append(prop(f"mf_keepsake_{KEEPSAKE_BY_FEAR[k]}", K["keepsake"], "Something small, half buried", kind="search", model="satchel", search_dc=12, item=f"mf_keepsake_{KEEPSAKE_BY_FEAR[k]}",
                                  flag=f"mf_keepsake_{KEEPSAKE_BY_FEAR[k]}_found"))
                if k == "barrow":
                    P.append(prop("barrow_grave_a", K["grave_a"], "A freshly opened grave", kind="decor", model="grave_open"))
                    P.append(prop("barrow_grave_b", K["grave_b"], "A second opened grave", kind="decor", model="grave_open"))
                P.append(impact_prop(one(rows, tuple(mp["spawns"]["default"]), taken, 1, 3)))
                P += scatter_props(rows, rng, taken, ps["scatter"], 26, ps["rect"], f"{k}_o", lambda m: m.replace("_", " ").capitalize())
                # a patrol in the middle area
                mid = [a for a in mp["areas"] if a[0] not in ("farm", "shore", "camp", "hamlet", "homestead", "graves", "village", "wood")]
                if k == "barrow":
                    pat_area, rect = "graves", (4, 3, 40, 14)
                elif k == "worm":
                    pat_area, rect = "jetty", (18, 13, 30, 15)
                elif k == "tall_man":
                    pat_area, rect = "wood", (6, 3, 21, 28)
                else:
                    pat_area = mid[0][0]
                    rect = (mid[0][2][0], mid[0][2][1], mid[0][3][0], mid[0][3][1])
                loc["encounters"].append(patrol_encounter(f, rows, pat_area, rect, rng))
            if is_lair:
                lc = K["lair"]
                P.append(prop(f"{k}_lair", lc, ps["lair_label"], model=ps["lair"], dialogue=f"{NS}{f['file']}:lair", when=f"flag.{fl(f, 'found')} and not flag.{fear_flag(f)}"))
                after_cell = one(rows, (lc[0] - 1, lc[1]), taken | {tuple(lc)}, 1, 4)
                P.append(prop(f"{k}_after", after_cell, "Where it fell", kind="decor", call=f"{NS}{f['file']}:aftermath", approach=12,
                              call_when=f"flag.{fear_flag(f)} and not flag.{fl(f, 'aftermath')}"))
                loc["encounters"] += lair_encounters(f, rows, lc, rng)
                if k == "dusk":
                    P.append(prop("dusk_toys", K["toys_nook"], "A nook of small toys", kind="examine", model="toy_chest", text="A nook of tiny chairs, a toy chest and a rocking horse with its paint gone."))
                    P.append(prop("dusk_ledger", K["ledger"], "A ledger of stitches", kind="examine", model="ledger", text="A ledger of stitches, line after line, each a name."))
                    P += scatter_props(rows, rng, taken, ["doll", "dollhouse", "crib", "rocking_horse", "cobwebs", "toy_shelf", "mobile", "candle_cluster"], 40, (2, 2, 31, 22), "dusk_o", lambda m: m.replace("_", " ").capitalize())
                    P.append(prop("mf_keepsake_dusk_note", K["keepsake"], "A cradle", kind="decor", model="crib"))
                    P.append(impact_prop(one(rows, tuple(mp["spawns"]["default"]), taken, 1, 3)))
                if k == "behemoth":
                    P.append(prop("behemoth_edge", K["lava_edge"], "The crater's edge", kind="decor", model="boulder"))
            loc["lights"] = [{"cell": list(K.get("lair", mp["spawns"]["default"])), "kind": "fire" if k == "behemoth" else "lamp", "bright_ft": 20, "dim_ft": 40, "color": "fire" if k == "behemoth" else "candle"}]
            write(f"data/locations/{lid}.json", loc)


def build_hub_and_hill():
    # the Founder's Round under the falling moon
    mp = MM.round_hub()
    K, rows = mp["K"], mp["m"].rows()
    rng = random.Random(2601)
    loc = location("mf_round", "The Founder's Round, Under the Moon", "The village square turned camp: the Ghostlight platform, the Night Ledger, the Vagrant's fire and the villagers who refused to leave.",
                   "The Round has become a camp. Tents crowd the north-west, the Night Ledger leans by the fire, and the Ghostlight Express stands steaming at a platform that was never part of the village. Overhead the moon fills half the sky.",
                   mp, rest="safe", rest_text="The Vagrant's train is warm, and the village keeps watch. A short rest here is safe.")
    taken = {tuple(v) for v in K.values()} | {tuple(v) for v in mp["spawns"].values()}
    P, N_, E = loc["props"], loc["npcs"], loc["exits"]
    E.append({"id": "to_village", "cell": [2, 12], "to": "wickermoor_village", "spawn": "default", "label": "Out into Wickermoor"})
    E.append({"id": "to_road", "cell": list(K["south"]), "to": "travel", "spawn": "default", "label": "To the roads"})
    P += [prop("mf_ledger", K["ledger"], "The Night Ledger", model="notice_board", dialogue=NS + "moon:ledger"),
          prop("mf_map_table", K["map_table"], "A table with the Hollow's map", model="table_round", text="A map of the Hollow, pinned flat with candle stubs. Eight regions are ringed in red, and the nearest ring is already crossed."),
          prop("mf_bonfire", K["bonfire"], "The Round's bonfire", kind="decor", model="brazier"),
          prop("mf_board_goat", K["board"], "The notice board, and the goat that will not leave it", model="notice_board",
               text="The village goat stands on its hind legs against the board and has eaten the notice about evacuation. Nobody has asked it to stop."),
          prop("mf_platform", K["platform"], "The Ghostlight platform", kind="decor", model="bench"),
          prop("mf_keepsake_1", (K["platform"][0] + 1, K["platform"][1] - 1), "A scrap on the platform", kind="search", model="letter", search_dc=10, item="mf_keepsake_1", flag="mf_keepsake_1_found"),
          impact_prop(one(rows, K["west"], taken, 1, 3))]
    P += scatter_props(rows, rng, taken, ["barrel", "crate_stack", "bench", "lantern_post", "cart", "sack_pile", "festival_cloth", "bunting", "bed_small", "candle_cluster"], 36, (3, 3, 32, 22), "mf_round_o", lambda m: m.replace("_", " ").capitalize())
    N_ += [npc("the_vagrant", K["vagrant"], "vagrant:hub_start", when="flag.moonfall_started", facing="east"),
           npc("sgt_gaunt", K["gaunt"], "last_night:gaunt_start", when="flag.moonfall_started and not flag.mf_last_night_asked", approach=6, facing="south"),
           npc("sgt_gaunt", K["gaunt"], "last_night:gaunt_vignette", when="flag.mf_last_night_asked and not flag.mf_gaunt_said", facing="south"),
           npc("sgt_gaunt", K["gaunt"], "last_night:gaunt_after", when="flag.mf_gaunt_said or (flag.moonfall_started and flag.mf_last_night_asked)", facing="south"),
           npc("tamsin_ledger", K["tamsin"], "last_night:tamsin_start", when="flag.moonfall_started and flag.mf_last_night_asked and not flag.mf_tamsin_said", facing="east"),
           npc("tamsin_ledger", K["tamsin"], None, when="not (flag.moonfall_started and flag.mf_last_night_asked and not flag.mf_tamsin_said)", facing="east"),
           npc("marianna_grey", K["marianna"], "last_night:marianna_start", when="flag.moonfall_started and flag.mf_last_night_asked and not flag.mf_marianna_said", facing="west"),
           npc("marianna_grey", K["marianna"], None, when="not (flag.moonfall_started and flag.mf_last_night_asked and not flag.mf_marianna_said)", facing="west"),
           npc("ambrose_quill", K["quill"], "verse:start", when="flag.moonfall_started and not flag.mf_verse_asked", facing="west"),
           npc("ambrose_quill", K["quill"], "verse:progress", when="flag.mf_verse_asked and quest.mf_last_verse == asked", facing="west"),
           npc("ambrose_quill", K["quill"], "verse:after", when="flag.mf_verse_asked and not quest.mf_last_verse == asked", facing="west")]
    loc["lights"] = [{"cell": list(K["bonfire"]), "kind": "fire", "bright_ft": 30, "dim_ft": 60, "color": "fire"}]
    write("data/locations/mf_round.json", loc)
    # the last hill, the moon a few hundred feet up
    mp = MM.last_hill()
    K, rows = mp["K"], mp["m"].rows()
    loc = location("mf_last_hill", "The Hill Under the Moon", "A hilltop with the moon a few hundred feet overhead, roofs and trees tearing loose in the gale, and Kehlenn's face in the crescent.",
                   "The hill is bare, and the moon hangs low over it like a ceiling. Gales pull at your coats, and somewhere below, a roof lets go and goes up toward the face.", mp, rest="no",
                   rest_text="There is no resting here. The wind is pulling the ground up by its roots.")
    taken = {tuple(v) for v in K.values()} | {tuple(v) for v in mp["spawns"].values()}
    loc["exits"] = [{"id": "to_rise", "cell": [3, 17], "to": "mf_rowans_volcano", "spawn": "default", "label": "Down the hill"}]
    loc["props"] = [prop("mf_hill_offer", K["moon_spot"], "The moon, close enough to touch", kind="decor", call=NS + "moon:last_offer", approach=12, call_when="flag.old_fears_slain >= 8 and not flag.moonfall_offer"),
                    prop("mf_hill_menu", K["board"], "The moon's offer", model="altar", dialogue=NS + "moon:last_menu", when="flag.old_fears_slain >= 8 and not flag.moonfall_offer"),
                    impact_prop(one(rows, K["start"], taken, 1, 3))]
    loc["props"] += scatter_props(rows, random.Random(2602), taken, ["rocks", "dead_tree_a", "leaves", "boulder", "rubble"], 14, (3, 3, 26, 18), "mf_hill_o", lambda m: m.replace("_", " ").capitalize())
    loc["npcs"] = [npc("the_vagrant", K["vagrant"], "vagrant:hub_start", when="flag.old_fears_slain >= 8", facing="east")]
    write("data/locations/mf_last_hill.json", loc)


def build_village_hook():
    path = ROOT / "data/locations/wickermoor_village.json"
    town = json.loads(path.read_text())
    town["npcs"] = [n for n in town["npcs"] if not str(n.get("dialogue", "")).startswith(NS)]
    cell = [30, 24]
    taken = {tuple(n["cell"]) for n in town["npcs"]} | {tuple(p["cell"]) for p in town["props"]}
    rows = town["map"]["rows"]
    while tuple(cell) in taken or rows[cell[1]][cell[0]] not in OPEN:
        cell[0] += 1
    town["npcs"].append({"npc": "the_vagrant", "cell": list(cell), "dialogue": NS + "vagrant:offer", "when": "flag.kehlenn_bound and not flag.moonfall_started", "approach": 8, "facing": "west"})
    town["props"] = [p for p in town["props"] if not p["id"].startswith("mf_")]
    c2 = [cell[0] + 1, cell[1] + 1]
    while tuple(c2) in taken or rows[c2[1]][c2[0]] not in OPEN:
        c2[0] += 1
    town["props"].append(impact_prop(tuple(c2)))
    path.write_text(json.dumps(town, indent=2, ensure_ascii=False) + "\n")


# ---- travel -----------------------------------------------------------------------------------------------------------------------------
POS = {"mf_round": (0.5, 0.52), "mf_covered_bridge": (0.84, 0.44), "mf_moonsong_rift": (0.24, 0.26), "mf_tall_man_palace": (0.17, 0.17), "mf_howlers_peaks": (0.08, 0.6),
       "mf_barrow_catacombs": (0.68, 0.72), "mf_jinxed_bayou": (0.58, 0.9), "mf_webwoods": (0.44, 0.74), "mf_rowans_volcano": (0.62, 0.2)}
SPOKE_H = {"mf_covered_bridge": 12, "mf_moonsong_rift": 16, "mf_tall_man_palace": 20, "mf_howlers_peaks": 24, "mf_barrow_catacombs": 8, "mf_jinxed_bayou": 28, "mf_webwoods": 10, "mf_rowans_volcano": 6}
CHAIN_H = [14, 12, 16, 18, 14, 16, 8]


def travel_place_id(f):
    return "mf_webwoods" if f["key"] == "dusk" else f["map"]


def build_travel():
    path = ROOT / "data/travel/wickermoor_hollow.json"
    t = json.loads(path.read_text())
    mine = lambda i: i.startswith("mf_") or i.startswith("wickermoor_to_mf_") or i.startswith("mf_to_")
    t["places"] = [p for p in t["places"] if not mine(p["id"])]
    t["roads"] = [r for r in t["roads"] if not mine(r["id"])]
    names = {"mf_round": "The Founder's Round, under the moon", "mf_covered_bridge": "The Covered Bridge", "mf_moonsong_rift": "Moonsong Lake", "mf_tall_man_palace": "The Healed Wood",
             "mf_howlers_peaks": "The Howlers", "mf_barrow_catacombs": "The Opened Barrow", "mf_jinxed_bayou": "The Jinxed Bayou", "mf_webwoods": "The Webwoods", "mf_rowans_volcano": "Rowan's Rise, burning"}
    t["places"].append({"id": "mf_round", "name": names["mf_round"], "location": "mf_round", "spawn": "from_travel", "pos": list(POS["mf_round"]), "region": REGION,
                        "when": "flag.moonfall_started", "summary": "The village square turned camp, with the Vagrant's train at a platform."})
    for f in FEARS:
        pid = travel_place_id(f)
        t["places"].append({"id": pid, "name": names[pid], "location": pid, "spawn": "from_travel" if pid != "mf_covered_bridge" else "from_travel", "pos": list(POS[pid]), "region": REGION,
                            "when": gate_when(f), "summary": f"{f['region'].capitalize()}, where {f['name']} waits."})
    t["roads"].append({"id": "wickermoor_to_mf_round", "from": "wickermoor_village", "to": "mf_round", "hours": 1, "name": "The village lanes to the Round", "when": "flag.moonfall_started"})
    for f in FEARS:
        pid = travel_place_id(f)
        t["roads"].append({"id": f"wickermoor_to_{pid}", "from": "wickermoor_village", "to": pid, "hours": SPOKE_H[pid], "name": f"The road to {names[pid]}", "when": gate_when(f)})
    for i in range(7):
        a, b = FEARS[i], FEARS[i + 1]
        pa, pb = travel_place_id(a), travel_place_id(b)
        t["roads"].append({"id": f"mf_to_{pa}_{pb}", "from": pa, "to": pb, "hours": CHAIN_H[i], "name": f"From {names[pa]} to {names[pb]}", "when": gate_when(b)})
    path.write_text(json.dumps(t, indent=2, ensure_ascii=False) + "\n")


# ---- quests -----------------------------------------------------------------------------------------------------------------------------
def stage(sid, journal, hint=None, objectives=None, ends=None, then=None):
    d = {"id": sid, "journal": journal}
    if objectives:
        d["objectives"] = objectives
    if hint:
        d["hint"] = hint
    if ends:
        d["ends"] = ends
    if then:
        d["then"] = then
    return d


LOST_WHEN = "flag.moonfall_started and flag.moonfall_nights_left <= 0 and not flag.moonfall_fled"
CLOCK_OBJ = ["Old Fears slain: {flag.old_fears_slain} of 8", "Nights left: {flag.moonfall_nights_left}"]

FEAR_QUEST = {
    "headsman": ("A farmer says neighbours behead neighbours since the moon shrieked, and the field behind his barn swallows people. The trouble comes from the old covered bridge east of Foxwillow.",
                 "Osric Plow's neighbours have taken to beheading each other. The Galloping Headsman, a headless centaur wrongly beheaded by Foxwillow's founders, is the cause."),
    "worm": ("Moonsong Lake takes memories; its fishers are losing their names. Something pulled through from another place sleeps beneath it.", "Pell Netwright's village forgets itself in the lake mist. The White Worm sleeps in a rift on the lake bed."),
    "tall_man": ("Folk are wandering into the healed Hartsblight at night, and the ones found come back screaming. A thing in the old fey palace is calling them.", "Bram Fallow's loggers wander into the trees at night. The Tall Man, a rotted archfey, hunts from his ruined palace."),
    "titan": ("The Howlers roar and throw rocks down on the mining hamlets; no fire burns near the peaks. The mountain itself seems to have woken.", "Jory Delve's family went up the pass and did not come down. The Wild Titan walks the high ridges."),
    "barrow": ("The graves of Maidenmist are opening, and the living weaken by the hour. A nameless king with an army of wights has woken beneath the royal barrow.", "Solomon Roderick says every grave he ever cut a stone for has opened. The Barrow King holds his throne of skulls below."),
    "leviathan": ("Everything goes wrong by a little in Murkwater Bend, and something huge turns in the bayou at night. An alligator hexed into a colossus of bad luck has woken.", "Nadine Marsh's bayou has sunk into bad luck. The Jinxed Leviathan sleeps in the cursed pool."),
    "dusk": ("Children are vanishing from their beds on the homesteads by the Webwoods, and the grown folk walk like sacks. A weeping shade in white takes them.", "Ysolde Thrush's brothers and sisters were taken from their beds. The Dusk Mother weeps in a hut in the clearing."),
    "behemoth": ("Rowan's Rise has burst, and meteors fall every hour. A fiend born of every fear of the end, called up by a spirit, climbs from the crater.", "Brother Ashfall's camp waits on the end. The Brimstone Behemoth rises from Rowan's Rise."),
}


def build_quests():
    sc = "Old Fears slain: {flag.old_fears_slain} of 8"
    write("data/quests/moonfall.json", {
        "id": "moonfall", "name": "Moonfall", "kind": "main", "region": REGION, "giver": "the_vagrant",
        "summary": "The Crooked Moon will fall in thirteen nights. Eight ancient powers pull it down; each kill buys a day. At the end, Kehlenn makes her last offer.",
        "closes": [{"stage": "lost", "when": LOST_WHEN, "from": ["shriek", "hunt", "one_last_choice"], "warn": "The moon is almost on top of us.", "warn_when": "flag.moonfall_nights_left <= 3"}],
        "stages": [
            stage("shriek", "The moon shrieked in Kehlenn's voice: it will fall in thirteen nights. The Vagrant waits at the Round with his train.", "Speak to the Vagrant in Wickermoor.", CLOCK_OBJ),
            stage("hunt", "We took up the hunt. Eight Old Fears pull the moon down, and each one we kill buys a day.", "Find the next Old Fear: the Round's map and the roads show where.", CLOCK_OBJ),
            stage("one_last_choice", "All eight are dead. The moon hangs a few hundred feet over the hill, and Kehlenn has one last offer.", "Climb the hill and answer Kehlenn.", [sc]),
            stage("refused", "We refused Kehlenn's offer. The moon rose back into the sky, and its face faded.", ends="success"),
            stage("accepted", "We accepted Kehlenn's offer. The moon fell on everyone else, and we floated in a green sea to remake the realm.", ends="success"),
            stage("fled", "We took the Vagrant's train out on the last night, and left the Hollow to the moon.", ends="failure"),
            stage("lost", "The nights ran out. The moon fell on the Hollow, and there was no one left to see it.", ends="failure"),
        ]})
    for f in FEARS:
        a, b = FEAR_QUEST[f["key"]]
        write(f"data/quests/{fq(f)}.json", {
            "id": fq(f), "name": f"The {f['short']}", "kind": "main", "region": REGION, "giver": f["hook_npc"],
            "summary": b, "closes": [{"stage": "lost", "when": LOST_WHEN, "from": ["asked", "trail", "ready"]}],
            "stages": [
                stage("asked", a, "Ask around the region for how to find it: its hook-giver, and the one who knows its secret.", ["Find where it lairs"]),
                stage("trail", f"We found where {f['name']} lairs. There may be a way to hurt it more than the usual.", "Learn its weakness from the one who knows it, or go straight to its lair.", [f"Face {f['name']}", "Optional: learn its weakness"]),
                stage("ready", f"We carry what hurts {f['name']}. Time to go to its lair.", "Go to its lair.", [f"Face {f['name']}"]),
                stage("slain", f"{f['name']} is dead. The moon's gaze moves to {f['next_region']}.", ends="success"),
                stage("lost", "The nights ran out before it fell.", ends="failure"),
            ]})
    write("data/quests/mf_last_night.json", {
        "id": "mf_last_night", "name": "Last Night in Wickermoor", "kind": "side", "region": REGION, "giver": "sgt_gaunt",
        "summary": "Sergeant Gaunt would like the village to have one last evening together, with three goodbyes he can name.",
        "stages": [
            stage("asked", "Sergeant Gaunt asked us to sit with the village a while on its last night: three goodbyes at the Round.", "Say goodbye to Gaunt, Tamsin Ledger and Marianna Grey at the Round.", ["Goodbyes said ({flag.mf_goodbyes} of 3)"]),
            stage("done", "We sat with the three of them, and it was the best hour of the whole sorry business.", ends="success"),
            stage("skipped", "We told Sergeant Gaunt there was no time. He saluted stiffly, and the village watched us go.", ends="failure"),
        ]})
    write("data/quests/mf_ride_out.json", {
        "id": "mf_ride_out", "name": "The Vagrant's Ride Out", "kind": "side", "region": REGION, "giver": "the_vagrant",
        "summary": "The Vagrant has one ride out on the final night, for those who would rather not be there when the moon lands.",
        "stages": [
            stage("offered", "The Vagrant offered one train out of the Hollow on the final night, and said he would not think the less of us.", "Ask the Vagrant about the train out when you are ready."),
            stage("taken", "We took the train. The Hollow stayed behind, and the moon fell behind us.", ends="success"),
            stage("declined", "We told the Vagrant we stay and fight. He grinned, and said the seat is ours if we change our minds.", ends="failure", then=["offered", "taken"]),
        ]})
    write("data/quests/mf_what_moon_keeps.json", {
        "id": "mf_what_moon_keeps", "name": "What the Moon Keeps", "kind": "side", "region": REGION, "giver": "the_vagrant",
        "summary": "The moon keeps what the dead lose. Four small things of ours lie in its pockets, one from each part of our journey.",
        "stages": [
            stage("asked", "The Vagrant says the moon keeps four small things of ours, one from each part of the journey: his platform, the farmland, Maidenmist, and the burning hill.", "Search the Round's platform, the farmland, the Maidenmist barrow and Rowan's Rise.", ["Keepsakes returned ({flag.mf_keepsakes} of 4)"]),
            stage("returned", "We gave the four keepsakes to the Vagrant to carry. He will keep them safe in the baggage car.", ends="success"),
            stage("kept", "We kept the four keepsakes close. Things want to be near their people.", ends="success"),
            stage("left", "We left the keepsakes to the moon. It will probably look after them better than most.", ends="failure"),
        ]})
    write("data/quests/mf_last_verse.json", {
        "id": "mf_last_verse", "name": "The Last Verse", "kind": "side", "region": REGION, "giver": "ambrose_quill",
        "summary": "Ambrose Quill is composing the finest verse of his career and cannot find its last line.",
        "stages": [
            stage("asked", "Ambrose Quill cannot find the last line of his finest verse.", "Offer Quill a line at the Round: stirring, wry or honest, or play him a chord if you carry Jericho's banjo."),
            stage("delivered", "Quill climbed the dais and recited his verse to the village, and the last line was ours.", ends="success"),
            stage("silenced", "We told Quill to stop. He folded the page away, and the village heard no verse that night.", ends="failure"),
        ]})


# ---- flags ------------------------------------------------------------------------------------------------------------------------------
INTS = {"moonfall_clock", "moonfall_credit", "moonfall_nights_left", "old_fears_slain", "mf_goodbyes", "mf_keepsakes"}
STRS = {"moonfall_offer", "mf_verse_style"}
PENDING = {"kehlenn_bound": ("bool", "Read from the Crooked Tree (R24): the ritual bound Kehlenn in the moon."), "vigil_deaths": ("int", "Read from Wicker's Vigil (R23): innocents lost on the moors and at the stones (0 to 21).")}


def build_flags():
    flag_re = re.compile(r"\bflag\.([a-z][a-z0-9_]*)")
    set_re = re.compile(r"^set ([a-z][a-z0-9_]*)", re.M)
    read, setf = set(), set()
    texts = []
    for p in (ROOT / "narrative/moonfall").glob("*.dialogue"):
        t = p.read_text()
        texts.append(t)
        setf |= set(set_re.findall(t))
    for p in list((ROOT / "data/locations").glob("mf_*.json")) + [ROOT / "data/locations/wickermoor_village.json"]:
        t = p.read_text()
        texts.append(t)
    for p in (ROOT / "data/quests").glob("mf_*.json"):
        texts.append(p.read_text())
    texts.append((ROOT / "data/quests/moonfall.json").read_text())
    for t in texts:
        read |= set(flag_re.findall(t))
    # flags the encounters set
    for p in (ROOT / "data/locations").glob("mf_*.json"):
        d = json.loads(p.read_text())
        for e in d.get("encounters", []):
            if "flag" in e:
                setf.add(e["flag"])
        for pr in d.get("props", []):
            if "flag" in pr:
                setf.add(pr["flag"])
    sched = json.loads((ROOT / "data/schedule/moonfall.json").read_text())
    for e in sched["events"]:
        setf |= set(e.get("set", {}))
        read |= set(flag_re.findall(e.get("when", "")))
        read |= {"moonfall_clock"}
    # flags other lanes register: skip them
    other = set()
    for p in (ROOT / "data/flags").glob("*.json"):
        if p.name in ("moonfall.json", "moonfall_pending.json"):
            continue
        for x in json.loads(p.read_text()).get("flags", []):
            other.add(x["id"])
    mine = sorted((setf | read) - other - set(PENDING))
    out = []
    for fid in mine:
        typ = "int" if fid in INTS else ("string" if fid in STRS else "bool")
        d = {"id": fid, "type": typ, "summary": f"Moonfall (R26): {fid.replace('_', ' ')}"}
        if fid in setf and fid not in read:
            d["read_later"] = True
        out.append(d)
    write("data/flags/moonfall.json", {"flags": out})
    write("data/flags/moonfall_pending.json", {"flags": [{"id": k, "type": t, "summary": s + " Placeholder: delete this file when R23/R24 register and set it.", "set_by": "engine"} for k, (t, s) in PENDING.items()]})


# ---- the nights clock (schedule) ------------------------------------------------------------------------------------------------------
def build_schedule():
    events = []
    for c in range(0, 12):                    # credit: 8 kills + the rewind's 3
        total = START_NIGHTS + c
        for d in range(1, total + 1):
            cond = f"flag.moonfall_started and not flag.moonfall_fled and flag.moonfall_credit == {c} and days_since.moonfall_clock " + (">= " if d == total else "== ") + str(d)
            events.append({"id": f"mf_tick_c{c}_d{d}", "summary": f"Night {d} with {c} nights won back: {max(0, total - d)} left.", "hour": 3, "when": cond, "set": {"moonfall_nights_left": max(0, total - d)}})
    events.append({"id": "mf_impact", "summary": "The moon hits.", "hour": 4, "once": True, "when": LOST_WHEN, "dialogue": NS + "moon:impact"})
    write("data/schedule/moonfall.json", {"id": "moonfall", "region": REGION, "summary": "The falling moon's nights clock: moonfall_nights_left = 13 + nights won back - nights since the hunt began, set at the Witching Hour; the moon hits at zero.", "events": events})


# ---- cutscenes --------------------------------------------------------------------------------------------------------------------------
PICS = {
    "mf_moon_shrieks": ["Night over Wickermoor's clocktower, the huge crooked moon with its mouth torn open wide", "Townsfolk in the street looking up at the moon, some kneeling, lanterns forgotten in their hands"],
    "mf_headsman_reveals": ["A headless centaur executioner bursting out of a covered bridge's dark mouth, a burning axe raised", "A flaming skull flying ahead of the rider down a moonlit road of corn"],
    "mf_headsman_falls": ["A fallen rider's flame guttering out on an old bridge, the corn behind it letting go of the ground", "The huge moon turning its gaze slowly west over a black lake"],
    "mf_worm_reveals": ["A vast pale worm rising from a tear in the air over black lake water, its mouth a ring of soft teeth", "A choir of white worms in the water, all turning toward a jetty"],
    "mf_worm_falls": ["A great pale worm falling back through a closing rift in the air, the lake still as glass", "The moon turning its gaze north over a dark forest"],
    "mf_tall_man_reveals": ["An impossibly tall thin figure unfolding between the pillars of a ruined palace, head bowed beneath the roof", "A long hand reaching, and the shadows of a dark wood standing up to follow it"],
    "mf_tall_man_falls": ["A tall thin figure collapsing like a dropped puppet in a ruined hall, its shadows lying down", "The moon turning its gaze slowly north toward snowy mountains"],
    "mf_titan_reveals": ["A giant of rock, root and ice rising over a mountain summit, its fists the size of cottages", "A roar rolling down a snow slope and a rockfall following it"],
    "mf_titan_falls": ["A giant of stone sitting down slowly on a summit like a mountain settling, its arms hanging", "The moon turning its gaze south and east over a cemetery's open graves"],
    "mf_barrow_reveals": ["A king in black armour with a crown of bone rising from a throne of skulls, sword drawn, ranks of the dead behind him", "A hall of standing wights turning as one toward the door"],
    "mf_barrow_falls": ["A bone crown rolling ringing across a stone floor as armour falls to dust", "The moon turning its gaze south toward swamplights in a marsh"],
    "mf_leviathan_reveals": ["A colossal alligator breaking the surface of a black pool, wearing a crown of old hexes, grinning", "Swamplights winking out and on across a bayou as its jaws open"],
    "mf_leviathan_falls": ["A colossal alligator sinking into a black pool, the swamplights going out one by one", "The moon turning its gaze south and west toward a forest of spiders"],
    "mf_dusk_reveals": ["A weeping shade in white at a great loom, huge shears in her hands and a doll hanging from each finger", "Hundreds of dolls on shelves in a hall, all turning their painted faces"],
    "mf_dusk_falls": ["A pair of huge shears falling and a white shape dissolving into thread and dust", "A hut's window with a small candle lit in it, and children's laughter somehow visible as warm light"],
    "mf_rowans_erupts": ["A hill bursting open into a volcano over a moor, red light pouring out", "Winged fiends rising from rivers of lava over the dark moors"],
    "mf_behemoth_reveals": ["A mountainous fiend of horn and flame climbing out of a volcano's crater, wings of smoke across the sky", "The moor lit red by its breath, a line of tiny cultists kneeling"],
    "mf_behemoth_falls": ["A mountainous fiend sinking into lava as the sky above the crater begins to clear", "The huge moon hanging low over a hill, looking down, smiling"],
    "mf_one_last_choice": ["The giant moon a few hundred feet above a hill, roofs and trees tearing loose into the gale toward it", "The crone's face in the crescent speaking, her lips shaping words"],
    "mf_offer_refused": ["The huge moon lifting away from the Hollow like a lid, its face softening and fading", "The stars coming back one by one over a calm village, the crescent hanging without a face"],
    "mf_offer_accepted": ["The moon coming down on a land like a hand closing, everything going white", "Four small figures floating alone in a sea of green light"],
    "mf_moon_impact": ["The huge moon filling the whole sky, the night gone white from edge to edge", "A silent empty crater where a village had been, and a sneering moon gone"],
    "mf_train_out": ["A lit train pulling out of the fog and a frogman in a wide hat taking it off to a village", "The huge moon sagging lower over rooftops, the last lamp in a square going out"],
}


def build_cutscenes():
    pics = {}
    for first, prompts in PICS.items():
        for n, desc in enumerate(prompts, 1):
            pics[first if n == 1 else f"{first}_{n}"] = desc
    write("tools/content/moonfall_cutscenes.json", {"style": read("tools/content/ghostlight_cutscenes.json")["style"], "pictures": pics})
    for cid, desc in pics.items():
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": cid.replace("mf_", "").replace("_", " ").capitalize(), "summary": desc, "images": [{"image": cid, "when": ""}]})


# ---- campaign ---------------------------------------------------------------------------------------------------------------------------
def build_campaign():
    path = ROOT / "data/campaign.json"
    c = json.loads(path.read_text())
    qr = c["quest_regions"]
    if "moonfall" not in qr["order"]:
        i = qr["order"].index("companions") if "companions" in qr["order"] else len(qr["order"])
        qr["order"].insert(i, "moonfall")
    qr["names"]["moonfall"] = "Moonfall"
    path.write_text(json.dumps(c, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    build_people()
    build_items()
    build_fear_maps()
    build_hub_and_hill()
    build_village_hook()
    build_travel()
    build_quests()
    build_schedule()
    build_cutscenes()
    build_flags()
    build_campaign()
    print("ok")
