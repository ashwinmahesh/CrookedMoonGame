// Generates realistic trees with EZ-Tree (MIT, dgreenheck) and writes each as glTF (.gltf + .bin) with its bark and leaf
// textures, for the Crooked Moon's plants. Usage: node gen.mjs <out dir>
import * as THREE from 'three';
import fs from 'node:fs';
import path from 'node:path';

THREE.TextureLoader.prototype.load = function (url) { const t = new THREE.Texture(); t.userData.url = url; return t; };
const { Tree } = await import('@dgreenheck/ez-tree');
const out = process.argv[2];
fs.mkdirSync(path.join(out, 'textures'), { recursive: true });

// [id, preset, seed, how: "" | "far" (a lighter copy for the land far off) | "dead" (bare boughs)]
const SPECS = [];
for (const [id, preset, seed] of [
  ['ez_oak_a', 'Oak Large', 11], ['ez_oak_b', 'Oak Medium', 23], ['ez_oak_c', 'Oak Large', 47], ['ez_oak_young', 'Oak Small', 5],
  ['ez_ash_a', 'Ash Large', 3], ['ez_ash_b', 'Ash Medium', 17],
  ['ez_aspen_a', 'Aspen Medium', 9],
  ['ez_pine_a', 'Pine Large', 13], ['ez_pine_b', 'Pine Medium', 29],
]) { SPECS.push([id, preset, seed, '']); SPECS.push([id + '_far', preset, seed, 'far']); }
SPECS.push(['ez_dead_a', 'Oak Medium', 31, 'dead'], ['ez_dead_b', 'Ash Large', 41, 'dead'], ['ez_dead_c', 'Oak Large', 53, 'dead']);

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
for (const [id, preset, seed, how] of SPECS) {
  const tree = new Tree();
  tree.loadPreset(preset);
  tree.options.seed = seed;
  const b = tree.options.branch;
  if (how === 'far') {
    for (const k in b.segments) b.segments[k] = Math.max(3, Math.floor(b.segments[k] / 2));
    for (const k in b.sections) b.sections[k] = Math.max(1, Math.floor(b.sections[k] / 2));
    tree.options.leaves.count = Math.max(4, Math.floor(tree.options.leaves.count * 0.45));
    tree.options.leaves.size *= 1.4;
  }
  if (how === 'dead') {
    tree.options.leaves.count = 0;
    b.levels = Math.min(b.levels, 3);
  }
  tree.generate();
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
  // Scaled to stand HEIGHT world units tall (a unit is a 5 ft square), its foot at the origin, like the game's own plants.
  const HEIGHT = { oak: 4.6, ash: 4.4, aspen: 4.8, pine: 5.2, dead: 4.2 }[id.split('_')[1]] ?? 4.5;
  let top = -1e9, bottom = 1e9;
  for (const g of [tree.branches, tree.leaves]) for (let i = 1; i < g.verts.length; i += 3) { top = Math.max(top, g.verts[i]); bottom = Math.min(bottom, g.verts[i]); }
  const k = HEIGHT / (top - bottom);
  for (const g of [tree.branches, tree.leaves]) for (let i = 0; i < g.verts.length; i += 3) { g.verts[i] *= k; g.verts[i + 1] = (g.verts[i + 1] - bottom) * k; g.verts[i + 2] *= k; }
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
