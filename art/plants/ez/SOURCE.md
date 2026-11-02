# EZ-Tree trees

- Made with EZ-Tree 1.1.0 by Daniel Greenheck (https://github.com/dgreenheck/ez-tree, npm @dgreenheck/ez-tree), MIT License
  (LICENSE-ez-tree.txt beside this file), with three.js 0.170.0
- Made 2026-11-02 with Ashwin's yes ("Go ahead with this") by tools/art/ez_trees.mjs: nine trees from its Oak, Ash, Aspen and
  Pine presets, a lighter far copy of each, and three bare dead trees, scaled to the game's tree heights with their foot at
  the origin, and, for the ground, three bushes (Bush 1, 2 and 3, thinned to about 300 to 1,000 triangles and fitted to the painted
  bush_a, bush_b and heather). The leaves carry a second UV set (how free each vertex is in the wind, and a phase), vertex
  alpha (how much light reaches it) and normals leaning out from the crown, which the wind shader reads
  (world/look/real_leaf.gdshader). textures/ holds EZ-Tree's own bark (colour, normal, AO) and leaf pictures, taken from its package.
- To make them again: in a scratch folder, `npm install --ignore-scripts @dgreenheck/ez-tree@1.1.0 three@0.170.0`, then
  `node <repo>/tools/art/ez_trees.mjs <repo>/art/plants/ez`.
