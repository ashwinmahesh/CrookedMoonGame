"""The plan for the companions' region banter (narrative/banter/<region>.dialogue; Banter.next plays a file only where its name starts with the place's
region id, data/locations/*.json `region`). Each region has six to eight slots: one exchange between two or three companions about what is in front of them in
one place, gated on the place (`at:<location id>`) and on the story's state so a remark never runs ahead of the chapter.

    at     the location id(s) where the exchange can play (a list: any of them)
    gate   the story state it needs (a condition; "" for none), written with flags that exist in data/flags
    state  the same state in plain words, for the brief
    with   companions the slot prefers (the place suits them)

`assign()` fixes who speaks in each slot, once, from this plan alone: every companion speaks in every region, the fifteen pairs are spread as evenly as
the places allow, and about one slot in four is a trio. The briefs and the converter both read it.
Used by tools/content/companion_talks.py (the converter) and the brief builder in docs/plans/gemini_companions/.
"""
from __future__ import annotations

from itertools import combinations

IDS = ["rook_coldwake", "tobin_hayward", "silas_vane", "delphine_ravelle", "lucan_houndstooth", "cordelia_skein"]

## What a region's exchanges must not stage or mention, because a companion's own scene or a chapter's set piece owns it.
REGIONS: dict[str, dict] = {
    "ghostlight_express": {
        "title": "The Ghostlight Express",
        "avoid": "The letter in the mailbags (Silas), the doctor's medical bag (Cordelia) and the handbill in the circus car (Delphine) are those companions' own scenes: "
                 "do not mention them. Do not name the creatures in the cars or say what is wrong with the train. Nobody knows the train will crash.",
        "slots": [
            {"at": "ghostlight_boarding", "gate": "not flag.gl_crashed", "state": "The party is on Barrow Hill about to board the Ghostlight Express. Nothing has gone wrong yet."},
            {"at": "ghostlight_g3_lounge", "gate": "not flag.gl_crashed", "state": "The train is running through the dark. The party has just come into the lounge car."},
            {"at": "ghostlight_g4_dining", "with": ['tobin_hayward'], "gate": "not flag.gl_crashed", "state": "The train is running. The party has come into the dining car."},
            {"at": "ghostlight_g5_mail", "gate": "not flag.gl_crashed", "state": "The train is running. The party has come into the mail car."},
            {"at": "ghostlight_g6_baggage", "gate": "not flag.gl_crashed", "state": "The train is running. The party has come into the baggage car."},
            {"at": "ghostlight_g7_circus", "gate": "not flag.gl_crashed", "state": "The train is running. The party has come into the circus car."},
            {"at": "ghostlight_g8_tender", "gate": "not flag.gl_crashed", "state": "The party has reached the Tender, the fuel car at the front of the train."},
            {"at": "ghostlight_wreckage", "gate": "flag.gl_crashed", "state": "The Ghostlight Express has crashed. The party stands at the wreck, in a wood in a bowl of land."},
        ],
    },
    "wickermoor": {
        "title": "Wickermoor Village",
        "avoid": "The Connection scenes (Mori Shade, Sister Rain, Holly Aster, Alda Farnum, Hilda Brom, Thomasin Ardor and what they say to a companion) belong to the companions: "
                 "do not stage them. Name villagers only as the place facts do. The Crooked House's inside, the Rookery's boss and Fool's Day's villain are not to be described.",
        "slots": [
            {"at": "wickermoor_village", "gate": "not flag.vessla_slain", "state": "The party is new to the village. The Crooked House on the hill above is still haunted and the storm has not ended.", "focus": "the Oak of Many Faces and the Founder's statue, and the odd feel of a village under a storm"},
            {"at": "wickermoor_green_queen_inn", "gate": "not flag.vessla_slain", "state": "The party is at the inn. The Crooked House on the hill above is still haunted."},
            {"at": "wickermoor_village", "gate": "flag.vessla_slain and not flag.act2_done", "state": "The Crooked House has been cleansed and the storm is over. The party is back in the village, with Act Two still ahead.", "focus": "how the village looks and sounds now the storm has ended: the clocktower, the square, the people about"},
            {"at": "wickermoor_shop_bakery", "with": ['silas_vane'], "gate": "flag.act2_done >= 2", "state": "Two of the five Act Two places are behind the party; the village goes about its business."},
            {"at": "wickermoor_village", "gate": "flag.act2_done >= 5", "state": "All five Act Two places are behind the party. Act Three has begun and the end is near.", "focus": "how small and precious the village feels with the end near: the notice board, the oak, the Green Queen's sign"},
            {"at": "rk_dovecote_r1", "gate": "flag.rk_started and not flag.golub_dead", "state": "The Roving Rookery has come to the valley: a dovecote that walks. Its keeper, a hag called Golub Graygullet, has not been dealt with."},
            {"at": "fd_festival", "with": ['delphine_ravelle'], "gate": "flag.festival_active and not flag.chuckles_dead", "state": "It is the Festival of Fools. The village has swollen to three times its size, hung with ribbon, and there is no way out. Chuckles has not been dealt with."},
            {"at": "fd_silent_church", "with": ['rook_coldwake'], "gate": "flag.festival_active and not flag.chuckles_dead", "state": "The party has found the Silent Church, the one place the festival cannot reach. Chuckles has not been dealt with."},
        ],
    },
    "crooked_house": {
        "title": "The Crooked House",
        "avoid": "The crystal ball in the Parlour (Rook), the bergamot tree in the Conservatory (Tobin) and the stuffed Pomeranian and crow in the Trophy Room (Lucan) are those companions' own scenes: "
                 "do not mention them. Lucan's hound is only called Dreadfang here. Do not describe the thing that haunts the house.",
        "slots": [
            {"at": "druskenvald_estate", "gate": "not flag.vessla_slain", "state": "The party is on the hilltop grounds above the village, in the storm, before going into the house."},
            {"at": "crooked_house_first", "gate": "not flag.seance_done", "state": "The party is on the ground floor of the bent manor. No séance has been held."},
            {"at": "crooked_house_first", "gate": "flag.seance_done and not flag.vessla_slain", "state": "The séance in the parlour has been held and the spirit board has said goodbye for good. The house is still haunted."},
            {"at": "crooked_house_second", "gate": "not flag.vessla_slain", "state": "The party has come up to the second floor of the haunted house."},
            {"at": "crooked_house_second", "gate": "flag.jasper_slain and not flag.vessla_slain", "state": "Filthy Jasper has died in the master bedroom. The house is still haunted."},
            {"at": "crooked_house_third", "gate": "not flag.vessla_slain", "state": "The party has come up to the top floor of the haunted house."},
            {"at": "crooked_house_attic", "with": ['rook_coldwake'], "gate": "not flag.vessla_slain", "state": "The party has reached the hidden attic."},
            {"at": "druskenvald_estate", "gate": "flag.vessla_slain", "state": "Vessla Browntooth is dead. The house has unbent, the storm has ended and the porch is open. The party stands on the grounds again."},
        ],
    },
    "foxwillow": {
        "title": "Foxwillow and the Fields of the Crow",
        "avoid": "Rook and Tobin at the first monument, Lucan and Tobin at the corn's edge, and Tobin and Silas at the burning windmill are optional scenes of their own: do not stage them. "
                 "The Circle of Secrets takes companions' secrets: say nothing about anyone's secret. Raum is not to be described beyond what the facts say.",
        "slots": [
            {"at": "foxwillow", "gate": "not flag.fw_brawl_a_done", "state": "The party has just come over the ridge and seen Foxwillow burning. No fight has been fought yet."},
            {"at": "foxwillow", "gate": "flag.fw_brawl_c_done and not flag.raum_slain", "state": "The three brawls in the square are over. Raum is not yet dealt with."},
            {"at": "fw_windmill", "gate": "not flag.fw_mill_done", "state": "The party has come to the windmill on its bluff. The mill fight has not happened yet."},
            {"at": "fw_store", "gate": "not flag.raum_slain", "state": "The party is in the general store. Raum is not yet dealt with."},
            {"at": "fw_library", "with": ['cordelia_skein'], "gate": "not flag.fw_librarian_done", "state": "The party has come into the town library. The librarian has not been dealt with."},
            {"at": "fw_circle", "gate": "not flag.raum_slain", "state": "The party has come to the Circle of Secrets, at the wall of corn east of the fields."},
            {"at": "fw_maze_j1", "gate": "not flag.raum_slain", "state": "The party is in the first clearing of the corn maze. Raum is not yet dealt with."},
            {"at": "foxwillow", "gate": "flag.raum_slain", "state": "Raum is dead. The fires are dying and the party is back in town."},
        ],
    },
    "crimson_monastery": {
        "title": "The Crimson Monastery",
        "avoid": "The belfry's bell and anything that rings in Delphine's memory is her own scene: nobody mentions the bell to her or about her. Do not describe Renathyr or the monastery's rulers. "
                 "Do not give the monastery's history.",
        "slots": [
            {"at": "mon_ground", "gate": "not flag.renathyr_slain", "state": "The party has come inside the monastery's walls, on its peak."},
            {"at": "mon_upper", "gate": "not flag.renathyr_slain", "state": "The party has come up to the monastery's upper floor."},
            {"at": "mon_stables", "with": ['lucan_houndstooth'], "gate": "not flag.renathyr_slain", "state": "The party is outside the east wall, at the Hunt's stables and kennels."},
            {"at": "mon_bell_tower", "gate": "not flag.renathyr_slain", "state": "The party is climbing the monastery's bell tower."},
            {"at": "mon_sanctum", "with": ['rook_coldwake'], "gate": "not flag.renathyr_slain", "state": "The party has reached the Bloody Sanctum."},
            {"at": "mon_cathedral_moon", "gate": "not flag.renathyr_slain", "state": "The party is in the cathedral under a blood moon."},
            {"at": "mon_ground", "gate": "flag.renathyr_slain", "state": "Renathyr is dead. The party is back in the monastery's grounds, which are quieter."},
        ],
    },
    "drowned_crossroads": {
        "title": "The Drowned Crossroads",
        "avoid": "The green baize table where Silas's bet was taken is his own scene: nobody mentions a particular table, Silas's debt or his creditor. Silas and Delphine's three-card monte is theirs: do not stage it. "
                 "The Grinning Sinner is not to be described beyond what the facts say.",
        "slots": [
            {"at": "dc_trail1", "with": ['lucan_houndstooth'], "gate": "not flag.vander_met", "state": "The party is on the first night's trail through the bayou, on a dry hummock."},
            {"at": "dc_trail3", "gate": "not flag.dc_ghoul_done", "state": "The party has come to the old battlefield, under a green fog."},
            {"at": "dc_murkwater", "gate": "not flag.grinning_sinner_slain", "state": "The party has come to Murkwater Bend, the stilt town."},
            {"at": "dc_fort", "gate": "not flag.screams_done", "state": "The party is inside the Bayou King's fort, among the refugees."},
            {"at": "dc_shack", "with": ['delphine_ravelle'], "gate": "not flag.grinning_sinner_slain", "state": "The party has come into the Marshwinder shack."},
            {"at": "dc_lagoon", "gate": "not flag.grinning_sinner_slain", "state": "The party is at the lagoon, looking at the riverboat casino across the water."},
            {"at": "dc_boat_promenade", "with": ['silas_vane'], "gate": "not flag.grinning_sinner_slain", "state": "The party has come aboard the riverboat casino and stands on its top deck."},
            {"at": "dc_lagoon", "gate": "flag.grinning_sinner_slain", "state": "The Grinning Sinner is dead. The party is back at the lagoon, with the casino quiet."},
        ],
    },
    "skitterdeep_mine": {
        "title": "Skitterdeep Mine",
        "avoid": "What Tobin tastes in the ground at the end of his chapter is his own scene: nobody tastes the earth or names a root. Tobin and Silas's plague-tonic scene is theirs: do not stage it. "
                 "Do not describe Stonoga or what is in the deep level.",
        "slots": [
            {"at": "sk_hills_trail", "gate": "not flag.sk_arrived", "state": "The party is on the rutted hill trail north-west of the village, on its way to the mine."},
            {"at": "sk_camp", "gate": "not flag.stonoga_slain", "state": "The party has come to the abandoned mining camp, with the headframe over its black shaft."},
            {"at": "sk_upper", "gate": "not flag.stonoga_slain", "state": "The party is in the upper workings, below the headframe."},
            {"at": "sk_machine_shop", "with": ['lucan_houndstooth'], "gate": "not flag.stonoga_slain", "state": "The party has come into the machine shop, where the middle room smells of horse and rot."},
            {"at": "sk_warehouse", "gate": "not flag.stonoga_slain", "state": "The party has come into the mine's old store."},
            {"at": "sk_deep", "with": ['cordelia_skein'], "gate": "not flag.stonoga_slain", "state": "The party has gone down to the deep level."},
            {"at": "sk_camp", "gate": "flag.stonoga_slain", "state": "Stonoga is dead. The party is back at the camp above the shaft."},
        ],
    },
    "memorys_rest": {
        "title": "Memory's Rest",
        "avoid": "The crematorium, a dead scholar's ledger and scorched spectacles are Cordelia's own scene, and anything about her making or her clutch is her secret: nobody mentions them. "
                 "Do not name the sanatorium's keepers or say what is done to the patients.",
        "slots": [
            {"at": "mr_shore", "gate": "not flag.lethica_slain", "state": "The party has come out of the marsh onto the rocky Moonsong shore, where a rowboat waits."},
            {"at": "mr_isle", "gate": "not flag.lethica_slain", "state": "The party has landed on the Isle of Mourn and stands before the sanatorium."},
            {"at": "mr_ground", "with": ['cordelia_skein'], "gate": "not flag.lethica_slain", "state": "The party has come into the sanatorium's ground floor."},
            {"at": "mr_upper", "gate": "not flag.lethica_slain", "state": "The party has gone up to the second floor, between the two wings."},
            {"at": "mr_grotto", "with": ['cordelia_skein'], "gate": "not flag.lethica_slain", "state": "The party has reached the Grotto of Tears."},
            {"at": "mr_ground", "gate": "flag.lethica_slain", "state": "Lethica is dead. The party is back on the sanatorium's ground floor."},
            {"at": "mr_isle", "gate": "flag.lethica_slain", "state": "Lethica is dead. The party is out on the island's neglected garden again."},
        ],
    },
    "dawns_gate": {
        "title": "Dawn's Gate and the Howlers Pass",
        "avoid": "Do not describe the monastery's rulers or what happens inside it. Kristoff Gruber is the innkeeper; name no other villager.",
        "slots": [
            {"at": "dawns_gate", "gate": "not flag.renathyr_slain", "state": "The party has come down into Dawn's Gate, a dour mining village below the monastery."},
            {"at": "dg_briar", "gate": "not flag.renathyr_slain", "state": "The party is in the Briar's taproom."},
            {"at": "dg_briar_cellar", "gate": "not flag.renathyr_slain", "state": "The party has gone down to the Briar's cellar."},
            {"at": "dg_briar_upper", "gate": "not flag.renathyr_slain", "state": "The party is upstairs at the Briar, in the small rooms over the taproom."},
            {"at": "mon_pass", "gate": "not flag.renathyr_slain", "state": "The party is climbing the Howlers Pass towards the monastery, whose red windows light the way."},
            {"at": "dawns_gate", "gate": "flag.renathyr_slain", "state": "Renathyr is dead. The party is back in Dawn's Gate, which is quieter."},
            {"at": "mon_pass", "gate": "flag.renathyr_slain", "state": "Renathyr is dead. The party goes back down the pass."},
        ],
    },
    "hartsblight_forest": {
        "title": "Hartsblight Forest",
        "avoid": "Tobin and Lucan each face something of their own in the forest, and Tobin and Cordelia have a scene at the stones: do not stage those or mention anyone's past. "
                 "Do not describe Gorthos or what poisons the forest beyond what the facts say. Fire is Tobin's fear: nobody mocks it.",
        "slots": [
            {"at": "hb_pine_barrens", "with": ['lucan_houndstooth'], "gate": "not flag.gorthos_slain", "state": "The party is among the pines, with rusted traps hidden in the needles."},
            {"at": "hb_infested_outcrop", "gate": "not flag.gorthos_slain", "state": "The party has come to the outcrop with a dead botanists' camp on top."},
            {"at": "hb_noxious_hollow", "with": ['tobin_hayward'], "gate": "not flag.gorthos_slain", "state": "The party has come into the mouldy hollow with a dead trapper at the foot of the beech."},
            {"at": "hb_patient_commune", "gate": "not flag.gorthos_slain", "state": "The party has come to the dead commune at the forest's edge."},
            {"at": "hb_druid_commune", "gate": "not flag.gorthos_slain", "state": "The party has come to the Druids' Commune, with its drum circle."},
            {"at": "hb_altar_of_rot", "with": ['tobin_hayward'], "gate": "not flag.hb_effigy_burned", "state": "The party stands before the Altar of Rot and its towering effigy, which has not been burned."},
            {"at": "hb_wellspring", "gate": "not flag.gorthos_slain", "state": "The party has crossed the river to the ring of standing stones round the green pool."},
            {"at": "hb_druid_commune", "gate": "flag.gorthos_slain", "state": "Gorthos is dead. The party is back at the Druids' Commune and the forest is quieter."},
        ],
    },
    "maidenmist_cemetery": {
        "title": "Maidenmist Cemetery",
        "avoid": "Rook's own stones and ledger are his Thread's: nobody asks about a grave of his. Do not describe the dead things in the depths. "
                 "Yorgrim the gravedigger has gone silent: name him only if the facts do.",
        "slots": [
            {"at": "mm_gate", "with": ['rook_coldwake'], "gate": "", "state": "The party has come to the bent iron gate of the cemetery, between two hooded reapers."},
            {"at": "mm_corpse_road", "gate": "", "state": "The party is walking the Corpse Road through the mist."},
            {"at": "mm_gravestones_a", "gate": "", "state": "The party has taken the shortcut through the endless gravestones."},
            {"at": "mm_cremation_gardens", "gate": "", "state": "The party is walking the Cremation Gardens, among the urns and fountains."},
            {"at": "mm_mausoleum_lanes", "gate": "", "state": "The party is in the Mausoleum Lanes, among small ivy-grown vaults and murky water."},
            {"at": "mm_kings_rest", "with": ['lucan_houndstooth'], "gate": "", "state": "The party has come to King's Rest, the great barrow with the armoured king over it."},
            {"at": "mm_shadestone_sanctuary", "gate": "", "state": "The party has come to the Shadestone Sanctuary, a quiet place among the standing stones."},
            {"at": "mm_necropolis_depths", "with": ['cordelia_skein'], "gate": "not flag.necrolisk_slain", "state": "The party has gone down into the Necropolis Depths. The necrolisk is not yet dealt with."},
        ],
    },
    "crooked_nightmare": {
        "title": "The Crooked Nightmare",
        "avoid": "What Rook hears in the ruins and what Cordelia meets at the crater are their own scenes: nobody hears a voice or names a meteorite's meaning. Everything here is a dream: "
                 "nobody explains it. Do not describe the Crooked Man.",
        "slots": [
            {"at": "nm_estate", "gate": "not flag.nm_chapter_done", "state": "The party stands before the cleansed manor, which has bent crooked again."},
            {"at": "nm_dark_wood", "gate": "not flag.nm_chapter_done", "state": "The party is in an autumn wood under a full moon, with handprints on the trees."},
            {"at": "nm_wedding", "with": ['delphine_ravelle'], "gate": "not flag.nm_chapter_done", "state": "The party has come to a moonless meadow wedding feast."},
            {"at": "nm_oven", "with": ['tobin_hayward'], "gate": "not flag.nm_chapter_done", "state": "The party has come to a room-sized brick oven, blazing."},
            {"at": "nm_bookshelf", "gate": "not flag.nm_chapter_done", "state": "The party has been shrunk and stands on a shelf in the library."},
            {"at": "nm_attic", "gate": "not flag.nm_chapter_done", "state": "The party has come to the swollen attic with its seething walls and clawed cauldron."},
            {"at": "nm_crater", "gate": "not flag.nm_chapter_done", "state": "The party stands in a smoking crater under a clean half-moon."},
            {"at": "nm_estate_ruins", "gate": "flag.crooked_house_destroyed", "state": "The Crooked House has fallen. The party is among the ruins under a clear sky."},
        ],
    },
}


def all_pairs() -> list[tuple[str, str]]:
    return list(combinations(IDS, 2))


def assign() -> dict[str, list[list[str]]]:
    """{region: [speakers per slot]}, deterministic: every companion speaks in every region, pairs spread evenly, a few trios."""
    use: dict[tuple[str, str], int] = {p: 0 for p in all_pairs()}
    out: dict[str, list[list[str]]] = {}
    trio_every = 4
    for r_i, (region, plan) in enumerate(REGIONS.items()):
        slots = plan["slots"]
        chosen: list[list[str]] = []
        covered: set[str] = set()
        for s_i, slot in enumerate(slots):
            want = [c for c in slot.get("with", [])]
            left = len(slots) - s_i
            missing = [c for c in IDS if c not in covered]
            sizes = [3, 2] if (s_i % trio_every == (r_i % trio_every)) else [2, 3]
            best: tuple[float, list[str]] | None = None
            for size in sizes if len(missing) <= 2 * left else [3]:
                from itertools import combinations as comb
                for combo in comb(IDS, size):
                    pairs = list(comb(combo, 2))
                    cost = sum(use[p] for p in pairs) * 1.0
                    cost += -3.0 * len([c for c in combo if c in missing])      # reach the companions this region hasn't heard yet
                    cost += -2.0 * len([c for c in combo if c in want])
                    cost += 0.8 * (size - 2) * (1 if sizes[0] == 2 else -1)       # the trios land where the rotation puts them
                    if best is None or cost < best[0] - 1e-9:
                        best = (cost, list(combo))
            assert best is not None
            combo = best[1]
            for p in combinations(combo, 2):
                use[p] += 1
            covered |= set(combo)
            chosen.append(combo)
        assert covered == set(IDS), (region, covered)
        out[region] = chosen
    return out


if __name__ == "__main__":
    plan = assign()
    use: dict[str, int] = {}
    for region, slots in plan.items():
        print(region, [" + ".join(c.split("_")[0] for c in s) for s in slots])
        for s in slots:
            for p in combinations(sorted(s), 2):
                use["+".join(c.split("_")[0] for c in p)] = use.get("+".join(c.split("_")[0] for c in p), 0) + 1
    print(sorted(use.items(), key=lambda x: -x[1]))
    print(sum(len(p["slots"]) for p in REGIONS.values()), "slots")
