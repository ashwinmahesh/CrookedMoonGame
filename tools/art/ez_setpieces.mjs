// Generates the Crooked Moon's gnarled set-piece trees with EZ-Tree (MIT, dgreenheck): the raven oak, the ambush lookout
// tree and the bare twisted dead trees that stand in for the old low-poly dead_tree_a and dead_tree_b props. Written as glTF
// (.gltf + .bin) with EZ-Tree's own bark and leaf textures into art/plants/ez_setpiece/ (art/nature/real_nature.json names
// them, CrookedMoonLook's "real_tree" set piece stands them). Run from a scratch folder that has
// `npm install --ignore-scripts @dgreenheck/ez-tree@1.1.0 three@0.170.0`: node ez_setpieces.mjs <out dir>
import * as THREE from 'three';
import fs from 'node:fs';
import path from 'node:path';

THREE.TextureLoader.prototype.load = function (url) { const t = new THREE.Texture(); t.userData.url = url; return t; };
const { Tree } = await import('@dgreenheck/ez-tree');
const out = process.argv[2];
fs.mkdirSync(path.join(out, 'textures'), { recursive: true });

// [id, preset, seed, tweaks, HEIGHT]. Tweaks (all optional): `trunk` the trunk's radius (the presets' trunks are thin against
// their length), `gnarl` and `twist` the curl and twist of each branch level, `length` the first branch's length, `children`
// how many branches each level grows, `levels` caps the branching, `leaves` the share of the leaves kept (0 is bare: EZ-Tree
// always grows a leaf at each deciduous branch tip, so they are cut out of the mesh), `leafSize` scales the leaves, `squeeze`
// narrows the whole tree, `lean` thins its radial segments. HEIGHT is in world units (5 ft each).
const SPECS = [
  ['ez_sp_raven_oak', 'Oak Large', 61, { trunk: 3.6, length: 34, gnarl: [0.22, 0.34, 0.36, 0.12], twist: [0.05, 0.12, 0.18, 0], leaves: 0.14, leafSize: 0.85 }, 5.6],
  ['ez_sp_lookout', 'Pine Large', 19, { trunk: 1.9, gnarl: [0.1, 0.16, 0.1, 0], twist: [0.04, 0.08, 0.1, 0], leaves: 0.4 }, 6.4],
  ['ez_sp_dead_a', 'Oak Medium', 71, { trunk: 2.5, length: 26, gnarl: [0.2, 0.32, 0.34, 0.1], twist: [0.12, 0.2, 0.28, 0], levels: 3, leaves: 0, squeeze: 0.85 }, 3.7],
  ['ez_sp_dead_b', 'Ash Large', 83, { trunk: 2.3, length: 30, gnarl: [0.18, 0.3, 0.34, 0.1], twist: [0.1, 0.22, 0.3, 0], levels: 3, leaves: 0, squeeze: 0.75, lean: 0.7 }, 4.0],
  ['ez_sp_dead_c', 'Oak Large', 97, { trunk: 3.0, length: 24, gnarl: [0.24, 0.36, 0.36, 0.1], twist: [0.14, 0.22, 0.3, 0], levels: 3, leaves: 0, squeeze: 0.7, lean: 0.7 }, 3.5],
  ['ez_sp_dead_d', 'Oak Small', 109, { trunk: 2.0, length: 22, gnarl: [0.25, 0.36, 0.36, 0.1], twist: [0.15, 0.25, 0.3, 0], levels: 3, leaves: 0, squeeze: 0.85 }, 3.1],
];

const written = {};
function saveTexture(tex, name) {
  const url = tex?.userData?.url;
  if (!url) return null;
  if (written[url]) return written[url];
  const m = /^data:image\/(\w+);base64,(.*)$/.exec(url);
  const file = `textures/${name}.${m[1] === 'jpeg' ? 'jpg' : m[1]}`;
  fs.writeFileSync(path.join(out, file), Buffer.from(m[2], 'base64'));
  written[url] = file;
  return file;
}

const report = {};
for (const [id, preset, seed, tw, HEIGHT] of SPECS) {
  const tree = new Tree();
  tree.loadPreset(preset);
  tree.options.seed = seed;
  const b = tree.options.branch;
  if (tw.gnarl) for (const k of [0, 1, 2, 3]) b.gnarliness[k] = tw.gnarl[k];
  if (tw.twist) for (const k of [0, 1, 2, 3]) b.twist[k] = tw.twist[k];
  if (tw.trunk) b.radius[0] = tw.trunk;
  if (tw.length) b.length[0] = tw.length;
  if (tw.levels) b.levels = Math.min(b.levels, tw.levels);
  if (tw.lean) for (const k in b.segments) b.segments[k] = Math.max(3, Math.floor(b.segments[k] * tw.lean));
  if (tw.leafSize) tree.options.leaves.size *= tw.leafSize;
  tree.generate();
  // Keeps a share of the leaves: a leaf is a run of 6 indices (a quad); the rest are cut, and a bare tree loses them all.
  {
    const keep = tw.leaves ?? 1;
    const idx = Array.from(tree.leaves.indices);
    const kept = [];
    let rnd = seed * 7919 + 13;
    const rand = () => { rnd = (rnd * 1103515245 + 12345) & 0x7fffffff; return rnd / 0x7fffffff; };
    for (let i = 0; i + 5 < idx.length; i += 6) if (rand() < keep) kept.push(...idx.slice(i, i + 6));
    // Only the vertices still used stay, so the height below is measured on what is drawn.
    const used = new Map(), V = [], N = [], U = [];
    const L = tree.leaves;
    const remap = kept.map((v) => {
      if (!used.has(v)) { used.set(v, used.size); V.push(L.verts[v * 3], L.verts[v * 3 + 1], L.verts[v * 3 + 2]); N.push(L.normals[v * 3], L.normals[v * 3 + 1], L.normals[v * 3 + 2]); U.push(L.uvs[v * 2], L.uvs[v * 2 + 1]); }
      return used.get(v);
    });
    L.verts = new Float32Array(V); L.normals = new Float32Array(N); L.uvs = new Float32Array(U); L.indices = new Uint32Array(remap);
  }
  const o = tree.options;
  const bark = tree.branchesMesh.material;
  const leaf = tree.leavesMesh.material;
  const barkType = o.bark.type, leafType = o.leaves.type;
  const files = {
    bark_color: saveTexture(bark.map, `bark_${barkType}_color`),
    bark_normal: saveTexture(bark.normalMap, `bark_${barkType}_normal`),
    bark_ao: saveTexture(bark.aoMap, `bark_${barkType}_ao`),
    leaf_color: saveTexture(leaf.map, `leaves_${leafType}`),
  };
  // Scaled to stand HEIGHT world units tall (a unit is a 5 ft square), its foot at the origin.
  let top = -1e9, bottom = 1e9;
  for (const g of [tree.branches, tree.leaves]) for (let i = 1; i < g.verts.length; i += 3) { top = Math.max(top, g.verts[i]); bottom = Math.min(bottom, g.verts[i]); }
  const k = HEIGHT / (top - bottom);
  for (const g of [tree.branches, tree.leaves]) for (let i = 0; i < g.verts.length; i += 3) { g.verts[i] *= k * (tw.squeeze ?? 1); g.verts[i + 1] = (g.verts[i + 1] - bottom) * k; g.verts[i + 2] *= k * (tw.squeeze ?? 1); }
  const parts = [{ g: tree.branches, mat: 0 }];
  if (tree.leaves.indices.length > 0) parts.push({ g: tree.leaves, mat: 1 });
  const chunks = []; let offset = 0;
  const accessors = [], views = [], prims = [];
  function addView(arr, target) {
    const buf = Buffer.from(arr.buffer, arr.byteOffset, arr.byteLength);
    const pad = (4 - (buf.length % 4)) % 4;
    chunks.push(buf, Buffer.alloc(pad));
    views.push({ buffer: 0, byteOffset: offset, byteLength: buf.length, target });
    offset += buf.length + pad;
    return views.length - 1;
  }
  let lo = [1e9, 1e9, 1e9], hi = [-1e9, -1e9, -1e9];
  for (const { g, mat } of parts) {
    const pos = new Float32Array(g.verts), nor = new Float32Array(g.normals), uv = new Float32Array(g.uvs);
    const idx = new Uint32Array(g.indices);
    const pmin = [1e9, 1e9, 1e9], pmax = [-1e9, -1e9, -1e9];
    for (let i = 0; i < pos.length; i += 3) for (let k = 0; k < 3; k++) { pmin[k] = Math.min(pmin[k], pos[i + k]); pmax[k] = Math.max(pmax[k], pos[i + k]); }
    for (let k = 0; k < 3; k++) { lo[k] = Math.min(lo[k], pmin[k]); hi[k] = Math.max(hi[k], pmax[k]); }
    const a = accessors.length;
    accessors.push({ bufferView: addView(pos, 34962), componentType: 5126, count: pos.length / 3, type: 'VEC3', min: pmin, max: pmax });
    accessors.push({ bufferView: addView(nor, 34962), componentType: 5126, count: nor.length / 3, type: 'VEC3' });
    accessors.push({ bufferView: addView(uv, 34962), componentType: 5126, count: uv.length / 2, type: 'VEC2' });
    accessors.push({ bufferView: addView(idx, 34963), componentType: 5125, count: idx.length, type: 'SCALAR' });
    prims.push({ attributes: { POSITION: a, NORMAL: a + 1, TEXCOORD_0: a + 2 }, indices: a + 3, material: mat });
  }
  const bin = Buffer.concat(chunks);
  fs.writeFileSync(path.join(out, `${id}.bin`), bin);
  const images = [], textures = [];
  function tex(file) { if (!file) return undefined; images.push({ uri: file }); textures.push({ source: images.length - 1 }); return { index: textures.length - 1 }; }
  const barkTint = new THREE.Color(o.bark.tint), leafTint = new THREE.Color(o.leaves.tint);
  const barkMat = { name: `bark_${barkType}`, pbrMetallicRoughness: { baseColorTexture: tex(files.bark_color), baseColorFactor: [barkTint.r, barkTint.g, barkTint.b, 1], metallicFactor: 0, roughnessFactor: 0.92 } };
  const n = tex(files.bark_normal); if (n) barkMat.normalTexture = n;
  const ao = tex(files.bark_ao); if (ao) barkMat.occlusionTexture = ao;
  const leafMat = { name: `leaves_${leafType}`, pbrMetallicRoughness: { baseColorTexture: tex(files.leaf_color), baseColorFactor: [leafTint.r, leafTint.g, leafTint.b, 1], metallicFactor: 0, roughnessFactor: 0.8 }, alphaMode: 'MASK', alphaCutoff: 0.5, doubleSided: true };
  const gltf = {
    asset: { version: '2.0', generator: 'EZ-Tree 1.1.0 (dgreenheck, MIT) via gen.mjs' },
    scene: 0, scenes: [{ nodes: [0] }], nodes: [{ name: id, mesh: 0 }],
    meshes: [{ name: id, primitives: prims }],
    materials: [barkMat, leafMat], images, textures, samplers: [],
    accessors, bufferViews: views, buffers: [{ uri: `${id}.bin`, byteLength: bin.length }],
  };
  fs.writeFileSync(path.join(out, `${id}.gltf`), JSON.stringify(gltf));
  report[id] = { preset, seed, triangles: tree.triangleCount, size: hi.map((h, k) => +(h - lo[k]).toFixed(2)), bark: barkType, leaves: leafType };
}
fs.writeFileSync(path.join(out, 'trees.json'), JSON.stringify(report, null, 1));
console.log(JSON.stringify(report, null, 1));
