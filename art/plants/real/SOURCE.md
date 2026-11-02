# Poly Haven leaf pictures for the realistic ground plants

- Source: https://polyhaven.com, fetched through api.polyhaven.com on 2026-11-02: the 1k diffuse and alpha maps of
  fern_02 (Rob Tuytel scanning, Rico Cilliers modelling) and grass_medium_02 (Rico Cilliers)
- Licence: Creative Commons Zero (CC0 1.0), https://creativecommons.org/publicdomain/zero/1.0/ (https://polyhaven.com/license)
- Falls under Ashwin's earlier yes for more Poly Haven CC0 (the realistic wilderness pilot's "okay go").
- What is here: fern_02.png (the fern's five fronds) and grass_medium_02.png (ten grass blades, green and dry), each the
  diffuse map with the alpha map put in as its alpha channel and nothing else changed. The models themselves (6,000 and
  7,800 triangles, 25,000 for grass_medium_01) are not used: they are film-grade, and Flora draws these plants by the
  thousand. world/look/plant_cards.gd cuts single leaves out by their rectangles (art/plants/real_trees.json `textures`)
  and builds each plant from strips of a few triangles.
- For: grass, sedge, reeds, cattails, ferns and bracken in place of the painted ones (world/look/real_trees.gd).
