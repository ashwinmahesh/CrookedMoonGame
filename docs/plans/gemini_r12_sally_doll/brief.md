Reply with plain text only: no JSON, no code fences, no commentary before or after. Do not send messages to anyone else.

You are drafting dialogue for a Halloween D&D video game, "The Crooked Moon" (an original story; use only the names and facts given here and invent no new people, places, monsters or history). The player leads a party of four adventurers; never name, describe, gender or give a face to them. The setting is the Druskenvald estate, a manor on a hill above the village of Wickermoor Hollow, in an autumn that never ends. Tonight the manor has warped into a crooked, haunted house and a storm has shut the party inside. Long ago the head of the house, Eustace Lockwood, murdered his household; their ghosts remain, and each one still guards a keepsake the party needs.

SCENE: the children's room on the second floor: two small beds, a closet, a toy chest, an armoire, a window on the dark. On one little bed sits a wooden doll with a chipped painted face and frayed yarn hair, trembling. A small ghost, Sally Lockwood (speaker id: sally_lockwood), a girl of about eight, lives in the doll; only a fragment of her is left. Something is hiding in the room, a thing from the dark that scratches from a different corner each time; Sally cannot see it, she can only hear it and be afraid. All she wants is for someone to check for monsters (in the closet, under the beds, in the toy chest, in the armoire, outside the window). Once the party has killed the thing, Sally is told it is safe, thanks them, and at last can rest; the doll is then the keepsake the party takes. Somewhere far off, something barks, and Sally feels braver when she hears it (a quiet hint only; do not explain it).

VOICES:
- Sally: small, polite, frightened; a well brought up child. Simple short words; "please", "excuse me", "thank you", "I'm sorry to be a bother"; she whispers; she trusts easily and apologises too much. No baby talk, no phonetic spelling. She does not know she is dead and never says so. Never mention how she died.
- Narrator: the Vagrant, an old train conductor telling this tale afterwards in a folksy, warm, wry Southern drawl: word choice and rhythm (reckon, ain't, folks, a spell, a piece, y'all), and drop a final g ("flickerin'") in about one Narrator line in three, not more. Narrator rules: second person ("you"), present tense, one or two sentences, under about 30 words, concrete senses (a smell, a sound, a cold) over adjectives, no game words (no HP, roll, check, save, level, DC, fight), never tell the player what to feel, never the word "suddenly", no facts the party could not perceive. Never mention a fiddle. Do not use {name}. Gentle with the child: no horror at her expense.

FORMAT (exactly this, nothing else): for each node, a row "~ node_id" followed by one row per line: "speaker_id [mood]: Text". Moods allowed: neutral, smile, angry, afraid, sad, sly, weary (the mood is optional; Narrator lines take none: "Narrator: Text"). Plain punctuation only: straight quotes, no em dashes, no asterisks, no markdown, no stage directions in brackets, no placeholders. A character line is one or two short sentences, under about 25 words. Do not write options, menus or any mechanical rows; the game's wiring is added afterwards. For "interject" rows write exactly "interject class:paladin: Text" with the class named (a hero of that class says it, in the first person, one short kind or uneasy sentence).

NODES TO WRITE (counts are exact):

~ start   (the first words from the doll)
 - 2 Narrator lines: the small room (cold, a toy out of place), then the doll on the bed with its yarn hair stirring as if breathed on, and a child's whisper coming from it.
 - 3 lines by sally_lockwood [afraid]: an apologetic whispered hello; she has been waiting for grown-ups to come; there is something in the room and could someone please check for monsters.
 - 1 interject row by class:paladin, 1 by class:rogue.

~ return   (they come back while the thing still hides)
 - 2 lines by sally_lockwood [afraid]: relieved they came back; she heard the scratching again, in a different corner.

~ who   (asked who she is)
 - 3 lines by sally_lockwood: her name is Sally, the doll is hers and she lives in it now because it is safest; she is not allowed out after supper; her little brother is upstairs and cries a great deal.

~ hiding_talk   (asked what is hiding)
 - 3 lines by sally_lockwood [afraid]: she never sees it, only hears the scratching; it is never in the same place twice; it could be the closet, under either bed, the toy chest, the armoire, or even outside the window.

~ brave   (the party promises to check; this node ends the talk)
 - 2 lines by sally_lockwood [smile]: she says thank you very much, nobody ever checks; far away something barks and she says it makes her feel braver.
 - 1 Narrator line: the doll's chipped face seems to settle, and a very faint bark, far off and warm, comes through the walls.

~ rest   (the party tells her the thing is dead and the room is safe)
 - 2 lines by sally_lockwood [smile]: she hears it is gone; she did not know a room could be so quiet; she thanks them politely and wishes to sleep.
 - 1 Narrator line: the yarn hair lies still and the little chest of the doll stops shivering.

~ rest_end   (the party tells her to sleep; she rests; this is the end of the scene)
 - 2 lines by sally_lockwood [smile]: she says goodnight, and that she will be good; she asks that they please look after her doll for her.
 - 2 Narrator lines: the cold goes out of the room like a held breath let go; the doll in your hands is only a doll, light and a little warm.

~ done   (the room after she has rested)
 - 1 Narrator line: the room is only a room now, two small beds neatly made and a window with the night in it.

~ not_yet   (the party says they have not found the thing)
 - 1 line by sally_lockwood [afraid]: please keep looking, she can still hear it scratching.

Keep every Narrator line fresh: do not repeat an image from another line.
