# Realistic textures: what the world has and what it needs (branch `look-full-3d`)

Ashwin's look (2026-11-02): fully 3D, realistic lighting and textures, Modern the only finish. This is the state of the surfaces
after the moods were moved from `toon` to `modern` blocks and the village surfaces took their PBR maps.

## What the engine's Modern finish already uses

- **2K PBR** (albedo, normal `_n`, ORM `_orm`, webp) for every surface the engine's own manifest names: the interiors (wood planks,
  plaster, wainscot, parquet, tile, marble, wallpaper, carpet...), `kit/` (plaster, dressed stone), `dungeon/`, `cave/`, `wild/` (moss,
  heath), `marsh/` (mud), `mountain/`, `tent/`, plus decals (blood, cracks, dust, leaves, moss, mud) with normals. The ground blend
  (edge-matched variants, macro noise, per-surface tint) reads the ORM, and the ground wet or snowy follows the weather.
- **Fixed in this branch (data only):** this game's village surfaces (grass, cobbles, mud road, house wall, slate and thatch roofs)
  borrow the engine's textures but named only the albedo (`art/textures/manifest.json` had no `normal_file` or `orm_file`), so towns,
  the estate and the Express wreck's ground drew colour with no relief or roughness. They now take the `_n` and `_orm` of the same
  2K pictures. The estate's cobbles and the village road show it.
- Lighting: moonlight and lamps cast soft shadows, bloom on, the mood's `modern` block sets ambient, key, fog, mist and the
  ground tint per region. The 19 interior moods that lived only in `toon` blocks were moved into `modern` blocks (the resolved
  look is identical), and the Wickermoor, Express car and Crooked House moods were quieted for a realistic night.

## What is still flat or stylised

1. **Town surfaces are borrowed, not Wickermoor's own:** moss for grass, marsh mud for roads, stone flags for cobbles, plaster
   for walls, dressed stone for slate, heath for thatch. They read as the right material but not as *a* village: the roofs are a
   single tile of stone or heath. The Medieval Village MegaKit (Ashwin's pack, CC0) has a proper set of seamless PBR trims to take
   their place: Plaster (BaseColor, Normal, ORM), Brick, RedBrick, UnevenBrick, FlatTiles, RoundTiles, RoundRocks, RockTrim and
   WoodTrim (BaseColor, Normal, Roughness or ORM), 28 pictures in `glTF/` and 44 in `Textures/`, at the pack's resolution. That is the
   cheapest big step toward a real village: add them as `village/roof_clay`, `village/wall_brick` and so on, one line each in the
   game's texture manifest, and map `arena_themes.village`. They are not copied into the repo yet (the world-rebuild thread owns the
   buildings); it would be about 25 MB through LFS.
2. **The buildings are the engine's kit** (a box with a gabled roof and a painted-on timber look from the textures above). The pack's
   modular pieces (walls, roofs, overhangs, doors, windows, 304 models) would replace them: the world-rebuild thread's job. The
   Crooked House's on-screen warp (BuildingMorph) has to be re-tested on those meshes.
3. **Props and set pieces drawn as sprites** (the catalog's `sprite` entries: the Oak with its eight face decals, the Wicker Man, the
   tarot-table and other small things painted in look P) are flat cel pictures standing in a 3D scene; the Fantasy Props MegaKit
   (211 models) covers dressing, but not trees or the Wicker Man. These need photoreal repaints (the photoreal recipe, as billboards
   with a normal-lit look) or real 3D models.
4. **People are 2D sprites** until the pack people (branch `pack-rig`) or the Tripo figures are placed: the party, foes and most NPCs
   are look-P sprites. The figures' ink is already 0 here.
5. **Foliage:** the engine's pines, dead trees and the six plant leaf cards (cel-painted) read as illustration. The leaf cards wait for
   the photoreal recipe.
6. **Sky and horizon:** the moon's four faces and the nine vistas are cel paintings; they wait for the photoreal repaint (the
   next branch, `look-photoreal`).

## Cheap fixes done now vs left

Done: the PBR keys; the moods' move to `modern` and the Wickermoor, car and Crooked House tuning. Left: the Wickermoor inn and other
interiors still lean red and purple, which comes from the maps' lamp colours and the `tavern` theme's textures, not from the mood
data (I tried quieting `wm_indoors` and the capture did not change); the fix is in the interior theme's palette or in the props'
light colours, a per-map data pass.
