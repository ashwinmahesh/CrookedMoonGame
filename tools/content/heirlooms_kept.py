"""Heirlooms and curios whose data the chapter builders no longer write.

Their files in data/magic_items are kept by hand since their powers were built (combat/crooked/cm_heirlooms_*.gd and the
items' `powers`), so a builder run leaves them alone instead of writing its first draft over them. So are the place files of
every floor of a building merged into one place (merge_floors.py): a builder run must not write an old floor back, nor an
old ground floor over the merged place that took its id.
"""
import merge_floors

HAND_KEPT = {
    "amber_birdcage", "shield_of_marius_renathyr", "sword_of_the_crimson_abbot", "cutlass_of_briggsy_kratch",
    "blunderbuss_of_the_grinning_sinner", "mask_of_lethica_nightborne", "veil_of_the_weeping_widow", "staff_of_farryn",
    "idol_of_the_beast_of_blight", "shovel_of_yorgrim", "lantern_of_the_chained_reaper", "revelry_suit",
    "marotte_of_the_lord_of_fools", "cauldron_of_the_vermintoll_coven",
}


def kept(rel):
    """Whether `rel` (a path the builder is about to write) is one of these items' data files."""
    parts = rel.replace("\\", "/").split("/")
    if merge_floors.is_merged_path(rel):
        return True
    return len(parts) == 3 and parts[0] == "data" and parts[1] in ("items", "magic_items") and parts[2][:-5] in HAND_KEPT
