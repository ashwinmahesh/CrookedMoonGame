# Ghostlight Express props audit (2026-11-03)

Ashwin (2026-11-03): the Lounge Car's seascape was drawn as a dresser. Every prop in the Ghostlight Express's places (Barrow Hill, the cars g1 to g8, the wreckage) was checked: its id, label and model against the art the props catalog draws for it (art/sprites/props/catalog.json: `ids`, then `models`, then the model's own art). Most of the mismatches came from the `case` model, which the catalog maps to a glass-fronted cabinet. These are the props whose art changed; tests/integration/test_train_cars.gd checks the train's labels against their art.

| Place | Prop | Label | Old art | New art |
|---|---|---|---|---|
| g1_passenger | `g1_seats` | Paired seats | armchair | settee + train_seats |
| g1_passenger | `g1_booths` | The end booths | armchair | (nothing) |
| g1_passenger | `g1_passengers` | The pale passengers | armchair | (nothing) |
| g2_sleeper | `g2_beds` | The made beds | cabinet_glass | bed_small |
| g2_sleeper | `g2_phonograph` | The brass phonograph | cabinet_glass | music_box |
| g2_sleeper | `g2_clothes_chest` | A clothes chest | cabinet_glass | chest |
| g3_lounge | `g3_seascape` | The landscape paintings | cabinet_glass | painting + framed_picture |
| g3_lounge | `g3_paintings` | Landscape paintings | cabinet_glass | painting_row |
| g3_lounge | `g3_banquette` | The lounge banquette | armchair | settee |
| g3_lounge | `g3_banquette_seat` | The banquette, three seats | armchair | settee |
| g4_dining | `g4_booth_n1` | A booth | table | table_set |
| g4_dining | `g4_booth_n2` | A booth | table | table_set |
| g4_dining | `g4_booth_n3` | A booth | table | table_set |
| g4_dining | `g4_booth_s1` | A booth | table | table_set |
| g4_dining | `g4_booth_s2` | A booth | table | table_set |
| g4_dining | `g4_booth_s3` | A booth | table | table_set |
| g4_dining | `g4_menu_cards` | Brass-rimmed menu cards | letters_table | receipt_table |
| g4_dining | `g4_big_booth` | The empty half-booth | table | table_set |
| g4_dining | `g4_silverware` | Polished silverware | oil_lamp | table_set |
| g5_mail | `g5_mailbags` | Canvas mailbags | refuse_mound | sack_pile |
| g5_mail | `g5_sorting_bench` | The sorting bench | table | workbench |
| g6_baggage | `g6_druskenvald_trunks` | The Druskenvalds' trunks | cabinet_glass | trunk |
| g6_baggage | `g6_steamer_trunk` | A steamer trunk | cabinet_glass | chest |
| g6_baggage | `g6_abandoned_luggage` | Abandoned luggage | cabinet_glass | chest_painted |
| g6_baggage | `g6_medical_bag` | A discarded medical bag | cabinet_glass | sack |
| g6_baggage | `g6_iron_ring_loose` | The iron ring in the cinders | cabinet_glass | wall_chains + small:iron_ring |
| g6_baggage | `g6_abandoned_cases` | Abandoned luggage | cabinet_glass | trunk |
| g7_circus | `g7_key_ring` | A ring of keys on a hook | cabinet_glass | curtain_hooks |
| g7_circus | `g7_crates` | Red-and-white crates | cabinet_glass | crate_stack |
| g7_circus | `g7_banners` | Carnival banners | letters_table | banner_regiment |
| g7_circus | `g7_marionette_chest` | A marionette chest | cabinet_glass | toy_chest |
| g7_circus | `g7_trapeze` | The trapeze | (nothing) | rope_coils |
| g7_circus | `g7_punch_chest` | The marionette chest's lid | cabinet_glass | toy_chest |
| g7_circus | `g7_strongman_trunk` | The strongman's trunk | (nothing) | trunk |
| g8_tender | `g8_tank` | The fuel tank | cabinet_glass | great_vat |
| wreckage | `wr_moon` | The Crooked Moon | boulder | (nothing) |
| wreckage | `wr_trunks` | The Druskenvalds' surviving trunks | cabinet_glass | trunk |

## The same mismatch elsewhere (not changed here)

The `case` model draws `cabinet_glass` everywhere, so any other place's trunk, chest or crate whose prop says `model: case` without an `ids` entry is a glass cabinet too. These are the props found that way outside the train, left for the builder or a later lane:

- dc_casino: `dc_casino_cashbox` (The croupier's cashbox)
- dc_murkwater: `dc_pit_stakes` (The bookie's coin box), `dc_crate1` (Crates and coiled rope), `dc_crate3` (Crates and coiled rope), `dc_crate5` (Crates and coiled rope), `dc_crate7` (Crates and coiled rope)
- fw_burnt_cottage: `fw_burnt_cottage_locket` (A blackened box)
- fw_windmill: `fw_isaac_chest` (A cellar chest, shut)
- mon_holy_vein: `mon_holy_vein_alms_box` (A pilgrim's alms box)
- mr_ground: `mr_c_storage` (A linen chest)
- sk_machine_shop: `sk_winch` (The winch drum and its lever box)
- wickermoor_green_queen_inn: `inn_cellar_crate` (A crate marked for the Green Queen)
- wickermoor_mayors_house: `clock_chamber_tool_chest` (The clockmaker's tool chest)
- wickermoor_trading_post: `trading_cellar_crates` (Stacked crates)

## Each car's own look (Ashwin, 2026-11-03: every car looked the same)

The cars' furniture squares (`=`) were all drawn with the manor's set (books on tables, armchairs, candelabra). Each car now has its
own set (catalog `low_cover`, keyed by the place) and its areas their own floor and walls (the location's `floor`/`walls`):

| Car | Floor, walls | Furniture squares | Lamps |
|---|---|---|---|
| g1 Passenger | carpet, wood panelling | red leather seats in facing pairs with ghost passengers in some (TrainSeats) | candle |
| g2 Sleeper | carpet and green wallpaper in the cabins, parquet and panelling in the corridor | berths, a dressing table, trunks | candle |
| g3 Lounge | parquet, carved panelling | armchairs, settees, low tables, the long bar | gaslight |
| g4 Dining | parquet, wainscot | laid tables down both sides | candle |
| g5 Mail | workshop boards, wood panelling | pigeonhole shelves along the walls, mailbags, sorting tables | gaslight |
| g6 Baggage | workshop boards, attic boards | trunks, chests, stacked crates, sacks | ember |
| g7 Circus | planks, striped yellow paper | covered cages, wicker cages, crates, painted chests | carnival yellow |
