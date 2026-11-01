"""R21 Fool's Day: the cast, shared by the one-shot data builder (build_fools_day.py) and the dialogue assembler (build_fools_day_dialogue.py).
The twelve forced revelers (the digest's default line-up), their three Fateweaving swaps, the seven booths and the costume troupe."""

# costume key: (troupe name, stat block, booth key where the costume lurks, label)
COSTUMES = {
    "bear": ("Bjorn the Horned Bear", "reveler_of_stories_great_beast", "e", "the Horned Bear"),
    "flag": ("Chuckles's own flag-bearer", "herald_of_fools", "g", "the Flag-Bearer"),
    "knight": ("Libro the Singing Tome", "reveler_of_stories_hero", "c", "the Knight and his Tome"),
    "bell": ("Cloche the Chiming Bell", "reveler_of_song_bell", "b", "the Chiming Bell"),
    "hut": ("Chateau the Dancing Manor", "reveler_of_stories_witch", "f", "the Dancing Manor"),
    "hive": ("Apia the Queen Bee", "reveler_of_song_drone", "a", "the Queen Bee's Hive"),
    "stork": ("Cicogna the Stilted Stork", "reveler_of_song_drum", "d", "the Stilted Stork"),
}

# npc id: (name, costume, cell in the festival, swap condition that puts this person in the slot instead of the default, or "" for a default)
REVELERS = {
    "solomon_roderick": ("Solomon Roderick", "bear", (50, 26), ""),
    "hilda_brom": ("Hilda Brom", "bear", (50, 31), ""),
    "wendel_somerton": ("Wendel Somerton", "flag", (44, 37), "default"),
    "alda_farnum": ("Alda Farnum", "flag", (44, 37), "flag.connection_ascendancy"),
    "jean_myriel": ("Jean Myriel", "flag", (44, 37), "flag.connection_immortality"),
    "finneas_trout": ("Finneas Trout", "knight", (42, 23), ""),
    "eleanor_heyling": ("Eleanor Heyling", "knight", (47, 23), ""),
    "doris_squire": ("Doris Squire", "bell", (36, 23), ""),
    "weston_murdoch": ("Weston Murdoch", "bell", (40, 23), ""),
    "holly_aster": ("Holly Aster", "hut", (31, 37), "default"),
    "thomasin_ardor": ("Thomasin Ardor", "hut", (31, 37), "flag.connection_evolution"),
    "morgan": ("Morgan", "hive", (30, 23), ""),
    "baltus_tolliver": ("Baltus Tolliver", "hive", (35, 23), ""),
    "old_rusty": ("Old Rusty", "stork", (30, 26), ""),
    "sister_rain": ("Sister Rain", "stork", (30, 31), ""),
}

# the booth keys: id, name, host npc id, host's stat block, counter cells (x0, y, count, vertical?), host cell
BOOTHS = {
    "a": ("Apiary Aim", "fd_host_apiary", "reveler_of_song_drone", (31, 22, 3, False), (32, 21), "darts"),
    "b": ("Bell and Ball", "fd_host_bell", "reveler_of_song_bell", (37, 22, 3, False), (38, 21), "shell game"),
    "c": ("Riddles and Rhymes", "fd_host_riddles", "reveler_of_stories_hero", (43, 22, 3, False), (44, 21), "riddles"),
    "d": ("Rhythm Hero", "fd_host_rhythm", "reveler_of_song_drum", (29, 27, 3, True), (28, 28), "drums"),
    "e": ("Strongarm", "fd_host_strongarm", "reveler_of_stories_great_beast", (51, 27, 3, True), (52, 28), "arm wrestling"),
    "f": ("Wretched Drink", "fd_host_drink", "reveler_of_stories_witch", (32, 38, 3, False), (33, 39), "drinking"),
    "g": ("Puppet Theater", "fd_host_puppets", "herald_of_fools", (45, 38, 3, False), (46, 39), "puppets"),
}
HOST_NAMES = {
    "fd_host_apiary": ("The Beekeeper", "Reveler of Song in a wicker beekeeper's mask, running the dart cabinets."),
    "fd_host_bell": ("The Bell Sewer", "Reveler of Song in a suit sewn all over with tiny bells."),
    "fd_host_riddles": ("The Blinkered Rider", "Reveler of Stories dressed as a knight, a blinkered horse and a propped book beside him."),
    "fd_host_rhythm": ("The Stilted Drummer", "Reveler of Song on stilts in traveller's clothes, drum sticks at the ready."),
    "fd_host_strongarm": ("The Horned Bear", "Reveler of Stories, a horned bear hung with grim offerings, one table between you."),
    "fd_host_drink": ("The Hen-Legged Hostess", "Reveler of Stories behind a dollhouse on carved chicken legs, pouring foul cups."),
    "fd_host_puppets": ("The Puppet Master", "Herald of Fools behind a tall painted box and its red-ribbon puppets."),
}
