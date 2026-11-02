# Mori Shade brings back the fallen (wickermoor/mori_shade.dialogue: raising_gate, raising, raising_after, raising_closed)

Gemini (gemini-4-argon-medium, "Gemini 4 Argon (Medium)" in the agy log) through ai-bridge, project `ai-bridge` (the `crooked-moon` project refused sends, as for the R12 briefs). `brief.md` is the brief as sent; `reply_raw.json` is the raw reply, untouched.

- Asked: the terms Mori states when the party asks whether one of theirs can be called back (she asks the Ferryman to turn his oar and carries his toll; ten days; ten days of stumbling; a hundred gold for each rung of craft; no gems; the sum shown for each hero first), her closing line after the screen, and the refusal outside the day's hours.
- Edits to the draft: none; all seven lines went in as drafted (one Narrator line drops its g: "smellin'").
- Added by us: `raising_gate` (the hours: `hour >= 7 and hour < 23`), the `services` command, the jumps `-> raising_after` and `-> menu`, and the option "Ask whether one of ours who has fallen can be called back" in Mori's three entrances (her usual menu, the first conversation with the brass plates, Act III's hub).
- Mechanism: no new engine rule. Mori's NPC data holds one `raise_dead` entry for each level 1 to 20 (price 100 gp a level, material 0, `if: hour >= 7 and hour < 23 and level == N`) and a `services_closed` line; the engine takes an entry's own `material` and `text` and an NPC's `services_closed` (engine branch `service-terms`).
- Voice: the seven lines are not voiced yet (no clip until the voice thread reads them).
