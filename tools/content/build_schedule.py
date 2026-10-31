#!/usr/bin/env python3
"""The village's clock (R11): the clocktower's bell at each named hour and about ten of the Hollow's customs, played out on the nights the
party is in the village (here_only). Our own words; a ritual picks a prop that is already in the Round (the bonfire, the hare, the turnips,
the oak, the river). data/schedule/wickermoor.json"""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
V = "wickermoor_village"
BELLS = [(7, "the Twilight Hour", "The clocktower strikes seven slow notes for the Twilight Hour, and the shutters on the north row creak open one by one."),
         (11, "the Dusk Hour", "Eleven strokes roll out of the clocktower for the Dusk Hour, and lamps are lit along the lanes."),
         (15, "the Nightfall Hour", "The bell tolls fifteen times for the Nightfall Hour, and the shops begin to put up their boards."),
         (19, "the Evening Hour", "The clocktower strikes the Evening Hour, and the doorsteps fill with carved turnips, each with a candle lit inside."),
         (23, "the Midnight Hour", "Midnight strikes, and every dog in the village raises its head and goes quiet."),
         (3, "the Witching Hour", "The bell tolls the Witching Hour a beat too late, and the last of the lanterns gutters in the Round.")]
RITUALS = [
    ("wicker_race", 20, 2, 1, "Children race wicker animals along the south lane, shrieking, a wicker hare well ahead of the field."),
    ("turnip_faces", 19, 3, 2, "Folk are painting fresh faces onto turnips and setting them over their doors, each in its own scowl."),
    ("river_effigy", 21, 5, 3, "At the river's edge a crowd casts straw effigies onto the black water and watches them turn out of sight."),
    ("bird_song", 7, 4, 1, "From the half-built church comes a day-long song for the bird spirits, many voices, none of them quite together."),
    ("rune_stones", 22, 6, 4, "Under the lych-light a woman sets small runed stones on the graves along the south side, one by one, and says a name over each."),
    ("oak_marriage", 18, 7, 5, "A young couple stands hand in hand before the oak while the mayor mumbles a rite, and the carved faces seem to lean in."),
    ("bonfire_drums", 23, 8, 2, "On the edge of the village a bonfire of bleached bone is lit, and drums start somewhere beyond the light."),
    ("mock_drowning", 21, 9, 6, "Before the river a villager is held under the water just long enough to scare them and then pulled out, laughing and coughing."),
    ("honey_stings", 11, 10, 7, "Two beekeepers press a bee to a neighbour's arm and chant a rhyme to the honey spirits, who are said to like it."),
    ("hare_feast", 0, 11, 8, "In the Round a long table is laid, and people eat bloody hearts of beet and red meat and do not look at one another."),
]
events = []
for hour, name, text in BELLS:
    events.append({"id": f"wm_bell_{hour:02d}", "summary": f"The clocktower strikes {name}.", "hour": hour, "location": V, "here_only": True, "narration": text})
for rid, hour, every, first, text in RITUALS:
    events.append({"id": f"wm_ritual_{rid}", "summary": f"A custom of the Hollow: {rid.replace('_', ' ')}.", "hour": hour, "every_days": every, "first_day": first,
                   "location": V, "here_only": True, "narration": text})
(ROOT / "data/schedule/wickermoor.json").write_text(json.dumps({"id": "wickermoor", "region": "wickermoor", "summary": "The clocktower's hours and the village's customs.", "events": events}, indent=2) + "\n")
print(len(events), "events")
